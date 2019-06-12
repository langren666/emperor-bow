GLOBAL.setmetatable(env, {
	__index = function(t, k)
		if k ~= "PrefabFiles" and k ~= "Assets" and k ~= "clothing_exclude" then
			return GLOBAL[k] and GLOBAL[k] or nil
		end
	end,
})
 
STRINGS.NAMES.LR_EMPERORBOW = "帝王弓"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.LR_EMPERORBOW = "只有拥有帝王之气的人才能驾驭它"
local IsServer = TheNet:GetIsServer()
local GetVolume = function() return TheSim:GetSoundVolume("set_sfx") end  --根据这个来调节客户端的mod音量
local function LR_CANATTACK(attacker, target)
	return target ~= attacker and attacker and target and attacker:IsValid()
		and target:IsValid() and attacker.components.combat and target.components.combat
		and attacker.components.health and target.components.health
		and target.components.combat:CanBeAttacked(attacker)	
		and not target.components.health:IsDead()
		and not target:HasTag("playerghost") 
		and target.entity:IsVisible()
		and not (attacker:HasTag("player") and (target:HasTag("eyeturret") or target:HasTag("wall")))
end
GLOBAL.LR_CANATTACK = LR_CANATTACK

Assets = {
	Asset("ANIM", "anim/bow_attack_action.zip"),
	Asset("SOUNDPACKAGE", "sound/bowattack.fev"),
	Asset("SOUND", "sound/bowattack.fsb"),
}

PrefabFiles = {
	"lr_emperorbow", --弓箭
	"lr_emperorbow_fx", --特效
	"lr_bulleye", --靶心
}


------------------------[[ 普通射箭动作的SG ]]------------------------
if IsServer then
AddStategraphState("wilson", State({
    name = "bowattack",
    tags = { "attack", "notalking", "abouttoattack", "autopredict" },

    onenter = function(inst)
        local buffaction = inst:GetBufferedAction()
        local target = buffaction ~= nil and buffaction.target or nil
		local equip = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		
		inst.components.combat:SetTarget(target)
		inst.components.locomotor:Stop()
		
		if not equip:HasTag("lr_bow") or target == nil or not target:IsValid() then
			inst.sg:GoToState("idle")
			return
		end	
		
		inst.components.combat:StartAttack()
		inst.AnimState:PlayAnimation("bow_attack")
		inst.components.combat:BattleCry()
        inst:FacePoint(target.Transform:GetWorldPosition())
        inst.sg.statemem.attacktarget = target
    end,

    timeline =
    {		
		TimeEvent(6 * FRAMES, function(inst)
			inst:PerformBufferedAction()
			inst.sg:RemoveStateTag("abouttoattack")
		end),			
		TimeEvent(11 * FRAMES, function(inst)
			inst.sg:RemoveStateTag("attack")
		end)		
    },

    events =
    {
        EventHandler("equip", function(inst) inst.sg:GoToState("idle") end),
        EventHandler("unequip", function(inst) inst.sg:GoToState("idle") end),
        EventHandler("animqueueover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.sg:GoToState("idle")
            end
        end),
    },

    onexit = function(inst)
        inst.components.combat:SetTarget(nil)
        if inst.sg:HasStateTag("abouttoattack") then
            inst.components.combat:CancelAttack()
        end
    end,		
}))

else

AddStategraphState("wilson_client", State({
    name = "bowattack",
    tags = { "attack", "notalking", "abouttoattack", "autopredict" },

    onenter = function(inst)
        local buffaction = inst:GetBufferedAction()
        local target = buffaction ~= nil and buffaction.target or nil
		local equip = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
		
		if not equip:HasTag("lr_bow") or target == nil or not target:IsValid() then
			inst.sg:GoToState("idle")
			return
		end	
        inst.components.locomotor:Stop()
		inst.replica.combat:StartAttack()
		
		inst:PerformPreviewBufferedAction()
		inst.AnimState:PlayAnimation("bow_attack")
        inst:FacePoint(target.Transform:GetWorldPosition())
        inst.sg.statemem.attacktarget = target
    end,

    timeline =
    {					
		TimeEvent(2 * FRAMES, function(inst)
			inst.SoundEmitter:PlaySound("bowattack/attack/bow_shoot", nil, 0.25 * GetVolume())
		end),	
		TimeEvent(6 * FRAMES, function(inst)
			inst:ClearBufferedAction()
			inst.sg:RemoveStateTag("abouttoattack")
		end),
		TimeEvent(11 * FRAMES, function(inst)
			inst.sg:RemoveStateTag("attack")
		end)
    },

    events =
    {
        EventHandler("animqueueover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.sg:GoToState("idle")
            end
        end),
    },

    onexit = function(inst)
        if inst.sg:HasStateTag("abouttoattack") then
            inst.replica.combat:CancelAttack()
        end
    end,		
}))
end


