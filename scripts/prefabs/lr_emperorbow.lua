local EMPERORBOW_RANGE1 = 20 --正常攻击距离
local EMPERORBOW_RANGE2 = 25 --一级蓄力
local EMPERORBOW_RANGE3 = 30 --二级蓄力
local LR_CANATTACK = LR_CANATTACK

local assets = {
	Asset("ANIM", "anim/lr_emperorbow.zip"),
	Asset("ANIM", "anim/swap_lr_emperorbow1.zip"),
	Asset("ANIM", "anim/swap_lr_emperorbow2.zip"),
	Asset("ANIM", "anim/swap_lr_emperorbow3.zip"),
	Asset("ANIM", "anim/swap_lr_emperorbow4.zip"),
	Asset("ANIM", "anim/swap_lr_emperorbow5.zip"),
	Asset("ATLAS", "images/inventoryimages/lr_emperorbow1.xml"),
	Asset("IMAGE", "images/inventoryimages/lr_emperorbow1.tex"),
	Asset("ATLAS", "images/inventoryimages/lr_emperorbow2.xml"),
	Asset("IMAGE", "images/inventoryimages/lr_emperorbow2.tex"),
	Asset("ATLAS", "images/inventoryimages/lr_emperorbow3.xml"),
	Asset("IMAGE", "images/inventoryimages/lr_emperorbow3.tex"),
	Asset("ATLAS", "images/inventoryimages/lr_emperorbow4.xml"),
	Asset("IMAGE", "images/inventoryimages/lr_emperorbow4.tex"),
	Asset("ATLAS", "images/inventoryimages/lr_emperorbow5.xml"),
	Asset("IMAGE", "images/inventoryimages/lr_emperorbow5.tex"),	
}

local bowprefabs = {
	"lr_emperorbow_fx", 
	"lr_emperorbow_hit_fx1", 
	"lr_emperorbow_hit_fx2",
	"lr_emperorbow_burn_fx1",
	"lr_emperorbow_burn_fx2",
}

local function lr_emperorbow_do_trail(inst)
    local owner = inst.components.inventoryitem:GetGrandOwner() or inst
    if not owner.entity:IsVisible() then
        return
    end

    local x, y, z = owner.Transform:GetWorldPosition()
    if owner.sg ~= nil and owner.sg:HasStateTag("moving") then
        local theta = -owner.Transform:GetRotation() * DEGREES
        local speed = owner.components.locomotor:GetRunSpeed() * .1
        x = x + speed * math.cos(theta)
        z = z + speed * math.sin(theta)
    end
    local mounted = owner.components.rider ~= nil and owner.components.rider:IsRiding()
    local map = TheWorld.Map
    local offset = FindValidPositionByFan(
        math.random() * 2 * PI,
        (mounted and 1 or .5) + math.random() * .5,
        4,
        function(offset)
            local pt = Vector3(x + offset.x, 0, z + offset.z)
            return map:IsPassableAtPoint(pt:Get())
                and not map:IsPointNearHole(pt)
                and #TheSim:FindEntities(pt.x, 0, pt.z, .7, { "shadowtrail" }) <= 0
        end
    )

    if offset ~= nil then
		local fx = SpawnPrefab(inst.trail_fx)
        fx.Transform:SetPosition(x + offset.x, 0, z + offset.z)
		fx._colour:set(inst.lr_shape)
    end
end

local function lr_emperorbow_equipped(inst, owner)
	owner.AnimState:OverrideSymbol("swap_object", "swap_lr_emperorbow" .. inst.lr_shape, "swap_bow_" .. inst.lr_shape)
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")
	if inst._trailtask == nil then
		inst._trailtask = inst:DoPeriodicTask(6 * FRAMES, lr_emperorbow_do_trail, 2 * FRAMES)
	end
end

local function lr_emperorbow_unequipped(inst, owner)
	owner.AnimState:Hide("ARM_carry")
	owner.AnimState:Show("ARM_normal")
    if inst._trailtask ~= nil then
        inst._trailtask:Cancel()
        inst._trailtask = nil
    end
end

