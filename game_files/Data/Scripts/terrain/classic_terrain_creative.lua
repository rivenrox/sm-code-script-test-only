dofile("$GAME_DATA/Scripts/terrain/classic_creative_celldata.lua")
dofile("$GAME_DATA/Scripts/terrain/classic_creative_tile_list.lua")
dofile("$SURVIVAL_DATA/Scripts/terrain/overworld/tile_database.lua")
dofile("$SURVIVAL_DATA/Scripts/terrain/terrain_util2.lua")

----------------------------------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------------------------------

function Init()
	InitTileList()
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

	-- v0.5.0: graphicsCellPadding is no longer included in min/max
	local graphicsCellPadding = 6
	xMin = xMin - graphicsCellPadding
	xMax = xMax + graphicsCellPadding
	yMin = yMin - graphicsCellPadding
	yMax = yMax + graphicsCellPadding

	initializeCellData( xMin, xMax, yMin, yMax, seed )

	CreateBordersClassic( xMin, xMax, yMin, yMax, seed )
	GenerateWorldClassic( -8, 7, -8, 7, seed )

	sm.terrainData.save( g_cellData )
end

----------------------------------------------------------------------------------------------------

function Load()
	if sm.terrainData.exists() then

		g_cellData = sm.terrainData.legacy_getData()
		
		if not g_cellData then
			g_cellData = sm.terrainData.load()
		end

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

	local r, g, b = sm.terrainTile.getColorAt( uid, tileCellOffsetX, tileCellOffsetY, lod, x - cellX * CELL_SIZE, y - cellY * CELL_SIZE )

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

	local mat1, mat2, mat3, mat4, mat5, mat6, mat7, mat8 = sm.terrainTile.getMaterialAt( uid, tileCellOffsetX, tileCellOffsetY, lod, x - cellX * CELL_SIZE, y - cellY * CELL_SIZE )
	
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
	local maxDist = math.max( math.abs(x), math.abs(y) ) / 2
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	
	if maxDist > DESERT_FADE_START and maxDist <= DESERT_FADE_END then
		local fade = ( maxDist - DESERT_FADE_START ) / DESERT_FADE_RANGE
		local clutterNoise = sm.noise.floatNoise2d( x, y, g_cellData.seed )
		
		if fade * 2 - 1 > clutterNoise then
			return -1
		end
	end

	x = x * 0.5 - cellX * CELL_SIZE
	y = y * 0.5 - cellY * CELL_SIZE

	local clutterIdx = sm.terrainTile.getClutterIdxAt( uid, tileCellOffsetX, tileCellOffsetY, x * 2, y * 2 )
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

function GetAssetsForCell( cellX, cellY, lod )
	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local assets = sm.terrainTile.getAssetsForCell( uid, tileCellOffsetX, tileCellOffsetY, lod )
		for _, asset in ipairs(assets) do
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
			hasReflectionProbe = hasReflectionProbe or ValueExists( node.tags, "REFLECTION" )

			node.pos.z = WaterNodeGridOffset( node, node.pos.z )
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
	return {}
end

----------------------------------------------------------------------------------------------------

function GetDecalsForCell( cellX, cellY )
	return {}
end

----------------------------------------------------------------------------------------------------

function GetCreationsForCell( cellX, cellY )
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