------------------------[[ 蓄力射箭的SG ]]------------------------
if IsServer then
AddStategraphState("wilson", State({
    name = "strong_bowattack_accumulate",
    tags = { "doing", "accumulating", "nodangle" },
	
	onenter = function(inst, item)
		if item == nil or not item:IsValid() or item.components.lr_accumulate_item == nil then
			inst.sg:GoToState("idle")
			return
		end
		inst.components.locomotor:Stop()
		inst.AnimState:PlayAnimation("bow_attack")
		inst.sg.statemem.item = item
		inst.sg.statemem.lockanim = false
		item.components.lr_accumulate_item:StartAccumulating() --开始蓄能
		--为什么要搞下面这一大堆玩意呢?
		--这是因为延迟补偿 会想方设法然玩家接下来一小段时间内行走 这样就会使得玩家退出这个state即使玩家可能并不想这么做
		--好吧 可是我们又要做到蓄力时可以随时移动以保证操作的灵活性(即使这样会打断蓄力) 因此也没办法一直禁用移动
		--怎么办呢? 只好强制性的让它一段时间不移动 并且移除掉接受到的predict walking 我们仅仅让这个过程维持0.1s
		--如此一来玩家如果键盘控制移动那么停下来的瞬间便可以进入蓄力状态 
		--如果鼠标点击某个点进行移动 那么移动的过程中点右键蓄力就会立即停下来进入蓄力状态
		inst.components.playercontroller:OnRemoteStopWalking() 
		inst.components.playercontroller.directwalking = false
        inst.components.playercontroller.dragwalking = false
        inst.components.playercontroller.predictwalking = false
		inst.sg.statemem.stopwalk = true
		inst.sg:AddStateTag("busy") --加上busy的Tag时间仅为0.1s 玩家依然感觉操作顺畅
	end,
	
    timeline = --先播放射箭的动作 播放一会后锁定到播放为60%的状态
    {		

		TimeEvent(3 * FRAMES, function(inst)
			inst.sg:RemoveStateTag("busy")
			inst.sg.statemem.stopwalk = false
		end),
		TimeEvent(6 * FRAMES, function(inst)
			inst.sg.statemem.lockanim = true
		end),
    },
	
    events =
    {
		EventHandler("stop_bowattack_accumulate", function(inst, data) --主动取消蓄能时触发事件
			data = data or {}
			local item = data.item
			local pos = data.pos
			if pos then
				inst:ForceFacePoint(pos)
			end
			if item and item.components.lr_accumulate_item then
				item.components.lr_accumulate_item:StopAccumulating(pos)
			end
			inst.sg:GoToState("strong_bowattack_accumulate_pst")
		end),
	},

	onupdate = function(inst)
		if inst.sg.statemem.lockanim then
			inst.AnimState:SetPercent("bow_attack", .6)
		end
		if inst.sg.statemem.stopwalk then
			inst.components.playercontroller:OnRemoteStopWalking() 
			inst.components.playercontroller.directwalking = false
			inst.components.playercontroller.dragwalking = false
			inst.components.playercontroller.predictwalking = false
		end
		if not inst.sg.statemem.item.components.equippable:IsEquipped() then
			inst.sg:GoToState("strong_bowattack_accumulate_pst")
		end
	end,

	onexit = function(inst)
		if inst.sg.statemem.item and inst.sg.statemem.item.components.lr_accumulate_item then
			inst.sg.statemem.item.components.lr_accumulate_item:CancelAccumulating()
			--这里调用的是被动取消蓄能 如果是完成蓄能StopAccumulating应该为主动取消蓄能时调用
		end
	end,
}))

