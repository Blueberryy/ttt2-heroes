if SERVER then
	AddCSLuaFile()

	resource.AddFile("models/props/w_crystal_green/w_crystal_green.mdl")
	resource.AddFile("materials/models/props/w_crystal_green/w_crystal_mat.vmt")
	resource.AddFile("materials/models/props/w_crystal_green/w_crystal_blue.vmt")
	resource.AddFile("materials/models/props/w_crystal_green/w_crystal_red.vmt")
	resource.AddFile("materials/models/props/w_crystal_green/w_crystal_white.vmt")
	resource.AddFile("materials/models/props/w_crystal_green/w_ground_blue.vmt")
	resource.AddFile("materials/models/props/w_crystal_green/w_Ground_mat.vmt")
	resource.AddFile("materials/models/props/w_crystal_green/w_ground_red.vmt")
	resource.AddFile("materials/sprites/crystal_sparkle.vmt")
	--resource.AddFile("particles/crystal_fx.pcf")

	resource.AddSingleFile("materials/models/props/w_crystal_green/w_crystal_normal.vtf")
	resource.AddSingleFile("materials/models/props/w_crystal_green/w_Ground_normal.vtf")
end

--game.AddParticles("particles/crystal_fx.pcf")
--PrecacheParticleSystem("crystal_shine")

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Model = Model("models/props/w_crystal_green/w_crystal_green.mdl")
ENT.CanUseKey = true
ENT.CanPickup = true

function ENT:Initialize()
	self:SetModel(self.Model)
	self:SetSkin(3)

	if SERVER then
		self:PhysicsInit(SOLID_VPHYSICS)
	end

	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)

	if SERVER then
		self:SetMaxHealth(100)
		self:SetHealth(100)
		self:SetUseType(SIMPLE_USE)
	end

	self:SetModelScale(0.75)
	self:PhysWake()

	--ParticleEffectAttach("crystal_shine", PATTACH_ABSORIGIN_FOLLOW, self, 0)
end

function ENT:UseOverride(activator)
	local owner = self:GetOwner()

	if IsValid(activator) and activator:IsTerror() and owner == activator and activator.crystaluses < 1 and activator:HasClass() then
		activator:SetNWBool("CanSpawnCrystal", true)
		activator:SetNWEntity("Crystal", NULL)

		if not activator.crystaluses then
			activator.crystaluses = 0
		end

		activator.crystaluses = activator.crystaluses + 1

		net.Start("TTT2Crystal")
		net.WriteInt(4, 8)
		net.Send(activator)

		activator:SetNWEntity("Crystal", NULL)

		self:Remove()

		if SERVER then
			timer.Simple(0.01, function()
				CrystalUpdate()
			end)
		end
	elseif IsValid(activator) and activator:IsTerror() and owner == activator then
		if activator.crystaluses >= 1 then
			net.Start("TTT2Crystal")
			net.WriteInt(7, 8)
			net.Send(activator)
		elseif not activator:HasClass() then
			net.Start("TTT2Crystal")
			net.WriteInt(9, 8)
			net.Send(activator)
		end
	end
end

local zapsound = Sound("npc/assassin/ball_zap1.wav")

function ENT:OnTakeDamage(dmginfo)
	if GetRoundState() ~= ROUND_ACTIVE then return end

	local owner, att, infl = self:GetOwner(), dmginfo:GetAttacker(), dmginfo:GetInflictor()

	if not IsValid(owner) or infl == owner or att == owner or (IsValid(att) and att:IsPlayer() and att:IsInTeam(owner) and not att:GetSubRoleData().unknownTeam) or not infl.GetSubRole and (not att or not att.GetSubRole) then return end

	if infl:GetClass() == "weapon_ttt_crystalknife" then
		if SERVER and IsValid(att) and att:IsPlayer() then
			net.Start("TTT2Crystal")
			net.WriteInt(5, 8)
			net.Send(owner)
		end

		GiveCrystalCredits(att, self)

		if IsValid(att) and att:GetSubRole() == ROLE_SIDEKICK and owner:HasTeam(TEAM_INNOCENT) then
			local text = att:Nick() .. " ist ein SIDEKICK!"

			for _, v in ipairs(player.GetAll()) do
				v:ChatPrint(text)
			end

			att:StripWeapon("weapon_ttt_crystalknife")
		end

		local effect = EffectData()
		effect:SetOrigin(self:GetPos())

		util.Effect("cball_explode", effect)

		sound.Play(zapsound, self:GetPos())

		owner:SetNWEntity("Crystal", NULL)

		self:Remove()

		owner.oldClass = owner:GetCustomClass()

		if SERVER then
			owner:UpdateClass(nil)

			timer.Simple(0.01, function()
				CrystalUpdate()
			end)
		end
	end
