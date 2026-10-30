dofile( "$SURVIVAL_DATA/Scripts/terrain/terrain_util2.lua" )

----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

DESERT_FADE_RANGE = 128
DESERT_FADE_START = 512
DESERT_FADE_END = DESERT_FADE_START + DESERT_FADE_RANGE
BARRIER_START = 704
BARRIER_END = 704 + 64

----------------------------------------------------------------------------------------------------
-- Randomize world
----------------------------------------------------------------------------------------------------

function CreateBordersClassic( xMin, xMax, yMin, yMax, seed )
	for cellY = yMin, yMax do
		for cellX = xMin, xMax do
			if g_cellData.uid[cellY][cellX]:isNil() then
				if not InsideBounds( cellX, cellY, DESERT_FADE_START ) then
					local uid = sm.uuid.getNil()

					
					if InsideBounds( cellX, cellY, DESERT_FADE_END ) then
						uid = getBorderFadeTile( cellX, cellY, seed )
					elseif InsideBounds( cellX, cellY, BARRIER_START ) then
						uid = getDesertTile( cellX, cellY, seed )
					elseif InsideBounds( cellX, cellY, BARRIER_END ) then
						uid = getBarrierTile( cellX, cellY, -BARRIER_END / CELL_SIZE, BARRIER_START / CELL_SIZE, seed )
					end

					setTile( cellX, cellY, GetSize( uid ), uid )
				end
			end
		end
	end
end

----------------------------------------------------------------------------------------------------

function GenerateWorldClassic( xMin, xMax, yMin, yMax, seed )
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
			setTile( xCoord, yCoord, GetSize( uid ), uid )
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

				setTile( cellX, cellY, GetSize( uid ), uid )
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

function setTile( currentX, currentY, size, uid )
	if size == nil or size == 0 then return end
	for cellY = 0, size - 1 do
		for cellX = 0, size - 1 do
			if InsideCellBounds( currentX + cellX, currentY + cellY ) then
				g_cellData.uid[currentY + cellY][currentX + cellX] = uid
				g_cellData.rotation[currentY + cellY][currentX + cellX] = 0
				g_cellData.xOffset[currentY + cellY][currentX + cellX] = cellX % size
				g_cellData.yOffset[currentY + cellY][currentX + cellX] = cellY % size
			end
		end
	end
end

----------------------------------------------------------------------------------------------------

function getCell( x, y )
	return math.floor( x / CELL_SIZE), math.floor( y / CELL_SIZE )
end
