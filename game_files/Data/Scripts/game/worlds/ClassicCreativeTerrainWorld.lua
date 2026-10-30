dofile( "$GAME_DATA/Scripts/game/worlds/CreativeBaseWorld.lua")

ClassicCreativeTerrainWorld = class( CreativeBaseWorld )

ClassicCreativeTerrainWorld.terrainScript = "$GAME_DATA/Scripts/terrain/classic_terrain_creative.lua"
ClassicCreativeTerrainWorld.enableSurface = true
ClassicCreativeTerrainWorld.enableAssets = true
ClassicCreativeTerrainWorld.enableClutter = true
ClassicCreativeTerrainWorld.enableNodes = false
ClassicCreativeTerrainWorld.enableCreations = false
ClassicCreativeTerrainWorld.enableHarvestables = false
ClassicCreativeTerrainWorld.enableKinematics = false
ClassicCreativeTerrainWorld.cellMinX = -11
ClassicCreativeTerrainWorld.cellMaxX = 10
ClassicCreativeTerrainWorld.cellMinY = -11
ClassicCreativeTerrainWorld.cellMaxY = 10
