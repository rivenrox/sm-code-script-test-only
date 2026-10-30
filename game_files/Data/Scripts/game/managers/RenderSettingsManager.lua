dofile "$SURVIVAL_DATA/Scripts/util.lua"

local TodFile = dofile( "$GAME_DATA/Render/Settings/time_of_day_default.todsettings" )

RenderSettingsManager = class( nil )

RenderSettingsManager.transitionTime = 2

function RenderSettingsManager.client_onCreate( self )
    g_renderSettingsManager = self
    self.cl = {}

    if TodFile then
        self.cl.outdoorTimeline = TodFile.timeline
        table.sort( self.cl.outdoorTimeline, function(a, b) return a.time < b.time end )
    else
        self.cl.outdoorTimeline = {}
    end

    self.cl.volumes = {}
    self.cl.mapVolumeSettings = {}
    self.cl.volumeOverride = {
        frac = 0,
        trigger = nil
     }

    self.cl.transition = 0
    self.cl.currentZone = nil
    self.cl.previousZone = nil

    self.cl.worldSettings = {}
    self.cl.renderSettings = {}
    self.cl.interpolationSettings = { from = nil, to = nil }

    self.cl.fallbackSettings = {}
    self.cl.fallbackSettings.camera_light = sm.render.getDefaultCameraLight()
    self.cl.fallbackSettings.fog = sm.render.getDefaultFog()
    self.cl.fallbackSettings.GI = sm.render.getDefaultGI()
    self.cl.fallbackSettings.horizon_light = sm.render.getDefaultHorizonLight()
    self.cl.fallbackSettings.reflection_color = sm.render.getDefaultReflectionColor()
    self.cl.fallbackSettings.LUT = { LUT = "Default" }
    self.cl.fallbackSettings.volumetric_fog = sm.render.getDefaultVolumetricFog()
    self.cl.fallbackSettings.voxel_lod_boost = { boost = sm.render.getDefaultVoxelLODBoost(), override = false }

    self.cl.renderSettings["fallback"] = self.cl.fallbackSettings

    for index, value in ipairs( self.cl.outdoorTimeline ) do
        if value.settingsPath and value.settingsPath ~= "" then
            if self.cl.renderSettings[value.settingsPath] == nil then
                self.cl.renderSettings[value.settingsPath] = self:cl_preprocessSettings( sm.json.open( value.settingsPath ).settings )
            end
        end
    end

    self.cl.playerId = {}
end

function RenderSettingsManager.Cl_onCellLoaded( x, y )
    if g_renderSettingsManager then
		g_renderSettingsManager:cl_onCellLoaded( x, y )
	end
end

function RenderSettingsManager.cl_onCellLoaded( self, x, y )
    local rendersettingsVolumes = sm.cell.getNodesByTag( x, y, "RENDERSETTINGS_VOLUME" )
    local cellKey = CellKey( x, y )
    for index, node in ipairs( rendersettingsVolumes ) do
        if self.cl.volumes[cellKey] == nil then
            self.cl.volumes[cellKey] = {}
        end

        local areaTrigger = sm.areaTrigger.createBox( node.scale * 0.5, node.position, node.rotation, sm.areaTrigger.filter.character )
        self.cl.volumes[cellKey] = self.cl.volumes[cellKey] or {}
        self.cl.volumes[cellKey][index] = areaTrigger
        areaTrigger:bindOnEnter( "cl_trigger_onEnter", self )
        areaTrigger:bindOnExit( "cl_trigger_onExit", self )
        
        self.cl.mapVolumeSettings[areaTrigger.id] = node.params
    end


end

function RenderSettingsManager.Cl_AddAreaTriggerRenderSettings( areaTrigger, renderSettingParams )
    if g_renderSettingsManager then
		g_renderSettingsManager:cl_addAreaTriggerRenderSettings( areaTrigger, renderSettingParams )
	end
end

function RenderSettingsManager.cl_addAreaTriggerRenderSettings( self, areaTrigger, renderSettingParams )
    areaTrigger:bindOnEnter( "cl_trigger_onEnter", self )
    areaTrigger:bindOnExit( "cl_trigger_onExit", self )
    self.cl.mapVolumeSettings[areaTrigger.id] = renderSettingParams
end

function RenderSettingsManager.cl_trigger_onEnter( self, trigger, results )
    if TriggerResultContainsLocalPlayer( results ) then
        self.cl.playerId[trigger.id] = sm.localPlayer.getPlayer().character.id
        self.cl.volumeOverride.trigger = trigger




    end
