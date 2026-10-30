
KinematicManager = class( nil )

function KinematicManager.sv_onCreate( self )
    self.sv = {}
    self.sv.eventRegistry = {}
	self.sv.saved = sm.storage.load( STORAGE_CHANNEL_KINEMATICMANAGER )
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.keyCounterTriggers = {}
		sm.storage.save( STORAGE_CHANNEL_KINEMATICMANAGER, self.sv.saved )
	end
end

function KinematicManager.sv_getOrCreateEventRegister( self, tileStorageKey, eventTrigger )
	self.sv.eventRegistry[tileStorageKey] = self.sv.eventRegistry[tileStorageKey] or {}
	self.sv.eventRegistry[tileStorageKey][eventTrigger] = self.sv.eventRegistry[tileStorageKey][eventTrigger] or { registered = {} }
	return self.sv.eventRegistry[tileStorageKey][eventTrigger]
end

function KinematicManager.Sv_RegisterToEvent( kinematic, tileStorageKey, eventTrigger, tags )
	if g_kinematicManager then
		g_kinematicManager:sv_registerToEvent( kinematic, tileStorageKey, eventTrigger, tags )
	end
end

function KinematicManager.sv_registerToEvent( self, kinematic, tileStorageKey, eventTrigger, tags )
	local activation = self:sv_getOrCreateEventRegister( tileStorageKey, eventTrigger )
	activation.registered[#activation.registered + 1] = { kinematic = kinematic, tags = tags }
end

function KinematicManager.Sv_UnregisterFromEvent( kinematic, tileStorageKey, eventTrigger )
	if g_kinematicManager then
		g_kinematicManager:sv_unregisterFromEvent( kinematic, tileStorageKey, eventTrigger )
	end
end

function KinematicManager.sv_unregisterFromEvent( self, kinematic, tileStorageKey, eventTrigger )
	if self.sv.eventRegistry[tileStorageKey] and self.sv.eventRegistry[tileStorageKey][eventTrigger] then
		local registered = self.sv.eventRegistry[tileStorageKey][eventTrigger].registered
		removeFromArray( registered, function( element ) return element.kinematic == kinematic end )
		if #registered == 0 then
			self.sv.eventRegistry[tileStorageKey][eventTrigger] = nil
		end
	end
end

function KinematicManager.Sv_GetRegistered( tileStorageKey, eventTrigger, tags )
	if g_kinematicManager then
		return g_kinematicManager:sv_getRegistered( tileStorageKey, eventTrigger, tags )
	end
end

function KinematicManager.Sv_IsMoving( tileStorageKey, eventTrigger, tags )
	if g_kinematicManager then
		return g_kinematicManager:sv_isMoving( tileStorageKey, eventTrigger, tags )
	end
	return false
end

local function checkTags( tags, requiredTags )
	if requiredTags then
		for _, tag in ipairs( requiredTags ) do
			if tags == nil or not isAnyOf( tag, tags ) then
				return false
			end
		end
	end
	return true
end

local function isMoving( kinematic )
	return sm.exists( kinematic ) and kinematic.publicData and kinematic.publicData.moving == true
end

function KinematicManager.sv_getRegistered( self, tileStorageKey, eventTrigger, tags )
	if self.sv.eventRegistry[tileStorageKey] and self.sv.eventRegistry[tileStorageKey][eventTrigger] then
		local registered = {}
		if tags then
			for _, val in ipairs( self.sv.eventRegistry[tileStorageKey][eventTrigger].registered ) do
				if checkTags( val.tags, tags ) then
					registered[#registered + 1] = val.kinematic
				end
			end
		else
			for _, val in ipairs( self.sv.eventRegistry[tileStorageKey][eventTrigger].registered ) do
				registered[#registered + 1] = val.kinematic
			end
		end
		if #registered > 0 then
			return registered
		end
	end
	return nil
end

function KinematicManager.sv_isMoving( self, tileStorageKey, eventTrigger, tags )
	assert( sm.isServerMode(), "KinematicManager function sv_isMoving was called from client" )
	local registered = self:sv_getRegistered( tileStorageKey, eventTrigger, tags )
	if registered then
		for _, kinematic in ipairs( registered ) do
			if isMoving( kinematic ) then
				return true
			end
		end
	end
	return false
end

function KinematicManager.Sv_ResetTrack( tileStorageKey, eventTrigger, setTrackData )
	if g_kinematicManager then
		g_kinematicManager:sv_resetTrack( tileStorageKey, eventTrigger, setTrackData )
	end
end

function KinematicManager.sv_resetTrack( self, tileStorageKey, eventTrigger, setTrackData )
	assert( sm.isServerMode(), "KinematicManager function sv_setTrack was called from client" )
	setTrackData = setTrackData or {}
	local registered = self:sv_getRegistered( tileStorageKey, eventTrigger, setTrackData.tags )
	if registered then
		for _, kinematic in ipairs( registered ) do
			if sm.exists( kinematic ) then
				sm.event.sendToHarvestable( kinematic, "sv_e_resetTrack", setTrackData )
			end
		end
	end
end

function KinematicManager.Sv_Activate( tileStorageKey, eventTrigger, activationData )
	if g_kinematicManager then
		g_kinematicManager:sv_activate( tileStorageKey, eventTrigger, activationData )
	end
end

function KinematicManager.sv_activate( self, tileStorageKey, eventTrigger, activationData )
	assert( sm.isServerMode(), "KinematicManager function sv_activate was called from client" )
	activationData = activationData or {}
	if activationData.persistent == true then
		activationData.tick = activationData.tick or sm.game.getServerTick()
		TileStorageManager.Sv_SetValueInSubTable( tileStorageKey, KINEMATIC_EVENTTRIGGER_TABLE, eventTrigger, activationData )
	end
	local registered = self:sv_getRegistered( tileStorageKey, eventTrigger, activationData.tags )
	if registered then
		for _, kinematic in ipairs( registered ) do
			if sm.exists( kinematic ) then
				sm.event.sendToHarvestable( kinematic, "sv_e_activate", activationData )
			end
		end
	end
end

function KinematicManager.Sv_ClearActivation( tileStorageKey, eventTrigger )
	if g_kinematicManager then
		g_kinematicManager:sv_clearActivation( tileStorageKey, eventTrigger )
	end
end

function KinematicManager.sv_clearActivation( self, tileStorageKey, eventTrigger )
	assert( sm.isServerMode(), "KinematicManager function sv_activate was called from client" )
	TileStorageManager.Sv_SetValueInSubTable( tileStorageKey, KINEMATIC_EVENTTRIGGER_TABLE, eventTrigger, nil )
end

function KinematicManager.Sv_DestroyKinematic( tileStorageKey, eventTrigger )
	if g_kinematicManager then
		g_kinematicManager:sv_destroyKinematic( tileStorageKey, eventTrigger )
	end
end

function KinematicManager.sv_destroyKinematic( self, tileStorageKey, eventTrigger )
	assert( sm.isServerMode(), "KinematicManager function sv_activate was called from client" )
	local registered = self:sv_getRegistered( tileStorageKey, eventTrigger )
	if registered then
		for _, kinematic in ipairs( registered ) do
			if sm.exists( kinematic ) then
				sm.event.sendToHarvestable( kinematic, "sv_e_destroy" )
			end
		end
	end
end

function KinematicManager.Sv_OnCellCreated( world, cellX, cellY )
	if g_kinematicManager then
		g_kinematicManager:sv_onCellCreated( world, cellX, cellY )
	end
end

function KinematicManager.sv_onCellCreated( self, world, cellX, cellY )
	local nodes = sm.cell.getNodesByTag( cellX, cellY, "KINEMATIC_KEY_EVENT_TRIGGER", world )
	if not IsEmptyTable( nodes ) then
		local shouldSave = false
		for _,node in ipairs( nodes ) do
			local tileStorageKey = TileStorageManager.Sv_GetTileStorageKeyFromPosition( world, node.position )
			if tileStorageKey then
				if self.sv.saved.keyCounterTriggers[tileStorageKey] == nil then
					self.sv.saved.keyCounterTriggers[tileStorageKey] = {}
				end
				local keyTag = node.params.keyTag
				local keyCount = node.params.keyCount
				local kinematicEventTrigger = node.params.kinematicEventTrigger
				self.sv.saved.keyCounterTriggers[tileStorageKey][keyTag] = { targetCount = keyCount, kinematicEventTrigger = kinematicEventTrigger }
				shouldSave = true
			end
		end
		if shouldSave then
			sm.storage.save( STORAGE_CHANNEL_KINEMATICMANAGER, self.sv.saved )
		end
	end
end

function KinematicManager.Sv_KeyLockCounterSet( tileStorageKey, keyTag, keyCount )
	if g_kinematicManager then
		g_kinematicManager:sv_keyLockCounterSet( tileStorageKey, keyTag, keyCount )
	end
end

function KinematicManager.sv_keyLockCounterSet( self, tileStorageKey, keyTag, keyCount )
	if self.sv.saved.keyCounterTriggers[tileStorageKey] and self.sv.saved.keyCounterTriggers[tileStorageKey][keyTag] then
		if self.sv.saved.keyCounterTriggers[tileStorageKey][keyTag].targetCount == keyCount then
			KinematicManager.Sv_Activate( tileStorageKey, self.sv.saved.keyCounterTriggers[tileStorageKey][keyTag].kinematicEventTrigger )
			self.sv.saved.keyCounterTriggers[tileStorageKey][keyTag] = nil
			if IsEmptyTable( self.sv.saved.keyCounterTriggers[tileStorageKey] ) then
				self.sv.saved.keyCounterTriggers[tileStorageKey] = nil
			end
			sm.storage.save( STORAGE_CHANNEL_KINEMATICMANAGER, self.sv.saved )
		end
	end
end