local function lr_emperorbow_putininventory(inst, data) --扔地上长啥样 捡起来啥样
	local animlength = inst.AnimState:GetCurrentAnimationLength()
	inst:ApplyShape(math.floor((inst.AnimState:GetCurrentAnimationTime() % animlength) / animlength / 0.2) + 1)
end

local function lr_emperorbow_onsave(inst, data)
	data.lr_shape = inst.lr_shape
	data.lr_animtime = inst.AnimState:GetCurrentAnimationTime() % inst.AnimState:GetCurrentAnimationLength()
end

local function lr_emperorbow_onload(inst, data)
	if data then
		if data.lr_shape then
			inst:ApplyShape(data.lr_shape)
		end
		if data.lr_animtime then
			inst.AnimState:SetTime(data.lr_animtime)
		end
	end
end

local function ReticuleTargetFn()
    return Vector3(ThePlayer.entity:LocalToWorldSpace(6.5, 0, 0))
end

local function ReticuleMouseTargetFn(inst, mousepos)
    if mousepos ~= nil then
        local x, y, z = inst.Transform:GetWorldPosition()
        local dx = mousepos.x - x
        local dz = mousepos.z - z
        local l = dx * dx + dz * dz
        if l <= 0 then
            return inst.components.reticule.targetpos
        end
        l = 6.5 / math.sqrt(l)
        return Vector3(x + dx * l, 0, z + dz * l)
    end
end

local function ReticuleUpdatePositionFn(inst, pos, reticule, ease, smoothing, dt)
    local x, y, z = inst.Transform:GetWorldPosition()
    reticule.Transform:SetPosition(x, 0, z)
    local rot = -math.atan2(pos.z - z, pos.x - x) / DEGREES
    if ease and dt ~= nil then
        local rot0 = reticule.Transform:GetRotation()
        local drot = rot - rot0
        rot = Lerp((drot > 180 and rot0 + 360) or (drot < -180 and rot0 - 360) or rot0, rot, dt * smoothing)
    end
    reticule.Transform:SetRotation(rot)
end

local validcolours = {
	{ 1, .75, 0, 1 },
	{ 0x91/255, 0x2C/255, 0xEE/255, 1},
	{ 0, 0xEE/255, 0, 1},
	{ 0xFF/255, 0xFF/255, 0, 1},
	{ 0, 0xBF/255, 0xFF/255, 1},
}

local invalidcolours = {
	{ .5, 0, 0, 1 },
	{ 0xAB/255, 0x82/255, 0xFF/255, 1},
	{ 0x9A/255, 0xFF/255, 0x9A/255, 1},
	{ 0xFF/255, 0xEC/255, 0x8B/255, 1},
	{ 193/255, 210/255, 240/255, 1},
}

local function OnShapeDirty(inst)
	local shape = inst._shape:value()
	if shape >= 1 and shape <= 5 then
		inst.components.aoetargeting.reticule.validcolour = validcolours[shape]
		inst.components.aoetargeting.reticule.invalidcolour = invalidcolours[shape]
	end
end

local function FinishAccumulate(inst, cycle, currenttime, pos)
	local owner = inst.components.inventoryitem:GetGrandOwner()
	if pos ~= nil and owner ~= nil then
		if cycle == 1 then --普通攻击 手动瞄准
			inst.components.weapon:LaunchProjectileToPosition(owner, pos, 1)
		elseif cycle == 2 then
			inst.components.weapon:LaunchProjectileToPosition(owner, pos, 2, function(proj, inst, pos)
				local fx = SpawnPrefab("lr_emperorbow_burn_fx1")
				fx:ListenForEvent("onremove", function()
					fx:Remove()
				end, proj)
				fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
				fx.AnimState:SetSortOrder(1)
				fx.AnimState:PushAnimation("yellow_burn", true)
				proj.components.projectile.followfx = fx --modmain中对projectile组件进行了修改
				proj.components.projectile.followfxoffset = Vector3(1, 0, 0)
				proj.bombfx = "lr_emperorbow_bomb_fx1"
				proj.aoeradius = 2
				proj.aoemult = 0.5
				proj.components.projectile.hittimes = 2
				proj.accumulatelevel = 1
			end)
		elseif cycle == 3 then
			inst.components.weapon:LaunchProjectileToPosition(owner, pos, 4, function(proj, inst, pos)
				local fx = SpawnPrefab("lr_emperorbow_burn_fx2")
				fx:ListenForEvent("onremove", function()
					fx:Remove()
				end, proj)
				fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
				fx.AnimState:SetSortOrder(1)
				fx.AnimState:PushAnimation("purple_burn", true)
				proj.components.projectile.followfx = fx
				proj.components.projectile.followfxoffset = Vector3(1, 0, 0)
				proj.bombfx = "lr_emperorbow_bomb_fx2"
				proj.aoeradius = 3
				proj.aoemult = 1
				proj.components.projectile.hittimes = 4
				proj.accumulatelevel = 2
			end)
		end
	end
