dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"
dofile "$SURVIVAL_DATA/Scripts/game/managers/WorldManager.lua"

TileStorageManager = class( nil )

local SaveTickInterval = 10

function TileStorageManager.GetWorldAndPositionFromObject( userdataObject )
	local world, worldPosition
	if type( userdataObject ) == "Character" then
		world = userdataObject:getWorld()
		worldPosition = userdataObject.worldPosition
	elseif type( userdataObject ) == "Harvestable" then
		world = userdataObject:getWorld()
		if userdataObject:isKinematic() then
			worldPosition = userdataObject.initialPosition
		else
			worldPosition = userdataObject.worldPosition
		end
	elseif type( userdataObject ) == "Interactable" then
		if userdataObject.body then
			world = userdataObject.body:getWorld()
		end
		if userdataObject.shape then
			worldPosition = userdataObject.shape.worldPosition
		end
	end
	return world, worldPosition
end

function TileStorageManager.server_onCreate( self )
	g_tileStorageManager = self
	self.sv = {}
	self.sv.tileStorageKeys = {}
	self.sv.tileStorage = {}
	self.sv.tileStorageDirtyList = {}
	self.sv.tileStorageSyncList = {}

	self.sv.saveTimer = Timer()
	self.sv.saveTimer:start( SaveTickInterval )
	self.sv.saveTimer.count = SaveTickInterval

	self.sv.eventRegistry = {}


















end

function TileStorageManager.Sv_Save()
	if g_tileStorageManager then
		g_tileStorageManager:sv_save()
	end
end

function TileStorageManager.sv_save( self )
	local next = next
	if next( self.sv.tileStorageDirtyList ) ~= nil then
		for tileStorageKey, _ in pairs( self.sv.tileStorageDirtyList ) do
			if self.sv.tileStorageSyncList[tileStorageKey] then
				sm.storage.saveAndSync( tileStorageKey, self.sv.tileStorage[tileStorageKey] )
			else
				sm.storage.save( tileStorageKey, self.sv.tileStorage[tileStorageKey] )
			end
		end
		self.sv.tileStorageDirtyList = {}
		self.sv.tileStorageSyncList = {}
	end
end

function TileStorageManager.sv_e_save( self )
	self:sv_save()
end

--------------------------------------------------------------------------------

function TileStorageManager.Sv_GetTileStorageKeyFromCell( world, x, y )
	assert( sm.isServerMode(), "TileStorageManager.Sv_GetTileStorageKeyFromCell was called from client context" )
	if world:isIndoor() then
		return CalculateIndoorTileStorageKey( world.id )
	end
	local tileStorageKey = CalculateTileStorageKey( world.id, x, y )
	if tileStorageKey == nil then
		if world.publicData and world.publicData.type == "UndergroundWorld" then
			sm.log.error( "TileStorageManager.Sv_GetTileStorageKeyFromCell was called for an UndergroundWorld, but no tile storage key could be calculated. Probably because storage keys in cave areas require a world position." )
		else
			sm.log.error( "TileStorageManager.Sv_GetTileStorageKeyFromCell was called, but a tile storage key could not be calculated. World ID: " .. tostring( world.id ) .. " x: " .. tostring( x ) .. " y: " .. tostring( y ) )
		end
	end
	return tileStorageKey
end

function TileStorageManager.Sv_GetTileStorageKeyFromPosition( world, position )
	assert( sm.isServerMode(), "TileStorageManager.Sv_GetTileStorageKeyFromPosition was called from client context" )
	if world:isIndoor() then
		return CalculateIndoorTileStorageKey( world.id )
	end
	local cellX = math.floor( position.x / 64 )
	local cellY = math.floor( position.y / 64 )
	local tileStorageKey = CalculateTileStorageKey( world.id, cellX, cellY )
	if tileStorageKey == nil and world.publicData and world.publicData.type == "UndergroundWorld" then
		tileStorageKey = CalculateCavePocketKey( world.id, position )
	end
	return tileStorageKey
end

function TileStorageManager.Sv_GetTileStorageKeyFromObject( userdataObject )
	assert( sm.isServerMode(), "TileStorageManager.Sv_GetTileStorageKeyFromObject was called from client context" )
	if userdataObject and isAnyOf( type( userdataObject ), { "Character", "Harvestable", "Interactable" } ) then
		local world, worldPosition = TileStorageManager.GetWorldAndPositionFromObject( userdataObject )
		if world and worldPosition then
			return TileStorageManager.Sv_GetTileStorageKeyFromPosition( world, worldPosition )
		end
		return nil
	end
	sm.log.warning( "Tried to get tile storage key for an unsupported type: " .. type( userdataObject ) )
	return nil
