dofile "$SURVIVAL_DATA/Scripts/terrain/random_generation.lua"


function DefaultPrepareCell( cellX, cellY, loadFlags, randomizationTable, additionalProcessing )
	g_prefabNodes = {}
	-- This value needs to be larger then the number of connection nodes in the cell
	g_connectionNodeCount = 65536
	g_prefabCreations = {}
	g_prefabHarvestables = {}
	g_prefabDecals = {}
	g_prefabAssets = {}
	g_prefabKinematics = {}







	local uid, tileCellOffsetX, tileCellOffsetY = GetCellTileUidAndOffset( cellX, cellY )
	if not uid:isNil() then
		local prefabs = sm.terrainTile.getPrefabsForCell( uid, tileCellOffsetX, tileCellOffsetY )
		for prefabIndex, prefab in ipairs( prefabs ) do
			DefaultLoadPrefabProcedure( prefab, loadFlags, prefabIndex, prefab.name, randomizationTable, additionalProcessing, nil )
		end
	end
end

function DefaultLoadPrefabProcedure( prefab, loadFlags, prefabIndex, prefabName, randomizationTable, additionalProcessing, rootPrefabCenter )
	randomizationTable = randomizationTable or {
		prefabTable = {},
		blueprintTable = {}
	}
	additionalProcessing = additionalProcessing or {
		creations = nil,
		nodes = nil,
		assets = nil,
		decals = nil,
		harvestables = nil,
		kinematics = nil
	}
	RandomizePrefab( prefab, randomizationTable.prefabTable )

	local creations, prefabs, nodes, assets, decals, harvestables, kinematics, aabb = sm.terrainTile.getContentFromPrefab( prefab.name, loadFlags )

	if rootPrefabCenter == nil then
		if aabb and aabb.min and aabb.max then
			local center = ( ( aabb.min + aabb.max ) * 0.5 )
			rootPrefabCenter = prefab.pos + ( prefab.rot * ( center * prefab.scale ) )
		else
			rootPrefabCenter = sm.vec3.new( 0, 0, 0 )
		end
	end

	local mergeCreations = bit.band( prefab.flags, MergeCreationFlag ) ~= 0
	for _,creation in ipairs( creations ) do
		RandomizeCreation( creation, blueprintTable )



		creation.rot = prefab.rot * creation.rot
		creation.pos = prefab.pos + ( prefab.rot * creation.pos )
		concat( creation.tags, prefab.tags )
		creation.mergeCreation = mergeCreations
		creation.rootPrefabCenterPosition = rootPrefabCenter

		if additionalProcessing.creations then
			additionalProcessing.creations( creation, prefab, prefabIndex )
		end

		g_prefabCreations[#g_prefabCreations + 1] = creation
	end
	
	for _,subPrefab in ipairs( prefabs ) do

		subPrefab.rot = prefab.rot * subPrefab.rot
		subPrefab.pos = prefab.pos + ( prefab.rot * (subPrefab.pos * prefab.scale ) )
		subPrefab.scale = prefab.scale * subPrefab.scale

		concat( subPrefab.tags, prefab.tags )

		if mergeCreations then
			subPrefab.flags = bit.bor( subPrefab.flags, MergeCreationFlag )
		end

		DefaultLoadPrefabProcedure( subPrefab, loadFlags, prefabIndex, prefabName, randomizationTable, additionalProcessing, rootPrefabCenter )
	end
	
	local connectionNodeCount = g_connectionNodeCount or 65536
	for _,node in ipairs( nodes ) do

		node.rot = prefab.rot * node.rot
		node.pos = prefab.pos + ( prefab.rot * ( node.pos * prefab.scale ) )
		node.scale = node.scale * prefab.scale
		node.rootPrefabCenterPosition = rootPrefabCenter

		concat( node.tags, prefab.tags )
		
		if node.params and node.params.connections then
			node.params.connections.id = node.params.connections.id + g_connectionNodeCount;

			for index, value in ipairs(node.params.connections.otherIds) do
				if (type(value) == "table") then
					value.id = value.id + g_connectionNodeCount
				else
					node.params.connections.otherIds[index] = node.params.connections.otherIds[index] + g_connectionNodeCount
				end
			end

			connectionNodeCount = math.max( node.params.connections.id, connectionNodeCount )
		end


		if additionalProcessing.nodes then
			additionalProcessing.nodes( node, prefab, prefabIndex )
		end
		
		g_prefabNodes[#g_prefabNodes + 1] = node
	end
	g_connectionNodeCount = connectionNodeCount + 1

	for _,asset in ipairs( assets ) do

		asset.rot = prefab.rot * asset.rot
		asset.pos = prefab.pos + ( prefab.rot * ( asset.pos * prefab.scale ) )
		asset.scale = asset.scale * prefab.scale
		asset.rootPrefabCenterPosition = rootPrefabCenter

		concat( asset.tags, prefab.tags )

		if additionalProcessing.assets then
			additionalProcessing.assets( asset, prefab, prefabIndex )
		end
		
		g_prefabAssets[#g_prefabAssets + 1] = asset
	end
	for _,decal in ipairs( decals ) do
		decal.rot = prefab.rot * decal.rot
		decal.pos = prefab.pos + ( prefab.rot * ( decal.pos * prefab.scale ) )
		decal.scale = decal.scale * prefab.scale
		decal.rootPrefabCenterPosition = rootPrefabCenter

		concat( decal.tags, prefab.tags )

		if additionalProcessing.decals then
			additionalProcessing.decals( decal, prefab, prefabIndex )
		end
		
		g_prefabDecals[#g_prefabDecals + 1] = decal
	end
	for _,harvestable in ipairs( harvestables ) do
		harvestable.rot = prefab.rot * harvestable.rot
		harvestable.pos = prefab.pos + ( prefab.rot * ( harvestable.pos * prefab.scale ) )
		harvestable.scale = harvestable.scale * prefab.scale
		harvestable.rootPrefabCenterPosition = rootPrefabCenter

		concat( harvestable.tags, prefab.tags )

		if additionalProcessing.harvestables then
			additionalProcessing.harvestables( harvestable, prefab, prefabIndex )
		end
		
		g_prefabHarvestables[#g_prefabHarvestables + 1] = harvestable
	end
	for _,kinematic in ipairs( kinematics ) do
		kinematic.rot = prefab.rot * kinematic.rot
		kinematic.pos = prefab.pos + ( prefab.rot * ( kinematic.pos * prefab.scale ) )
		kinematic.scale = kinematic.scale * prefab.scale
		kinematic.rootPrefabCenterPosition = rootPrefabCenter

		concat( kinematic.tags, prefab.tags )

		if additionalProcessing.kinematics then
			additionalProcessing.kinematics( kinematic, prefab, prefabIndex )
		end
		
		g_prefabKinematics[#g_prefabKinematics + 1] = kinematic
	end
end