end

function RenderSettingsManager.cl_trigger_onExit( self, trigger, results )
    if results == nil then 
        return false 
    end
	for _,result in ipairs( results ) do
		if result.id == self.cl.playerId[trigger.id] then
			 self.cl.volumeOverride.trigger = nil
            self.cl.volumeOverride.frac = 0
			self.cl.playerId[trigger.id] = nil
		end
	end




end

function RenderSettingsManager.Cl_onCellUnloaded( x, y )
    if g_renderSettingsManager then
		g_renderSettingsManager:cl_onCellUnloaded( x, y )
	end
end

function RenderSettingsManager.cl_onCellUnloaded( self, x, y )
    local cellKey = CellKey( x, y )
    if self.cl.volumes[cellKey] then
        for index, areaTrigger in ipairs( self.cl.volumes[cellKey] ) do
            self.cl.mapVolumeSettings[areaTrigger.id] = nil
            areaTrigger:destroy()
        end
    end
    self.cl.volumes[cellKey] = nil
end

function RenderSettingsManager.Cl_RemoveAreaTriggerRenderSettings( areaTrigger )
    if g_renderSettingsManager then
		g_renderSettingsManager:cl_removeAreaTriggerRenderSettings( areaTrigger )
	end
end

function RenderSettingsManager.cl_removeAreaTriggerRenderSettings( self, areaTrigger )
    self.cl.mapVolumeSettings[areaTrigger.id] = nil
    if self.cl.volumeOverride.trigger and self.cl.volumeOverride.trigger.id == areaTrigger.id then
        self.cl.volumeOverride.trigger = nil
        self.cl.volumeOverride.frac = 0



    end
end

function RenderSettingsManager.client_onRefresh( self )
    if TodFile then
        self.cl.outdoorTimeline = TodFile.timeline
        table.sort( self.cl.outdoorTimeline, function(a, b) return a.time < b.time end )
    else
        self.cl.outdoorTimeline = {}
    end

    for index, value in ipairs( self.cl.outdoorTimeline ) do
        if value.settingsPath and value.settingsPath ~= "" then
            if self.cl.renderSettings[value.settingsPath] == nil then
                self.cl.renderSettings[value.settingsPath] = self:cl_preprocessSettings( sm.json.open( value.settingsPath ).settings )
            end
        end
    end
end


function RenderSettingsManager.cl_preprocessSettings( self, settings )
    self:cl_getHorizonLightArgs( settings.horizon_light )
    self:cl_getFogArgs( settings.fog )
    self:cl_getCameraLightArgs( settings.camera_light )
    
    if settings.camera_light.far and settings.camera_light.far.enable then
        self:cl_getCameraLightArgs( settings.camera_light.far )
    else
        settings.camera_light.far = {
            intensity = settings.camera_light.intensity,
            range = settings.camera_light.range,
            color = settings.camera_light.color,
        }
    end
    return settings
end

function RenderSettingsManager.cl_getHorizonLightArgs( self, horizonLight )
    horizonLight.top_color.a = horizonLight.top_color.a * horizonLight.top_intensity
    horizonLight.middle_color.a = horizonLight.middle_color.a * horizonLight.middle_intensity
    horizonLight.bottom_color.a = horizonLight.bottom_color.a * horizonLight.bottom_intensity
end

function RenderSettingsManager.cl_getFogArgs( self, fog )
    fog.start_color = fog.start_color * fog.start_mul
    fog.end_color = fog.end_color * fog.end_mul
end

function RenderSettingsManager.cl_getCameraLightArgs( self, cameraLight )
    cameraLight.color = cameraLight.color * cameraLight.color_mul
end

function RenderSettingsManager.cl_mixGI( self, fromGI, toGI, t )
    if t == 1 then
        return toGI
    elseif t == 0 then
        return fromGI
    end
    return { 
        weight = unclampedLerp( fromGI.weight, toGI.weight, t ) 
    }
end

function RenderSettingsManager.cl_mixCameraLight( self, fromCameraLight, toCameraLight, t )
    local result
    if t == 1 then
        result = toCameraLight
    elseif t == 0 then
        result = fromCameraLight
    else
        result = {
            intensity = unclampedLerp( fromCameraLight.intensity, toCameraLight.intensity, t ),
            range = unclampedLerp( fromCameraLight.range, toCameraLight.range, t ),
            color = sm.color.lerp( fromCameraLight.color, toCameraLight.color, t )
        }
        result.far = {
            intensity = unclampedLerp( fromCameraLight.far.intensity, toCameraLight.far.intensity, t ),
            range = unclampedLerp( fromCameraLight.far.range, toCameraLight.far.range, t ),
            color = sm.color.lerp( fromCameraLight.far.color, toCameraLight.far.color, t )
        }
    end
    return result