end

function ENT:FakeDestroy()
	local effect = EffectData()
	effect:SetOrigin(self:GetPos())

	util.Effect("cball_explode", effect)

	sound.Play(zapsound, self:GetPos())

	local owner = self:GetOwner()

	if IsValid(owner) then
		owner:SetNWEntity("Crystal", NULL)

		hook.Run("TTTHFakeDestroy", owner)
	end

	self:Remove()

	if IsValid(owner) then
		owner.oldClass = owner:GetCustomClass()

		if SERVER then
			owner:UpdateClass(nil)
		end
	end

	if SERVER then
		timer.Simple(0.01, function()
			CrystalUpdate()
		end)
	end
end

function ENT:Draw()
	local owner = self:GetOwner()

	if IsValid(owner) then
		self:SetColor(owner:GetRoleColor())
		self:DrawModel()
	end
end

function ENT:OnRemove()
	local owner = self:GetOwner() or self.Owner

	if IsValid(owner) then
		hook.Run("TTTHRemoveCrystal", owner)
	end
end

hook.Add("PlayerDisconnected", "TTT2CrystalDestroy", function(ply)
	if ply:HasCrystal() then
		ply:GetCrystal():FakeDestroy()
	end
end)

if CLIENT then
	local TryT
	local crystalMaterial = ("materials/vgui/ttt/icon_diamond.vmt")

	-- target ID
	hook.Add("TTTRenderEntityInfo", "DrawCrystalTargetID", function(data, params)
		local client = LocalPlayer()

		-- has to be a valid crystal
		if not data.ent:GetOwner() or data.ent:GetClass() ~= "ttt_crystal" then return end
		if data.distance > 100 then return end

		TryT = TryT or LANG.TryTranslation

		params.drawInfo = true
		params.displayInfo.title.text = TryT("ttt2_heroes_entity_crystal")

		params.drawOutline = true
		params.outlineColor = client:GetRoleColor()

		if data.ent:GetOwner() == client then
			params.displayInfo.key = input.GetKeyCode(input.LookupBinding("+use"))
			params.displayInfo.subtitle.text = TryT("target_pickup")

			params.displayInfo.desc[#params.displayInfo.desc + 1] = {
				text = TryT("ttt2_heroes_entity_crystal_owner_self")
			}
		elseif client:GetSubRole() == ROLE_SUPERVILLAIN or client:GetSubRole() == ROLE_SIDEKICK then
			params.displayInfo.icon.material = crystalMaterial
			params.displayInfo.subtitle.text = TryT("ttt2_heroes_entity_crystal_knife")

			params.displayInfo.desc[#params.displayInfo.desc + 1] = {
				text = TryT("ttt2_heroes_entity_crystal_owner") .. data.ent:GetOwner():Nick()
			}
		else
			params.displayInfo.icon.material = crystalMaterial
			params.displayInfo.subtitle.text = TryT("ttt2_heroes_entity_crystal_cant_interact")

			params.displayInfo.desc[#params.displayInfo.desc + 1] = {
				text = TryT("ttt2_heroes_entity_crystal_owner_unknown")
			}
		end

		if data.ent:GetOwner():GetTeam() ~= client:GetTeam() and client:GetActiveWeapon():GetClass() == "weapon_ttt_crystalknife" then
			params.displayInfo.desc[#params.displayInfo.desc + 1] = {
				text = TryT("ttt2_heroes_entity_crystal_destroy"),
				color = SUPERVILLAIN.color
			}
		end
	end)
end