end

--------------------------------------------------------------------------------

function TileStorageManager.Sv_GetTileStorage( tileStorageKey )
	if g_tileStorageManager then
		return g_tileStorageManager:sv_getTileStorage( tileStorageKey )
	end
end

function TileStorageManager.sv_getTileStorage( self, tileStorageKey )
	assert( sm.isServerMode(), "TileStorageManager function sv_getTileStorage was called from client context" )
	if self.sv.tileStorage[tileStorageKey] == nil then
		self.sv.tileStorage[tileStorageKey] = sm.storage.load( tileStorageKey ) or {}
	end
	return self.sv.tileStorage[tileStorageKey]
end

--------------------------------------------------------------------------------

function TileStorageManager.Sv_ClearTileStorage( tileStorageKey )
	if g_tileStorageManager then
		g_tileStorageManager:sv_clearTileStorage( tileStorageKey )
	end
end

function TileStorageManager.sv_clearTileStorage( self, tileStorageKey )
	assert( sm.isServerMode(), "TileStorageManager function sv_clearTileStorage was called from client context" )
	self.sv.tileStorage[tileStorageKey] = nil
	if IsEmptyTable( self.sv.tileStorageDirtyList ) then
		sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_save" )
	end
	self.sv.tileStorageDirtyList[tileStorageKey] = true






end

--------------------------------------------------------------------------------

function TileStorageManager.Sv_SetValueInSubTable( tileStorageKey, tableKey, valueKey, value )
	if g_tileStorageManager then
		g_tileStorageManager:sv_setValueInSubTable( tileStorageKey, tableKey, valueKey, value )
	end
end

function TileStorageManager.Sv_SyncedSetValueInSubTable( tileStorageKey, tableKey, valueKey, value )
	if g_tileStorageManager then
		g_tileStorageManager:sv_setValueInSubTable( tileStorageKey .. SYNC_KEY, tableKey, valueKey, value, true )
	end
end

function TileStorageManager.sv_setValueInSubTable( self, tileStorageKey, tableKey, valueKey, value, sync )
	local table = self:sv_getValue( tileStorageKey, tableKey )
	if table == nil then
		table = {}
	elseif type( table ) ~= "table" then
		sm.log.error( "Tilestorage accessed as subtable was not a table! Key:", tableKey )
		return
	end
	table[valueKey] = value
	self:sv_setValue( tileStorageKey, tableKey, table, sync )
end

function TileStorageManager.Sv_SetValue( tileStorageKey, valueKey, value, sync )
	if g_tileStorageManager then
		g_tileStorageManager:sv_setValue( tileStorageKey, valueKey, value, sync )
	end
end

function TileStorageManager.sv_setValue( self, tileStorageKey, valueKey, value, sync )
	assert( sm.isServerMode(), "TileStorageManager function sv_setValue was called from client context" )
	if valueKey == "" then
		sm.log.warning( "TileStorageManager tried to save value to an empty value key" )
		return
	end
	if self.sv.tileStorage[tileStorageKey] == nil then
		self.sv.tileStorage[tileStorageKey] = sm.storage.load( tileStorageKey ) or {}
	end
	self.sv.tileStorage[tileStorageKey][valueKey] = value
	if IsEmptyTable( self.sv.tileStorageDirtyList ) then
		sm.event.sendToScriptableObject( self.scriptableObject, "sv_e_save" )
	end
	self.sv.tileStorageDirtyList[tileStorageKey] = true
	if sync then
		self.sv.tileStorageSyncList[tileStorageKey] = true
	end






end

function TileStorageManager.Sv_GetValueInSubTable( tileStorageKey, tableKey, valueKey )
	if g_tileStorageManager then
		return g_tileStorageManager:sv_getValueInSubTable( tileStorageKey, tableKey, valueKey )
	end
end

function TileStorageManager.Sv_SyncedGetValueInSubTable( tileStorageKey, tableKey, valueKey )
	if g_tileStorageManager then
		return g_tileStorageManager:sv_getValueInSubTable( tileStorageKey .. SYNC_KEY, tableKey, valueKey )
	end
end

function TileStorageManager.sv_getValueInSubTable( self, tileStorageKey, tableKey, valueKey )
	local table = self:sv_getValue( tileStorageKey, tableKey )
	if table == nil then
		return nil
	end
	if type( table ) ~= "table" then
		sm.log.error( "Tilestorage accessed as subtable was not a table! Key:", tableKey )
		return nil
	end
	return table[valueKey]
