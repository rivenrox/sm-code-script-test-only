dofile( "$SURVIVAL_DATA/Scripts/game/util/Queue.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_logs.lua" )

HudEventTimer = class( nil )
HudEventTimer.time = 0.0
HudEventTimer.visible = false
HudEventTimer.priority = 0
HudEventTimer.iconType = "farmbot"

local PostCinematicDelay = 3.0

function HudEventTimer.update( self, visible, time )
	if self.destroyed then return end
	if visible ~= nil then self.visible = visible end
	if time ~= nil then self.time = time end
end

function HudEventTimer.destroy( self )
	self.destroyed = true
	self.time = 0.0
	self.visible = false
	self.priority = 0
end

local DefaultNotificationDuration = 4
local QuestNotificationDuration = 3.0

local FadeInDuration = 0.22
local FadeOutDuration = 0.11
local EventTimerDisplayDelay = 0.35
local StringNumberToImage = {
	["0"] = "explosion_timer_number_0.png",
	["1"] = "explosion_timer_number_1.png",
	["2"] = "explosion_timer_number_2.png",
	["3"] = "explosion_timer_number_3.png",
	["4"] = "explosion_timer_number_4.png",
	["5"] = "explosion_timer_number_5.png",
	["6"] = "explosion_timer_number_6.png",
	["7"] = "explosion_timer_number_7.png",
	["8"] = "explosion_timer_number_8.png",
	["9"] = "explosion_timer_number_9.png"
}
local NotificationTypes = {
	acceptQuest = 1,
	completeQuest = 2,
	warning = 3,
	unlock = 4,
	log = 5,
	raidWarning = 6,
	raidFinished = 7,
	generic = 8,
	questReward = 9
}

local LogNotification = {
	[LOGS.log_growlab_01] = { skin = "notification_growlab_1", message = "#{UNLOCKQUEST_ITEM_GROWLABKEY1}" },
	[LOGS.log_growlab_02] = { skin = "notification_growlab_2", message = "#{UNLOCKQUEST_ITEM_GROWLABKEY2}" },
	[LOGS.log_growlab_03] = { skin = "notification_growlab_3", message = "#{UNLOCKQUEST_ITEM_GROWLABKEY3}" },
	[LOGS.log_growlab_04] = { skin = "notification_growlab_4", message = "#{UNLOCKQUEST_ITEM_GROWLABKEY4}" },
	[LOGS.log_growlab_05] = { skin = "notification_growlab_5", message = "#{UNLOCKQUEST_ITEM_GROWLABKEY5}" },
	[LOGS.log_growlab_06] = { skin = "notification_growlab_6", message = "#{UNLOCKQUEST_ITEM_GROWLABKEY6}" },
	[LOGS.log_growlab_07] = { skin = "notification_growlab_7", message = "#{UNLOCKQUEST_ITEM_GROWLABKEY7}" },
	[LOGS.log_accesscard_01] = { skin = "notification_accesscard_01", message = "#{UNLOCKQUEST_ITEM_ACCESSCARD1}" }, -- Underground main elevator level 1
	[LOGS.log_accesscard_02] = { skin = "notification_accesscard_02", message = "#{UNLOCKQUEST_ITEM_ACCESSCARD2}" }, -- Underground main elevator level 2
	[LOGS.log_accesscard_03] = { skin = "notification_accesscard_03", message = "#{UNLOCKQUEST_ITEM_ACCESSCARD3}" }, -- Underground main elevator level 3
	[LOGS.log_accesscard_04] = { skin = "notification_accesscard_04", message = "#{UNLOCKQUEST_ITEM_ACCESSCARD4}" }, -- Underground main elevator level 4	
	[LOGS.log_warehousemasterkey] = { skin = "notification_masterkey", message = "#{UNLOCKQUEST_ITEM_MASTERKEY}" },
	[LOGS.log_warehouse_key] = { skin = "notification_warehousekey", message = "#{UNLOCKQUEST_ITEM_WAREHOUSEKEY}" },
	[LOGS.log_mechanicstation] = { skin = "notification_mechanicstation", message = "#{UNLOCKQUEST_ITEM_MECANICSTATION}" },
	[LOGS.log_hideout] = { skin = "notification_hideout", message = "#{LOG_HIDEOUT_TITLE}" },
	[LOGS.log_garage] = { skin = "notification_garage", message = "#{LOG_GARAGE_TITLE}" },
	[LOGS.log_mininghub] = { skin = "notification_mininghub", message = "#{LOG_MININGHUB_TITLE}" }, 
	[LOGS.log_underground_elevator_key_01] = { skin = "notification_elevatorkey", message = "#{UNLOCKQUEST_ITEM_UNDERGROUND_ELEVATOR}" }, -- Underground elevators level 1 (mining hub)
	[LOGS.log_underground_minerboss_key] = { skin = "notification_elevatorkey", message = "#{UNLOCKQUEST_ITEM_UNDERGROUND_MINERBOSS}" }, -- Placeholder skin
	[LOGS.log_packingstation_vegetable] = { skin = "notification_packingstation_vegetable", message = "#{UNLOCKQUEST_ITEM_PACKINGSTATION_VEGETABLE}" },
	[LOGS.log_packingstation_fruit] = { skin = "notification_packingstation_fruit", message = "#{UNLOCKQUEST_ITEM_PACKINGSTATION_FRUIT}" },
	[LOGS.log_audioBunkRecording] = { skin = "notification_audiolog", message = "#{UNLOCKQUEST_ITEM_AUDIOLOG1}" }, -- Audio log 1
	[LOGS.log_audioBunkRecording2] = { skin = "notification_audiolog", message = "#{UNLOCKQUEST_ITEM_AUDIOLOG2}" }, -- Audio log 2
	[LOGS.log_warehouseRecording] = { skin = "notification_audiolog", message = "#{UNLOCKQUEST_ITEM_AUDIOLOG_WAREHOUSE}" }, -- Audio log 3
	["phone"] = { skin = "notification_phone", message = "#{UNLOCKQUEST_ITEM_PHONE}" },
}

