local MipDivisor = { 1, 2, 4, 8, 16, 32 }
local TexLodScale = { 1, 2, 4, 8, 16, 32, 64, 128 }
local HScale = 2

----------------------------------------------------------------------------------------------------

function GetHeightArea( xStart, xRange, yStart, yRange, lod )
	local area = {}
	local step = HScale * MipDivisor[lod+1]
	for y = 0, yRange-1 do
		for x = 0, xRange-1 do
			area[#area+1] = GetHeightAt( xStart + x*step, yStart + y*step, lod )
		end
	end
	return area
end

----------------------------------------------------------------------------------------------------

function GetColorArea( xStart, xRange, yStart, yRange, lod )
	local area = {}
	local step = HScale * MipDivisor[lod+1]
	for y = 0, yRange-1 do
		for x = 0, xRange-1 do
			local r, g, b = GetColorAt( xStart + x*step, yStart + y*step, lod );
			local packedColor = bit.bor(bit.lshift(255, 24), bit.lshift(b*255, 16), bit.lshift(g*255, 8), r*255 )
			area[#area+1] = packedColor
		end
	end
	return area
end

----------------------------------------------------------------------------------------------------

function GetMaterialArea( xStart, xRange, yStart, yRange, lod )
    local area = {}
    local step = TexLodScale[lod+1]
    for y = 0, yRange-1 do
        local yStep = yStart + y*step
        for x = 0, xRange-1 do
            local xStep = xStart + x*step
            local mat0, mat1, mat2, mat3, mat4, mat5, mat6, mat7 = GetMaterialAt( xStep, yStep, lod )
            local packedMaterialA = bit.bor( bit.lshift(mat3*255, 24), bit.lshift(mat2*255, 16), bit.lshift(mat1*255, 8), mat0*255 )
            local packedMaterialB = bit.bor( bit.lshift(mat7*255, 24), bit.lshift(mat6*255, 16), bit.lshift(mat5*255, 8), mat4*255 )
            area[#area+1] = packedMaterialA
            area[#area+1] = packedMaterialB
        end
    end
    return area
end

----------------------------------------------------------------------------------------------------

function GetClutterIdxArea( xStart, xRange, yStart, yRange )
	local area = {}
	for y = 0, yRange-1 do
		for x = 0, xRange-1 do
			area[#area+1] = GetClutterIdxAt( ( xStart + x ) * 2, ( yStart + y ) * 2 )
		end
	end
	return area
end

----------------------------------------------------------------------------------------------------

function GetEffectMaterialArea( xStart, xRange, yStart, yRange )
	local area = {}
	for y = 0, yRange-1 do
		for x = 0, xRange-1 do
			area[#area+1] = GetEffectMaterialAt( xStart + x, yStart + y )
		end
	end
	return area
end

----------------------------------------------------------------------------------------------------

function GetCellGroups()
	if g_cellData.groupId then
		return g_cellData.groupId
	end
	return {}
end