end

function TileStorageManager.Sv_GetValue( tileStorageKey, valueKey )
	if g_tileStorageManager then
		return g_tileStorageManager:sv_getValue( tileStorageKey, valueKey )
	end
	return nil
end

function TileStorageManager.sv_getValue( self, tileStorageKey, valueKey )
	assert( sm.isServerMode(), "TileStorageManager function sv_getValue was called from client context" )
	if self.sv.tileStorage[tileStorageKey] == nil then
		self.sv.tileStorage[tileStorageKey] = sm.storage.load( tileStorageKey ) or {}
	end
	return self.sv.tileStorage[tileStorageKey][valueKey]
end

--------------------------------------------------------------------------------
function TileStorageManager.sv_onFixedUpdate( self, world )
	if not self.sv.saveTimer:done() then
		self.sv.saveTimer:tick()
	end
	if self.sv.saveTimer:done() then
		self.sv.saveTimer:reset()
		self:sv_save()
	end











































































end



















--------------------------------------------------------------------------------
































































































































function TileStorageManager.Sv_OnCellLoaded( world, x, y )










end

function TileStorageManager.sv_onCellLoaded( self, package )































































end

function TileStorageManager.Sv_OnCellUnLoaded( world, x, y )




end

function TileStorageManager.sv_onCellUnLoaded( self, package )




















end

function TileStorageManager.sv_removeDebugDrawText( self )
	for i, boxId in ipairs( self.sv.debugTileInfo.cleanUp.box ) do
		sm.debugDraw.removeBox( boxId )
		self.sv.debugTileInfo.cleanUp.box[i] = nil
	end
	for i, arrowId in ipairs( self.sv.debugTileInfo.cleanUp.arrow ) do
		sm.debugDraw.removeArrow( arrowId )
		self.sv.debugTileInfo.cleanUp.arrow[i] = nil
	end
	for i, textId in ipairs( self.sv.debugTileInfo.cleanUp.text ) do
		sm.debugDraw.removeText( textId )
		self.sv.debugTileInfo.cleanUp.text[i] = nil
	end
end

----------

----------
function TileStorageManager.Cl_GetTileStorageKeyFromCell( world, x, y )
	if world:isIndoor() then
		return CalculateIndoorTileStorageKey( world.id )
	end
	local tileStorageKey = CalculateTileStorageKey( world.id, x, y )
	if world.clientPublicData and world.clientPublicData.type == "UndergroundWorld" and tileStorageKey == nil then
		sm.log.error( "TileStorageManager.Cl_GetTileStorageKeyFromCell was called for an UndergroundWorld, but no tile storage key could be calculated. Probably because storage keys in cave areas require a world position." )
	elseif tileStorageKey == nil then
		sm.log.error( "TileStorageManager.Cl_GetTileStorageKeyFromCell was called, but a tile storage key could not be calculated. World ID: " .. tostring( world.id ) .. " x: " .. tostring( x ) .. " y: " .. tostring( y ) )
	end
	return tileStorageKey
end

function TileStorageManager.Cl_GetTileStorageKeyFromPosition( world, position )
	if world:isIndoor() then
		return CalculateIndoorTileStorageKey( world.id )
	end
	local cellX = math.floor( position.x / 64 )
	local cellY = math.floor( position.y / 64 )
	local tileStorageKey = CalculateTileStorageKey( world.id, cellX, cellY )
	if tileStorageKey == nil and world.clientPublicData and world.clientPublicData.type == "UndergroundWorld" then
		tileStorageKey = CalculateCavePocketKey( world.id, position )
	end
	return tileStorageKey
end

function TileStorageManager.Cl_GetTileStorageKeyFromObject( userdataObject )
	if userdataObject and isAnyOf( type( userdataObject ), { "Character", "Harvestable", "Interactable" } ) then
		local world, worldPosition = TileStorageManager.GetWorldAndPositionFromObject( userdataObject )
		if world and worldPosition then
			return TileStorageManager.Cl_GetTileStorageKeyFromPosition( world, worldPosition )
		end
		return nil
	end
	sm.log.warning( "Tried to get tile storage key for an unsupported type: " .. type( userdataObject ) )
	return nil
end

function TileStorageManager.Cl_GetValueSynced( tileStorageKey, valueKey )
	assert( not sm.isServerMode(), "TileStorageManager.Cl_GetValueSynced was called from server context" )
	local value = sm.storage.load( tileStorageKey .. SYNC_KEY ) or {}
	return value[valueKey]
end
