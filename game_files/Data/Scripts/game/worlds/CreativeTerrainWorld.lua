dofile( "$GAME_DATA/Scripts/game/worlds/CreativeBaseWorld.lua")

CreativeTerrainWorld = class( CreativeBaseWorld )

CreativeTerrainWorld.terrainScript = "$GAME_DATA/Scripts/terrain/terrain_creative.lua"
CreativeTerrainWorld.enableSurface = true
CreativeTerrainWorld.enableAssets = true
CreativeTerrainWorld.enableClutter = true
CreativeTerrainWorld.enableNodes = true
CreativeTerrainWorld.enableCreations = false
CreativeTerrainWorld.enableHarvestables = true
CreativeTerrainWorld.enableKinematics = true
CreativeTerrainWorld.cellMinX = -15
CreativeTerrainWorld.cellMaxX = 14
CreativeTerrainWorld.cellMinY = -15
CreativeTerrainWorld.cellMaxY = 14