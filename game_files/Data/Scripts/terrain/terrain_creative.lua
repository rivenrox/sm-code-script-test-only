dofile( "$GAME_DATA/Scripts/terrain/terrain_creative_celldata.lua" )
dofile( "$GAME_DATA/Scripts/terrain/creative_tile_list.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/tile_database.lua" )
dofile( "$SURVIVAL_DATA/Scripts/kinematic_util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util2.lua" )
dofile( "$GAME_DATA/Scripts/terrain/terrain_area_util.lua" )

----------------------------------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------------------------------

function Init( world )
	g_world = world
	InitTileList()
end

----------------------------------------------------------------------------------------------------

local function initializeCellData( xMin, xMax, yMin, yMax, seed )
	-- Version history:
	-- 2:	Changes integer 'tileId' to 'uid' from tile uuid
	--		Renamed 'tileOffsetX' -> 'xOffset'
	--		Renamed 'tileOffsetY' -> 'yOffset'
	--		Added 'version'
	
	g_cellData = {
		bounds = { xMin = xMin, xMax = xMax, yMin = yMin, yMax = yMax },
		seed = seed,
		-- Per Cell
		uid = {},
		xOffset = {},
		yOffset = {},
		rotation = {},
		groupId = {},
		version = 2,
	}

	-- Cells
	for cellY = yMin, yMax do
		g_cellData.uid[cellY] = {}
		g_cellData.xOffset[cellY] = {}
		g_cellData.yOffset[cellY] = {}
		g_cellData.rotation[cellY] = {}
		g_cellData.groupId[cellY] = {}

		for cellX = xMin, xMax do
			g_cellData.uid[cellY][cellX] = sm.uuid.getNil()
			g_cellData.xOffset[cellY][cellX] = 0
			g_cellData.yOffset[cellY][cellX] = 0
			g_cellData.rotation[cellY][cellX] = 0
			g_cellData.groupId[cellY][cellX] = 0
		end
	end
end

function Create( xMin, xMax, yMin, yMax, seed )

	local graphicsCellPadding = 6
	xMin = xMin - graphicsCellPadding
	xMax = xMax + graphicsCellPadding
	yMin = yMin - graphicsCellPadding
	yMax = yMax + graphicsCellPadding

	initializeCellData( xMin, xMax, yMin, yMax, seed )
	CreateBorders( xMin, xMax, yMin, yMax, seed )
	GenerateWorld( -9, 8, -9, 8, seed )

	sm.terrainData.save( g_cellData )
end

----------------------------------------------------------------------------------------------------

function Load()
	if sm.terrainData.exists() then
		g_cellData = sm.terrainData.load()
		if UpgradeCellData( g_cellData ) then
			sm.terrainData.save( g_cellData )
		end
		return true
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- Generator API Getters
----------------------------------------------------------------------------------------------------

function GetCellTileUidAndOffset( cellX, cellY )
	if InsideCellBounds( cellX, cellY ) then
		return	g_cellData.uid[cellY][cellX],
				g_cellData.xOffset[cellY][cellX],
				g_cellData.yOffset[cellY][cellX]
	end
	return sm.uuid.getNil(), 0, 0
end

----------------------------------------------------------------------------------------------------

function GetHeightAt( x, y, lod )
	local cellX, cellY = getCell( x, y )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )

	local rx, ry = InverseRotateLocal( cellX, cellY, x - cellX * CELL_SIZE, y - cellY * CELL_SIZE )

	local height = sm.terrainTile.getHeightAt( uid, tileCellOffsetX, tileCellOffsetY, lod, rx, ry )

	return height
end

----------------------------------------------------------------------------------------------------

function GetColorAt( x, y, lod )
	local cellX, cellY = getCell( x, y )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )

	local rx, ry = InverseRotateLocal( cellX, cellY, x - cellX * CELL_SIZE, y - cellY * CELL_SIZE )

	local r, g, b = sm.terrainTile.getColorAt( uid, tileCellOffsetX, tileCellOffsetY, lod, rx, ry )

	local noise = sm.noise.octaveNoise2d( x / 8, y / 8, 5, 45 )
	local brightness = noise * 0.25 + 0.75
	local color = { r, g, b }
	
	local desertColor = { 255 / 255, 171 / 255, 111 / 255 }

	local maxDist = math.max( math.abs(x), math.abs(y) )
	if maxDist >= BARRIER_END then
		color[1] = desertColor[1]
		color[2] = desertColor[2]
		color[3] = desertColor[3]
	elseif maxDist >= BARRIER_START then
		local fade = ( maxDist - BARRIER_START ) / ( BARRIER_END - BARRIER_START )
		color[1] = 1.0 + ( desertColor[1] - 1.0 ) * fade
		color[2] = 1.0 + ( desertColor[2] - 1.0 ) * fade
		color[3] = 1.0 + ( desertColor[3] - 1.0 ) * fade
	elseif maxDist >= DESERT_START then
		color[1] = 1
		color[2] = 1
		color[3] = 1
	end

	return color[1] * brightness, color[2] * brightness, color[3] * brightness