NotificationManager = class( nil )
-- Preset priority list. High number is high priority.
NotificationManager.Priority = {
	RaidCountdown = 10,
	WarehouseCountdown = 20,
}

-- Instant swaps only happen between generic notifications that share the same category.
NotificationManager.GenericCategory = {
	Default = "default",
}

--[[ Server ]]
function NotificationManager.server_onCreate( self )
	assert( g_notificationManagerServer == nil )
	g_notificationManagerServer = self
	self.sv = {}
end

function NotificationManager.Sv_QuestAccepted( questName, questType )
	sm.event.sendToScriptableObject( g_notificationManagerServer.scriptableObject, "sv_e_addNotification", { type = NotificationTypes.acceptQuest, promptText = questName, questType = questType } )
end

function NotificationManager.Sv_QuestCompleted( questName, questType )
	sm.event.sendToScriptableObject( g_notificationManagerServer.scriptableObject, "sv_e_addNotification", { type = NotificationTypes.completeQuest, promptText = questName, questType = questType } )
end

--function NotificationManager.Sv_Warning( icon, duration, message )
--	sm.event.sendToScriptableObject( g_notificationManagerServer.scriptableObject, "sv_e_addNotification", { type = NotificationTypes.warning, icon = icon, duration = duration, promptText = message } )
--end

function NotificationManager.Sv_SchematicUnlocked( itemUuid )
	sm.event.sendToScriptableObject( g_notificationManagerServer.scriptableObject, "sv_e_addNotification", { type = NotificationTypes.unlock, itemUuid = itemUuid } )
end

function NotificationManager.Sv_LogUnlock( notificationName )
	if not LogNotification[notificationName] then
		sm.log.warning( "NotificationManager.Sv_LogUnlock - No notification data for log notification name: "..tostring( notificationName ) )
		return
	end
	sm.event.sendToScriptableObject( g_notificationManagerServer.scriptableObject, "sv_e_addNotification", { type = NotificationTypes.log, promptText = LogNotification[notificationName].message, skin = LogNotification[notificationName].skin } )
end

function NotificationManager.Sv_Generic( text, duration, alert, player )
	sm.event.sendToScriptableObject( g_notificationManagerServer.scriptableObject, "sv_e_addNotification", { type = NotificationTypes.generic, promptText = text, duration = duration, alert = alert, player = player } )
end

--function NotificationManager.Sv_RaidWarning( message )
--	sm.event.sendToScriptableObject( g_notificationManagerServer.scriptableObject, "sv_e_addNotification", { type = NotificationTypes.raidWarning, promptText = message } )
--end

--function NotificationManager.Sv_RaidCompleted()
--	sm.event.sendToScriptableObject( g_notificationManagerServer.scriptableObject, "sv_e_addNotification", { type = NotificationTypes.raidFinished } )
--end

function NotificationManager.sv_e_addNotification( self, notificationData )
	if notificationData.player then
		self.network:sendToClient( notificationData.player, "cl_n_addFrontNotification", notificationData )
		return
	end
	self.network:sendToClients( "cl_n_addFrontNotification", notificationData )
end

