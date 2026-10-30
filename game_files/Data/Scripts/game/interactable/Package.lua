-- Package.lua --

Package = class()

--[[ Server ]]

-- Attempt to unpack the package
function Package.sv_tryUnpack( self )
	if not self.destroyed and self.shape.body.destructable then
		self.destroyed = true
		sm.shape.destroyPart( self.shape )
		self:sv_unpack()
	end
end

function Package.sv_unpack( self )
	sm.effect.playEffect( self.data.unboxEffect01, self.shape.worldPosition, nil, self.shape.worldRotation, sm.vec3.new(1,1,1), { Color = self.shape.color } )

	local yaw = math.atan2( self.shape.up.y, self.shape.up.x ) - math.pi / 2
	local zShapeOffset = math.abs( ( self.shape.worldRotation * sm.item.getShapeOffset( self.shape.uuid ) ).z )
	local spawnOffset = sm.vec3.new( 0, 0, -zShapeOffset )

	for i = 1, self.data.amount or 1 do
		sm.unit.createUnit( sm.uuid.new( self.data.unitUuid ), self.shape.worldPosition + spawnOffset, yaw, { color = self.shape.color } )
		spawnOffset = spawnOffset + sm.vec3.new( 0, 0, 0.25 )
	end
end

-- (Event) Called upon getting hit by a projectile.
function Package.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid )
	self:sv_tryUnpack()
end

-- (Event) Called upon getting hit by a melee attack.
function Package.server_onMelee( self, hitPos, attacker, damage, power, hitDirection )
	self:sv_tryUnpack()
end

-- (Event) Called upon collision with an explosion nearby
function Package.server_onExplosion( self, center, destructionLevel )
	self:sv_tryUnpack()
end

-- (Event) Called upon collision with another object
function Package.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal )
	if type( other ) == "Shape" and sm.exists( other ) then
		if other.shapeUuid == obj_powertools_sawblade or other.shapeUuid == obj_powertools_drill then
			local angularVelocity = other.body.angularVelocity
			if angularVelocity:length() > SPINNER_ANGULAR_THRESHOLD then
				self:sv_tryUnpack()
			end
		end
	end
end

function Package.sv_e_open( self )
	self:sv_tryUnpack()
end