end

----------------------------------------------------------------------------------------------------

function GetMaterialAt( x, y, lod )
	local cellX, cellY = getCell( x, y )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )

	local rx, ry = InverseRotateLocal( cellX, cellY, x - cellX * CELL_SIZE, y - cellY * CELL_SIZE )

	local mat1, mat2, mat3, mat4, mat5, mat6, mat7, mat8 = sm.terrainTile.getMaterialAt( uid, tileCellOffsetX, tileCellOffsetY, lod, rx, ry )

	local maxDist = math.max( math.abs(x), math.abs(y) )
	if maxDist >= BARRIER_END then
		mat1 = 1.0
	elseif maxDist >= BARRIER_START and maxDist <= BARRIER_END then
		mat2, mat3, mat4, mat5, mat6, mat7, mat8 = 0, 0, 0, 0, 0, 0, 0, 0
		local fade = ( maxDist - BARRIER_START ) / ( BARRIER_END - BARRIER_START )
		mat1 = 1.0
		mat2 = 1.0 - fade
	elseif maxDist >= DESERT_START then
		mat1, mat2, mat3, mat4, mat5, mat6, mat7, mat8 = 0, 0, 0, 0, 0, 0, 0, 0
		mat2 = 1.0
	end

	return mat1, mat2, mat3, mat4, mat5, mat6, mat7, mat8
end

----------------------------------------------------------------------------------------------------

function GetClutterIdxAt( x, y )
	local cellX = math.floor( x / ( CELL_SIZE * 2 ) )
	local cellY = math.floor( y / ( CELL_SIZE * 2 ) )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )

	local rx, ry = InverseRotateLocal( cellX, cellY, x - cellX * CELL_SIZE * 2, y - cellY * CELL_SIZE * 2, CELL_SIZE * 2 - 1 )

	local clutterIdx = sm.terrainTile.getClutterIdxAt( uid, tileCellOffsetX, tileCellOffsetY, rx, ry )
	return clutterIdx
end

----------------------------------------------------------------------------------------------------

function GetEffectMaterialAt( x, y )
	local mat0, mat1, mat2, mat3, mat4, mat5, mat6, mat7 = GetMaterialAt( x, y, 0 )

	local materialWeights = {}
	materialWeights["Grass"] = math.max( mat4, mat7 )
	materialWeights["Rock"] = math.max( mat0, mat2, mat5 )
	materialWeights["Dirt"] = math.max( mat3, mat6 )
	materialWeights["Sand"] = math.max( mat1 )
	local weightThreshold = 0.25
	local selectedKey = "Grass"

	for key, weight in pairs(materialWeights) do
		if weight > materialWeights[selectedKey] and weight > weightThreshold then
			selectedKey = key
		end
	end

	return selectedKey
end

----------------------------------------------------------------------------------------------------

local water_asset_uuid = sm.uuid.new( "990cce84-a683-4ea6-83cc-d0aee5e71e15" )

function GetAssetsForCell( cellX, cellY, lod )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local assets = sm.terrainTile.getAssetsForCell( uid, tileCellOffsetX, tileCellOffsetY, lod )
		for i,asset in ipairs(assets) do
			local rx, ry = RotateLocal( cellX, cellY, asset.pos.x, asset.pos.y )

			-- Water rotation
			if asset.uuid == water_asset_uuid then
				asset.pos = sm.vec3.new( rx, ry, asset.pos.z )
				asset.rot = sm.quat.new( 0.7071067811865475, 0.0, 0.0, 0.7071067811865475 )
			else
				asset.pos = sm.vec3.new( rx, ry, asset.pos.z )
				asset.rot = GetRotationQuat( cellX, cellY ) * asset.rot
			end
			asset.pos.z = WaterSurfaceGridOffset( asset, asset.pos.z )
		end

		return assets
	end
	return {}
end

----------------------------------------------------------------------------------------------------