AddStategraphState("wilson", State({
    name = "strong_bowattack_accumulate_pst",
    tags = { "idle" },
	
	onenter = function(inst)
		inst.components.locomotor:Stop()
		inst.AnimState:PlayAnimation("bow_attack")
		inst.AnimState:FastForward(0.225)
	end,
	
    events =
    {
		EventHandler("animover", function(inst) 
			if inst.AnimState:AnimDone() then
				inst.sg:GoToState("idle")
			end
		end),
	},
}))

else

AddStategraphState("wilson_client", State({
    name = "strong_bowattack_accumulate",
    tags = { "doing", "accumulating", "nodangle" },
	
	onenter = function(inst, item)
		inst.components.locomotor:Stop()
		inst.AnimState:PlayAnimation("bow_attack")
		inst.sg.statemem.item = item
		inst.sg.statemem.lockanim = false
		inst.sg.statemem.checkclock = 0
		inst.SoundEmitter:PlaySound("bowattack/skill/bow_accumulate", "lr_bow_accumulate", .4 * GetVolume())
		inst.sg:AddStateTag("busy")
	end,
	
    events =
    {
		EventHandler("stop_bowattack_accumulate", function(inst)
			inst.sg:GoToState("strong_bowattack_accumulate_pst", inst.sg.statemem.item)
		end),
	},

    timeline = --先播放射箭的动作 播放一会后锁定到播放为60%的状态
    {				
		TimeEvent(3 * FRAMES, function(inst)
			inst.sg:RemoveStateTag("busy")
		end),
		TimeEvent(6 * FRAMES, function(inst)
			inst.sg.statemem.lockanim = true
		end),
    },
	
	onupdate = function(inst)
		if inst.sg.statemem.lockanim then
			inst.AnimState:SetPercent("bow_attack", .6)
		end
		local item = inst.sg.statemem.item
		if item and item.components.lr_accumulate_item then
			if item.components.lr_accumulate_item._tick:value() == 0
				and item.components.lr_accumulate_item._cycle:value() == 0 then
				inst.sg.statemem.checkclock = inst.sg.statemem.checkclock + FRAMES
				if inst.sg.statemem.checkclock > .3 then
					inst.sg:GoToState("strong_bowattack_accumulate_pst", inst.sg.statemem.item)
					return
				end
			else
				inst.sg.statemem.checkclock = 0
			end
			if not inst.components.playercontroller:IsAOETargeting() then
				item.components.lr_accumulate_item:StopAccumulating()
				inst.sg:GoToState("strong_bowattack_accumulate_pst", inst.sg.statemem.item)
				return
			end			
		end
	end,
	
	onexit = function(inst)
		inst.components.playercontroller:CancelAOETargeting()
		inst.SoundEmitter:KillSound("lr_bow_accumulate")
	end,
}))

AddStategraphState("wilson_client", State({
    name = "strong_bowattack_accumulate_pst",
    tags = { "idle" },
	
	onenter = function(inst, item)
		inst.components.locomotor:Stop()
		inst.AnimState:PlayAnimation("bow_attack")
		inst.AnimState:FastForward(0.225)
		if item and item.components.lr_accumulate_item then
			local cycle = item.components.lr_accumulate_item._cycle:value()
			if cycle == 1 then
				inst.SoundEmitter:PlaySound("bowattack/attack/bow_shoot", nil, 0.25 * GetVolume())
			elseif cycle >= 2 then
				inst.SoundEmitter:PlaySound("bowattack/attack/bow_shoot_burn", nil, 0.5 * GetVolume())
			end
		end
	end,
	
    events =
    {
		EventHandler("animover", function(inst) 
			if inst.AnimState:AnimDone() then
				inst.sg:GoToState("idle")
			end
		end),
	},
}))
end