end

local function UpdateRange(inst)
	local cycle = inst.components.lr_accumulate_item.cycle
	local tick = inst.components.lr_accumulate_item._tick:value()
	local weaponrange = EMPERORBOW_RANGE1
	if cycle < 1 then
		weaponrange = EMPERORBOW_RANGE1
	elseif cycle == 1 then
		weaponrange = EMPERORBOW_RANGE1 + (EMPERORBOW_RANGE2 - EMPERORBOW_RANGE1) * tick / 100
	elseif cycle == 2 then
		weaponrange = EMPERORBOW_RANGE2 + (EMPERORBOW_RANGE3 - EMPERORBOW_RANGE2) * tick / 100
	else
		weaponrange = EMPERORBOW_RANGE3
	end
	inst.components.weapon:SetRange(weaponrange)
	inst._range:set(math.floor(weaponrange * 100)) --显示的距离是抛掷物的攻击距离
end

local function bowfn()
	local inst = CreateEntity()
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddNetwork()
	inst.AnimState:SetBank("lr_emperorbow")
	inst.AnimState:SetBuild("lr_emperorbow")
	inst.AnimState:PlayAnimation("idle", true)
	
	MakeInventoryPhysics(inst)

	inst:AddTag("lr_bow")
	
    inst:AddComponent("aoetargeting")
    inst.components.aoetargeting:SetAlwaysValid(true)
    inst.components.aoetargeting.reticule.reticuleprefab = "reticulelongmulti"
    inst.components.aoetargeting.reticule.pingprefab = "reticulelongmultiping"
    inst.components.aoetargeting.reticule.targetfn = ReticuleTargetFn
    inst.components.aoetargeting.reticule.mousetargetfn = ReticuleMouseTargetFn
    inst.components.aoetargeting.reticule.updatepositionfn = ReticuleUpdatePositionFn
    inst.components.aoetargeting.reticule.validcolour = { 1, .75, 0, 1 }
    inst.components.aoetargeting.reticule.invalidcolour = { .5, 0, 0, 1 }
    inst.components.aoetargeting.reticule.ease = true
    inst.components.aoetargeting.reticule.mouseenabled = true
	inst.components.aoetargeting.reticule.keeppress = true --蓄力技能 松开后标线消失
	inst.components.aoetargeting.reticule.syncrotateplayer = true --标线转动人物跟着转动
	inst.components.aoetargeting.reticule.bulleyeprefab = "lr_bulleye" --显示靶心
	
	inst:AddComponent("lr_accumulate_item")
	inst.components.lr_accumulate_item.cycles = {0.3, 1.5, 2}
	inst.components.lr_accumulate_item.event = "bowattack_accumulate"
	inst.components.lr_accumulate_item.rpc = GetModRPC("2018mod", "lr_accumulate_item")
	inst.components.lr_accumulate_item.stopevent = "stop_bowattack_accumulate"
	inst.components.lr_accumulate_item.stoprpc = GetModRPC("2018mod", "lr_stop_accumulate_item")
	
	inst._shape = net_tinybyte(inst.GUID, "bow._shape", "shapedirty")
	inst._range = net_ushortint(inst.GUID, "bow._range") --显示靶心
	
	if not TheNet:IsDedicated() then
		inst:ListenForEvent("shapedirty", OnShapeDirty)
	end
	
	inst.entity:SetPristine()
	if not TheWorld.ismastersim then
		return inst
	end
	
	inst.lr_shape = 1
	inst._shape:set(1)
	inst.trail_fx = "lr_emperorbow_fx"
	
	inst.components.lr_accumulate_item:SetOnFinish(FinishAccumulate)
	
	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.atlasname = "images/inventoryimages/lr_emperorbow1.xml"
	inst.components.inventoryitem.imagename = "lr_emperorbow1"
	
	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(lr_emperorbow_equipped)
	inst.components.equippable:SetOnUnequip(lr_emperorbow_unequipped)
	
	inst:AddComponent("inspectable")
	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(100) 
	inst.components.weapon:SetRange(EMPERORBOW_RANGE1)
	inst.components.weapon:SetProjectile("lr_emperorarrow1")
	
	inst.OnSave = lr_emperorbow_onsave
	inst.OnLoad = lr_emperorbow_onload
	
	inst.ApplyShape = function(inst, shape)
		shape = math.clamp(shape, 1, 5)
		inst.lr_shape = shape
		inst._shape:set(shape)
		inst.components.inventoryitem.atlasname = "images/inventoryimages/lr_emperorbow" .. shape .. ".xml"
		inst.components.inventoryitem.imagename = "lr_emperorbow" .. shape
		if inst.components.equippable:IsEquipped() then
			local owner = inst.components.inventoryitem:GetGrandOwner()
			owner.AnimState:OverrideSymbol("swap_object", "swap_lr_emperorbow" .. shape, "swap_bow_" .. shape)
		end
		inst.components.weapon:SetProjectile("lr_emperorarrow" .. shape)
	end
	
	inst:ListenForEvent("onputininventory", lr_emperorbow_putininventory)
	inst:ListenForEvent("lraccu_tickdirty", UpdateRange)
	
	MakeHauntableLaunch(inst)
	return inst
