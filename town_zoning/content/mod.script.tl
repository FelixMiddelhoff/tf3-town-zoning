
local mod = {}

-- The choices are handed to the game script in baseConfig.locations.town.populationDensity (unused after map generation):
--   1000 + 1 when the space of the removed zones is split among the kept zones
--   1000 + 2 when the tutorial is on (then the game script changes nothing)
--   1000 + 4 when one of the three former estate mods is active (then Town Zoning stays off)
mod.preRunFn = function(captureParams, _configDict : {{string, string}}, allModParams : {string : {string : integer}}, baseConfig : BaseConfig)
	local params = allModParams["felix_town_zoning_1"]
	local choice = params and params["removed"] or 1
	local split = choice ~= 2

	local tutorialOn = false
	local globalParams = allModParams[""]
	if globalParams and globalParams["guideSystemConfig.tutorial"] == 2 then
		tutorialOn = true
	end

	-- the three former estate mods must be off: they would change the same towns
	local oldMods = { "felix_residential_estate_towns_1", "felix_commercial_estate_towns_1", "felix_industrial_estate_towns_1" }
	for _, oldId in ipairs(oldMods) do
		if allModParams[oldId] ~= nil then
			log.message("TownZoning WARNING: the mod " .. oldId .. " is active. Deactivate it, it replaces the same towns.")
		end
	end

	local oldActive = false
	for _, oldId in ipairs(oldMods) do
		if allModParams[oldId] ~= nil then
			oldActive = true
		end
	end

	local channel = 1000
	if oldActive then
		channel = channel + 4
	end
	if split then
		channel = channel + 1
	end
	if tutorialOn then
		channel = channel + 2
	end
	baseConfig.locations.town.populationDensity = channel

	log.message("TownZoning: removed zones choice=" .. tostring(choice) .. " tutorial=" .. tostring(tutorialOn) .. " channel=" .. tostring(channel))
end

return mod