------------------------[[ 新的EventHandler来激活相应State ]]------------------------
if IsServer then
AddStategraphEvent("wilson", EventHandler("bowattack_accumulate", function(inst, data)
    if not (inst.sg:HasStateTag("busy") or inst.components.health:IsDead()) then
        inst.sg:GoToState("strong_bowattack_accumulate", data)
    end
end))
else
AddStategraphEvent("wilson_client", EventHandler("bowattack_accumulate", function(inst, data)
    if not (inst.sg:HasStateTag("busy") or inst.replica.health:IsDead()) then
        inst.sg:GoToState("strong_bowattack_accumulate", data)
    end
end))
end


------------------------[[ 调整原版SG以使得新的State生效 ]]------------------------
if IsServer then
AddStategraphPostInit("wilson", function(sg)
	for k1, v1 in pairs(sg.actionhandlers) do
		if v1.action == ACTIONS.ATTACK then
			local OriginalDestStateATTACK = v1.deststate
			v1.deststate = function(inst, action)
				local weapon = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
				if weapon and weapon:HasTag("lr_bow") and not inst.components.health:IsDead() and not inst.sg:HasStateTag("attack") then
					return "bowattack"
				end
				return OriginalDestStateATTACK(inst, action)
			end
		end
	end
end)

else

AddStategraphPostInit("wilson_client", function(sg)
	for k1, v1 in pairs(sg.actionhandlers) do
		if v1.action == ACTIONS.ATTACK then
			local OriginalClientDestStateATTACK = v1.deststate
			v1.deststate = function(inst, action)
				local weapon = inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
				if weapon and weapon:HasTag("lr_bow") and not inst.sg:HasStateTag("attack") then
					return "bowattack"
				end
				return OriginalClientDestStateATTACK(inst, action)	
			end
		end
	end
end)
end


------------------------[[ 对组件的调整 ]]------------------------
AddComponentPostInit("playercontroller", function(self, inst)
	local oldHasAOETargeting = self.HasAOETargeting
	function self:HasAOETargeting() --当鼠标上面拿着东西的时候 或者玩家死亡 不认为玩家想要使用技能
		return oldHasAOETargeting(self) 
			and inst.replica.inventory:GetActiveItem() == nil
			and not inst.replica.health:IsDead()
			and not inst:HasTag("playerghost")
	end

	local oldOnRightClick = self.OnRightClick
	function self:OnRightClick(down) 
		if not self:UsingMouse() then
			return
		elseif not down and self.reticule and self.reticule.keeppress and self:IsAOETargeting() then
		--摁住右键蓄力 松开右键取消蓄力(若蓄力不足视为主动打断蓄力 否则视为蓄力攻击)
			self:CancelAOETargeting()
			return
		end
		return oldOnRightClick(self, down)
	end
end)

AddComponentPostInit("reticule", function(self, inst)
	--某些物品标线移动时顺带转动人物
	local oldUpdatePosition = self.UpdatePosition
	function self:UpdatePosition(dt)
		oldUpdatePosition(self, dt)
		local rotation = self.reticule.Transform:GetRotation()
		if self.syncrotateplayer then	
			GLOBAL.ThePlayer.Transform:SetRotation(rotation)
		end
		if self.bulleye then
			self.bulleye.Transform:SetRotation(rotation)
			local angle = rotation * DEGREES
			local range = self.inst._range:value() / 100
			self.bulleye.Transform:SetPosition((GLOBAL.ThePlayer:GetPosition() + Vector3(range * math.cos(angle), 0, - range * math.sin(angle))):Get())
		end
	end
end)

AddComponentPostInit("aoetargeting", function(self, inst)
	--生成标线时 如果物品是蓄力型 那么触发蓄力事件
	local oldStartTargeting = self.StartTargeting
	function self:StartTargeting()
		oldStartTargeting(self)
		if self.inst.components.lr_accumulate_item then
			self.inst.components.lr_accumulate_item:StartAccumulating()
		end
		if self.reticule.bulleyeprefab and self.inst.components.reticule then
			self.inst.components.reticule.bulleye = SpawnPrefab(self.reticule.bulleyeprefab)
		end
	end
	--消除标线时 如果物品是蓄力型 那么停止蓄力
	local oldStopTargeting = self.StopTargeting
	function self:StopTargeting()
		if self.inst.components.reticule and self.inst.components.reticule.bulleye then
			self.inst.components.reticule.bulleye:Remove()
			self.inst.components.reticule.bulleye = nil
		end
		oldStopTargeting(self)
		if self.inst.components.lr_accumulate_item then
			self.inst.components.lr_accumulate_item:StopAccumulating()
		end
	end
end)