--[[ Client ]]
function NotificationManager.client_onCreate( self )
	assert( g_notificationManagerClient == nil )
	g_notificationManagerClient = self
	self.cl = {}
	self.cl.notificationQueue = Queue()
	self.cl.notificationTimer = 0.0
	self.cl.fadeTimer = 0.0
	self.cl.currentNotification = nil
	self.cl.notificationGuiData = nil

	self.cl.nextId = 1
	self.cl.eventTimers = {}
	self.cl.activeEventTimer = nil
	self.cl.eventTimerDisplayDelay = EventTimerDisplayDelay
	self.cl.timerEffectActive = false
	self.cl.timerGuiData = nil
	self.cl.timerGuiPreviouslyVisible = false

	self.cl.notificationGuiDirty = false
	self.cl.player = sm.localPlayer.getPlayer()
	self.cl.postCinematicDelay = false
	self.cl.cinematicTimer = 0.0

	self.cl.explosionAlarm1 = sm.effect.createEffect2D( "audio:event:/props/installations/warehouse/explode/alarm1" );
	self.cl.explosionAlarm2 = sm.effect.createEffect2D( "audio:event:/props/installations/warehouse/explode/alarm2" );
	self.cl.explosionAlarm3 = sm.effect.createEffect2D( "audio:event:/props/installations/warehouse/explode/alarm3" );

	sm.gui.bindDisplayMessageCallback( "cl_queueEngineMessage" )
end

function NotificationManager.cl_queueEngineMessage( self, text, duration, category )
	self:cl_showNotificationNow( { type = NotificationTypes.generic, promptText = text, duration = duration, category = category or NotificationManager.GenericCategory.Default } )
end

function NotificationManager.Cl_AddGenericNotification( text, duration, alert, category )
	if g_notificationManagerClient then
		g_notificationManagerClient:cl_showNotificationNow( { type = NotificationTypes.generic, promptText = text, duration = duration, alert = alert, category = category or NotificationManager.GenericCategory.Default } )
	end
end

function NotificationManager.Cl_ShowNotificationNow( text, duration, alert, category )
	if g_notificationManagerClient then
		g_notificationManagerClient:cl_showNotificationNow( { type = NotificationTypes.generic, promptText = text, duration = duration, alert = alert, category = category or NotificationManager.GenericCategory.Default } )
	end
end

function NotificationManager.cl_showNotificationNow( self, notificationData )
	if self.cl.currentNotification then
		if self.cl.currentNotification.promptText ~= nil and self.cl.currentNotification.promptText == notificationData.promptText then
			return
		end

		if self.cl.currentNotification.type ~= notificationData.type or self.cl.currentNotification.category ~= notificationData.category then

			notificationData.open = false
			notificationData.front = true
			notificationData.fadeInDone = false

			local categoryPred = function( value )
				return value.type == notificationData.type and value.category == notificationData.category
			end
			if self.cl.notificationQueue:replace( categoryPred, notificationData ) then
				return
			end

			self:cl_n_addFrontNotification( notificationData )
			return
		end
	end
	notificationData.open = false
	notificationData.front = true
	notificationData.fadeInDone = false
	notificationData.duration = notificationData.duration or DefaultNotificationDuration
	if self.cl.notificationGui ~= nil then
		self.cl.notificationGui:close()
		self.cl.notificationGui = nil
	end
	self.cl.currentNotification = notificationData
	self.cl.fadeTimer = 0.0
	self.cl.notificationTimer = 0.0
end

function NotificationManager.Cl_AddQuestRewardNotification( itemUuid )
	if g_notificationManagerClient then
		g_notificationManagerClient:cl_n_addFrontNotification( { type = NotificationTypes.questReward, itemUuid = itemUuid } )
	end
end

function NotificationManager.Cl_AddRaidWarningNotification( message )
	if g_notificationManagerClient then
		g_notificationManagerClient:cl_n_addFrontNotification( { type = NotificationTypes.raidWarning, promptText = message } )
	end
end