end

function RenderSettingsManager.cl_mixFog( self, fromFog, toFog, t )
    if t == 1 and not toFog.selective_override and not toFog.vertical_fog.selective_override then
        return toFog
    elseif t == 0 then
        return fromFog
    end

    local sel = toFog.selective_override

    local result = {
        falloff = unclampedLerp(fromFog.falloff, (not sel or sel.falloff) and toFog.falloff or fromFog.falloff, t),
        start = unclampedLerp(fromFog.start, (not sel or sel.start) and toFog.start or fromFog.start, t),
        start_color = sm.color.lerp(fromFog.start_color, (not sel or sel.start_color) and toFog.start_color or fromFog.start_color, t),
        ["end"] = unclampedLerp(fromFog["end"], (not sel or sel["end"]) and toFog["end"] or fromFog["end"], t),
        end_color = sm.color.lerp(fromFog.end_color, (not sel or sel.end_color) and toFog.end_color or fromFog.end_color, t),
        fade_distance = unclampedLerp(fromFog.fade_distance, (not sel or sel.fade_distance) and toFog.fade_distance or fromFog.fade_distance, t),
    }

    local vsel = toFog.vertical_fog.selective_override
    result.vertical_fog = {
        opacity = unclampedLerp(fromFog.vertical_fog.opacity, (not vsel or vsel.opacity) and toFog.vertical_fog.opacity or fromFog.vertical_fog.opacity, t),
        fade_distance = unclampedLerp(fromFog.vertical_fog.fade_distance, (not vsel or vsel.fade_distance) and toFog.vertical_fog.fade_distance or fromFog.vertical_fog.fade_distance, t),
        falloff = unclampedLerp(fromFog.vertical_fog.falloff, (not vsel or vsel.falloff) and toFog.vertical_fog.falloff or fromFog.vertical_fog.falloff, t),
        start = unclampedLerp(fromFog.vertical_fog.start, (not vsel or vsel.start) and toFog.vertical_fog.start or fromFog.vertical_fog.start, t),
        ["end"] = unclampedLerp(fromFog.vertical_fog["end"], (not vsel or vsel["end"]) and toFog.vertical_fog["end"] or fromFog.vertical_fog["end"], t),
        start_color = sm.color.lerp(fromFog.vertical_fog.start_color, (not vsel or vsel.start_color) and toFog.vertical_fog.start_color or fromFog.vertical_fog.start_color, t),
        end_color = sm.color.lerp(fromFog.vertical_fog.end_color, (not vsel or vsel.end_color) and toFog.vertical_fog.end_color or fromFog.vertical_fog.end_color, t)
    }

    return result
end

function RenderSettingsManager.cl_mixHorizonLight( self, fromHorizonLight, toHorizonLight, t )
    if t == 1 then
        return toHorizonLight
    elseif t == 0 then
        return fromHorizonLight
    end

    return {
        top_color = sm.color.lerp( fromHorizonLight.top_color, toHorizonLight.top_color, t ),
        middle_color = sm.color.lerp( fromHorizonLight.middle_color, toHorizonLight.middle_color, t ),
        bottom_color = sm.color.lerp( fromHorizonLight.bottom_color, toHorizonLight.bottom_color, t ),
        direction = sm.vec3.lerp( fromHorizonLight.direction, toHorizonLight.direction, t ),
        start = unclampedLerp( fromHorizonLight.start, toHorizonLight.start, t ),
        ["end"] = unclampedLerp( fromHorizonLight["end"], toHorizonLight["end"], t ),
        falloff = unclampedLerp( fromHorizonLight.falloff, toHorizonLight.falloff, t )
    }
end

