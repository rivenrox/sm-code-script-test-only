----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------

g_barrierTileList = g_barrierTileList or  { ["NE"] = {}, ["NW"] = {}, ["SE"] = {}, ["SW"] = {}, ["N"] = {}, ["S"] = {}, ["E"] = {}, ["W"] = {} }
g_desertTileList = g_desertTileList or {}
g_borderFadeTileList = g_borderFadeTileList or {}
g_terrainTileList = g_terrainTileList or {}


g_useCounts = g_useCounts or {}

-----------------------------------------------------------------------------------------------------

function getBarrierTile( x, y, tileMin, tileMax, seed )
	local direction = ""
	if y == tileMax then
		direction = direction .. "N"
	elseif y == tileMin then
		direction = direction .. "S"
	end

	if x == tileMax then
		direction = direction .. "E"
	elseif x == tileMin then
		direction = direction .. "W"
	end

	assert( g_barrierTileList[direction] )
	return g_barrierTileList[direction][1 + sm.noise.intNoise2d( x, y, seed ) % #g_barrierTileList[direction]]
end

-----------------------------------------------------------------------------------------------------

function getDesertTile( x, y, seed )
	local idx = 1 + sm.noise.intNoise2d( x, y, seed ) % #g_desertTileList
	return g_desertTileList[idx]
end

-----------------------------------------------------------------------------------------------------

function getBorderFadeTile( x, y, seed )
	local idx = 1 + sm.noise.intNoise2d( x, y, seed ) % #g_borderFadeTileList
	return g_borderFadeTileList[idx]
end

-----------------------------------------------------------------------------------------------------

function getSuitableTile( x, y, maxSize, seed )
	local size = 0
	local minSize = getGreatestPossibleMinSize( sm.noise.intNoise2d( x, y, seed ) %  maxSize )
	local usageCount = 0

	local suitable, lowestUsage = getSuitableTileCount( maxSize, minSize )

	local steps = sm.noise.intNoise2d( x, y, seed ) % suitable

	--step a number of suitable tiles forward and return the last one
	local index = 1
	while index <= #g_terrainTileList do
		local uid = g_terrainTileList[index]
		usageCount = g_useCounts[tostring(uid)] or 0
		if usageCount == lowestUsage then
			size = GetSize( uid )
			if size <= maxSize and size >= minSize then
				if steps > 0 then
					steps = steps - 1
				else
					break
				end
			end
		end

		index = index + 1
	end

	local uid = g_terrainTileList[index]
	g_useCounts[tostring(uid)] = g_useCounts[tostring(uid)]+1

	return uid
end

---------------------------------------------------------------------------------------------------

function getLargestSuitableTile( x, y, maxSize, seed )
	local size = 0
	local minSize = getGreatestPossibleMinSize(maxSize)

	local suitable, lowestUsage = getSuitableTileCount( maxSize, minSize )

	local steps = sm.noise.intNoise2d( x, y, seed ) % suitable

	--step a number of suitable tiles forward and return the last one
	local index = 1
	while index <= #g_terrainTileList do
		local uid = g_terrainTileList[index]
		if g_useCounts[tostring(uid)] == lowestUsage then
			size = GetSize( uid )
			if size <= maxSize and size >= minSize then
				if steps > 0 then
					steps = steps - 1
				else
					break
				end
			end
		end

		index = index + 1
	end

	local uid = g_terrainTileList[index]
	g_useCounts[tostring(uid)] = g_useCounts[tostring(uid)] + 1

	return uid
end

---------------------------------------------------------------------------------------------------

function getSuitableTileCount( maxSize, minSize )
	local suitableTiles = 0
	local lowestUsage = 1000 --Just a big number, no singe tile should be use this many times with the current map size
	local index = 1

	while index <= #g_terrainTileList do
		local uid = g_terrainTileList[index]
		local size = GetSize( uid )
		if size <= maxSize and size >= minSize then

			local usage = g_useCounts[tostring(uid)]
			if lowestUsage > usage then

				lowestUsage = usage
				suitableTiles = 1
			elseif usage == lowestUsage then
				suitableTiles = suitableTiles + 1
			end
		end
		index = index + 1
	end

	return suitableTiles, lowestUsage
end

----------------------------------------------------------------------------------------------------

function getGreatestPossibleMinSize( maxSize )
	local minSize = 1
	for index = 1, #g_terrainTileList do
		local uid = g_terrainTileList[index]
		local size = GetSize( uid )
		if size <= maxSize then
			minSize = math.max( minSize, size )
		end
	end

	return minSize
end

----------------------------------------------------------------------------------------------------

function InitTileList()

	-- Barriers
	-- Corners
	g_barrierTileList["NE"][#g_barrierTileList["NE"] + 1] = AddTile( 30000, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceNE.tile" )
	g_barrierTileList["NW"][#g_barrierTileList["NW"] + 1] = AddTile( 30001, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceNW.tile" )
	g_barrierTileList["SE"][#g_barrierTileList["SE"] + 1] = AddTile( 30002, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceSE.tile" )
	g_barrierTileList["SW"][#g_barrierTileList["SW"] + 1] = AddTile( 30003, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceSW.tile" )
	-- North
	g_barrierTileList["N"][#g_barrierTileList["N"] + 1] = AddTile( 31000, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceN_01.tile" )
	g_barrierTileList["N"][#g_barrierTileList["N"] + 1] = AddTile( 31001, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceN_02.tile" )
	g_barrierTileList["N"][#g_barrierTileList["N"] + 1] = AddTile( 31002, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceN_03.tile" )
	-- South
	g_barrierTileList["S"][#g_barrierTileList["S"] + 1] = AddTile( 32000, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceS_01.tile" )
	g_barrierTileList["S"][#g_barrierTileList["S"] + 1] = AddTile( 32001, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceS_02.tile" )
	g_barrierTileList["S"][#g_barrierTileList["S"] + 1] = AddTile( 32002, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceS_03.tile" )
	-- East
	g_barrierTileList["E"][#g_barrierTileList["E"] + 1] = AddTile( 33000, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceE_01.tile" )
	g_barrierTileList["E"][#g_barrierTileList["E"] + 1] = AddTile( 33001, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceE_02.tile" )
	g_barrierTileList["E"][#g_barrierTileList["E"] + 1] = AddTile( 33002, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceE_03.tile" )
	-- West
	g_barrierTileList["W"][#g_barrierTileList["W"] + 1] = AddTile( 34000, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceW_01.tile" )
	g_barrierTileList["W"][#g_barrierTileList["W"] + 1] = AddTile( 34001, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceW_02.tile" )
	g_barrierTileList["W"][#g_barrierTileList["W"] + 1] = AddTile( 34002, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/FenceW_03.tile" )


	-- Desert
	g_desertTileList[#g_desertTileList + 1] = AddTile( 20000, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/DESERT64_01.tile" )
	g_desertTileList[#g_desertTileList + 1] = AddTile( 20001, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/DESERT64_02.tile" )
	g_desertTileList[#g_desertTileList + 1] = AddTile( 20002, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/DESERT64_03.tile" )
	g_desertTileList[#g_desertTileList + 1] = AddTile( 20003, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/DESERT64_04.tile" )
	g_desertTileList[#g_desertTileList + 1] = AddTile( 20004, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/DESERT64_05.tile" )


	--BorderFade
	g_borderFadeTileList[#g_borderFadeTileList + 1] = AddTile( 10000, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/BORDERFADE128_01.tile" )
	g_borderFadeTileList[#g_borderFadeTileList + 1] = AddTile( 10001, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/Auto/BORDERFADE128_02.tile" )

	-- Standard tiles
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 1, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/FOREST256_01.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 2, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_01.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 3, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_02.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 4, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_03.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 5, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND128_01.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 6, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND128_02.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 7, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND128_03.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 8, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND128_04.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 9, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_01.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 10, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_02.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 11, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_03.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 12, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_04.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 13, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND512_01.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 14, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/HILLS256_01.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 15, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/HILLS512_01.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 16, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_01.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 17, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_02.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 18, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_03.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 19, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_04.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 20, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_05.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 21, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_06.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 22, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_07.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 23, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_08.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 24, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_09.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 25, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_10.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 26, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_11.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 27, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_12.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 28, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_13.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 29, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_14.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 30, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_15.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 31, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_16.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 32, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_17.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 33, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_18.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 34, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_19.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 35, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_20.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 36, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_01.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 37, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_02.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 38, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_03.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 39, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_04.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 40, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_05.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 41, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_06.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 42, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_07.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 43, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_08.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 44, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_09.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 45, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_10.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 46, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_11.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 47, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW128_12.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 48, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW256_01.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 49, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/START64_01.tile" )

	-- ^ Initial 1.0.0 tile set ^

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 50, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_05.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 51, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_06.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 52, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_07.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 53, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_04.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 54, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_05.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 55, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_06.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 56, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_07.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 57, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_08.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 58, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_09.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 59, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_10.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 60, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND128_05.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 61, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND128_06.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 62, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND128_07.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 63, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND128_08.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 64, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_08.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 65, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_09.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 66, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_10.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 67, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_11.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 68, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND256_12.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 69, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND512_02.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 70, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND512_03.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 71, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND512_04.tile" )

	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 72, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND512_05.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 73, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/GROUND64_11.tile" )
	g_terrainTileList[#g_terrainTileList + 1] = AddTile( 74, "$GAME_DATA/Terrain/Tiles/ClassicCreativeTiles/MEADOW64_21.tile" )

	for _, uid in ipairs( g_terrainTileList ) do
		g_useCounts[tostring(uid)] = 0
	end

	for _, uid in ipairs( g_borderFadeTileList ) do
		g_useCounts[tostring(uid)] = 0
	end

	for _, uid in ipairs( g_desertTileList ) do
		g_useCounts[tostring(uid)] = 0
	end

	for _, uid in ipairs( g_barrierTileList ) do
		g_useCounts[tostring(uid)] = 0
	end
end