function NotificationManager.client_onUpdate( self, dt )

	if self.cl.player and self.cl.player.clientPublicData.cutsceneCameraData then
		self.cl.postCinematicDelay = true
	end

	if self.cl.postCinematicDelay then
		self.cl.cinematicTimer = self.cl.cinematicTimer + dt
		if self.cl.cinematicTimer >= PostCinematicDelay then
			self.cl.postCinematicDelay = false
			self.cl.cinematicTimer = 0.0
		end
	end

	if self.cl.currentNotification == nil then
		if not self.cl.notificationQueue:empty() and not self.cl.postCinematicDelay then -- TODO add param for showing over active gui or not
			self.cl.currentNotification = self.cl.notificationQueue:pop()
			if self.cl.currentNotification.questType then
				self.cl.currentNotification.duration = QuestNotificationDuration
			else
				self.cl.currentNotification.duration = self.cl.currentNotification.duration or DefaultNotificationDuration
			end
		end
	end

	if self.cl.currentNotification and self.cl.postCinematicDelay then
		self.cl.currentNotification.open = false
		self.cl.currentNotification.effectActivated = false
		self.cl.currentNotification.fadeInDone = false
		if self.cl.notificationGui ~= nil then
			self.cl.notificationGui:close()
			self.cl.notificationGui = nil
		end
		return
	end

	if self.cl.currentNotification ~= nil then
		if self.cl.currentNotification.open == false then
			self.cl.currentNotification.open = true
			self:cl_createGuiData()
			self:cl_setTypeData()
			self.cl.notificationGuiDirty = true
			self.cl.fadeTimer = 0.0
			self.cl.notificationTimer = 0.0
		end
		if not self.cl.currentNotification.fadeInDone then
			self.cl.fadeTimer = self.cl.fadeTimer + dt
			local alpha = clamp( lerp( 0.0, 1.0, self.cl.fadeTimer / FadeInDuration ), 0.0, 1.0 )
			self.cl.holder.Alpha = alpha
			self.cl.notificationGuiDirty = true
			if alpha >= 1.0 then
				self.cl.currentNotification.fadeInDone = true
				self.cl.fadeTimer = 0.0
			end
		elseif self.cl.notificationTimer < self.cl.currentNotification.duration then
			self.cl.notificationTimer = self.cl.notificationTimer + dt

		elseif self.cl.notificationTimer >= self.cl.currentNotification.duration then
			self.cl.fadeTimer = self.cl.fadeTimer + dt
			local alpha = clamp( lerp( 1.0, 0.0, self.cl.fadeTimer / FadeOutDuration ), 0.0, 1.0 )
			self.cl.holder.Alpha = alpha
			self.cl.notificationGuiDirty = true
			if alpha <= 0.0 then
				self.cl.fadeTimer = 0.0
				self.cl.currentNotification = nil
				self.cl.notificationGui:close()
				self.cl.notificationGui = nil
			end
		end
	end

	if self.cl.notificationGuiDirty and self.cl.notificationGui ~= nil then
		self.cl.notificationGuiDirty = false
		self.cl.notificationGui:render( self.cl.notificationGuiData )
		if not self.cl.currentNotification.effectActivated then
			local backgroundEffectWidget = self.cl.notificationGui:getWidget( "BackgroundImageEffectBox" )
			self.cl.currentNotification.effectActivated = true
			if self.cl.currentNotification.type == NotificationTypes.warning then
				backgroundEffectWidget:startEffect( "raidwarning" )
			elseif self.cl.currentNotification.type == NotificationTypes.acceptQuest then
				if self.cl.currentNotification.questType == "main" then
					backgroundEffectWidget:startEffect( "acceptmain" )
				elseif self.cl.currentNotification.questType == "farmer" then
					backgroundEffectWidget:startEffect( "acceptfarmer" )
				elseif self.cl.currentNotification.questType == "vault" then
					backgroundEffectWidget:startEffect( "acceptfarmer" ) -- TODO: replace with "acceptvault" when vault particle effect exists
				else
					backgroundEffectWidget:startEffect( "acceptside" )
				end
			elseif self.cl.currentNotification.type == NotificationTypes.completeQuest then
				if self.cl.currentNotification.questType == "main" then
					backgroundEffectWidget:startEffect( "completemain" )
				elseif self.cl.currentNotification.questType == "farmer" then
					backgroundEffectWidget:startEffect( "completefarmer" )
				elseif self.cl.currentNotification.questType == "vault" then
					backgroundEffectWidget:startEffect( "completefarmer" ) -- TODO: replace with "completevault" when vault particle effect exists
				else
					backgroundEffectWidget:startEffect( "completeside" )
				end
			elseif self.cl.currentNotification.type == NotificationTypes.unlock then
				backgroundEffectWidget:startEffect( "unlockbase" )
			elseif self.cl.currentNotification.type == NotificationTypes.log then
				backgroundEffectWidget:startEffect( "log_unlock" )
			elseif self.cl.currentNotification.type == NotificationTypes.raidWarning then
				if self.cl.currentNotification.promptText == "#{RAID_WARNING_MESSAGE}" then
					backgroundEffectWidget:startEffect( "raidwarning" )
				else
					backgroundEffectWidget:startEffect( "raidfailed" )
				end
			elseif self.cl.currentNotification.type == NotificationTypes.raidFinished then
				backgroundEffectWidget:startEffect( "raidfinished" )
			elseif self.cl.currentNotification.type == NotificationTypes.questReward then
				backgroundEffectWidget:startEffect( "unlockbase" )
			end
		end
	end

	-- Timers

	if self.cl.timerGui ~= nil and self.cl.notificationGui == nil then
		-- Select the active event timer and remove destroyed event timers
		local activeEventTimer
		local validEventTimers = {}
		for eventTimerId, eventTimer in pairs( self.cl.eventTimers ) do
			if not eventTimer.destroyed then
				validEventTimers[eventTimerId] = eventTimer
				if eventTimer.visible and ( activeEventTimer == nil or eventTimer.priority > activeEventTimer.priority ) then
					activeEventTimer = eventTimer
				end
			end
		end
	
		self.cl.eventTimers = validEventTimers
		
		-- Play activation effect for the selected event timer
		local showEventTimerGui = false
		if activeEventTimer and self.cl.activeEventTimer and self.cl.activeEventTimer.id == activeEventTimer.id then
			if self.cl.eventTimerDisplayDelay == EventTimerDisplayDelay then
				self.cl.timerEffectActive = true
				local backgroundEffectWidget = self.cl.timerGui:getWidget( "BackgroundImageEffectBox" )

				if backgroundEffectWidget:isEffectPlaying( "destruction_warning" ) then
					backgroundEffectWidget:stopEffect( "destruction_warning" )
				elseif backgroundEffectWidget:isEffectPlaying( "raid_warning" ) then
					backgroundEffectWidget:stopEffect( "raid_warning" )
				end
				local timerEffectWidget = self.cl.timerGui:getWidget( "TimerHolderEffectBox" )
				timerEffectWidget:startEffect( "destruction_warning_init" )
				if self.cl.activeEventTimer.iconType == "explosion" then
					backgroundEffectWidget:startEffect( "destruction_warning" )
					self.cl.timerIcon.Skin = "notification_warning_icon_explosion"
				elseif self.cl.activeEventTimer.iconType == "farmbot" then
					backgroundEffectWidget:startEffect( "raid_warning" )
					self.cl.timerIcon.Skin = "notification_warning_icon_farmbot"
				end
				self.cl.timerIcon.Visible = true
			end
			self.cl.eventTimerDisplayDelay = math.max( self.cl.eventTimerDisplayDelay - dt, 0 )
			showEventTimerGui = self.cl.eventTimerDisplayDelay <= 0
		else
			self.cl.eventTimerDisplayDelay = EventTimerDisplayDelay
		end
		self.cl.activeEventTimer = activeEventTimer
	

		if not self.cl.activeEventTimer or self.cl.activeEventTimer.iconType ~= "explosion" or not showEventTimerGui then
			if self.cl.explosionAlarm1 ~= nil then
				self.cl.explosionAlarm1:stop()
			end
			if self.cl.explosionAlarm2 ~= nil then
				self.cl.explosionAlarm2:stop()
			end
			if self.cl.explosionAlarm3 ~= nil then
				self.cl.explosionAlarm3:stop()
			end
		end

		-- Display the selected event timer
		if showEventTimerGui then
			local timerTime = clamp( activeEventTimer.time, 0.0, 100 * 60.0 - FLT_EPSILON )

			if self.cl.activeEventTimer.iconType == "explosion" then
				local total = WAREHOUSE_DESTRUCTION_TICKS / 40.0
				local level = 3.0 - math.floor( timerTime / total * 3.0 )
	
				if level == 1 then
					if not self.cl.explosionAlarm1:isPlaying() then
						self.cl.explosionAlarm1:start()
					end
					if self.cl.explosionAlarm2 ~= nil then
						self.cl.explosionAlarm2:stop()
					end
					if self.cl.explosionAlarm3 ~= nil then
						self.cl.explosionAlarm3:stop()
					end
				elseif level == 2 then
					if not self.cl.explosionAlarm2:isPlaying() then
						self.cl.explosionAlarm2:start()
					end
					if self.cl.explosionAlarm1 ~= nil then
						self.cl.explosionAlarm1:stop()
					end
					if self.cl.explosionAlarm3 ~= nil then
						self.cl.explosionAlarm3:stop()
					end
				elseif level == 3 then
					if not self.cl.explosionAlarm3:isPlaying() then
						self.cl.explosionAlarm3:start()
					end
					if self.cl.explosionAlarm1 ~= nil then
						self.cl.explosionAlarm1:stop()
					end
					if self.cl.explosionAlarm2 ~= nil then
						self.cl.explosionAlarm2:stop()
					end
				end
			end

			local milliseconds = timerTime % 1.0
			local seconds = ( timerTime - milliseconds ) % 60.0
			local minutes = ( timerTime - ( seconds + milliseconds ) ) / 60
			local text = string.format( "%02i", minutes )..string.format( "%02i", seconds )..string.format( "%02i", milliseconds * 100 ) -- Cuts off the thousandths to match with gui
	
			local image = StringNumberToImage[text:sub( 6, 6 )]
			if image then
				self.cl.secondHundreths.ImageTexture = image
			end
			image = StringNumberToImage[text:sub( 5, 5 )]
			if image then
				self.cl.secondTenths.ImageTexture = image
			end
			image = StringNumberToImage[text:sub( 4, 4 )]
			if image then
				self.cl.secondOnes.ImageTexture = image
			end
			image = StringNumberToImage[text:sub( 3, 3 )]
			if image then
				self.cl.secondTens.ImageTexture = image
			end
			image = StringNumberToImage[text:sub( 2, 2  )]
			if image then
				self.cl.minuteOnes.ImageTexture = image
			end
			image = StringNumberToImage[text:sub( 1, 1 )]
			if image then
				self.cl.minuteTens.ImageTexture = image
			end
		end
		self.cl.timerHolder.Visible = showEventTimerGui
		if showEventTimerGui or showEventTimerGui ~= self.cl.timerGuiPreviouslyVisible then
			self.cl.timerGui:render( self.cl.timerGuiData )
			self.cl.timerGuiPreviouslyVisible = showEventTimerGui
		end
	elseif self.cl.timerGuiPreviouslyVisible and self.cl.notificationGui ~= nil and self.cl.activeEventTimer then
		local backgroundEffectWidget = self.cl.timerGui:getWidget( "BackgroundImageEffectBox" )
		backgroundEffectWidget:stopEffect( "destruction_warning" )
		local timerEffectWidget = self.cl.timerGui:getWidget( "TimerHolderEffectBox" )
		timerEffectWidget:stopEffect( "destruction_warning_init" )
		self.cl.timerEffectActive = false
		if self.cl.activeEventTimer.iconType == "explosion" then
			self.cl.timerIcon.Skin = "notification_warning_icon_explosion"
		elseif self.cl.activeEventTimer.iconType == "farmbot" then
			self.cl.timerIcon.Skin = "notification_warning_icon_farmbot"
		end
		self.cl.timerHolder.Visible = false
		self.cl.timerGui:render( self.cl.timerGuiData )
		self.cl.timerGuiPreviouslyVisible = false
		self.cl.eventTimerDisplayDelay = EventTimerDisplayDelay
	end
	if self.cl.timerEffectActive and self.cl.notificationGui ~= nil then
		self.cl.timerEffectActive = false
		local backgroundEffectWidget = self.cl.timerGui:getWidget( "BackgroundImageEffectBox" )
		backgroundEffectWidget:stopEffect( "destruction_warning" )
		local timerEffectWidget = self.cl.timerGui:getWidget( "TimerHolderEffectBox" )
		timerEffectWidget:stopEffect( "destruction_warning_init" )
	end
