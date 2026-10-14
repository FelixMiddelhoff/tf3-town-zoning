local CheckIntervalSeconds <const> = 5.0
local SlowCheckIntervalSeconds <const> = 30.0
local MaxRemovalAttempts <const> = 3
local MaxRestoreAttempts <const> = 3
local MinCapacity <const> = 10
local FallbackCapacity <const> = 60

-- zones: 1 = housing (residential), 2 = commerce (commercial), 3 = industry
local ZoneOfLetter <const> = { c = 2, r = 1, i = 3 }

-- typical ratio of the towns of the test savegames: housing 1.4, commerce 1.0, industry 1.0
local Ratios : {number} = { 1.4, 1.0, 1.0 }

-- names of the three former estate mods, each for one zone (name starts with one of the words, any case)
local LegacyKeywords : {{string : any}} = {
	{ zone = 1, words = { "residen", "housing", "wohngebiet", "wohnsiedlung", "wohnviertel", "[res]", "#res" } },
	{ zone = 2, words = { "commerc", "gewerbe" } },
	{ zone = 3, words = { "indus", "fabrik", "factory", "[ind]", "#ind" } },
}

-- the zones a town keeps, from its name: a flag like [c], [cr], [ri] at the start of the name (any order),
-- or a legacy word. nil when the town is not marked.
local flagsOf = function(name : string) : {integer : boolean}
	local lowered = string.lower(name or "")
	local letters = string.match(lowered, "^%s*%[([cri]+)%]")
	if letters and #letters <= 3 then
		local keep : {integer : boolean} = {}
		for letter in string.gmatch(letters, ".") do
			keep[ZoneOfLetter[letter]] = true
		end
		return keep
	end
	for _, entry in ipairs(LegacyKeywords) do
		for _, word in ipairs(entry.words) do
			if string.sub(lowered, 1, #word) == word then
				return { [entry.zone] = true }
			end
		end
	end
	return nil
end

-- the kept zones as a number (1 = housing, 2 = commerce, 4 = industry, summed), to notice a changed flag
local keyOf = function(keep : {integer : boolean}) : integer
	local key = 0
	if keep[1] then key = key + 1 end
	if keep[2] then key = key + 2 end
	if keep[3] then key = key + 4 end
	return key
end

local sizeOf = function(size : number) : number
	if size <= 0 then
		return 1.0
	end
	return size
end

-- new capacities when the space of the removed zones is split among the kept zones, in proportion to their own space.
-- The space of a zone is capacity times size; the kept zones get their size reset to 1, so the capacity is the space.
local splitCaps = function(caps : {integer}, sizes : {number}, keep : {integer : boolean}) : {integer}
	local removedSpace = 0.0
	local keptSpace = 0.0
	local keptCount = 0
	for i = 1, 3 do
		local space = caps[i] * sizeOf(sizes[i])
		if keep[i] then
			keptSpace = keptSpace + space
			keptCount = keptCount + 1
		else
			removedSpace = removedSpace + space
		end
	end

	local result : {integer} = { 0, 0, 0 }
	for i = 1, 3 do
		if keep[i] then
			local space = caps[i] * sizeOf(sizes[i])
			local share = 0.0
			if keptSpace > 0 then
				share = removedSpace * space / keptSpace
			else
				share = removedSpace / keptCount
			end
			local value = math.floor(space + share + 0.5)
			if value < MinCapacity then
				value = MinCapacity
			end
			result[i] = value
		end
	end
	return result
end

-- the capacities of the kept zones stay as they are, the removed zones get zero
local keepCaps = function(caps : {integer}, keep : {integer : boolean}) : {integer}
	local result : {integer} = { 0, 0, 0 }
	for i = 1, 3 do
		if keep[i] then
			result[i] = caps[i]
		end
	end
	return result
end

-- typical size of the towns of this map: the median land use (capacity times size) of every zone,
-- taken from the towns that have all three zones. nil when there is no such town.
local referenceCapacities = function() : {integer}
	local values : {{number}} = { {}, {}, {} }
	api.engine.forEachEntityWithComponent(function(entity : Engine.Entity)
		local town = api.engine.getComponent(entity, api.type.ComponentType.TOWN) as Engine.Component.Town
		if town and town.initialLandUseCapacities and town.sizeFactors then
			local c1 = town.initialLandUseCapacities[1] or 0
			local c2 = town.initialLandUseCapacities[2] or 0
			local c3 = town.initialLandUseCapacities[3] or 0
			if c1 > 0 and c2 > 0 and c3 > 0 then
				local townCaps : {number} = { c1, c2, c3 }
				for i = 1, 3 do
					values[i][#values[i] + 1] = townCaps[i] * sizeOf(town.sizeFactors[i] or 0)
				end
			end
		end
	end, api.type.ComponentType.TOWN)

	if #values[1] == 0 then
		return nil
	end
	local result : {integer} = { 0, 0, 0 }
	for i = 1, 3 do
		table.sort(values[i])
		local middle = values[i][math.floor((#values[i] + 1) / 2)]
		result[i] = math.floor(middle + 0.5)
		if result[i] < MinCapacity then
			result[i] = MinCapacity
		end
	end
	return result
end

-- the capacities saved before the town was converted, nil when none were saved
local savedCaps = function(state2 : {string : number}, e : string) : {integer}
	if (state2["oK" .. e] or 0) ~= 1 then
		return nil
	end
	return {
		math.floor((state2["o1" .. e] or 0) + 0.5),
		math.floor((state2["o2" .. e] or 0) + 0.5),
		math.floor((state2["o3" .. e] or 0) + 0.5),
	}
end

local savedSizes = function(state2 : {string : number}, e : string) : {number}
	return {
		sizeOf(state2["s1" .. e] or 1.0),
		sizeOf(state2["s2" .. e] or 1.0),
		sizeOf(state2["s3" .. e] or 1.0),
	}
end

-- the zones of a stored key (1 = housing, 2 = commerce, 4 = industry)
local keepFromKey = function(key : integer) : {integer : boolean}
	local keep : {integer : boolean} = {}
	keep[1] = key % 2 == 1
	keep[2] = math.floor(key / 2) % 2 == 1
	keep[3] = key >= 4
	return keep
end

-- capacities to restore a converted town to. After a split the town keeps its current total space and gets the
-- original proportions back, so it does not shrink when it was changed during the game. Without a split the kept
-- zones stay as they are and only the removed zones get their original capacities back. nil when nothing was saved.
local restoredCaps = function(state2 : {string : number}, e : string, caps : {integer}, sizes : {number}) : {integer}
	local orig = savedCaps(state2, e)
	if not orig then
		return nil
	end
	local origSizes = savedSizes(state2, e)
	local result : {integer} = { caps[1], caps[2], caps[3] }

	if (state2["sp" .. e] or 0) == 1 then
		local currentSpace = 0.0
		local originalSpace = 0.0
		for i = 1, 3 do
			currentSpace = currentSpace + caps[i] * sizeOf(sizes[i])
			originalSpace = originalSpace + orig[i] * origSizes[i]
		end
		for i = 1, 3 do
			if orig[i] > 0 and originalSpace > 0 then
				local value = math.floor(currentSpace * orig[i] / originalSpace + 0.5)
				if value < MinCapacity then
					value = MinCapacity
				end
				result[i] = value
			end
		end
		log.message("TownZoning: restore space of town " .. e .. " current=" .. tostring(math.floor(currentSpace + 0.5)) .. " original=" .. tostring(math.floor(originalSpace + 0.5)))
	else
		local keep = keepFromKey(state2["k" .. e] or 0)
		for i = 1, 3 do
			if not keep[i] then
				result[i] = orig[i]
			end
		end
	end
	return result
end

-- sizes to restore: after a split the original sizes, otherwise the kept zones keep their current size
local restoredSizes = function(state2 : {string : number}, e : string, sizes : {number}) : {number}
	local origSizes = savedSizes(state2, e)
	if (state2["sp" .. e] or 0) == 1 then
		return origSizes
	end
	local keep = keepFromKey(state2["k" .. e] or 0)
	local result : {number} = { origSizes[1], origSizes[2], origSizes[3] }
	for i = 1, 3 do
		if keep[i] then
			result[i] = sizeOf(sizes[i])
		end
	end
	return result
end

-- state keys per town entity e:
--   "c"..e  0 = untouched, 1 = converted, 2 = restoring the original zones
--   "k"..e  keyOf the kept zones when converted (a changed flag restores the town first)
--   "oK"..e = 1 when the original capacities were saved, "o1".."o3"..e original capacities, "s1".."s3"..e original sizes
--   "t"..e  1 = the kept zones still have to get size 1 (after the split)
--   "r"..e  removal attempts, "a"..e restore attempts
-- The game drops this state when a savegame is loaded without the mod.
local ret : GameScript<{string : number}> = {
	update = function(_userParams : table, state : GameScriptState<{string : number}>, dt : number) : any
		if dt == 0.0 then
			return
		end

		local state2 = state:get() or { elapsed = 0.0 }
		state2.elapsed = (state2.elapsed or 0.0) + dt
		if state2.elapsed < CheckIntervalSeconds then
			state:set(state2)
			return
		end
		state2.elapsed = 0.0

		state2.slowElapsed = (state2.slowElapsed or 0.0) + CheckIntervalSeconds
		local slowNow = false
		if state2.slowElapsed >= SlowCheckIntervalSeconds then
			state2.slowElapsed = 0.0
			slowNow = true
		end

		-- the choices of the mod (see mod.script.tl), read again on every round
		local baseConfig = api.res.getBaseConfig()
		local channel = math.floor(baseConfig.locations.town.populationDensity + 0.5)
		local split = channel % 2 == 1
		local tutorialOn = channel % 4 >= 2
		local disabled = channel % 8 >= 4
		if tutorialOn or disabled then
			-- the tutorial needs its towns, and a former estate mod is active: nothing is changed
			state:set(state2)
			return
		end

		api.engine.forEachEntityWithComponent(function(entity : Engine.Entity)
			local town = api.engine.getComponent(entity, api.type.ComponentType.TOWN) as Engine.Component.Town
			if not (town and town.initialLandUseCapacities and town.sizeFactors) then
				return
			end

			local e = tostring(entity)
			local name = api.engine.util.getEntityName(entity)
			local keep = flagsOf(name)
			local marked = keep ~= nil
			local key = 0
			if keep then
				key = keyOf(keep)
			end
			local phase = state2["c" .. e] or 0

			local caps : {integer} = {
				town.initialLandUseCapacities[1] or 0,
				town.initialLandUseCapacities[2] or 0,
				town.initialLandUseCapacities[3] or 0,
			}
			local sizes : {number} = {
				town.sizeFactors[1] or 0,
				town.sizeFactors[2] or 0,
				town.sizeFactors[3] or 0,
			}
			local removedCap = 0
			for i = 1, 3 do
				if not (keep and keep[i]) then
					removedCap = removedCap + caps[i]
				end
			end

			if phase == 2 then
				-- restoring: wait until the original capacities are back, then set the original sizes
				local orig = savedCaps(state2, e)
				if not orig then
					orig = referenceCapacities() or { FallbackCapacity, FallbackCapacity, FallbackCapacity }
				end
				local allBack = true
				for i = 1, 3 do
					if orig[i] > 0 and caps[i] <= 0 then
						allBack = false
					end
				end
				if allBack then
					log.message("TownZoning: town " .. e .. " '" .. tostring(name) .. "' restored")
					api.cmd.sendCommand(api.cmd.makeTownUpdateSizeCmd(entity, restoredSizes(state2, e, sizes), true))
					state2["c" .. e] = 0
				else
					local attempts = state2["a" .. e] or 0
					state2["a" .. e] = attempts + 1
					if attempts >= MaxRestoreAttempts then
						-- the capacities did not come back: typical size of the towns of this map
						local fallback : {integer} = { caps[1], caps[2], caps[3] }
						local reference = referenceCapacities()
						for i = 1, 3 do
							if orig[i] > 0 and fallback[i] <= 0 then
								if reference then
									fallback[i] = reference[i]
								else
									fallback[i] = math.floor(FallbackCapacity * Ratios[i] + 0.5)
								end
							end
						end
						log.message("TownZoning: fallback capacities for town " .. e)
						api.cmd.sendCommand(api.cmd.makeTownSetInitialLandUseCapacitiesCmd(entity, fallback))
					end
				end

			elseif phase == 1 and (not marked or (state2["k" .. e] or 0) ~= key) then
				-- no flag any more, or another flag: restore the original zones first
				local target = restoredCaps(state2, e, caps, sizes)
				log.message("TownZoning: restoring town " .. e .. " '" .. tostring(name) .. "' originals=" .. tostring(target ~= nil))
				if target then
					api.cmd.sendCommand(api.cmd.makeTownSetInitialLandUseCapacitiesCmd(entity, target))
				else
					local reference = referenceCapacities()
					if reference then
						api.cmd.sendCommand(api.cmd.makeTownSetInitialLandUseCapacitiesCmd(entity, reference))
					else
						api.cmd.sendCommand(api.cmd.makeTownSetInitialLandUseCapacitiesCmd(entity))
					end
				end
				state2["c" .. e] = 2
				state2["a" .. e] = 0

			elseif phase == 1 then
				-- converted: the kept zones get size 1 after a split, and the buildings of the removed zones are asked to go
				if (state2["t" .. e] or 0) == 1 then
					local newSizes : {number} = { sizes[1], sizes[2], sizes[3] }
					for i = 1, 3 do
						if keep[i] then
							newSizes[i] = 1.0
						end
					end
					api.cmd.sendCommand(api.cmd.makeTownUpdateSizeCmd(entity, newSizes, true))
					state2["t" .. e] = 0
				elseif slowNow then
					local built = api.engine.system.townBuildingSystem.getLandUsePersonCapacities(entity)
					local builtRemoved = 0
					for i = 1, 3 do
						if not keep[i] then
							builtRemoved = builtRemoved + (built and built[i] or 0)
						end
					end
					local attempts = state2["r" .. e] or 0
					if builtRemoved > 0 and attempts < MaxRemovalAttempts then
						state2["r" .. e] = attempts + 1
						log.message("TownZoning: removal request " .. tostring(attempts + 1) .. " for town " .. e)
						api.cmd.sendCommand(api.cmd.makeTownUpdateSizeCmd(entity, sizes, true))
					end
				end

			elseif marked and removedCap > 0 then
				-- a new marked town: remember the original zones, then convert
				state2["oK" .. e] = 1
				for i = 1, 3 do
					state2["o" .. tostring(i) .. e] = caps[i]
					state2["s" .. tostring(i) .. e] = sizes[i]
				end
				state2["k" .. e] = key
				state2["sp" .. e] = 0
				state2["c" .. e] = 1
				state2["r" .. e] = 0
				state2["a" .. e] = 0

				local newCaps : {integer}
				if split then
					newCaps = splitCaps(caps, sizes, keep)
					state2["t" .. e] = 1
					state2["sp" .. e] = 1
				else
					newCaps = keepCaps(caps, keep)
				end
				log.message("TownZoning: converting town " .. e .. " '" .. tostring(name) .. "' keep=" .. tostring(key) .. " split=" .. tostring(split) .. " from " .. table.concat({ tostring(caps[1]), tostring(caps[2]), tostring(caps[3]) }, "/") .. " to " .. table.concat({ tostring(newCaps[1]), tostring(newCaps[2]), tostring(newCaps[3]) }, "/"))
				api.cmd.sendCommand(api.cmd.makeTownSetInitialLandUseCapacitiesCmd(entity, newCaps))
			end
		end, api.type.ComponentType.TOWN)

		state:set(state2)
	end,
}

return ret