if IsServer then
--对武器组件和抛掷物组件的调整 使得武器可以向某个坐标发射抛掷物
local function LaunchProjectileToPosition(self, attacker, pos, damagemult, initprojectilefn)
	local launcher = attacker and attacker.components.combat and attacker or self.inst.components.inventoryitem:GetGrandOwner()
	if self.projectile ~= nil and launcher ~= nil then
		local proj = SpawnPrefab(self.projectile)
		
		if initprojectilefn then
			initprojectilefn(proj, self.inst, pos)
		end
		if proj ~= nil then
			if proj.components.projectile ~= nil then
				proj.components.projectile.launcher = launcher
				proj.Transform:SetPosition(attacker.Transform:GetWorldPosition())
				proj.components.projectile:ThrowToPosition(self.inst, pos, attacker, damagemult)
				if self.inst.projectiledelay ~= nil then
					proj.components.projectile:DelayVisibility(self.inst.projectiledelay)
				end
			end
		end
	end
end

local function ThrowToPosition(self, owner, pos, attacker, damagemult)
	self.notarget = true
    self.owner = owner
    self.start = owner:GetPosition()
	self:RotateToTarget(pos)
	self.angle = self.inst.Transform:GetRotation()
	self.damagemult = damagemult

    if attacker ~= nil and self.launchoffset ~= nil then
        local x, y, z = self.inst.Transform:GetWorldPosition()
        local facing_angle = attacker.Transform:GetRotation() * DEGREES
        self.inst.Transform:SetPosition(x + self.launchoffset.x * math.cos(facing_angle), y + self.launchoffset.y, z - self.launchoffset.x * math.sin(facing_angle))
    end
	
    self.inst.Physics:SetMotorVel(self.speed, 0, 0)
    self.inst:StartUpdatingComponent(self)
    self.inst:PushEvent("onthrown", { thrower = owner, targetpos = pos })
    if self.onthrown ~= nil then
        self.onthrown(self.inst, owner, nil, attacker)
    end
end

AddComponentPostInit("weapon", function(self, inst)
	self.LaunchProjectileToPosition = LaunchProjectileToPosition
end)

AddComponentPostInit("projectile", function(self, inst)
	self.ThrowToPosition = ThrowToPosition
	local oldOnUpdate = self.OnUpdate
	self.OnUpdate = function(self, dt)
		if self.notarget then
			local current = self.inst:GetPosition()
			if self.angle then
				self.inst.Transform:SetRotation(self.angle)
			end
			if self.followfx and self.angle then
				self.followfx.Transform:SetRotation(self.angle)
				local offsetx = 0
				local offsety = 0
				if self.followfxoffset then
					offsetx = self.followfxoffset.x
					offsety = self.followfxoffset.y
				end
				local x, y, z = self.inst.Transform:GetWorldPosition()
				local facing_angle = self.angle * DEGREES
				self.followfx.Transform:SetPosition(x + offsetx * math.cos(facing_angle), y + offsety, z - offsetx * math.sin(facing_angle))
			end
			if self.range ~= nil and distsq(self.start, current) > self.range * self.range then
				self:Miss()
			else 
				local ents = TheSim:FindEntities(current.x, current.y, current.z, self.hitdist + 5, {"_combat", "_health"})
				local hitptx, hitpty, hitptz = self.inst.Transform:GetWorldPosition()
				for i,v in ipairs(ents) do 
					if not self.inst:IsValid() then
						break
					end
					if LR_CANATTACK(self.launcher, v) and not (self.hittargets and self.hittargets[v]) then
						local hitradius = self.hitdist + v:GetPhysicsRadius(0)
						local targetptx, targetpty, targetptz = v.Transform:GetWorldPosition()
						if distsq(hitptx, hitptz, targetptx, targetptz) <= hitradius * hitradius then
							--原来的self:Hit(target) 无法接受攻击半径的变化(会导致玩家打不到怪) 也无法实现多倍攻击力的攻击
							local damagemult = self.damagemult or 1	
							local attacker = self.owner
							local weapon = self.inst
							if self.hittimes == nil then
								self:Stop()
								self.inst.Physics:Stop()
							end
							if attacker.components.combat == nil and attacker.components.weapon ~= nil and attacker.components.inventoryitem ~= nil then
								weapon = attacker
								attacker = weapon.components.inventoryitem.owner
							end
							if attacker ~= nil and attacker.components.combat ~= nil then
								local Combat = attacker.components.combat
								local oldignorehitrange = Combat.ignorehitrange
								Combat.ignorehitrange = true --暂时忽视攻击者的攻击距离 
								attacker.components.combat:DoAttack(v, weapon, self.inst, self.stimuli, damagemult)
								if self.onhit ~= nil then
									self.onhit(self.inst, attacker, v)
								end								
								Combat.ignorehitrange = oldignorehitrange
							end
							if self.hittimes then
								self.hittimes = self.hittimes - 1
								self.hittargets = self.hittargets or {}
								self.hittargets[v] = true
								if self.hittimes <= 0 then
									self:Stop()
									self.inst.Physics:Stop()
									self.inst:Remove()
								end
							end
						end
					end
				end
			end
			return
		end
		if oldOnUpdate then
			oldOnUpdate(self, dt)
		end
	end
end)
end