end

function NotificationManager.cl_createGuiData( self )
	if self.cl.currentNotification.front then
		self.cl.notificationGui = sm.jsonGui.createGui( { layer = "LuaNotification", isInteractive = false, needsCursor = false, isHud = true } )
	else
		self.cl.notificationGui = sm.jsonGui.createGui( { layer = "Wallpaper", isInteractive = false, needsCursor = false, isHud = true } )
	end
	self.cl.notificationGuiData = sm.json.open( "$SURVIVAL_DATA/Gui/JsonGuis/GenericNotificationJson.gui" )
	self.cl.holder = FindWidget( self.cl.notificationGuiData, "Holder" )
	self.cl.backgroundImage = FindWidget( self.cl.notificationGuiData, "BackgroundImage" )
	self.cl.icon = FindWidget( self.cl.notificationGuiData, "Icon" )
	self.cl.textHolder = FindWidget( self.cl.notificationGuiData, "TextHolder" )
	self.cl.headlineText = FindWidget( self.cl.notificationGuiData, "HeadlineText" )
	self.cl.promptText = FindWidget( self.cl.notificationGuiData, "PromptText" )
	self.cl.genericHolder = FindWidget( self.cl.notificationGuiData, "GenericHolder" )
	self.cl.genericTop = FindWidget( self.cl.notificationGuiData, "GenericTop" )
	self.cl.genericText = FindWidget( self.cl.notificationGuiData, "GenericText" )
	self.cl.raidWarningText = FindWidget( self.cl.notificationGuiData, "RaidWarningText" )
	self.cl.raidWarningHolder = FindWidget( self.cl.notificationGuiData, "RaidWarningHolder" )
	self.cl.raidFinishHolder = FindWidget( self.cl.notificationGuiData, "RaidFinishHolder" )
	self.cl.holder.Alpha = 0.0
	self.cl.holder.Visible = true