function RenderSettingsManager.cl_mixReflection( self, fromReflection, toReflection, t )
    if t == 1 then
        return toReflection
    elseif t == 0 then
        return fromReflection
    end
    return {
        reflection_high = {
            min = unclampedLerp( fromReflection.reflection_high.min, toReflection.reflection_high.min, t ),
            max = unclampedLerp( fromReflection.reflection_high.max, toReflection.reflection_high.max, t ),
            mul = unclampedLerp( fromReflection.reflection_high.mul, toReflection.reflection_high.mul, t )
        },
        reflection_medium = {
            min = unclampedLerp( fromReflection.reflection_medium.min, toReflection.reflection_medium.min, t ),
            max = unclampedLerp( fromReflection.reflection_medium.max, toReflection.reflection_medium.max, t ),
            mul = unclampedLerp( fromReflection.reflection_medium.mul, toReflection.reflection_medium.mul, t )
        },
        reflection_low = {
            min = unclampedLerp( fromReflection.reflection_low.min, toReflection.reflection_low.min, t ),
            max = unclampedLerp( fromReflection.reflection_low.max, toReflection.reflection_low.max, t ),
            mul = unclampedLerp( fromReflection.reflection_low.mul, toReflection.reflection_low.mul, t )
        },
        reflection_off = {
            min = unclampedLerp( fromReflection.reflection_off.min, toReflection.reflection_off.min, t ),
            max = unclampedLerp( fromReflection.reflection_off.max, toReflection.reflection_off.max, t ),
            mul = unclampedLerp( fromReflection.reflection_off.mul, toReflection.reflection_off.mul, t )
        }
    }
end

function RenderSettingsManager.cl_mixVolumetricFog( self, fromVolumetricFog, toVolumetricFog, t )
    if t == 1 then
        return toVolumetricFog
    elseif t == 0 then
        return fromVolumetricFog
    end
    return {
        min = unclampedLerp( fromVolumetricFog.min, toVolumetricFog.min, t ),
        max = unclampedLerp( fromVolumetricFog.max, toVolumetricFog.max, t ),
        loop_speed = unclampedLerp( fromVolumetricFog.loop_speed, toVolumetricFog.loop_speed, t ),
        scroll_speed = unclampedLerp( fromVolumetricFog.scroll_speed, toVolumetricFog.scroll_speed, t ),
        scale = unclampedLerp( fromVolumetricFog.scale, toVolumetricFog.scale, t ),
        intensity = unclampedLerp( fromVolumetricFog.intensity, toVolumetricFog.intensity, t )
    }
end

function RenderSettingsManager.cl_mixVoxelLODBoost( self, fromVoxelLODBoost, toVoxelLODBoost, t )
    if t == 1 then
        return toVoxelLODBoost
    elseif t == 0 then
        return fromVoxelLODBoost
    end
    return {
        boost = unclampedLerp( fromVoxelLODBoost.boost, toVoxelLODBoost.boost, t ),
        override = toVoxelLODBoost.override
    }
end



function RenderSettingsManager.cl_mixRenderSettings( self, fromSettings, toSettings, t )
    local mix = {
        GI = nil,
        camera_light = nil,
        fog = nil,
        reflection_color = nil,
        LUTargs = nil,
        horizon_light = nil,
        volumetric_fog = nil,
        voxel_lod_boost = nil
    }

    -- GI
    mix.GI = self:cl_mixGI( fromSettings.GI, toSettings.GI, t )

    -- Camera light
    mix.camera_light = self:cl_mixCameraLight( fromSettings.camera_light, toSettings.camera_light, t )

    -- Fog
    mix.fog = self:cl_mixFog( fromSettings.fog, toSettings.fog, t )

    -- Reflection
    mix.reflection_color = self:cl_mixReflection( fromSettings.reflection_color, toSettings.reflection_color, t )

    -- LUT
    local toLUT = toSettings.LUT
    local fromLUT = fromSettings.LUT
    mix.LUTargs = { fromLUT.LUT, toLUT.LUT, t }

    -- Horizon Light
    -- Only applies if no directional light i.e. not Outdoor or Challenge
    mix.horizon_light = self:cl_mixHorizonLight( fromSettings.horizon_light, toSettings.horizon_light, t )

    -- Volumetric Fog
    mix.volumetric_fog = self:cl_mixVolumetricFog( fromSettings.volumetric_fog, toSettings.volumetric_fog, t )

    -- Voxel LOD Boost
    mix.voxel_lod_boost = self:cl_mixVoxelLODBoost( fromSettings.voxel_lod_boost, toSettings.voxel_lod_boost, t )

    return mix
end

