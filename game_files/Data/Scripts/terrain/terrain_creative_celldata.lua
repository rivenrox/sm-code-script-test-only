dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util2.lua" )

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

BORDER_START = 576
BORDER_END = BORDER_START + CELL_SIZE

BEACH_FIRST_START = BORDER_END
BEACH_FIRST_END = BEACH_FIRST_START + CELL_SIZE

WATER_START = BEACH_FIRST_END
WATER_END = WATER_START + CELL_SIZE * 2

BEACH_SECOND_START = WATER_END
BEACH_SECOND_END = BEACH_SECOND_START + CELL_SIZE

DESERT_START = BEACH_SECOND_END
DESERT_END = DESERT_START + CELL_SIZE

BARRIER_START = DESERT_END
BARRIER_END = BARRIER_START + CELL_SIZE

----------------------------------------------------------------------------------------------------
-- Randomize world
----------------------------------------------------------------------------------------------------

function CreateBorders( xMin, xMax, yMin, yMax, seed )
	for cellY = yMin, yMax do
		for cellX = xMin, xMax do
			if g_cellData.uid[cellY][cellX]:isNil() then
				if not InsideBounds( cellX, cellY, BORDER_START ) then
					local uid = sm.uuid.getNil()
					local rotation

					if InsideBounds( cellX, cellY, BORDER_END ) then
						uid = getBorderTile( cellX, cellY, seed )
						rotation = math.random( 0, 3 )
					elseif InsideBounds( cellX, cellY, BEACH_FIRST_END ) then
						uid, rotation = getBeachTile( cellX, cellY, -BEACH_FIRST_END / CELL_SIZE, BEACH_FIRST_START / CELL_SIZE, seed, false )
					elseif InsideBounds( cellX, cellY, WATER_END ) then
						uid = getWaterTile( cellX, cellY, seed )
						rotation = math.random( 0, 3 )
					elseif InsideBounds( cellX, cellY, BEACH_SECOND_END ) then
						uid, rotation = getBeachTile( cellX, cellY, -BEACH_SECOND_END / CELL_SIZE, BEACH_SECOND_START / CELL_SIZE, seed, true )
					elseif InsideBounds( cellX, cellY, DESERT_END ) then
						uid = getDesertTile( cellX, cellY, seed )
						rotation = math.random( 0, 3 )
					elseif InsideBounds( cellX, cellY, BARRIER_END ) then
						uid = getBarrierTile( cellX, cellY, -BARRIER_END / CELL_SIZE, BARRIER_START / CELL_SIZE, seed )
						rotation = 0
					end

					setTile( cellX, cellY, GetSize( uid ), uid, rotation )
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------

function GenerateWorld( xMin, xMax, yMin, yMax, seed )
	local uid = sm.uuid.getNil()
	local size = 0
	---------------------------------------------------------------------------
	--Try to place a few random tiles just to make things interesting
	---------------------------------------------------------------------------

	local remainingAttempts = 5
	math.randomseed( seed )
	while remainingAttempts > 0 do
		local xCoord = math.random( xMin, xMax )
		local yCoord = math.random( yMin, yMax )

		uid = g_cellData.uid[yCoord][xCoord]
		if uid:isNil() then
			local maxSize = GetMaxTileSize2( xCoord, yCoord, xMax, yMax )
			uid = getLargestSuitableTile( xCoord, yCoord, maxSize, seed )
			setTile( xCoord, yCoord, GetSize( uid ), uid, math.random( 0, 3 ) )
		end

		remainingAttempts = remainingAttempts - 1
	end

	---------------------------------------------------------------------------
	--Fill unasigned tiles
	---------------------------------------------------------------------------

	for cellY = yMin, yMax do
		for cellX = xMin, xMax do
			local uid = g_cellData.uid[cellY][cellX]
			if uid:isNil() then
				local maxSize = GetMaxTileSize2( cellX, cellY, xMax, yMax )
				if sm.noise.intNoise2d( cellX, cellY, seed ) % 5 == 0 then
					uid = getLargestSuitableTile( cellX, cellY, maxSize, seed )
				else
					uid = getSuitableTile( cellX, cellY, maxSize, seed )
				end

				setTile( cellX, cellY, GetSize( uid ), uid, math.random( 0, 3 ) )
			end
		end
	end
end

----------------------------------------------------------------------------------------------------

function GetMaxTileSize2( currentX, currentY, xMax, yMax )
	local xSteps = 0
	local ySteps = 0
	local maxArea = 1
	local bestX = 1
	local bestY = 1
	local dimensionLimit = yMax

	for cellX = currentX, xMax do
		xSteps = xSteps + 1
		ySteps = 0
		for cellY = currentY, dimensionLimit do
			ySteps = ySteps + 1
			local uid = g_cellData.uid[cellY][cellX]
			if uid:isNil() then
				if xSteps * ySteps >= maxArea then
					if math.min( xSteps, ySteps ) > math.min( bestX, bestY ) then
						bestX = xSteps
						bestY = ySteps
						maxArea = xSteps * ySteps
					end
				end
			else
				dimensionLimit = cellY - 1
				break
			end
		end
	end

	return math.min(bestX, bestY)
end

----------------------------------------------------------------------------------------------------

function InsideBounds( cellX, cellY, bounds )
	local tileBounds = bounds / CELL_SIZE -- bounds in meters
	if cellX < -tileBounds or cellX >= tileBounds then
		return false
	elseif cellY < -tileBounds or cellY >= tileBounds then
		return false
	end
	return true
end

----------------------------------------------------------------------------------------------------

function setTile( currentX, currentY, size, uid, rotation )
	if size == nil or size == 0 then return end
	rotation = rotation and rotation or 0
	for cellY = 0, size - 1 do
		for cellX = 0, size - 1 do
			if InsideCellBounds( currentX + cellX, currentY + cellY ) then
				g_cellData.uid[currentY + cellY][currentX + cellX] = uid
				g_cellData.rotation[currentY + cellY][currentX + cellX] = rotation

				if rotation == 1 then
					g_cellData.xOffset[currentY + cellY][currentX + cellX] = cellY % size
					g_cellData.yOffset[currentY + cellY][currentX + cellX] = ( size - 1 ) - cellX % size
				elseif rotation == 2 then
					g_cellData.xOffset[currentY + cellY][currentX + cellX] = ( size - 1 ) - cellX % size
					g_cellData.yOffset[currentY + cellY][currentX + cellX] = ( size - 1 ) - cellY % size
				elseif rotation == 3 then
					g_cellData.xOffset[currentY + cellY][currentX + cellX] = ( size - 1 ) - cellY % size
					g_cellData.yOffset[currentY + cellY][currentX + cellX] = cellX % size
				else
					g_cellData.xOffset[currentY + cellY][currentX + cellX] = cellX % size
					g_cellData.yOffset[currentY + cellY][currentX + cellX] = cellY % size
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------

function getCell( x, y )
	return math.floor( x / CELL_SIZE), math.floor( y / CELL_SIZE )
end