end

function NotificationManager.cl_setTypeData( self )
	self.cl.backgroundImage.Visible = true
	self.cl.icon.Visible = true
	self.cl.textHolder.Visible = true
	self.cl.genericHolder.Visible = false
	self.cl.raidWarningHolder.Visible = false
	self.cl.raidFinishHolder.Visible = false
	if self.cl.currentNotification.type == NotificationTypes.acceptQuest then
		if self.cl.currentNotification.questType == "main" then
			self.cl.backgroundImage.Skin = "notification_mainquest_base"
			self.cl.icon.Skin = "notification_mainquest_icon"
			self.cl.headlineText.Caption = "#{MAIN_QUEST}"
		elseif self.cl.currentNotification.questType == "farmer" then
			self.cl.backgroundImage.Skin = "notification_farmquest_base"
			self.cl.icon.Skin = "notification_farmquest_icon"
			self.cl.headlineText.Caption = "#{FARMER_QUEST}"
		elseif self.cl.currentNotification.questType == "vault" then
			self.cl.backgroundImage.Skin = "notification_vaultquest_base"
			self.cl.icon.Skin = "notification_vaultquest_icon"
			self.cl.headlineText.Caption = "#{VAULT_QUEST}"
		else
			self.cl.backgroundImage.Skin = "notification_sidequest_base"
			self.cl.icon.Skin = "notification_sidequest_icon"
			self.cl.headlineText.Caption = "#{SIDE_QUEST}"
		end
		self.cl.promptText.Caption = self.cl.currentNotification.promptText
		self.cl.promptText.Visible = true
	elseif self.cl.currentNotification.type == NotificationTypes.completeQuest then
		if self.cl.currentNotification.questType == "main" then
			self.cl.backgroundImage.Skin = "notification_mainquest_base"
			self.cl.icon.Skin = "notification_mainquest_icon_clear"
			self.cl.headlineText.Caption = "#{MAIN_QUEST}"
		elseif self.cl.currentNotification.questType == "farmer" then
			self.cl.backgroundImage.Skin = "notification_farmquest_base"
			self.cl.icon.Skin = "notification_farmquest_icon_clear"
			self.cl.headlineText.Caption = "#{FARMER_QUEST}"
		elseif self.cl.currentNotification.questType == "vault" then
			self.cl.backgroundImage.Skin = "notification_vaultquest_base"
			self.cl.icon.Skin = "notification_vaultquest_icon_clear"
			self.cl.headlineText.Caption = "#{VAULT_QUEST}"
		else
			self.cl.backgroundImage.Skin = "notification_sidequest_base"
			self.cl.icon.Skin = "notification_sidequest_icon_clear"
			self.cl.headlineText.Caption = "#{SIDE_QUEST}"
		end
		self.cl.promptText.Caption = "#{COMPLETE}"
		self.cl.promptText.Visible = true
	elseif self.cl.currentNotification.type == NotificationTypes.unlock then
		self.cl.backgroundImage.Skin = "notification_unlock_schematic"
		self.cl.icon.Skin = "ImageBox"
		self.cl.headlineText.Caption = "#{UNLOCKED_CAPS}"
		local resource, group, name = sm.gui.getItemIconFromUuid( self.cl.currentNotification.itemUuid )
		self.cl.icon.ImageResource = resource
		self.cl.icon.ImageGroup = group
		self.cl.icon.ImageName = name
		self.cl.promptText.Caption = sm.shape.getShapeUpperCaseTitle( self.cl.currentNotification.itemUuid )
		self.cl.promptText.Visible = true
	elseif self.cl.currentNotification.type == NotificationTypes.log then
		self.cl.backgroundImage.Skin = "notification_unlock_logbook"
		self.cl.headlineText.Caption = "#{UNLOCKQUEST_ITEM_NOTIFICATIONTITLE}"
		self.cl.icon.Skin = self.cl.currentNotification.skin
		self.cl.promptText.Caption = self.cl.currentNotification.promptText
		self.cl.promptText.Visible = true
	elseif self.cl.currentNotification.type == NotificationTypes.warning then
		self.cl.backgroundImage.Skin = "notification_warning_base"
		self.cl.promptText.Caption = self.cl.currentNotification.promptText
		self.cl.promptText.Visible = true
		if self.cl.currentNotification.icon == "farmbot" then
			self.cl.icon.Skin = "notification_warning_icon_farmbot"
		elseif self.cl.currentNotification.icon == "explosion" then
			self.cl.icon.Skin = "notification_warning_icon_explosion"
		end
	elseif self.cl.currentNotification.type == NotificationTypes.generic then
		if self.cl.currentNotification.alert then
			self.cl.genericTop.Skin = "notification_alert"
		end
		self.cl.backgroundImage.Visible = false
		self.cl.icon.Visible = false
		self.cl.textHolder.Visible = false
		self.cl.genericHolder.Visible = true
		self.cl.genericText.Caption = self.cl.currentNotification.promptText
	elseif self.cl.currentNotification.type == NotificationTypes.raidWarning then
		self.cl.backgroundImage.Skin = "notification_raidwarning_base"
		self.cl.raidWarningText.Caption = self.cl.currentNotification.promptText
		self.cl.icon.Visible = false
		self.cl.raidWarningHolder.Visible = true
		self.cl.textHolder.Visible = false
	elseif self.cl.currentNotification.type == NotificationTypes.raidFinished then
		self.cl.backgroundImage.Skin = "notification_raidsuccess_base"
		self.cl.raidFinishHolder.Visible = true
		self.cl.icon.Visible = false
		self.cl.textHolder.Visible = false
	elseif self.cl.currentNotification.type == NotificationTypes.questReward then
		self.cl.backgroundImage.Skin = "notification_unlock_outfit"
		self.cl.icon.Skin = "ImageBox"
		self.cl.headlineText.Caption = "#{UNLOCKED_CAPS}"
		self.cl.icon.ImageResource = "CustomizationIconMap"
		self.cl.icon.ImageGroup = "CustomizationIconMap"
		if type( self.cl.currentNotification.itemUuid ) == "string" then
			self.cl.icon.ImageName = self.cl.currentNotification.itemUuid.."_male"
			self.cl.promptText.Caption = sm.localPlayer.getGarmentUpperCaseTitle( sm.uuid.new( self.cl.currentNotification.itemUuid ) )
		else
			self.cl.icon.ImageName = tostring( self.cl.currentNotification.itemUuid ).."_male"
			self.cl.promptText.Caption = sm.localPlayer.getGarmentUpperCaseTitle( self.cl.currentNotification.itemUuid )
		end
		self.cl.promptText.Visible = true
	else
		sm.log.error( "Notification manager recieved a unhandled type: ", self.cl.currentNotification.type )
	end
