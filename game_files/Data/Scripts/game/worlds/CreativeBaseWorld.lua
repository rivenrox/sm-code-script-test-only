dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_explosions.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/AttachedFireManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/CablebotManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_sob.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/WaterManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/WorldManager.lua" )

CreativeBaseWorld = class( nil )

function CreativeBaseWorld.server_onCreate( self )
	sm.fire.setFireLimit( FIRE_INSTANCE_LIMIT )

	self.waterManager = WaterManager()
	self.waterManager:sv_onCreate( self )

	self.sv = {}
	self.sv.ambienceManager = sm.scriptableObject.createScriptableObject( sm.uuid.new( "635b5d17-fa35-4591-82ec-358da595bac0" ), nil, self.world )
	self.sv.rayProjectileManager = sm.scriptableObject.createScriptableObject( sm.uuid.new( "8504131e-8f58-4d25-beab-3bc996b7a95e" ), nil, self.world )

	WorldManager.Sv_RegisterWorld( "weatherworld", self.world )
end

function CreativeBaseWorld.client_onCreate( self )
	self.world.clientPublicData = {
		musicParameter = 7
	}

	if self.waterManager == nil then
		assert( not sm.isHost )
		self.waterManager = WaterManager()
	end
	self.waterManager:cl_onCreate()

	WorldManager.Cl_RegisterWorld( "weatherworld", self.world )
end

function CreativeBaseWorld.client_onFixedUpdate( self )
	AttachedFireManager.Cl_OnWorldFixedUpdate( self.world )
	CablebotManager.Cl_OnWorldFixedUpdate( self.world )
	self.waterManager:cl_onFixedUpdate()
end

function CreativeBaseWorld.sv_e_spawnNewCharacter( self, params )
	local spawnRayBegin = sm.vec3.new( params.x, params.y, 1024 )
	local spawnRayEnd = sm.vec3.new( params.x, params.y, -1024 )
	local oldCharacter = params.player:getCharacter()
	local valid, result = sm.physics.spherecast( spawnRayBegin, spawnRayEnd, 0.3, oldCharacter )
	local pos
	if valid then
		pos = sm.vec3.lerp( spawnRayBegin, spawnRayEnd, result.fraction ) + sm.vec3.new( 0, 0, 0.4 )
	else
		pos = sm.vec3.new( params.x, params.y, 100 )
	end

	local character = sm.character.createCharacter( params.player, self.world, pos )
	params.player:setCharacter( character )
end


function CreativeBaseWorld.server_onFixedUpdate( self )
	AttachedFireManager.Sv_OnWorldFixedUpdate( self.world )
	CablebotManager.Sv_OnWorldFixedUpdate( self.world )
	self.waterManager:sv_onFixedUpdate()
end

function CreativeBaseWorld.server_onProjectileFire( self, firePos, fireVelocity, _, attacker, projectileUuid )
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		sm.message.send( MESSAGE_TYPES.GENERAL.ProjectileFire, { world = self.world, position = firePos, attacker = attacker } )
	end
end

function CreativeBaseWorld.server_onInteractableCreated( self, interactable )
	g_unitManager:sv_onInteractableCreated( interactable )
end

function CreativeBaseWorld.server_onInteractableDestroyed( self, interactable )
	g_unitManager:sv_onInteractableDestroyed( interactable )
end

function CreativeBaseWorld.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
	-- Notify units about projectile hit
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		sm.message.send( MESSAGE_TYPES.GENERAL.ProjectileHit, { world = self.world, position = hitPos, attacker = attacker } )
	end

