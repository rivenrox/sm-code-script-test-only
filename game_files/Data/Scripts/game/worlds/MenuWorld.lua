MenuWorld = class( CreativeBaseWorld )
MenuWorld.enableSurface = true
MenuWorld.enableAssets = true
MenuWorld.enableClutter = true
MenuWorld.enableNodes = false
MenuWorld.enableCreations = false
MenuWorld.enableHarvestables = false
MenuWorld.enableKinematics = false
MenuWorld.enableNavMesh = false
MenuWorld.cellMinX = 1
MenuWorld.cellMaxX = 2
MenuWorld.cellMinY = 0
MenuWorld.cellMaxY = 0

function MenuWorld.sv_e_spawnNewCharacter( self, params )
	local spawnPosition = sm.vec3.new( 127.8451, 23.3785, 2.4759 )
	local yaw = 0
	local pitch = 0

	local character = sm.character.createCharacter( params.player, self.world, spawnPosition, yaw, pitch )
	params.player:setCharacter( character )
end

function MenuWorld.sv_e_loadMenuCreations( self )
	--Creations
	local blueprints = sm.menuCreation.load()
	if blueprints then
		for _, blueprintObject in ipairs( blueprints ) do
			local blueprintJson = sm.json.writeJsonString( blueprintObject )
			sm.creation.importFromString( self.world, blueprintJson, sm.vec3.zero(), sm.quat.identity(), true )
		end
	end
end

function MenuWorld.sv_e_export( self )
	local menuCreations = sm.body.getCreationsFromBodies( sm.body.getAllBodies() )
	local blueprints = {}
	for i, creation in ipairs( menuCreations ) do
		local blueprintJsonString = sm.creation.exportToString( creation[1], true, false ) -- First body, exportToString finds the rest
		local blueprint = sm.json.parseJsonString( blueprintJsonString )
		blueprints[#blueprints+1] = blueprint
	end
	sm.menuCreation.save( blueprints )
end

function MenuWorld.sv_e_clear( self )
	for _, body in ipairs( sm.body.getAllBodies() ) do
		for _, shape in ipairs( body:getShapes() ) do
			shape:destroyShape()
		end
	end
end