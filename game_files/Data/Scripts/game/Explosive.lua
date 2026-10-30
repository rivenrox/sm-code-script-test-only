dofile( "$SURVIVAL_DATA/Scripts/game/managers/AttachedFireManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

Explosive = class()
Explosive.poseWeightCount = 1

local FireDelay = 80 --ticks (2 seconds)
local ChainExplosionDelay = 5 --ticks (0.125 seconds)
local FlameProjectiles = 3
local FlameProjectileVelocity = 9.0

--[[ Server ]]

-- (Event) Called upon creation on server
function Explosive.server_onCreate( self )
	self:server_init()
end

-- (Event) Called when script is refreshed (in [-dev])
function Explosive.server_onRefresh( self )
	self:server_init()
end

-- Initialize explosive
function Explosive.server_init( self )
	self.alive = true
	self.counting = false
	self.fireDelayProgress = 0
	
	self.interactable.publicData = { drillLevel = 1 }
	self.plasmaDrillHitTick = 0

	-- Default values. Overwritten by data.
	self.destructionLevel = 1
	self.destructionRadius = 1.0
	self.impulseRadius = 12.0
	self.impulseMagnitude = 400.0

	-- Read data from interactive.json. See "scripted": "data".
	if self.data then
		if self.data.destructionLevel then
			self.destructionLevel = self.data.destructionLevel
		end
		if self.data.destructionRadius then
			self.destructionRadius = self.data.destructionRadius
		end
		if self.data.impulseRadius then
			self.impulseRadius = self.data.impulseRadius
		end
		if self.data.impulseMagnitude then
			self.impulseMagnitude = self.data.impulseMagnitude
		end
	end
end

-- (Event) Called upon game tick. (40 times a second)
function Explosive.server_onFixedUpdate( self, timeStep )
	if self.counting then
		self.fireDelayProgress = self.fireDelayProgress + 1
		if self.fireDelayProgress >= FireDelay then
			self:server_tryExplode()
		end
	end
end

-- Attempt to create an explosion
function Explosive.server_tryExplode( self )
	if self.alive and self.shape.body.destructable then
		self.alive = false
		self.counting = false
		self.fireDelayProgress = 0
		
		-- Create explosion
		sm.physics.explode( self.shape.worldPosition, self.destructionLevel, self.destructionRadius, self.impulseRadius, self.impulseMagnitude, self.explosionEffectName, self.shape, nil, nil, self.data.damage,self.shape,self.shape:getShapeUuid() )
		AttachedFireManager.Sv_OnExplosion( self.shape.worldPosition, self.destructionLevel )

		-- Fire ignite projectile
		for i = 1, FlameProjectiles do
			sm.projectile.shapeProjectileAttack( projectile_flame, 0, sm.vec3.zero(), RandomUnitVector() * FlameProjectileVelocity, self.shape )
		end

		sm.shape.destroyPart( self.shape )
	end
end

-- Trigger or accelerate the explosion countdown from a hit at hitPos.
function Explosive.server_triggerHit( self, hitPos )
	if self.alive and self.shape.body.destructable then
		if self.counting then
			self.fireDelayProgress = self.fireDelayProgress + FireDelay * 0.5
		else
			self:server_startCountdown()
			self.network:sendToClients( "client_hitActivation", hitPos )
		end
	end
end

-- (Event) Called upon getting hit by a projectile.
function Explosive.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	if damage > 0 then
		self:server_triggerHit( hitPos )
	end
end

-- (Event) Called upon getting hit by a melee attack.
function Explosive.server_onMelee( self, hitPos, attackingCharacter, damage, power, hitDirection )
	self:server_triggerHit( hitPos )
end

function Explosive.sv_e_plasmaDrill( self, params )
	local currentTick = sm.game.getCurrentTick()
	if currentTick - self.plasmaDrillHitTick > 20 then
		self:server_triggerHit( params.hitPos )
		self.plasmaDrillHitTick = currentTick
	end
end

-- (Event) Called upon collision with an explosion nearby
function Explosive.server_onExplosion( self, center, destructionLevel )
	-- Explode within a few ticks
	if self.alive and self.shape.body.destructable then
		self.fireDelayProgress = math.max( self.fireDelayProgress, FireDelay - ChainExplosionDelay )
		self.counting = true
	end
end

-- (Event) Called upon collision with another object
function Explosive.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	if sm.exists(other) and type( other ) == "Character" and other:isPlayer() then
		return
	end
	local collisionDirection = (selfPointVelocity - otherPointVelocity):normalize()
	local diffVelocity = (selfPointVelocity - otherPointVelocity):length()
	-- local selfPointVelocityLength = selfPointVelocity:length() 
	-- local otherPointVelocityLength = otherPointVelocity:length()
	local scaleFraction = 1.0 - ( self.fireDelayProgress / FireDelay )
	local dotFraction = math.abs( collisionDirection:dot( collisionNormal ) )

	local hardTrigger = diffVelocity * dotFraction >= 10 * scaleFraction
	local lightTrigger = diffVelocity * dotFraction >= 6 * scaleFraction

	if self.alive and self.shape.body.destructable then
		if hardTrigger then
			-- Trigger explosion immediately
			self.counting = true
			self.fireDelayProgress = self.fireDelayProgress + FireDelay
		elseif lightTrigger then
			if self.counting then
				self.fireDelayProgress = self.fireDelayProgress + FireDelay * ( 1.0 - scaleFraction )
			else
				self:server_startCountdown()
				self.network:sendToClients( "client_hitActivation", collisionPosition )
			end
		end
	end
end

-- Start countdown and update clients
function Explosive.server_startCountdown( self )
	self.counting = true
	self.network:sendToClients( "client_startCountdown" )
end

--[[ Client ]]

-- (Event) Called upon creation on client
function Explosive.client_onCreate( self )
	self.client_counting = false
	self.client_fuseDelayProgress = 0
	self.client_fireDelayProgress = 0
	self.client_effect_doOnce = true

	-- Default values. Overwritten by data.
	self.explosionEffectName = "PropaneTank - ExplosionSmall"
	self.activateEffectName = "PropaneTank - ActivateSmall"

	-- Read data from interactive.json. See "scripted": "data".
	if self.data then
		if self.data.effectExplosion then
			self.explosionEffectName = self.data.effectExplosion
		end
		if self.data.effectActivate then
			self.activateEffectName = self.data.effectActivate
		end
	end

	self.singleHitEffect = sm.effect.createEffect( "PropaneTank - SingleActivate", self.interactable )
	self.activateEffect = sm.effect.createEffect( self.activateEffectName, self.interactable )
end

function Explosive.client_onDestroy( self )
	self.singleHitEffect:stopImmediate()
	self.activateEffect:stopImmediate()
end

-- (Event) Called upon every frame. (Same as fps)
function Explosive.client_onUpdate( self, dt )
	if self.client_counting then
		self.client_fuseDelayProgress = self.client_fuseDelayProgress + dt
		local scaleAndVibration = ScaleAndVibrate( self.client_fuseDelayProgress, FireDelay / SERVER_TICKS_PER_SECOND, 0.0, 0.2, 200 )
		self.interactable:setPoseWeight( 0, scaleAndVibration )

		self.client_fireDelayProgress = self.client_fireDelayProgress + dt
		self.activateEffect:setParameter( "progress", self.client_fireDelayProgress / ( FireDelay * ( 1 / 40 ) ) )
	end
end

-- Called from server upon getting triggered by a hit
function Explosive.client_hitActivation( self, hitPos )
	local localPos = self.shape:transformPoint( hitPos )

	local smokeDirection = ( hitPos - self.shape.worldPosition ):normalize()
	local worldRot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), smokeDirection )
	local localRot = self.shape:transformRotation( worldRot )

	self.singleHitEffect:start()
	self.singleHitEffect:setOffsetRotation( localRot )
	self.singleHitEffect:setOffsetPosition( localPos )
end

-- Called from server upon countdown start
function Explosive.client_startCountdown( self )
	self.client_counting = true
	self.activateEffect:start()

	local offsetRotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), sm.vec3.new( 0, 1, 0 ) ) * sm.vec3.getRotation( sm.vec3.new( 1, 0, 0 ), sm.vec3.new( 0, 1, 0 ) )
	self.activateEffect:setOffsetRotation( offsetRotation )
end