function RenderSettingsManager.cl_applySettings( self, target, source )
    if source.GI ~= nil and source.GI.override == true then
        target.GI = source.GI
    end
    if source.camera_light ~= nil and source.camera_light.override == true then
        target.camera_light = source.camera_light
    elseif source.camera_light ~= nil and source.camera_light.far.enable == true then
        target.camera_light = shallowcopy( target.camera_light )
        target.camera_light.far = source.camera_light.far
    end
    if source.fog ~= nil and source.fog.override == true then
        local sel = source.fog.selective_override
        if sel then
            target.fog = shallowcopy( target.fog )
            for field, enabled in pairs( sel ) do
                if enabled and source.fog[field] ~= nil then
                    target.fog[field] = source.fog[field]
                end
            end
        else
            target.fog = source.fog
        end

        local vsel = source.fog.vertical_fog.selective_override
        if vsel then
            target.fog = shallowcopy( target.fog )
            target.fog.vertical_fog = shallowcopy( target.fog.vertical_fog )
            for vField, vEnabled in pairs( vsel ) do
                if vEnabled and source.fog.vertical_fog[vField] ~= nil then
                    target.fog.vertical_fog[vField] = source.fog.vertical_fog[vField]
                end
            end
        else
            target.fog = shallowcopy( target.fog )
            target.fog.vertical_fog = source.fog.vertical_fog
        end
    end
    if source.reflection_color ~= nil and source.reflection_color.override == true then
        target.reflection_color = source.reflection_color
    end
    if source.LUT ~= nil and source.LUT.override == true then
        target.LUT = source.LUT
    end
    if source.horizon_light ~= nil and source.horizon_light.enable == true then
        target.horizon_light = source.horizon_light
    end
    if source.volumetric_fog ~= nil and source.volumetric_fog.override == true then
        target.volumetric_fog = source.volumetric_fog
    end
    if source.voxel_lod_boost ~= nil and source.voxel_lod_boost.override == true then
        target.voxel_lod_boost = source.voxel_lod_boost
    end
end

function RenderSettingsManager.cl_resetAll( self )
    sm.render.resetGI()
    sm.render.resetCameraLight()
    sm.render.resetFog()
    sm.render.resetAllReflectionColor()
    sm.render.resetLUT()
    sm.render.resetHorizonLight()
    sm.render.resetVolumetricFog()
    sm.render.resetVoxelLODBoost()
end