end

local function MakeArrow(name)
	local arrowassets =
	{
		Asset("ANIM", "anim/" .. name .. ".zip"),
	}
	
	local fxcolours = {
		{0xFF/255, 0x30/255, 0x30/255, .5},
		{0xFF/255, 0x00/255, 0xFF/255, .5},
		{0x32/255, 0xCD/255, 0x32/255, .5},
		{255/255, 215/255, 0/255, .5},
	}

	local function CreateTail(colour)
		local inst = CreateEntity()

		inst:AddTag("FX")
		inst:AddTag("NOCLICK")
		--[[Non-networked entity]]
		inst.entity:SetCanSleep(false)
		inst.persists = false

		inst.entity:AddTransform()
		inst.entity:AddAnimState()

		inst.AnimState:SetBank("lavaarena_blowdart_attacks")
		inst.AnimState:SetBuild("lavaarena_blowdart_attacks")
		inst.AnimState:PlayAnimation("tail_1")
		inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
		inst.AnimState:SetMultColour(0, 0, 0, 0)
		inst.AnimState:SetAddColour(unpack(colour > #fxcolours and fxcolours[math.random(#fxcolours)] or fxcolours[colour]))

		inst:ListenForEvent("animover", inst.Remove)

		return inst
	end

	local function OnUpdateProjectileTail(inst)
		if inst.entity:IsVisible() then
			local tail = CreateTail(inst._colour:value())
			tail.Transform:SetPosition(inst.Transform:GetWorldPosition())
			tail.Transform:SetRotation(inst.Transform:GetRotation())
		end
	end
	
	local function OnThrown(inst, data)
		inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround) 
		if data and data.thrower then
			if data.thrower.lr_shape then
				inst._colour:set(math.clamp(data.thrower.lr_shape, 1, 5))
			else
				inst._colour:set(1)
			end
			if data.thrower.components.weapon then --抛掷物运动距离略高于武器攻击距离
				inst.components.projectile:SetRange(data.thrower.components.weapon.attackrange)
			end
		end
	end
	
	local function OnHit(inst, attacker, target)
		if inst:IsValid() then
			SpawnPrefab("lr_emperorbow_hit_fx1").Transform:SetPosition(inst.Transform:GetWorldPosition())
			if inst.bombfx == nil then
				local colour = inst._colour:value()
				if colour ~= 0 then
					local fx = SpawnPrefab("lr_emperorbow_hit_fx2")
					fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
					fx.AnimState:SetMultColour(0, 0, 0, 0)
					fx.AnimState:SetAddColour(unpack(colour > #fxcolours and fxcolours[math.random(#fxcolours)] or fxcolours[colour]))
				end
			else
				local fx = SpawnPrefab(inst.bombfx)
				fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
			end
			if inst.accumulatelevel == nil then
				inst:Remove()
			else
				local level = inst.accumulatelevel
				if level == 1 or level == 2 then
					if level == 1 then
						if target and target.sg and target.sg:HasState("hit") 
							and not (target.components.health and target.components.health:IsDead()) and math.random() < .5 then
							target.sg:GoToState("hit")
						end
					elseif level == 2 then
						if target and target.sg and target.sg:HasState("hit") 
							and not (target.components.health and target.components.health:IsDead()) then
							target.sg:GoToState("hit")
						end
					end
					if inst.aoeradius then
						local hitptx, hitpty, hitptz = inst.Transform:GetWorldPosition()
						local ents = TheSim:FindEntities(hitptx, hitpty, hitptz, inst.aoeradius + 5, {"_combat", "_health"})
						local weapon = inst.components.projectile.owner
						local attacker = inst.components.projectile.launcher
						if attacker then
							local Combat = attacker.components.combat
							local oldignorehitrange = Combat.ignorehitrange
							Combat.ignorehitrange = true --暂时忽视攻击者的攻击距离 
							for i,v in ipairs(ents) do 
								if LR_CANATTACK(attacker, v) and v ~= target then
									local hitradius = inst.aoeradius + v:GetPhysicsRadius(0)
									local targetptx, targetpty, targetptz = v.Transform:GetWorldPosition()
									if distsq(hitptx, hitptz, targetptx, targetptz) <= hitradius * hitradius then
										attacker.components.combat:DoAttack(v, weapon, inst, inst.components.projectile.stimuli, inst.aoemult)							
									end
								end
							end
							Combat.ignorehitrange = oldignorehitrange
						end
					end
				else
					inst:Remove()
				end
			end
		end
	end

	local function arrowfn()
		local inst = CreateEntity()
		inst.entity:AddTransform()
		inst.entity:AddAnimState()
		inst.entity:AddNetwork()
		
		inst.AnimState:SetBank(name)
		inst.AnimState:SetBuild(name)
		inst.AnimState:PlayAnimation("idle")
		
		MakeInventoryPhysics(inst)
		RemovePhysicsColliders(inst)
		
		inst:AddTag("NOCLICK")
		inst:AddTag("projectile") 
		
		inst._colour = net_tinybyte(inst.GUID, "trail._colour", "colourdirty")
		
		if not TheNet:IsDedicated() then
			inst:ListenForEvent("colourdirty", function(inst)
				if inst._colour:value() ~= 0 and inst._updatetailtask == nil then
					inst._updatetailtask = inst:DoPeriodicTask(0, OnUpdateProjectileTail)
				end
			end)
		end
		
		inst.entity:SetPristine()
		if not TheWorld.ismastersim then
			return inst
		end
		
		inst:AddComponent("projectile")	
		inst.components.projectile:SetSpeed(30)
		inst.components.projectile:SetOnHitFn(OnHit)
		inst.components.projectile:SetOnMissFn(inst.Remove)
		inst.components.projectile:SetHoming(false)
		inst.components.projectile:SetLaunchOffset(Vector3(0, 1, 0))
		
		inst:ListenForEvent("onthrown", OnThrown)
		inst.persists = false
		return inst
	end

	return Prefab(name, arrowfn, arrowassets)
end

return Prefab("lr_emperorbow", bowfn, assets, bowprefabs),
		MakeArrow("lr_emperorarrow1"),
		MakeArrow("lr_emperorarrow2"),
		MakeArrow("lr_emperorarrow3"),
		MakeArrow("lr_emperorarrow4"),
		MakeArrow("lr_emperorarrow5")