------------------------[[ 对界面的调整 ]]------------------------
local RingMeter = require "widgets/ringmeter"
local Text = require "widgets/text"
AddClassPostConstruct("screens/playerhud", function(self)
	self.lr_accumulatemeters = {} --蓄力条
	function self:ShowAccumulateMeter(pos, item)
		local tick = item.components.lr_accumulate_item._tick:value()
		local cycle = item.components.lr_accumulate_item._cycle:value()	
		if tick == 0 and cycle == 0 then
			self:KillAccumulateMeter(item)
			return 
		end
		local period = item.components.lr_accumulate_item.cycles[math.min(#item.components.lr_accumulate_item.cycles, cycle + 1)]
		local meter = self.lr_accumulatemeters[item]
		if meter == nil then
			meter = self.popupstats_root:AddChild(RingMeter(self.owner))
			meter.num = meter:AddChild(Text(FALLBACK_FONT_OUTLINE, 40, "", {1, 1, 1, 1}))
			meter.num:SetPosition(0, 30)
			self.lr_accumulatemeters[item] = meter
		end
		meter:SetWorldPosition(pos)
		meter.num:SetString(tostring(cycle))
		meter:StartTimer(period, tick / 100 * period)
	end
	function self:KillAccumulateMeter(item)
		local meter = self.lr_accumulatemeters[item]
		if meter then
			meter:Kill()
			self.lr_accumulatemeters[item] = nil
		end
	end
end)


------------------------[[ AddModRPCHandler ]]------------------------
if IsServer then
AddModRPCHandler("2018mod", "lr_accumulate_item", function(player, item) --开始蓄力
	if type(item) == "table" and item:IsValid() and item.components.lr_accumulate_item 
		and item.components.equippable:IsEquipped()
		and item.components.lr_accumulate_item.event then
		player:PushEvent(item.components.lr_accumulate_item.event, item)
	end
end)
AddModRPCHandler("2018mod", "lr_stop_accumulate_item", function(player, item, pos) --停止蓄力
	if type(item) == "table" and type(pos) == "string" and item:IsValid() and item.components.lr_accumulate_item 
		and item.components.lr_accumulate_item.stopevent then
		pos = pos:split(" ")
		local posx = tonumber(pos[1])
		local posz = tonumber(pos[2])
		if type(posx) == "number" and type(posz) == "number" then
			player:PushEvent(item.components.lr_accumulate_item.stopevent, {item = item, pos = Vector3(posx, 0, posz)})
		end
	end
end)

else

AddModRPCHandler("2018mod", "lr_accumulate_item", function() end)
AddModRPCHandler("2018mod", "lr_stop_accumulate_item", function() end)
end