-- 













	if projectileUuid == projectile_pesticide then
		local forward = sm.vec3.new( 0, 1, 0 )
		local randomDir = forward:rotateZ( math.rad( math.random( 0, 359 ) ) )
		local effectPos = hitPos
		local success, result = sm.physics.raycast( hitPos + sm.vec3.new( 0, 0, 0.1 ), hitPos - sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 ), nil, sm.physics.filter.static + sm.physics.filter.dynamicBody )
		if success then
			effectPos = result.pointWorld + sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 )
		end
		sm.scriptableObject.createScriptableObject( sob_pesticide_cloud, { position = effectPos, rotation = sm.vec3.getRotation( forward, randomDir ) }, self.world )
	end

	if projectileUuid == projectile_glowstick or projectileUuid == projectile_glowstick_detach then
		if target then
			local targetType = type( target )
			if not (targetType == "Shape" or targetType == "Harvestable" or targetType == "VoxelTerrain" ) then
				sm.effect.playEffect( "GlowstickProjectile - Bounce", hitPos )
				return
			end
		end

		local inputLifetime = nil
		if userData then
			inputLifetime = userData.lifetime
		end
		GlowstickManager.Sv_CreateGlowstick( { hitPos = hitPos, hitTime = hitTime, hitNormal = hitNormal, target = target, world = self.world, lifetime = inputLifetime, projectileUuid = projectileUuid } )
	end

	if projectileUuid == projectile_explosivetape then
		sm.physics.explode( hitPos, 7, 2.0, 6.0, 25.0, "RedTapeBot - ExplosivesHit", nil, nil, nil, 35 )
	end

	if projectileUuid == projectile_smallexplosive then
		sm.physics.explode( hitPos, 7, 2.0, 6.0, 25.0, "PropaneTank - ExplosionSmall", nil, nil, nil, 35 )
	end

	if projectileUuid == projectile_cornade_explosive then
		sm.physics.explode( hitPos, 5, 3.0, 6.0, 25.0, "Cornnade - Explosion", nil, nil, nil, 35, attacker, EXPLOSIONS.explosion_cornade )
	end

	if projectileUuid == projectile_water then
		AttachedFireManager.Sv_Quench( hitPos )
	end
	if projectileUuid == projectile_flame then
		if attacker and type( attacker ) == "Player" and sm.exists( attacker ) then
			PotatoLauncherSplash( self.world, hitPos )
		else
			sm.fire.igniteSphere( hitPos, 0.25, true )
		end
	end
	if projectileUuid == projectile_foam then
		AttachedFireManager.Sv_Quench( hitPos )
	end
	if projectileUuid == projectile_cablebot then
		CablebotManager.Sv_AttachCablebot( hitPos, hitVelocity:safeNormalize( sm.vec3.new( 0, 1, 0 ) ) )
	end

	if projectileUuid == projectile_clay then
		local clayMaterial = 0
		self.world:voxelDensityAddition( hitPos, hitNormal, 2.5, 5, clayMaterial, sm.world.voxelFilter.all, attacker )
	end
end

function CreativeBaseWorld.server_onExplosion( self, center, destructionLevel, radius )
	self.world:sphereVoxelDensitySubtraction( center, radius, bit.bor( sm.world.voxelFilter.material0, sm.world.voxelFilter.material1, sm.world.voxelFilter.material2, sm.world.voxelFilter.material3 ), 10.0 )
	CablebotManager.Sv_Explosion( center, radius )
end

function CreativeBaseWorld.server_onVoxelConstruction( self, constructions )
	local glowstickIds = {}
	for _, construction in ipairs( constructions ) do
		for i = 1, 8 do
			if construction.densities[i] > 0 then
				GlowstickManager.Sv_GetGlowstickIds( construction.aabbsMin[i] - 1, construction.aabbsMax[i] + 1, glowstickIds, false )
			end
		end
	end

	if not IsEmptyTable( glowstickIds ) then
		GlowstickManager.Sv_CheckVoxelContact( glowstickIds )
	end
end

function CreativeBaseWorld.server_onVoxelDestruction( self, destructions )
	local glowstickIds = {}
	for _, destruction in ipairs( destructions ) do
		for i = 1, 8 do
			if destruction.densities[i] > 0 then
				GlowstickManager.Sv_GetGlowstickIds( destruction.aabbsMin[i] - 1, destruction.aabbsMax[i] + 1, glowstickIds, true )
			end
		end
	end

	if not IsEmptyTable( glowstickIds ) then
		GlowstickManager.Sv_CheckVoxelContact( glowstickIds )
	end
end

function CreativeBaseWorld.server_onCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
	g_unitManager:sv_onWorldCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
end

function CreativeBaseWorld.sv_e_clear( self )
	for _, body in ipairs( sm.body.getAllBodies() ) do
		for _, shape in ipairs( body:getShapes() ) do
			shape:destroyShape()
		end
	end
end

