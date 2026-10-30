dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/tile_database.lua" )
--dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/processing.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_meadow.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_forest.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_field.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_burntForest.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_autumnForest.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_lake.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/type_desert.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/roads_and_cliffs.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/overworld/celldata.lua" )

dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util2.lua" )

dofile( "$GAME_DATA/Scripts/terrain/terrain_area_util.lua" )
dofile( "$GAME_DATA/Scripts/terrain/terrain_prepare_cell_util.lua" )

dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/kinematic_util.lua" )

--dofile("terrain_celldata.lua")
--dofile("cell_rotation_utility.lua")

g_isEditor = g_isEditor or false

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

ERROR_TILE_UUID = sm.uuid.new( "723268d4-8d59-4500-a433-7d900b61c29c" )

local TYPE_MEADOW = 1
local TYPE_FOREST = 2
local TYPE_DESERT = 3
local TYPE_FIELD = 4
local TYPE_BURNTFOREST = 5
local TYPE_AUTUMNFOREST = 6
local TYPE_LAKE = 8


local FENCE_MIN_CELL = -12
local FENCE_MAX_CELL = 11

local DESERT_FADE_START = ( FENCE_MAX_CELL - 0.2 ) * CELL_SIZE
local DESERT_FADE_END = ( FENCE_MAX_CELL ) * CELL_SIZE
local DESERT_FADE_RANGE = DESERT_FADE_END - DESERT_FADE_START
local GRAPHICS_CELL_PADDING = 6

local function updateDesertFade( iMin, iMax )
	FENCE_MIN_CELL = iMin
	FENCE_MAX_CELL = iMax

	DESERT_FADE_START = ( FENCE_MAX_CELL - 0.2 ) * CELL_SIZE
	DESERT_FADE_END = ( FENCE_MAX_CELL ) * CELL_SIZE
	DESERT_FADE_RANGE = DESERT_FADE_END - DESERT_FADE_START
end

----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------

local f_uidToPath = {}

local function getOrCreateTileId( path, temp )
	if temp.pathToUid[path] == nil then
		local uid = sm.terrainTile.getTileUuid( path )
		temp.nextLegacyId = temp.nextLegacyId + 1
		temp.pathToUid[path] = uid
	end
	
	return temp.pathToUid[path]
end

local function setCell(cell, uid )
	g_cellData.uid[cell.y][cell.x] = uid
	g_cellData.xOffset[cell.y][cell.x] = cell.offsetX
	g_cellData.yOffset[cell.y][cell.x] = cell.offsetY
	g_cellData.rotation[cell.y][cell.x] = cell.rotation
end

function setFence( cellX, cellY, dir, seed, temp )
	local path = "$GAME_DATA/Terrain/Tiles/CreativeTiles/Auto/Fence"..dir
	
	if dir == "NE" or dir == "NW" or dir == "SE" or dir == "SW" then
		path = path..".tile"
	elseif dir == "N" or dir == "S" or dir == "E" or dir == "W" then
		local idx = 1 + sm.noise.intNoise2d( cellX, cellY, seed ) % 3
		path = path.."_0"..idx..".tile"
	end
	
	local cellData = { x = cellX, y = cellY, offsetX = 0, offsetY = 0, rotation = 0 }
	
	setCell( cellData, getOrCreateTileId( path, temp ) )
end

----------------------------------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------------------------------

function Init( world, generatorIndex, data )
	g_world = world
	g_isEditor = data.isWorldEditor or false
	initForestTiles()
	initDesertTiles()
	initMeadowTiles()
	initLakeTiles()
	initFieldTiles()
	initBurntForestTiles()
	initAutumnForestTiles()
	initRoadAndCliffTiles()
end

----------------------------------------------------------------------------------------------------