function GetNodesForCell( cellX, cellY )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local hasReflectionProbe = false

		local tileNodes = sm.terrainTile.getNodesForCell( uid, tileCellOffsetX, tileCellOffsetY )
		for i, node in ipairs( tileNodes ) do
			local rx, ry = RotateLocal( cellX, cellY, node.pos.x, node.pos.y )

			node.pos = sm.vec3.new( rx, ry, node.pos.z )
			node.pos.z = WaterNodeGridOffset( node, node.pos.z )
			node.rot = GetRotationQuat( cellX, cellY ) * node.rot

			hasReflectionProbe = hasReflectionProbe or ValueExists( node.tags, "REFLECTION" )
		end

		if not hasReflectionProbe then
			local x = ( cellX + 0.5 ) * CELL_SIZE
			local y = ( cellY + 0.5 ) * CELL_SIZE
			local node = {}
			node.pos = sm.vec3.new( 32, 32, GetHeightAt( x, y, 0 ) + 4 )
			node.rot = sm.quat.new( 0.707107, 0, 0, 0.707107 )
			node.scale = sm.vec3.new( 64, 64, 64 )
			node.tags = { "REFLECTION" }
			tileNodes[#tileNodes + 1] = node
		end

		return tileNodes
	end
	return {}
end

----------------------------------------------------------------------------------------------------

function GetHarvestablesForCell( cellX, cellY, size )
	if not InsideBounds( cellX, cellY, BORDER_START ) then
		-- No harvestables near the border
		return {}
	end
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		-- Load harvestables from cell
		local harvestables = sm.terrainTile.getHarvestablesForCell( uid, tileCellOffsetX, tileCellOffsetY, size )
		for _, harvestable in ipairs( harvestables ) do
			local rx, ry = RotateLocal( cellX, cellY, harvestable.pos.x, harvestable.pos.y )

			harvestable.pos = sm.vec3.new( rx, ry, harvestable.pos.z )
			harvestable.rot = GetRotationQuat( cellX, cellY ) * harvestable.rot
		end

		return harvestables
	end
	return {}
end

----------------------------------------------------------------------------------------------------

function GetDecalsForCell( cellX, cellY )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local cellDecals = sm.terrainTile.getDecalsForCell( uid, tileCellOffsetX, tileCellOffsetY )
		for _, decal in ipairs(cellDecals) do
			local rx, ry = RotateLocal( cellX, cellY, decal.pos.x, decal.pos.y )

			decal.pos = sm.vec3.new( rx, ry, decal.pos.z )
			decal.rot = GetRotationQuat( cellX, cellY ) * decal.rot
		end

		return cellDecals
	end

	return {}
end

----------------------------------------------------------------------------------------------------

function GetCreationsForCell( cellX, cellY )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local cellCreations = sm.terrainTile.getCreationsForCell( uid, tileCellOffsetX, tileCellOffsetY )
		for i,creation in ipairs( cellCreations ) do
			local rx, ry = RotateLocal( cellX, cellY, creation.pos.x, creation.pos.y )

			creation.pos = sm.vec3.new( rx, ry, creation.pos.z )
			creation.rot = GetRotationQuat( cellX, cellY ) * creation.rot
		end

		return cellCreations
	end

	return {}
end

----------------------------------------------------------------------------------------------------

function GetKinematicsForCell( cellX, cellY, size, terrainTaskTick )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		-- Load kinematics from cell
		local kinematics = sm.terrainTile.getKinematicsForCell( uid, tileCellOffsetX, tileCellOffsetY, size )

		local tileStorageKey
		local storageData
		if #kinematics > 0 then
			tileStorageKey = CalculateTileStorageKey( g_world.id, cellX, cellY )
			storageData = sm.terrainGeneration.loadGameStorage( tileStorageKey )
		end
		
		for _, kinematic in ipairs( kinematics ) do
			local rx, ry = RotateLocal( cellX, cellY, kinematic.pos.x, kinematic.pos.y )
			local x = cellX * CELL_SIZE + rx
			local y = cellY * CELL_SIZE + ry

			kinematic.pos = sm.vec3.new( rx, ry, kinematic.pos.z )
			kinematic.rot = GetRotationQuat( cellX, cellY ) * kinematic.rot
			
			LoadKinematicFromStorage( kinematic, storageData, sm.vec3.new( x, y, kinematic.pos.z ), terrainTaskTick, g_world, cellX, cellY )
		end
		
		return kinematics
	end
	return {}
end

----------------------------------------------------------------------------------------------------

function GetCellGroups()
	if g_cellData.groupId then
		return g_cellData.groupId
	end
	return {}
end

----------------------------------------------------------------------------------------------------
-- Tile Reader Path Getter
----------------------------------------------------------------------------------------------------

function GetTilePath( uid )
	if not uid:isNil() then
		return GetPath( uid )
	end
	return ""
end
