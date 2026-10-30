dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/QuestManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/QuestEntityManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/camera_util.lua" )

EffectManager = class( nil )

local IntroFadeDuration = 1.1
local IntroEndFadeDuration = 1.1
local IntroFadeTimeout = 5.0
local CutsceneBlendInTime = 0.4
local CutsceneBlendInEasing = "easeInOutSine"
local CutsceneBlendOutTime = 0.4
local CutsceneBlendOutEasing = "easeInOutSine"

function EffectManager.server_onCreate( self )
	self.sv = {}
	self.sv.cinematicTeleportNodes = {}
end

function EffectManager.Sv_UpdateTagFilteredEffectsForCell( world, x, y, flags )
	if g_effectManager then
		local params = {}
		params.world = world
		params.x = x
		params.y = y
		params.flags = flags
		sm.event.sendToScriptableObject( g_effectManager.scriptableObject, "sv_e_updateTagFilteredEffectsForCell", params )
	end
end

function EffectManager.sv_e_updateTagFilteredEffectsForCell( self, params )
	self.network:sendToClients( "cl_n_updateTagFilteredEffectsForCell", params )
end

function EffectManager.Sv_UpdateTagFilteredEffectsForTile( world, position, flags )
	if g_effectManager then
		local params = {}
		local xMin, xMax, yMin, yMax = GetTileRanges( position, world.id )
		if xMin == nil or xMax == nil or yMin == nil or yMax == nil then
			sm.log.warning( "EffectManager.Sv_UpdateTagFilteredEffectsForTile - Failed to get tile ranges for position " .. tostring(position) .. " in world " .. tostring(world.id) )
			return
		end
		params.world = world
		params.xMin = xMin
		params.xMax = xMax
		params.yMin = yMin
		params.yMax = yMax
		params.flags = flags
		sm.event.sendToScriptableObject( g_effectManager.scriptableObject, "sv_e_updateTagFilteredEffectsForTile", params )
	end
end

function EffectManager.sv_e_updateTagFilteredEffectsForTile( self, params )
	self.network:sendToClients( "cl_n_updateTagFilteredEffectsForTile", params )
end

--Client

function EffectManager.client_onCreate( self )
    self.cl = {}
    self.cl.worldCellEffects = {}
	self.cl.worldNamedEffects = {}
	self.cl.taggedEffects = {}

	self.namedEffectStates = {}
	self.cl.namedCinematicStates = {}
	self.cl.currentCinematicEffect = nil

	self.cl.eventEffectNodes = {}
	self.cl.worldEffectNodes = {}
	self.cl.worldEffectsNextIds = {}
	self.cl.worldSphereGroups = {}

	self.cl.worldList = {}
    self.cl.loadedWorldCells = {}
    self.cl.unloadedWorldCells = {}

	self.cl.cutsceneBlendIn = nil
	self.cl.cutsceneBlendInFromPosition = nil
	self.cl.cutsceneBlendInFromRotation = nil
	self.cl.cutsceneBlendOut = nil
	self.cl.cutsceneBlendOutFromPosition = nil
	self.cl.cutsceneBlendOutFromRotation = nil

	self.cl.loadingScreenLifted = false
	g_effectManager = self
end

function EffectManager.cl_createEffect( self, world, effectNode )
	local effect = sm.effect.createEffect( effectNode.node.params.effect.name )

	effect:setWorld( world )
	effect:setPosition( effectNode.node.position )
	effect:setRotation( effectNode.node.rotation )
	effect:setScale( effectNode.node.scale )
	if effectNode.node.params.effect.params  then
		for k,v in kvpairs( effectNode.node.params.effect.params ) do
			effect:setParameter(k, v)
		end
	end

	if effectNode.timeOfDay then
		effect:setTimeOfDay( true, effectNode.timeOfDay[1], effectNode.timeOfDay[2], effectNode.timeOfDay[3] )
	end

	if effectNode.autoPlay then
		effect:setAutoPlay( true )
	end

	effectNode.effect = effect
end

function EffectManager.Cl_AlertOnWorldLoadCell( world, x, y )
    if g_effectManager then
        g_effectManager:cl_alertOnWorldLoadCell( world, x, y )
    end
end