local function initializeCellData( xMin, xMax, yMin, yMax, seed )
	-- Version history:
	-- 2:	Changes integer 'tileId' to 'uid' from tile uuid
	--		Renamed 'tileOffsetX' -> 'xOffset'
	--		Renamed 'tileOffsetY' -> 'yOffset'
	--		Added 'version'
	--		TODO: Implement upgrade

	g_cellData = {
		bounds = { xMin = xMin, xMax = xMax, yMin = yMin, yMax = yMax },
		seed = seed,
		-- Per Cell
		uid = {},
		xOffset = {},
		yOffset = {},
		rotation = {},
		groupId = {},
		-- Per Corner
		corners = {},
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

	for cornerY = yMin, yMax+1 do
		g_cellData.corners[cornerY] = {}
		for cornerX = xMin, xMax+1 do
			g_cellData.corners[cornerY][cornerX] = 0
		end
	end

end

function Create( xMin, xMax, yMin, yMax, seed, data )
	
	local temp = { pathToUid = {}, nextLegacyId = 1 }

	-- if data worldfile we are in game
	if data.worldFile then
		jWorld = sm.json.open( data.worldFile, true )
		
		-- v0.5.0: graphicsCellPadding is no longer included in min/max
		xMin =  xMin - GRAPHICS_CELL_PADDING
		xMax =  xMax + GRAPHICS_CELL_PADDING
		yMin =  yMin - GRAPHICS_CELL_PADDING
		yMax =  yMax + GRAPHICS_CELL_PADDING
		
		initializeCellData( xMin, xMax, yMin, yMax, seed )
		g_zones = {}
		g_portals = {}

		LoadTerrain( jWorld )
		updateDesertFade( 
			g_cellData.bounds.xMin + (GRAPHICS_CELL_PADDING-1), 
			g_cellData.bounds.xMax - (GRAPHICS_CELL_PADDING-1) )
		
		for i = FENCE_MIN_CELL + 1, FENCE_MAX_CELL - 1 do
			setFence( i, FENCE_MIN_CELL, "S", seed, temp )
			setFence( i, FENCE_MAX_CELL, "N", seed, temp )
			setFence( FENCE_MIN_CELL, i, "W", seed, temp )
			setFence( FENCE_MAX_CELL, i, "E", seed, temp )	
		end
		setFence( FENCE_MIN_CELL, FENCE_MIN_CELL, "SW", seed, temp )
		setFence( FENCE_MAX_CELL, FENCE_MIN_CELL, "SE", seed, temp )
		setFence( FENCE_MIN_CELL, FENCE_MAX_CELL, "NW", seed, temp )
		setFence( FENCE_MAX_CELL, FENCE_MAX_CELL, "NE", seed, temp )

		for path, uid in pairs( temp.pathToUid ) do
			f_uidToPath[tostring(uid)] = path
		end
		
		sm.terrainData.save( { f_uidToPath, g_cellData } )
	else -- we are coming from the editor and data will be loaded later
		xMin =  xMin - GRAPHICS_CELL_PADDING
		xMax =  xMax + GRAPHICS_CELL_PADDING
		yMin =  yMin - GRAPHICS_CELL_PADDING
		yMax =  yMax + GRAPHICS_CELL_PADDING
		initializeCellData( xMin, xMax, yMin, yMax, seed )
		updateDesertFade( g_cellData.bounds.xMin +5 , g_cellData.bounds.xMax - 5  )
	end
end
	
----------------------------------------------------------------------------------------------------

function TryUpgradeLegacyData()
	legacy_idToPath = sm.terrainData.legacy_loadTerrainData( 1 )
	legacy_cellData = sm.terrainData.legacy_loadTerrainData( 2 )
	
	if legacy_idToPath ~= nil and legacy_cellData ~= nil then
		sm.log.info( "Found Legacy Custom Terrain data, attempting upgrade" )
		local temp = { pathToUid = {}, nextLegacyId = 1 }

		for id, path in pairs( legacy_idToPath ) do
			path = UpgradeCreativeTilePath( path )
			AddTile( id, path  ) -- For UpgradeCellData
			getOrCreateTileId( path, temp ) -- For f_uidToPath
		end
		
		if( UpgradeCellData( legacy_cellData ) ) then
			for path, uid in pairs( temp.pathToUid ) do
				f_uidToPath[tostring(uid)] = path
			end

			-- Store legacy data as version 0.6.0 format
			sm.terrainData.save( { f_uidToPath, legacy_cellData } )
			return true
		end
	end
	return false
end

function Load()
	if not g_isEditor then
		if sm.terrainData.exists() or TryUpgradeLegacyData() then
			local terrainData = sm.terrainData.load()
	
			f_uidToPath = terrainData[1]
			g_cellData = terrainData[2]
			
			updateDesertFade(
				g_cellData.bounds.xMin + (GRAPHICS_CELL_PADDING-1) , 
				g_cellData.bounds.xMax - (GRAPHICS_CELL_PADDING-1) )
			return true
		end
	end
	return false
end

local groundTypeGeneration = {}
groundTypeGeneration[TYPE_MEADOW] = getMeadowTileIdAndRotation
groundTypeGeneration[TYPE_FOREST] = getForestTileIdAndRotation
groundTypeGeneration[TYPE_DESERT] = getDesertTileIdAndRotation
groundTypeGeneration[TYPE_FIELD] = getFieldTileIdAndRotation
groundTypeGeneration[TYPE_BURNTFOREST] = getBurntForestTileIdAndRotation
groundTypeGeneration[TYPE_AUTUMNFOREST] = getAutumnForestTileIdAndRotation
groundTypeGeneration[TYPE_LAKE] = getLakeTileIdAndRotation

local function evaluateTileType( x, y, corners, type, fn )
	local typeSE = bit.tobit( corners[y  ][x+1] == type and 8 or 0 )
	local typeSW = bit.tobit( corners[y  ][x  ] == type and 4 or 0 )
	local typeNW = bit.tobit( corners[y+1][x  ] == type and 2 or 0 )
	local typeNE = bit.tobit( corners[y+1][x+1] == type and 1 or 0 )
	local typeBits = bit.bor( typeSE, typeSW, typeNW, typeNE )

	local tileId, rotation = fn( typeBits, sm.noise.intNoise2d( x, y, g_cellData.seed + 2854 ), sm.noise.intNoise2d( x, y, g_cellData.seed + 9439 ) )
	return tileId, rotation
end

function LoadTerrain( terrainData )
	if terrainData.cellData == nil then
		return
	end
	local terrainTileList = { pathToUid = {}, nextLegacyId = 1 }

	if terrainData.cornerData then
		terrainData.corners = {}

		for i = 1, #terrainData.cornerData do
			local cd = terrainData.cornerData[i]
			local x = cd["x"]
			local y = cd["y"]
			g_cellData.corners[y][x] = cd["type"]
		end
	end

	for _, cell in pairs( terrainData.cellData ) do
		setCell( cell, sm.uuid.getNil() )

		if cell.path ~= "" then
			setCell( cell,  getOrCreateTileId( cell.path, terrainTileList ) )
		else
			-- if ground is painted, set to correct type
			for biome, func in pairs( groundTypeGeneration ) do
				local uid, rotation = evaluateTileType( cell.x, cell.y, g_cellData.corners, biome, func )
				if not uid:isNil() then
					cell.rotation = rotation
					setCell( cell, uid )
				end
			end
		end
	end

	LoadZonesAndPortals( terrainData )
	for path, uid in pairs( terrainTileList.pathToUid ) do
		f_uidToPath[tostring(uid)] = path
	end
end

function LoadZonesAndPortals( terrainData )
	g_zones = terrainData.zoneData
	g_portals = terrainData.portalData
end

function GetCullingZoneTree()
	return g_portals, g_zones
end

----------------------------------------------------------------------------------------------------

local function getCell( x, y )
	return math.floor( x / CELL_SIZE), math.floor( y / CELL_SIZE )
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

local function getDetailHeightAt( x, y, lod )
	local cellX, cellY = getCell( x, y )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )

	local rx, ry = InverseRotateLocal( cellX, cellY, x - cellX * CELL_SIZE, y - cellY * CELL_SIZE )

	return sm.terrainTile.getHeightAt( uid, tileCellOffsetX, tileCellOffsetY, lod, rx, ry )