function RenderSettingsManager.client_onUpdate( self, dt )
    local isOutdoor = sm.render.isOutdoor()

    if self.cl.volumeOverride.trigger and sm.exists( self.cl.volumeOverride.trigger ) then

        local trigger = self.cl.volumeOverride.trigger
        local position = sm.localPlayer.getPlayer():getCharacter():getWorldPosition()
        local volumeParams = self.cl.mapVolumeSettings[trigger.id]

        
        local border = volumeParams.settings.settings.border or 0
        local boxMin = trigger:getWorldMin()
        local boxMax = trigger:getWorldMax()
        local halfExtents = trigger:getSize()

        -- position is guaranteed to be inside box
        local xValue  = saturate( min( boxMax.x - position.x, position.x - boxMin.x ) /  math.min( border, halfExtents.x ) )
        local yValue  = saturate( min( boxMax.y - position.y, position.y - boxMin.y ) /  math.min( border, halfExtents.y ) )
        local zValue  = saturate( min( boxMax.z - position.z, position.z - boxMin.z ) /  math.min( border, halfExtents.z ) )

        local path = self.cl.mapVolumeSettings[trigger.id].settings.settings.renderSettings
        if path ~= nil and path ~= "" then
            self.cl.volumeOverride.frac = math.min( xValue, yValue, zValue )
            if self.cl.renderSettings[path] == nil then
                self.cl.renderSettings[path] = self:cl_preprocessSettings( sm.json.open( path ).settings )
            end
            self.cl.volumeOverride.currentOverride = self.cl.renderSettings[path]
        end
    else
        self.cl.volumeOverride.frac = 0
        self.cl.volumeOverride.currentOverride = nil
    end

    local player = sm.localPlayer.getPlayer()
    if player == nil then
        return
    end
    local character = player:getCharacter()
    if character == nil then
        return
    end
    local world = character:getWorld()
    if world == nil then
        return
    end

    local volumeOverride = nil
    if  self.cl.volumeOverride.frac > 0 and self.cl.volumeOverride.currentOverride then
        volumeOverride = self.cl.volumeOverride.currentOverride
    end

    if isOutdoor then
        self.cl.currentZone = nil
        self.cl.previousZone = nil
    
        local tod = sm.game.getTimeOfDay()
        
        local anyTodSettings = false
        for _, value in ipairs( self.cl.outdoorTimeline ) do
            if value.settingsPath ~= "" then
                anyTodSettings = true
            end
        end

        -- get the most recent setting in the timeline
        if anyTodSettings then
            local fromSetting = self.cl.outdoorTimeline[1]
            local toSetting = self.cl.outdoorTimeline[1]

            local timelineIndex = 0
            for i, value in ipairs( self.cl.outdoorTimeline ) do
                if value.time < tod then
                    fromSetting = self.cl.outdoorTimeline[i]
                    timelineIndex = i
                else
                    break
                end
            end

            if timelineIndex == #self.cl.outdoorTimeline then
                toSetting = self.cl.outdoorTimeline[1]
                self.cl.transition = inverseLerp( fromSetting.time, 1 + toSetting.time, tod )
            elseif timelineIndex == 0 then
                fromSetting = self.cl.outdoorTimeline[#self.cl.outdoorTimeline]
                self.cl.transition = inverseLerp( fromSetting.time, 1 + toSetting.time, 1 + tod )
            else
                toSetting = self.cl.outdoorTimeline[timelineIndex + 1]
                self.cl.transition = inverseLerp( fromSetting.time, toSetting.time, tod )
            end

            self.cl.interpolationSettings.from = fromSetting.settingsPath
            self.cl.interpolationSettings.to = toSetting.settingsPath

            if self.cl.interpolationSettings.from == "" then
                self.cl.interpolationSettings.from = nil
            end
            if self.cl.interpolationSettings.to == "" then
                self.cl.interpolationSettings.to = nil
            end
        elseif volumeOverride == nil then
            -- the timeline is empty, reset all settings
            self:cl_resetAll()
            return
        end
        if AmbienceManager then
            AmbienceManager.Cl_UpdateZone( nil )
        end
    else

        local zoneId = world:getZoneId( character:getWorldPosition() )

        if self.cl.currentZone ~= zoneId and zoneId ~= nil then
            if self.cl.previousZone == zoneId then -- reverse transition 
                self.cl.previousZone, self.cl.currentZone = self.cl.currentZone, self.cl.previousZone
                self.cl.transition = 1 - self.cl.transition
                self.cl.interpolationSettings.from, self.cl.interpolationSettings.to = self.cl.interpolationSettings.to, self.cl.interpolationSettings.from
            else
                self.cl.previousZone = self.cl.currentZone
                self.cl.currentZone = zoneId
                self.cl.transition = 0

                -- find the settings of the current zone
                local settingsPath = nil
                if self.cl.worldSettings[world:getId()] then
                    for _, zone in ipairs( self.cl.worldSettings[world:getId()] ) do
                        if zone.id == self.cl.currentZone then
                            settingsPath = zone.settingsPath
                            break
                        end
                    end
                end
                self.cl.interpolationSettings.from = self.cl.interpolationSettings.to
                self.cl.interpolationSettings.to = settingsPath
            end
            if AmbienceManager then
                AmbienceManager.Cl_UpdateZone( self.cl.currentZone )
            end
        end
    end

    if not isOutdoor then
        if WarehouseManager and WarehouseManager.Cl_GetWarehouseFromWorld( world ) then
            -- Warehouses don't have a default render settings file. But they use one during the destruction event.
            local worldSettings = self.cl.renderSettings["defaultWorld"..world:getId()]
            if not worldSettings then
                self:cl_resetAll()
                return
            end
        end

        if self.cl.skipTransition then
            self.cl.transition = 1
            self.cl.skipTransition = false
        else
            self.cl.transition = self.cl.transition + ( ( 1 / RenderSettingsManager.transitionTime ) *  dt )
            self.cl.transition = min( self.cl.transition, 1 )
        end
    end
    

    local t = isOutdoor and self.cl.transition or sm.util.smootherstep( 0, 1, self.cl.transition )
    
    -- start with the fallback settings
    local toSettings = shallowcopy( self.cl.renderSettings["fallback"] )
    local fromSettings = shallowcopy( self.cl.renderSettings["fallback"] )
    
    -- apply the world settings if they exist
    if not isOutdoor then
        local worldSettings = self.cl.renderSettings["defaultWorld"..world:getId()]
        if worldSettings then
            self:cl_applySettings( toSettings, worldSettings )
            self:cl_applySettings( fromSettings, worldSettings )
        end
    end

    -- apply the interpolated settings if they exist
    if self.cl.interpolationSettings.to ~= nil then
        self:cl_applySettings( toSettings, self.cl.renderSettings[self.cl.interpolationSettings.to] )
    end
    if self.cl.interpolationSettings.from ~= nil then
        self:cl_applySettings( fromSettings, self.cl.renderSettings[self.cl.interpolationSettings.from] )
    end





    -- mix the interpolated settings
    local mix = self:cl_mixRenderSettings( fromSettings, toSettings, t )
   
    -- if an override configuration exists, mix it in.
    if volumeOverride then
        if volumeOverride.GI and volumeOverride.GI.override then
            mix.GI = self:cl_mixGI( mix.GI, volumeOverride.GI, self.cl.volumeOverride.frac )
        end
        if volumeOverride.camera_light and volumeOverride.camera_light.override then
            mix.camera_light = self:cl_mixCameraLight( mix.camera_light, volumeOverride.camera_light, self.cl.volumeOverride.frac )
        end
        if volumeOverride.fog and volumeOverride.fog.override then
            mix.fog = self:cl_mixFog( mix.fog, volumeOverride.fog, self.cl.volumeOverride.frac )
        end
        if volumeOverride.reflection_color and volumeOverride.reflection_color.override then
            mix.reflection_color = self:cl_mixReflectionLevel( mix.reflection_color, volumeOverride.reflection_color, self.cl.volumeOverride.frac )
        end
        if volumeOverride.LUT and volumeOverride.LUT.override then
            mix.LUTargs = { mix.LUTargs[2], volumeOverride.LUT.LUT, self.cl.volumeOverride.frac }
        end
        if volumeOverride.horizon_light and volumeOverride.horizon_light.enable then
            mix.horizon_light = self:cl_mixHorizonLight( mix.horizon_light, volumeOverride.horizon_light, self.cl.volumeOverride.frac )
        end
        if volumeOverride.volumetric_fog and volumeOverride.volumetric_fog.override then
            mix.volumetric_fog = self:cl_mixVolumetricFog( mix.volumetric_fog, volumeOverride.volumetric_fog, self.cl.volumeOverride.frac )
        end
        if volumeOverride.voxel_lod_boost and volumeOverride.voxel_lod_boost.override then
            mix.voxel_lod_boost = self:cl_mixVoxelLODBoost( mix.voxel_lod_boost, volumeOverride.voxel_lod_boost, self.cl.volumeOverride.frac )
        end
    end

    -- apply the mixed settings
    sm.render.setGI( mix.GI.weight )
    sm.render.setCameraLight( mix.camera_light.intensity, mix.camera_light.range, mix.camera_light.color, mix.camera_light.far.intensity, mix.camera_light.far.range, mix.camera_light.far.color )
    sm.render.setFog( mix.fog.start, mix.fog["end"], mix.fog.falloff, mix.fog.start_color, mix.fog.end_color,
        mix.fog.vertical_fog.opacity, mix.fog.vertical_fog.fade_distance, mix.fog.vertical_fog.falloff,
        mix.fog.vertical_fog.start, mix.fog.vertical_fog["end"], mix.fog.vertical_fog.start_color, mix.fog.vertical_fog.end_color, mix.fog.fade_distance )
    sm.render.setReflectionLevelColor( "High", mix.reflection_color.reflection_high.min, mix.reflection_color.reflection_high.max, mix.reflection_color.reflection_high.mul )
    sm.render.setReflectionLevelColor( "Medium", mix.reflection_color.reflection_medium.min, mix.reflection_color.reflection_medium.max, mix.reflection_color.reflection_medium.mul )
    sm.render.setReflectionLevelColor( "Low", mix.reflection_color.reflection_low.min, mix.reflection_color.reflection_low.max, mix.reflection_color.reflection_low.mul )
    sm.render.setReflectionLevelColor( "Off", mix.reflection_color.reflection_off.min, mix.reflection_color.reflection_off.max, mix.reflection_color.reflection_off.mul )
    sm.render.setLUT( unpack( mix.LUTargs ) )
    sm.render.setHorizonLight( mix.horizon_light.top_color, mix.horizon_light.middle_color, mix.horizon_light.bottom_color, mix.horizon_light.direction, mix.horizon_light.start, mix.horizon_light["end"], mix.horizon_light.falloff )
    sm.render.setVolumetricFog( mix.volumetric_fog.min, mix.volumetric_fog.max, mix.volumetric_fog.loop_speed, mix.volumetric_fog.scroll_speed, mix.volumetric_fog.scale, mix.volumetric_fog.intensity )
    sm.render.setVoxelLODBoost( mix.voxel_lod_boost.boost )























































end

function RenderSettingsManager.client_onLocalPlayerChangedWorld( self, world )
    g_renderSettingsManager:cl_refreshCurrentWorldSettings( world )
end

function RenderSettingsManager.Cl_RefreshCurrentWorldSettings( world )
    if g_renderSettingsManager then
        g_renderSettingsManager:cl_refreshCurrentWorldSettings( world )
    end
end

function RenderSettingsManager.cl_refreshCurrentWorldSettings( self, world )
    self.cl.currentZone = nil
    self.cl.previousZone = nil
    self.cl.interpolationSettings.from = nil
    self.cl.interpolationSettings.to = nil
    self.cl.transition = 0
    self.cl.skipTransition = true

    -- set the default render settings
    if self.cl.renderSettings["defaultWorld"..world:getId()] == nil then
        if world.clientPublicData and world.clientPublicData.defaultRenderSetting and world.clientPublicData.defaultRenderSetting ~= "" then
            self.cl.renderSettings["defaultWorld"..world:getId()] = self:cl_preprocessSettings( sm.json.open( world.clientPublicData.defaultRenderSetting ).settings )
        else
            self.cl.renderSettings["defaultWorld"..world:getId()] = self.cl.fallbackSettings
        end
    end
	
    -- load world settings file if needed
    if self.cl.worldSettings[world:getId()] == nil then
        if world.clientPublicData and world.clientPublicData.zoneSettings then
            if world.clientPublicData.zoneSettings ~= nil then
                self.cl.worldSettings[world:getId()] = world.clientPublicData.zoneSettings.zoneData
            end
        end

        -- load render settings if needed
        if self.cl.worldSettings[world:getId()] then
            for _, value in ipairs( self.cl.worldSettings[world:getId()] ) do
                if self.cl.renderSettings[value.settingsPath] == nil then
                    self.cl.renderSettings[value.settingsPath] = self:cl_preprocessSettings( sm.json.open( value.settingsPath ).settings )
                end
            end
        end
    end
end

function RenderSettingsManager.Cl_ModifyWorldRenderSettingsDefault( world, settingsPath )
    if g_renderSettingsManager then
        g_renderSettingsManager:cl_modifyWorldRenderSettingsDefault( world, settingsPath )
    end
end

function RenderSettingsManager.cl_modifyWorldRenderSettingsDefault( self, world, settingsPath )
    local key = "defaultWorld"..world:getId()
    self.cl.renderSettings[key] = self:cl_preprocessSettings( sm.json.open( settingsPath ).settings )

    local player = sm.localPlayer.getPlayer()
    if player == nil then
        return
    end
    local character = player:getCharacter()
    if character == nil then
        return
    end
    local currentWorld = character:getWorld()
    if currentWorld == nil then
        return
    end

    -- if we are in the world and there is no zone, transition to the new default
    if currentWorld == world and self.cl.currentZone == nil then
        self.cl.transition = 0
        self.cl.interpolationSettings.from = self.cl.interpolationSettings.to
        self.cl.interpolationSettings.to = key
    end
end

function RenderSettingsManager.Cl_ModifyZoneRenderSettings( world, index )
    if g_renderSettingsManager then
        g_renderSettingsManager:cl_modifyZoneRenderSettings( world, index )
    end
end

function RenderSettingsManager.cl_modifyZoneRenderSettings( self, world, zoneIndex )
    if self.cl.worldSettings[world:getId()] ~= nil then
        if world.clientPublicData and world.clientPublicData.zoneSettings then
            self.cl.worldSettings[world:getId()] = world.clientPublicData.zoneSettings.zoneData
        end

        if self.cl.worldSettings[world:getId()] then
            for _, value in ipairs( self.cl.worldSettings[world:getId()] ) do
                if self.cl.renderSettings[value.settingsPath] == nil then
                    self.cl.renderSettings[value.settingsPath] = self:cl_preprocessSettings( sm.json.open( value.settingsPath ).settings )
                end
            end
        end
    end

    if self.cl.currentZone == zoneIndex then
        self.cl.previousZone = self.cl.currentZone
        self.cl.currentZone = zoneIndex
        self.cl.transition = 0

        -- find the settings of the current zone
        local settingsPath = nil
        if self.cl.worldSettings[world:getId()] then
            for _, zone in ipairs( self.cl.worldSettings[world:getId()] ) do
                if zone.id == self.cl.currentZone then
                    settingsPath = zone.settingsPath
                    break
                end
            end
        end
        self.cl.interpolationSettings.from = self.cl.interpolationSettings.to
        self.cl.interpolationSettings.to = settingsPath
    end
end