function EffectManager.cl_alertOnWorldLoadCell( self, world, x, y )
	if self.cl.worldList[world.id] == nil then
		self.cl.worldList[world.id] = world 
	end

    if self.cl.loadedWorldCells[world.id] == nil then
        self.cl.loadedWorldCells[world.id] = { world = world, cells = {} }
    end
	self.cl.loadedWorldCells[world.id].cells[#self.cl.loadedWorldCells[world.id].cells+1] = { x = x, y = y }
end

function EffectManager.Cl_AlertOnWorldUnloadCell( world, x, y )
    if g_effectManager then
        g_effectManager:cl_alertOnWorldUnloadCell( world, x, y )
    end
end

function EffectManager.cl_alertOnWorldUnloadCell( self, world, x, y )
    if self.cl.unloadedWorldCells[world.id] == nil then
        self.cl.unloadedWorldCells[world.id] = { world = world, cells = {} }
    end
	self.cl.unloadedWorldCells[world.id].cells[#self.cl.unloadedWorldCells[world.id].cells+1] = { x = x, y = y }
end

function EffectManager.Sv_OnCellLoaded( world, x, y )
    if g_effectManager then
        g_effectManager:sv_onCellLoaded( world, x, y )
    end
end

function EffectManager.sv_onCellLoaded( self, world, x, y )
	local cinematicTpNodes = sm.cell.getNodesByTags( x, y, { "CINEMATIC_TELEPORT" }, world )
	local worldId = world.id
	if #cinematicTpNodes > 0 then
		for _, node in ipairs( cinematicTpNodes ) do
			if self.sv.cinematicTeleportNodes[worldId] == nil then
				self.sv.cinematicTeleportNodes[worldId] = {}
			end
			self.sv.cinematicTeleportNodes[worldId][node.params.destinationName] = node
		end
	end
end

function EffectManager.cl_n_updateTagFilteredEffectsForTile( self, params )
	if g_effectManager then
		for x = params.xMin, params.xMax do
			for y = params.yMin, params.yMax do
				self:cl_updateTagFilteredEffectsForCell( params.world, x, y, params.flags )
			end
		end
	end
end

function EffectManager.cl_n_updateTagFilteredEffectsForCell( self, params )
	if g_effectManager then
		g_effectManager:cl_updateTagFilteredEffectsForCell( params.world, params.x, params.y, params.flags )
	end
end

function EffectManager.Cl_UpdateTagFilteredEffectsForCell( world, x, y, flags )
	if g_effectManager then
		g_effectManager:cl_updateTagFilteredEffectsForCell( world, x, y, flags )
	end
end

function EffectManager.cl_updateTagFilteredEffectsForCell( self, world, x, y, flag )
	-- affected effects will either be started or stopped, so begin by stopping all affected effects.

	local nodeTagSearch = { "EFFECT", "~FIRE", "~UNMANAGED_EFFECT" }

	local cellKey = CellKey( x, y )
	for index, filterFlag in ipairs( flag ) do
		local taggedEffects = SafeNestedAccess( self.cl.taggedEffects, world.id, cellKey, filterFlag )
		if taggedEffects then
			for _,effect in ipairs( taggedEffects ) do
				if effect and sm.exists( effect ) then
					effect:stopImmediate()
					effect:destroy()
				end
			end
		end
		table.insert( nodeTagSearch, "*ts:show:"..filterFlag )
		table.insert( nodeTagSearch, "*ts:hide:"..filterFlag )
	end
	local nodes = sm.cell.getNodesByTags( x, y, nodeTagSearch, world )
	self:cl_handleCellNodes( world, x, y, nodes )
end

function EffectManager.cl_onWorldCellLoaded( self, world, x, y )
	local nodes = sm.cell.getNodesByTags( x, y, { "EFFECT", "~FIRE", "~UNMANAGED_EFFECT" }, world )
	self:cl_handleCellNodes( world, x, y, nodes )
end

function EffectManager.Cl_HandleNodesManual( world, x, y, nodes )
	if g_effectManager then
		sm.event.sendToScriptableObject( g_effectManager.scriptableObject, "cl_e_handleNodesManual", { world = world, x = x, y = y, nodes = nodes } )
	end
end

function EffectManager.cl_e_handleNodesManual( self, params )
	self:cl_handleCellNodes( params.world, params.x, params.y, params.nodes )
end

function EffectManager.cl_handleCellNodes( self, world, x, y, nodes )
	if #nodes > 0 then
		local worldId = world.id
			
		if( self.cl.worldSphereGroups[worldId] == nil ) then
			self.cl.worldSphereGroups[worldId] = sm.cullSphereGroup.newCullSphereGroup()
		end

		self.cl.worldCellEffects[worldId] = self.cl.worldCellEffects[worldId] or {}
		self.cl.worldCellEffects[worldId][CellKey( x, y )] = {}
		local effects = self.cl.worldCellEffects[worldId][CellKey( x, y )]
		local tileStorageFlags = nil
		for _,node in ipairs( nodes ) do
			if node.params and node.params.effect then

				local effectNode = {
					effect = nil,
					node = node,
					timeOfDay = node.params.effect.timeOfDay,
					autoPlay = node.params.effect.autoPlay == nil or node.params.effect.autoPlay == true,
					name = node.params.name,
				}

				effects[#effects + 1] = effectNode
				
				-- EffectNode with name are always created and not culled
				if effectNode.name then
					self.cl.worldNamedEffects[worldId] = self.cl.worldNamedEffects[worldId] or {}
					if self.cl.worldNamedEffects[worldId][effectNode.name] == nil then
						self:cl_createEffect( world, effectNode )
						self.cl.worldNamedEffects[worldId][effectNode.name] = { effect = effectNode.effect, position = node.position }
					else
						sm.log.warning( "Duplicate Named Effect found " .. effectNode.name )
					end
				end
				if node.params.eventName then

					if self.cl.eventEffectNodes[worldId] == nil then
						self.cl.eventEffectNodes[worldId] = {}
					end

					if self.cl.eventEffectNodes[worldId][CellKey( x, y )] == nil then
						self.cl.eventEffectNodes[worldId][CellKey( x, y )] = {}
					end

					if self.cl.eventEffectNodes[worldId][CellKey( x, y )][node.params.eventName] == nil then
						self.cl.eventEffectNodes[worldId][CellKey( x, y )][node.params.eventName] = {}
					end

					self:cl_createEffect( world, effectNode )
					self.cl.eventEffectNodes[worldId][CellKey( x, y )][node.params.eventName][#self.cl.eventEffectNodes[worldId][CellKey( x, y )][node.params.eventName] + 1] = effectNode
				else
					if tileStorageFlags == nil then
						local tileStorageKey = TileStorageManager.Cl_GetTileStorageKeyFromPosition( world, node.position )
						if tileStorageKey then
							tileStorageFlags = TileStorageManager.Cl_GetValueSynced( tileStorageKey, TILESTORAGE_FLAGS_TABLE ) or {}
						else
							tileStorageFlags = {}
						end
					end
					
					local shouldShow = ShouldShow( node.tags, tileStorageFlags )

					-- fetch all filterFlag from the node tags.
					local filterFlags = GetAllFilterFlags( node.tags )

					if not IsEmptyTable( filterFlags ) then
						if shouldShow then
							self:cl_createEffect( world, effectNode )
							for filterFlag, _ in pairs( filterFlags ) do
								InitializeNestedTables( self.cl.taggedEffects, worldId, CellKey( x, y ), filterFlag )
								table.insert( self.cl.taggedEffects[worldId][CellKey( x, y )][filterFlag], effectNode.effect )
							end
						end
					else
						if self.cl.worldEffectNodes[worldId] == nil  then
							self.cl.worldEffectNodes[worldId] = {}
						end
						
						if self.cl.worldEffectsNextIds[worldId] then
							effectNode.id = self.cl.worldEffectsNextIds[worldId]
							self.cl.worldEffectsNextIds[worldId] = self.cl.worldEffectsNextIds[worldId] + 1
							self.cl.worldEffectNodes[worldId][effectNode.id] = effectNode
						else
							effectNode.id = 1
							self.cl.worldEffectsNextIds[worldId] = 2
							self.cl.worldEffectNodes[worldId][effectNode.id] = effectNode
						end
	
						local tableParams = {}
						if effectNode.node.params.effect.params  then
							for k,v in kvpairs( effectNode.node.params.effect.params ) do
								tableParams[k]=v
							end
						end
						local effectCullSize = sm.effect.estimateSize( node.params.effect.name, tableParams )
	
						self.cl.worldSphereGroups[worldId]:addSphere( effectNode.id, node.position, effectCullSize )
					end
				end
			end
		end
	end
end

function EffectManager.cl_onWorldCellUnloaded( self, world, x, y )
	local worldId = world.id
	local cellKey = CellKey( x, y )
	local effects = self.cl.worldCellEffects[worldId] and self.cl.worldCellEffects[worldId][cellKey] or nil
	if effects then
		for _, effectNode in ipairs( effects ) do

			if effectNode.name then
				self.cl.worldNamedEffects[worldId][effectNode.name] = nil
			end
			
			if effectNode.id then
				self.cl.worldSphereGroups[worldId]:removeSphere( effectNode.id )
				self.cl.worldEffectNodes[worldId][effectNode.id] = nil
			end

			if effectNode.effect then
				effectNode.effect:destroy()
				effectNode.effect = nil
			end
			if effectNode.node.params then
				if effectNode.node.params.eventName then
					self.cl.eventEffectNodes[worldId][cellKey][effectNode.node.params.eventName] = nil
				end
			end
		end
		self.cl.worldCellEffects[worldId][cellKey] = nil
	end
	local taggedEffects = self.cl.taggedEffects[worldId] and self.cl.taggedEffects[worldId][cellKey] or nil
	if taggedEffects then
		for _,effectList in pairs( self.cl.taggedEffects[worldId][cellKey] ) do
			for _,effect in ipairs( effectList ) do
				if effect and sm.exists( effect ) then
					effect:stopImmediate()
					effect:destroy()
				end
			end
		end
		self.cl.taggedEffects[worldId][cellKey] = nil
	end
end

function EffectManager.Sv_ActivateEventEffect( world, eventName, position )
	if g_effectManager then
		g_effectManager:sv_activateEventEffect( world, eventName, position )
	end
end

function EffectManager.sv_activateEventEffect( self, world, eventName, position )
	local params = {}
	if not world.indoor then
		params.xMin, params.xMax, params.yMin, params.yMax = GetTileRanges( position, world.id )
	end
	params.world = world
	params.eventName = eventName
	params.tileStorageKey = TileStorageManager.Sv_GetTileStorageKeyFromPosition( world, position )
	sm.event.sendToScriptableObject( g_effectManager.scriptableObject, "sv_e_activateEventEffect", params )
end

function EffectManager.sv_e_activateEventEffect( self, params )
	self.network:sendToClients( "cl_n_startEventEffects", params )
end

function EffectManager.Cl_OnLoadingScreenLifted()
    if g_effectManager then
        g_effectManager:cl_onLoadingScreenLifted()
    end
end

function EffectManager.cl_onLoadingScreenLifted( self )
	self.cl.loadingScreenLifted = true
end

function EffectManager.client_onUpdate( self, dt )

	for worldId, cellTable in pairs( self.cl.unloadedWorldCells ) do
		for _, cellInfo in ipairs( cellTable.cells ) do
			self:cl_onWorldCellUnloaded( cellTable.world, cellInfo.x, cellInfo.y )
		end
		self.cl.unloadedWorldCells[worldId].cells = {}
	end

    for worldId, cellTable in pairs( self.cl.loadedWorldCells ) do
        for _, cellInfo in ipairs( cellTable.cells ) do
            self:cl_onWorldCellLoaded( cellTable.world, cellInfo.x, cellInfo.y )
        end
        self.cl.loadedWorldCells[worldId].cells = {}
    end

	for _, world in pairs( self.cl.worldList ) do
		self:cl_worldUpdate( world, dt )
	end
end

function EffectManager.cl_worldUpdate( self, world, dt )
	if self.cl.loadingScreenLifted then
		self:cl_handleCinematics( world, dt )
		self:cl_handleEffectsAndCullSpheres( world )
	end
end

function EffectManager.cl_handleEffectsAndCullSpheres( self, world )
	local worldId = world.id
	
	if self.cl.worldSphereGroups[worldId] == nil  then
		self.cl.worldSphereGroups[worldId] = sm.cullSphereGroup.newCullSphereGroup()
	end

	local rangeMult = sm.render.isOutdoor() and 0.1 or 0.5
	local cullInRange = sm.render.getDrawDistance() * rangeMult
	local cullOutRange = sm.render.getDrawDistance() * rangeMult + 0.5
	
	local character = sm.localPlayer.getPlayer().character
	if sm.exists( character ) and character:getWorld() == world then

		local pos = character:getWorldPosition()
		local remove, add = self.cl.worldSphereGroups[worldId]:getDelta( pos, cullInRange, cullOutRange )
		for _, value in ipairs( remove ) do
			if self.cl.worldEffectNodes[worldId][value].effect then
				self.cl.worldEffectNodes[worldId][value].effect:destroy()
				self.cl.worldEffectNodes[worldId][value].effect = nil
			end
		end
		for _, value in ipairs( add ) do
			self:cl_createEffect( world, self.cl.worldEffectNodes[worldId][value] )
		end
	else
		local remove = self.cl.worldSphereGroups[worldId]:leave()
		for _, value in ipairs( remove ) do
			if self.cl.worldEffectNodes[worldId][value].effect then
				self.cl.worldEffectNodes[worldId][value].effect:destroy()
				self.cl.worldEffectNodes[worldId][value].effect = nil
			else
				sm.log.warning("Destroy effect without effect")
			end
		end
	end	
end

function EffectManager.Cl_GetWorldNamedEffect( world, name )
	if g_effectManager then
		return g_effectManager:cl_getWorldNamedEffect( world, name )
	end
end

function EffectManager.cl_getWorldNamedEffect( self, world, name )
	local namedEffects = self.cl.worldNamedEffects[world.id]
	if namedEffects then
		return namedEffects[name]
	end
	return nil
end

local CinematicState = {
	START = 1,
	PLAYING = 2,
	CANCEL = 3,
}

function EffectManager.Cl_PlayNamedCinematic( params )
	g_effectManager:cl_playNamedCinematic( params )
end

function EffectManager.cl_playNamedCinematic( self, params )
	if params.interruptible == nil then
		params.interruptible = true
	end
	
	self.cl.namedCinematicStates[params.name] = { state = CinematicState.START, callbackData = params.callbackData, interruptible = params.interruptible }
	
	if not ( params.callbackData and params.callbackData.world ) or not params.forceCameraData then
		return
	end

	self:cl_handleCinematics( params.callbackData.world, 0, params.forceCameraData )

	local player = sm.localPlayer.getPlayer()
	if player.clientPublicData and player.clientPublicData.cutsceneCameraData then
		local wantedCameraData = player.clientPublicData.cutsceneCameraData
		if wantedCameraData.distance < MAX_CINEMATIC_DISTANCE then
			SetWantedCameraData( wantedCameraData )
		end
	end
end

function EffectManager.Sv_PlayNamedCinematic( params )
	sm.event.sendToScriptableObject( g_effectManager.scriptableObject, "sv_playNamedCinematic", params )
end

function EffectManager.sv_playNamedCinematic( self, params )
	self.network:sendToClients( "cl_playNamedCinematic", params )
end

local function StartEffect( effect )
	if effect and not effect:isPlaying() then
		effect:start()
	end
end

function EffectManager.cl_n_startEventEffects( self, params )
	local fnStartEffects = function( x, y )
		local cellKey = CellKey( x, y )
		if self.cl.eventEffectNodes[params.world.id][cellKey] then
			for _,effectList in pairs( self.cl.eventEffectNodes[params.world.id][cellKey] ) do
				for _,effectNode in ipairs( effectList ) do
					if effectNode.node.params.eventName == params.eventName then
						if not params.world or TileStorageManager.Cl_GetTileStorageKeyFromPosition( params.world, effectNode.node.position ) == params.tileStorageKey then
							effectNode.effect:start()
						end
					end
				end
			end
		end
	end

	if self.cl.eventEffectNodes[params.world.id] then
		if params.world.indoor then
			fnStartEffects( 0, 0 )
		else
			for  x = params.xMin, params.xMax  do
				for y = params.yMin, params.yMax do
					fnStartEffects( x, y )
				end
			end
		end
	end
end

function EffectManager.Cl_CancelAllCinematics()
    if g_effectManager then
		sm.event.sendToScriptableObject( g_effectManager.scriptableObject, "cl_cancelAllCinematics" )
    end
end

function EffectManager.cl_cancelAllCinematics( self )
	for _, cinematic in pairs( self.cl.namedCinematicStates ) do
		if cinematic.interruptible == true then
			cinematic.state = CinematicState.CANCEL
		end
	end
end

-- Effect Callback
function EffectManager.cl_e_handleCinematicEvent( self, params, callbackData )
	local myPlayer = sm.localPlayer.getPlayer()
	local myCharacter = myPlayer and myPlayer.character or nil

	if params.eventName == "survivalstart01.dramatics_standup" then
		if sm.exists( myCharacter ) then
			sm.event.sendToCharacter( myCharacter, "cl_e_onEvent", "dramatics_standup" )
		end
	elseif params.eventName == "cinematic.look_around" then
		if sm.exists( myCharacter ) then
			sm.event.sendToCharacter( myCharacter, "cl_e_onEvent", "look_around" )
		end
	elseif params.eventName == "survivalstart01.fadeout" then
		if myCharacter and myCharacter:getWorld() == callbackData.world then
			sm.event.sendToPlayer( myPlayer, "cl_e_startCinematicFadeToBlack", { duration = IntroFadeDuration, timeout = IntroFadeTimeout } )
		end
	elseif params.eventName == "survivalstart01.fadein" then
		if myCharacter and myCharacter:getWorld() == callbackData.world then
			sm.event.sendToPlayer( myPlayer, "cl_e_endFadeToBlack", { duration = IntroEndFadeDuration } )
		end
	elseif params.eventName == "challengemodecomplete.celebrate" then
		sm.event.sendToWorld( callbackData.world, "cl_onCinematicEvent", { eventName = params.eventName } )
	end
end

-- Effect callback
function EffectManager.cl_e_cinematicFadeOut( self, params, callbackData )
	local myPlayer = sm.localPlayer.getPlayer()
	local myCharacter = myPlayer and myPlayer.character or nil
	if myCharacter and myCharacter:getWorld() == callbackData.world then
		sm.event.sendToPlayer( myPlayer, "cl_e_startCinematicFadeToBlack", { duration = params.duration, timeout = IntroFadeTimeout } )
	end
end

function EffectManager.cl_e_cinematicFadeIn( self, params, callbackData )
	local myPlayer = sm.localPlayer.getPlayer()
	local myCharacter = myPlayer and myPlayer.character or nil
	if myCharacter and myCharacter:getWorld() == callbackData.world then
		sm.event.sendToPlayer( myPlayer, "cl_e_endFadeToBlack", { duration = params.duration } )
	end
end

-- Effect Callback
function EffectManager.sv_e_spawnEnemies( self, params, callbackData )
	NodeSpawnManager.Sv_ActivateSpawnTrigger( params.eventName, callbackData.world )
end

-- Effect Callback
function EffectManager.sv_e_triggerKinematic( self, params, callbackData )
	if callbackData.tileStorageKey == nil then
		sm.log.warning( "EffectManager.sv_e_triggerKinematic - Missing tileStorageKey in callbackData. Ensure callbackData is set through PlayNamedCinematic." )
	end
	KinematicManager.Sv_Activate( callbackData.tileStorageKey, params.kinematicTrigger )
end

-- Effect Callback
function EffectManager.sv_e_teleportHostPlayer( self, params)
	local hostPlayer = sm.player.getHostPlayer()
	if hostPlayer and sm.exists( hostPlayer ) then
		local hostCharacter = hostPlayer:getCharacter()
		if hostCharacter then
			local world = hostCharacter:getWorld()
			local destinationNode = self.sv.cinematicTeleportNodes[world.id][params.teleportDestination]
			if destinationNode then
				hostCharacter:setWorldPosition( destinationNode.position )
				self.network:sendToClient( hostPlayer, "cl_n_setTeleportViewDirection", { rotation = destinationNode.rotation * sm.vec3.new( 0, 0, 1 ) } )
			end
		end
	end
end

-- Effect Callback
function EffectManager.sv_e_teleportPlayers( self, params, callbackData )
	local players = callbackData.players or sm.player.getAllPlayers()

	-- use the host to get the world
	local hostPlayer = sm.player.getHostPlayer()
	if hostPlayer and sm.exists( hostPlayer ) then
		local hostCharacter = hostPlayer:getCharacter()
		if hostCharacter then

			local world = hostCharacter:getWorld()
			if callbackData.useEffectWorld then
				world = callbackData.world
			end

			-- fetch all the named teleport nodes
			local teleportNodes = {}
			for _, destination in ipairs(params.teleportDestinations) do
				table.insert( teleportNodes, self.sv.cinematicTeleportNodes[world.id][destination] )
			end

			-- teleport all players
			local teleportNodeCount = #teleportNodes
			for index, player in ipairs( players ) do
				if params.teleportHost == false and player == hostPlayer then
					-- skip the host
				else
					local destinationNode = teleportNodes[(index - 1) % teleportNodeCount + 1]
					if destinationNode then
						local viewDirection = destinationNode.rotation * sm.vec3.new(0, 0, 1)
						local character = player:getCharacter()
						
						if character then
							local distanceFromDestination = character and ( character:getWorldPosition() - destinationNode.position):length() or 0
							local fadeFromBlack = character:getWorld() ~= world or distanceFromDestination > ( 64.0 * 4.0 )
							sm.event.sendToGame( "sv_e_recreatePlayerInWorld", { player = player, world = world, pos = destinationNode.position, dir = viewDirection, fadeFromBlack = fadeFromBlack }, sm.event.types.instant )
						end
					end
				end
			end
		end
	end
end

-- Effect Callback
function EffectManager.sv_e_sendQuestEvent( self, params )
	QuestManager.Sv_SendEvent( params.eventName, params.eventParams )
end

function EffectManager.cl_n_setTeleportViewDirection( self, params )
	sm.localPlayer.setDirection( params.rotation )
end

-- Effect Callback
function EffectManager.sv_e_sendUnitEvent( self, params, callbackData )
	sm.message.send( params.eventName )
end

-- Called for each active world
function EffectManager.cl_handleCinematics( self, world, dt, forceCameraData )
	local player = sm.localPlayer.getPlayer()

	local activeCameraEffects = {}
	for name, cinematic in pairs( self.cl.namedCinematicStates ) do
		local ne = self:cl_getWorldNamedEffect( world, name )
		if ne and ne.effect then -- Exists in this world
			if cinematic.state == CinematicState.START and sm.localPlayer.getPlayer().character then

				ne.effect:bindEventClientCallback( cinematic.callbackData, self )
				if sm.isHost then
					ne.effect:bindEventServerCallback( cinematic.callbackData, self )
				end

				StartEffect( ne.effect )
				cinematic.state = CinematicState.PLAYING
			end
			if cinematic.state == CinematicState.PLAYING then
				if ne.effect:isDone() then
					ne.effect:clearClientEventCallback()
					if sm.isHost then
						ne.effect:clearServerEventCallback()
					end
					ne.effect:stop()
				
					self.cl.namedCinematicStates[name] = nil
				else
					local myCharacter = sm.localPlayer.getPlayer().character
					if myCharacter and ( ne.effect:hasActiveCamera() or forceCameraData ) and world == myCharacter:getWorld() then
						activeCameraEffects[#activeCameraEffects + 1] = { effect = ne.effect, distance = ( myCharacter.worldPosition - ne.position ):length() }
					end
				end
			elseif cinematic.state == CinematicState.CANCEL then
				ne.effect:clearClientEventCallback()
				if sm.isHost then
					ne.effect:clearServerEventCallback()
				end
				self.cl.namedCinematicStates[name] = nil
			end
		end
	end

	local closestCameraEffect
	local closestCameraEffectDistance = math.huge

	for _, cameraEffect in ipairs( activeCameraEffects ) do
		if cameraEffect.distance < closestCameraEffectDistance then
			closestCameraEffect = cameraEffect.effect
			closestCameraEffectDistance = cameraEffect.distance
		end
	end

	local character = player:getCharacter()
	if character and character:getWorld() == world then
		local cutsceneCameraData
		if closestCameraEffect then
			local cameraData = closestCameraEffect:getCameraData()
			
			local cameraPosition = cameraData.cameraPosition
			local cameraRotation = cameraData.cameraRotation
			
			-- Blend in
			local stopBlendingIn = self.cl.cutsceneBlendIn and self.cl.cutsceneBlendIn >= CutsceneBlendInTime
			if cameraData and cameraData.hasBlendIn and not stopBlendingIn then
				self.cl.cutsceneBlendIn = self.cl.cutsceneBlendIn and self.cl.cutsceneBlendIn + dt or dt
				self.cl.cutsceneBlendIn = math.min( self.cl.cutsceneBlendIn, CutsceneBlendInTime )

				self.cl.cutsceneBlendInFromPosition = self.cl.cutsceneBlendInFromPosition or sm.camera.getPosition()
				self.cl.cutsceneBlendInFromRotation = self.cl.cutsceneBlendInFromRotation or sm.camera.getRotation()

				local cameraDesiredPosition = cameraData.cameraPosition
				local cameraDesiredRotation = cameraData.cameraRotation

				local blend = clamp( self.cl.cutsceneBlendIn / CutsceneBlendInTime, 0, 1 )
				blend = sm.util.easing( CutsceneBlendInEasing, blend )
				cameraPosition = sm.vec3.lerp( self.cl.cutsceneBlendInFromPosition, cameraDesiredPosition, blend )
				cameraRotation = sm.quat.slerp( self.cl.cutsceneBlendInFromRotation, cameraDesiredRotation, blend )
			end

			-- Blend out prep
			if cameraData and cameraData.hasBlendOut then
				self.cl.cutsceneBlendOut = 0
				self.cl.cutsceneBlendOutFromPosition = cameraPosition
				self.cl.cutsceneBlendOutFromRotation = cameraRotation
			end

			-- Finalize
			cutsceneCameraData = {}
			cutsceneCameraData.hideGui = true
			cutsceneCameraData.cameraState = sm.camera.state.cutsceneTP
			cutsceneCameraData.cameraPosition = cameraPosition
			cutsceneCameraData.cameraRotation = cameraRotation
			cutsceneCameraData.cameraFov = cameraData.cameraFov
			cutsceneCameraData.lockedControls = true
			cutsceneCameraData.distance = closestCameraEffectDistance
		else
			self.cl.cutsceneBlendIn = nil
			self.cl.cutsceneBlendInFromPosition = nil
			self.cl.cutsceneBlendInFromRotation = nil

			-- Blend out if a cutscene has asked for it
			if self.cl.cutsceneBlendOut and self.cl.cutsceneBlendOut < CutsceneBlendOutTime then
				self.cl.cutsceneBlendOut = self.cl.cutsceneBlendOut and self.cl.cutsceneBlendOut + dt or dt
				self.cl.cutsceneBlendOut = math.min( self.cl.cutsceneBlendOut, CutsceneBlendOutTime )

				self.cl.cutsceneBlendOutFromPosition = self.cl.cutsceneBlendOutFromPosition or sm.camera.getPosition()
				self.cl.cutsceneBlendOutFromRotation = self.cl.cutsceneBlendOutFromRotation or sm.camera.getRotation()

				local cameraDesiredPosition = sm.camera.getDefaultPosition()
				local cameraDesiredRotation = sm.camera.getDefaultRotation()

				local blend = clamp( self.cl.cutsceneBlendOut / CutsceneBlendOutTime, 0, 1 )
				blend = sm.util.easing( CutsceneBlendOutEasing, blend )
				local cameraPosition = sm.vec3.lerp( self.cl.cutsceneBlendOutFromPosition, cameraDesiredPosition, blend )
				local cameraRotation = sm.quat.slerp( self.cl.cutsceneBlendOutFromRotation, cameraDesiredRotation, blend )

				-- Finalize
				cutsceneCameraData = {}
				cutsceneCameraData.hideGui = true
				cutsceneCameraData.cameraState = sm.camera.state.cutsceneTP
				cutsceneCameraData.cameraPosition = cameraPosition
				cutsceneCameraData.cameraRotation = cameraRotation
				cutsceneCameraData.cameraFov = sm.camera.getDefaultFov()
				cutsceneCameraData.lockedControls = true
				cutsceneCameraData.distance = 0
			else
				self.cl.cutsceneBlendOut = nil
				self.cl.cutsceneBlendOutFromPosition = nil
				self.cl.cutsceneBlendOutFromRotation = nil
			end
		end

		player.clientPublicData = player.clientPublicData or {}
		player.clientPublicData.cutsceneCameraData = cutsceneCameraData
	end

	self.cl.currentCinematicEffect = closestCameraEffect
end