end

local function getCliffHeightAt( x, y )
	local cellX, cellY = getCell( x, y )

	local cliffLevelSW = getCornerCliffLevel( cellX, cellY )
	local cliffLevelSE = getCornerCliffLevel( cellX + 1, cellY )
	local cliffLevelNW = getCornerCliffLevel( cellX, cellY + 1 )
	local cliffLevelNE = getCornerCliffLevel( cellX + 1, cellY + 1 )

	return math.min( math.min( cliffLevelSW, cliffLevelSE ), math.min( cliffLevelNW, cliffLevelNE ) ) * 8
end

function GetHeightAt( x, y, lod )
	local height = -16
	height = getDetailHeightAt( x, y, lod )
	--height = height + getElevationHeightAt( x, y )
	--height = height + getCliffHeightAt( x, y )

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
	if maxDist >= DESERT_FADE_END then
		color[1] = desertColor[1]
		color[2] = desertColor[2]
		color[3] = desertColor[3]
	else
		if maxDist > DESERT_FADE_START then
			local fade = ( maxDist - DESERT_FADE_START ) / DESERT_FADE_RANGE
			color[1] = color[1] + ( desertColor[1] - color[1] ) * fade
			color[2] = color[2] + ( desertColor[2] - color[2] ) * fade
			color[3] = color[3] + ( desertColor[3] - color[3] ) * fade
		end
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
	if maxDist >= DESERT_FADE_END then
		mat1 = 1.0
	elseif maxDist > DESERT_FADE_START then
		local fade = ( maxDist - DESERT_FADE_START ) / DESERT_FADE_RANGE
		mat1 = mat1 + ( 1.0 - mat1 ) * fade
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

