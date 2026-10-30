dofile( "$GAME_DATA/Scripts/game/worlds/CreativeBaseWorld.lua")

CreativeCustomWorld = class( CreativeBaseWorld )

CreativeCustomWorld.terrainScript = "$GAME_DATA/Scripts/terrain/terrain_custom.lua"
CreativeCustomWorld.enableSurface = true
CreativeCustomWorld.enableAssets = true
CreativeCustomWorld.enableClutter = true
CreativeCustomWorld.enableNodes = true
CreativeCustomWorld.enableCreations = true
CreativeCustomWorld.enableHarvestables = true
CreativeCustomWorld.enableKinematics = true
CreativeCustomWorld.enableVoxelTerrain = true
CreativeCustomWorld.cellMinX = -11
CreativeCustomWorld.cellMaxX = 10
CreativeCustomWorld.cellMinY = -11
CreativeCustomWorld.cellMaxY = 10