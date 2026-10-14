local data : NotificationType<{string : any}> = {}

data.useDataState = function(_params : {string : any}) : NotificationGuiData
	return {
		title = _("Town Zoning is switched off"),
		description = _("A former estate mod (Residential, Commercial or Industrial Estate Towns) is active. Town Zoning changes nothing while it is on. Deactivate the former estate mod and start a new game."),
		icon = "::game_mechanics/notifications/gui/icons/stuck_vehicle.tga",
		iconExplainTooltip = _("Town Zoning is switched off"),
	}
end

return data