function PrepareCell( cellX, cellY, loadFlags )
	DefaultPrepareCell( cellX, cellY, loadFlags )
end

----------------------------------------------------------------------------------------------------

local water_asset_uuid = sm.uuid.new( "990cce84-a683-4ea6-83cc-d0aee5e71e15" )

function GetAssetsForCell( cellX, cellY, lod )
	local prefabAssets = g_prefabAssets
	g_prefabAssets = {}
	

	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local assets = sm.terrainTile.getAssetsForCell( uid, tileCellOffsetX, tileCellOffsetY, lod )
		concat( assets, prefabAssets )

		for i,asset in ipairs(assets) do
			local rx, ry = RotateLocal( cellX, cellY, asset.pos.x, asset.pos.y )

			local x = cellX * CELL_SIZE + rx
			local y = cellY * CELL_SIZE + ry

			local height = asset.pos.z
			
			-- Water rotation
			if asset.uuid == water_asset_uuid then
				asset.rot = sm.quat.new( 0.7071067811865475, 0.0, 0.0, 0.7071067811865475 )
			else
				asset.rot = GetRotationQuat( cellX, cellY ) * asset.rot
			end
			asset.pos = sm.vec3.new( rx, ry, height )
			asset.pos.z = WaterSurfaceGridOffset( asset, asset.pos.z )
		end

		if g_isEditor then
			local hvs = GetHarvestablesForCell( cellX, cellY, lod )
			for _, h in ipairs( hvs ) do
				h.colors = {}
				h.colors["default"] = h.color
				table.insert( assets, h )
			end
		end

		return assets
	end
	return {}
end

----------------------------------------------------------------------------------------------------

function GetCreationsForCell( cellX, cellY )

	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local creations = sm.terrainTile.getCreationsForCell( uid, tileCellOffsetX, tileCellOffsetY )

		for i,creation in ipairs( creations ) do
			local rx, ry = RotateLocal( cellX, cellY, creation.pos.x, creation.pos.y )
			creation.pos = sm.vec3.new( rx, ry, creation.pos.z )
			creation.rot = GetRotationQuat( cellX, cellY ) * creation.rot
		end

		return creations
	end

	return {}