end

function NotificationManager.cl_n_addFrontNotification( self, notificationData )
	notificationData.open = false
	notificationData.front = true
	notificationData.fadeInDone = false

	local pred = function( value )
		return notificationData.promptText == value.promptText
	end
	if notificationData.promptText ~= nil and ( ( self.cl.currentNotification and pred( self.cl.currentNotification ) ) or self.cl.notificationQueue:contains( pred ) ) then
		return
	end
	self.cl.notificationQueue:push( notificationData )
end

function NotificationManager.cl_n_addRearNotification( self, notificationData )
	notificationData.open = false
	notificationData.front = false

	local pred = function( value )
		return notificationData.promptText == value.promptText
	end
	if notificationData.promptText ~= nil and ( ( self.cl.currentNotification and pred( self.cl.currentNotification ) ) or self.cl.notificationQueue:contains( pred ) ) then
		return
	end
	self.cl.notificationQueue:push( notificationData )
end

function NotificationManager.Cl_CreateEventTimer( priority, iconType )
	if g_notificationManagerClient then
		return g_notificationManagerClient:cl_createEventTimer( priority, iconType )
	end
	return nil
end

function NotificationManager.cl_createEventTimer( self, priority, iconType )
	local eventTimer = HudEventTimer()
	eventTimer.priority = priority
	eventTimer.id = self.cl.nextId
	eventTimer.iconType = iconType
	self.cl.eventTimers[self.cl.nextId] = eventTimer
	self.cl.nextId = self.cl.nextId + 1
	if self.cl.timerGui == nil then
		self.cl.timerGui = sm.jsonGui.createGui( { layer = "Wallpaper", isInteractive = false, needsCursor = false, isHud = true } )
		self.cl.timerGuiData = sm.json.open( "$SURVIVAL_DATA/Gui/JsonGuis/GenericNotificationJson.gui" )
		self.cl.timerHolder = FindWidget( self.cl.timerGuiData, "Holder" )
		self.cl.timerBackground = FindWidget( self.cl.timerGuiData, "BackgroundImage" )
		self.cl.timerIcon = FindWidget( self.cl.timerGuiData, "Icon" )
		self.cl.timerPanel = FindWidget( self.cl.timerGuiData, "TimerHolder" )
		self.cl.textHolder = FindWidget( self.cl.timerGuiData, "TextHolder" )
		self.cl.minuteTens = FindWidget( self.cl.timerGuiData, "MinuteTens" )
		self.cl.minuteOnes = FindWidget( self.cl.timerGuiData, "MinuteOnes" )
		self.cl.secondTens = FindWidget( self.cl.timerGuiData, "SecondTens" )
		self.cl.secondOnes = FindWidget( self.cl.timerGuiData, "SecondOnes" )
		self.cl.secondTenths = FindWidget( self.cl.timerGuiData, "SecondTenths" )
		self.cl.secondHundreths = FindWidget( self.cl.timerGuiData, "SecondHundreths" )
		self.cl.textHolder.Visible = false
		self.cl.timerBackground.Skin = "notification_warning_base"
		self.cl.timerBackground.Visible = true
		self.cl.timerPanel.Visible = true
		self.cl.timerGuiPreviouslyVisible = true
		self.cl.timerGui:render( self.cl.timerGuiData )
	end
	return eventTimer
end