local function selectHarvestableToPlace( keyword )
	if keyword == "stone" then
		local stones = {
			hvs_stone_small01, hvs_stone_small02, hvs_stone_small03
			--hvs_stone_medium01, hvs_stone_medium02, hvs_stone_medium03,
			--hvs_stone_large01, hvs_stone_large02, hvs_stone_large03
		}
		return stones[math.random( 1, #stones )]
	elseif keyword == "tree" then
		local trees = {
			hvs_tree_birch01, hvs_tree_birch02, hvs_tree_birch03,
			hvs_tree_leafy01, hvs_tree_leafy02, hvs_tree_leafy03,
			hvs_tree_spruce01, hvs_tree_spruce02, hvs_tree_spruce03,
			hvs_tree_pine01, hvs_tree_pine02, hvs_tree_pine03
		}
		return trees[math.random( 1, #trees )]
	elseif keyword == "birch" then
		local trees = { hvs_tree_birch01, hvs_tree_birch02, hvs_tree_birch03 }
		return trees[math.random( 1, #trees )]
	elseif keyword == "leafy" then
		local trees = { hvs_tree_leafy01, hvs_tree_leafy02, hvs_tree_leafy03 }
		return trees[math.random( 1, #trees )]
	elseif keyword == "spruce" then
		local trees = {	hvs_tree_spruce01, hvs_tree_spruce02, hvs_tree_spruce03 }
		return trees[math.random( 1, #trees )]
	elseif keyword == "pine" then
		local trees = { hvs_tree_pine01, hvs_tree_pine02, hvs_tree_pine03 }
		return trees[math.random( 1, #trees )]
	end
	return nil
end

function CreativeBaseWorld.sv_e_onChatCommand( self, params )
	if params[1] == "/aggroall" then
		local units = sm.unit.getAllUnits()
		for _, unit in ipairs( units ) do
			sm.event.sendToUnit( unit, "sv_e_receiveTarget", { targetCharacter = params.player.character } )
		end
		sm.gui.chatMessage( "Hostiles received " .. params.player:getName() .. "'s position." )
	elseif params[1] == "/killall" then
		local units = sm.unit.getAllUnits()
		for _, unit in ipairs( units ) do
			unit:destroy()
		end
	elseif params[1] == "/place" then
		local harvestableUuid = selectHarvestableToPlace( params[2] )
		if harvestableUuid and params.aimPosition then
			local from = params.aimPosition + sm.vec3.new( 0, 0, 16.0 )
			local to = params.aimPosition - sm.vec3.new( 0, 0, 16.0 )
			local success, result = sm.physics.raycast( from, to, nil, sm.physics.filter.default )
			if success and result.type == "terrainSurface" then
				local harvestableYZRotation = sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) )
				local harvestableRotation = sm.quat.fromEuler( sm.vec3.new( 0, math.random( 0, 359 ), 0 ) )
				local placePosition = result.pointWorld
				if params[2] == "stone" then
					placePosition = placePosition + sm.vec3.new( 0, 0, 2.0 )
				end
				sm.harvestable.createHarvestable( harvestableUuid, placePosition, harvestableYZRotation * harvestableRotation )
			end
		end
	end
end









-- Beacons
function CreativeBaseWorld.sv_e_createBeacon( self, params )
	if params.player and sm.exists( params.player ) then
		self.network:sendToClient( params.player, "cl_n_createBeacon", params )
	else
		self.network:sendToClients( "cl_n_createBeacon", params )
	end
end

function CreativeBaseWorld.cl_n_createBeacon( self, params )
	g_beaconManager:cl_createBeacon( params )
end

function CreativeBaseWorld.sv_e_destroyBeacon( self, params )
	if params.player and sm.exists( params.player ) then
		self.network:sendToClient( params.player, "cl_n_destroyBeacon", params )
	else
		self.network:sendToClients( "cl_n_destroyBeacon", params )
	end
end

function CreativeBaseWorld.cl_n_destroyBeacon( self, params )
	g_beaconManager:cl_destroyBeacon( params )
end

function CreativeBaseWorld.sv_e_unloadBeacon( self, params )
	if params.player and sm.exists( params.player ) then
		self.network:sendToClient( params.player, "cl_n_unloadBeacon", params )
	else
		self.network:sendToClients( "cl_n_unloadBeacon", params )
	end
end

function CreativeBaseWorld.cl_n_unloadBeacon( self, params )
	g_beaconManager:cl_unloadBeacon( params )
end

function CreativeBaseWorld.server_onCellCreated( self, x, y )
	self.waterManager:sv_onCellLoaded( x, y )
end

function CreativeBaseWorld.client_onCellLoaded( self, x, y )
	self.waterManager:cl_onCellLoaded( x, y )
	EffectManager.Cl_AlertOnWorldLoadCell( self.world, x, y )
	RenderSettingsManager.Cl_onCellLoaded( x, y )
end

function CreativeBaseWorld.server_onCellLoaded( self, x, y )
	self.waterManager:sv_onCellReloaded( x, y )
end

function CreativeBaseWorld.server_onCellUnloaded( self, x, y )
	self.waterManager:sv_onCellUnloaded( x, y )
end

function CreativeBaseWorld.client_onCellUnloaded( self, x, y )
	self.waterManager:cl_onCellUnloaded( x, y )
	EffectManager.Cl_AlertOnWorldUnloadCell( self.world, x, y )
	RenderSettingsManager.Cl_onCellUnloaded( x, y )
end

function CreativeBaseWorld.server_onMelee( self, hitPos, attacker, target, damage, power, hitDirection, hitNormal )
	if type( target ) == "VoxelTerrain" and type( attacker ) == "Player" then
		local radius = 2
		local world = attacker:getCharacter():getWorld()
		world:voxelDensitySubtraction( hitPos, sm.vec3.zero(), radius, { 30, 30, 30, 30, 30, 30, 30, 30 }, sm.world.voxelFilter.all )
	end
end

function CreativeBaseWorld.server_onTerrainCreated( self )
	GlowstickManager.Sv_WorldReady( self.world )
end

function CreativeBaseWorld.server_onTerrainLoaded( self )
	GlowstickManager.Sv_WorldReady( self.world )
end

function CreativeBaseWorld.client_onTerrainCreated( self )
	GlowstickManager.Cl_WorldReady( self.world )
end

function CreativeBaseWorld.client_onTerrainLoaded( self )
	GlowstickManager.Cl_WorldReady( self.world )
end