end

----------------------------------------------------------------------------------------------------

function GetNodesForCell( cellX, cellY )
	local prefabNodes = g_prefabNodes
	g_prefabNodes = {}

	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local hasReflectionProbe = false

		local tileNodes = sm.terrainTile.getNodesForCell( uid, tileCellOffsetX, tileCellOffsetY )
		concat( tileNodes, prefabNodes )

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
	local prefabHarvestables = g_prefabHarvestables
	g_prefabHarvestables = {}

	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		-- Load harvestables from cell
		local harvestables = sm.terrainTile.getHarvestablesForCell( uid, tileCellOffsetX, tileCellOffsetY, size )
		concat( harvestables, prefabHarvestables )

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
	local prefabDecals = g_prefabDecals
	g_prefabDecals = {}

	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local cellDecals = sm.terrainTile.getDecalsForCell( uid, tileCellOffsetX, tileCellOffsetY )
		concat( cellDecals, prefabDecals )
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
	local prefabCreations = g_prefabCreations
	g_prefabCreations = {}

	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local cellCreations = sm.terrainTile.getCreationsForCell( uid, tileCellOffsetX, tileCellOffsetY )
		concat( cellCreations, prefabCreations )
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
-- Tile Reader Path Getter
----------------------------------------------------------------------------------------------------

function UpgradeCreativeTilePath( path )
	if string.find( path, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/", 1, false ) == nil
			and string.find( path, "$GAME_DATA/Terrain/Tiles/CreativeTiles/", 1, false ) == nil then
				return string.gsub( path, "$GAME_DATA/Terrain/Tiles/", "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/", 1 )
		end
	return path
end

function GetTilePath( uid )
	if not uid:isNil() then
		if f_uidToPath[tostring(uid)] then
			return UpgradeCreativeTilePath( f_uidToPath[tostring(uid)] )
		else
			return GetPath( uid )
		end
	end
	return ""
end

-------------------------------------------------------------------------------------------------------

function GetKinematicsForCell( cellX, cellY, size, terrainTaskTick )
	local prefabKinematics = g_prefabKinematics
	g_prefabKinematics = {}


	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local cellKinematics = sm.terrainTile.getKinematicsForCell( uid, tileCellOffsetX, tileCellOffsetY, size )

		local tileStorageKey
		local storageData
		if #cellKinematics > 0 then
			tileStorageKey = CalculateTileStorageKey( g_world.id, cellX, cellY )
			storageData = sm.terrainGeneration.loadGameStorage( tileStorageKey )
		end
		
		concat( cellKinematics, prefabKinematics )
		
		for i,kinematic in ipairs( cellKinematics ) do
			local rx, ry = RotateLocal( cellX, cellY, kinematic.pos.x, kinematic.pos.y )
			local x = cellX * CELL_SIZE + rx
			local y = cellY * CELL_SIZE + ry

			kinematic.pos = sm.vec3.new( rx, ry, kinematic.pos.z )
			kinematic.rot = GetRotationQuat( cellX, cellY ) * kinematic.rot

			LoadKinematicFromStorage( kinematic, storageData, sm.vec3.new( x, y, kinematic.pos.z ), terrainTaskTick, g_world, cellX, cellY )
		end

		return cellKinematics
	end
	return {}
end

-------------------------------------------------------------------------------------------------------

function GetVoxelTerrainForCell( cellX, cellY )
	
	local uid, xOffset, yOffset = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local rotation = GetCellRotation( cellX, cellY )

		sm.voxelTerrainCell.copyTileCellVoxels( uid, xOffset, yOffset, rotation )
	end

end

----------------------------------------------------------------------------------------------------

function GetCellGroups()
	if g_cellData.groupId then
		return g_cellData.groupId
	end
	return {}
end