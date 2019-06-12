local assets =
{
    Asset("ANIM", "anim/cane_shadow_fx.zip"),
}

local hitfx1_assets =
{
    Asset("ANIM", "anim/explode.zip")
}

local hitfx2_assets =
{
    Asset("ANIM", "anim/die.zip")
}

local burnfx_assets = 
{
	Asset("ANIM", "anim/lr_emperorbow_burn_fx.zip")
}

local bombfx_assets = 
{
	Asset("ANIM", "anim/lr_emperorbow_bomb_fx.zip")
}

local NUM_VARIATIONS = 3
local MIN_SCALE = 1
local MAX_SCALE = 1.8

local fxcolours = {
	{0xFF/255, 0x30/255, 0x30/255, .5},
	{0xFF/255, 0x00/255, 0xFF/255, .5},
	{0x32/255, 0xCD/255, 0x32/255, .5},
	{255/255, 215/255, 0/255, .5},
}

local function MakeShadowFX(name, num, prefabs)
    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddNetwork()
		inst.entity:AddAnimState()
		inst.AnimState:SetBank("cane_shadow_fx")
		inst.AnimState:SetBuild("cane_shadow_fx")

        inst:AddTag("FX")
        inst:AddTag("shadowtrail")

        inst.variation = tostring(num or math.random(NUM_VARIATIONS))
		
		inst._colour = net_tinybyte(inst.GUID, "shadow_trail._colour", "colourdirty")
        if num == nil then
            inst:SetPrefabName(name..inst.variation)
        end
		
		if not TheNet:IsDedicated() then
			inst:ListenForEvent("colourdirty", function(inst)
				local colour = inst._colour:value()
				if colour > 0 then
					local rand = math.random(62)
					local flip = rand > 31
					local scale = MIN_SCALE + (MAX_SCALE - MIN_SCALE) * (flip and rand - 32 or rand - 1) / 30
					local anim = "shad" .. inst.variation
					inst.AnimState:SetScale(flip and -scale or scale, scale)
					inst.AnimState:PlayAnimation(anim)
					inst.AnimState:SetMultColour(1, 1, 1, 0)
					inst.AnimState:SetAddColour(unpack(colour > #fxcolours and fxcolours[math.random(#fxcolours)] or fxcolours[colour]))
				end
			end)
			inst:ListenForEvent("animover", inst.Hide)			
		end

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst.persists = false
        inst:DoTaskInTime(2, inst.Remove)
        return inst
    end

    return Prefab(name, fn, assets, prefabs)
end

local function PlayExplodeAnim(proxy)
	local inst = CreateEntity()

	inst:AddTag("FX")
    --[[Non-networked entity]]
	inst.entity:SetCanSleep(false)
	inst.persists = false

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst.Transform:SetFromProxy(proxy.GUID)

	inst.Transform:SetScale(.5, .5, .5)

	inst.AnimState:SetBank("explode")
	inst.AnimState:SetBuild("explode")
	inst.AnimState:PlayAnimation("small_firecrackers")
	inst.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
	inst.AnimState:SetLightOverride(1)

	inst:ListenForEvent("animover", inst.Remove)
end

local function hitfx1_fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddNetwork()

			--Dedicated server does not need to spawn the local fx
	if not TheNet:IsDedicated() then
		--Delay one frame so that we are positioned properly before starting the effect
		--or in case we are about to be removed
		inst:DoTaskInTime(0, PlayExplodeAnim)
	end

	inst.Transform:SetFourFaced()

	inst:AddTag("FX")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end
	
	inst.persists = false
	inst:DoTaskInTime(1, inst.Remove)
	return inst
end


local function hitfx2_fn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
	inst.entity:AddNetwork()
	inst.entity:AddSoundEmitter()
	inst.entity:AddAnimState()
	inst.AnimState:SetBank("die_fx")
	inst.AnimState:SetBuild("die")
	inst.AnimState:PlayAnimation("small")

	inst:AddTag("FX")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end
	
	inst.SoundEmitter:PlaySound("dontstarve/common/deathpoof")
	inst.persists = false
	inst:ListenForEvent("animover", inst.Remove)
	return inst
end

local function burnfx1_fn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
	inst.entity:AddNetwork()
	inst.entity:AddAnimState()
	inst.entity:AddLight()
	inst.AnimState:SetBank("lr_emperorbow_burn_fx")
	inst.AnimState:SetBuild("lr_emperorbow_burn_fx")
	inst.AnimState:PlayAnimation("yellow_burn_pre")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetSortOrder(1)
	inst.Transform:SetScale(1.5, 1.5, 1.5)
	inst.Light:SetRadius(3)
	inst.Light:SetFalloff(0.8)
	inst.Light:SetIntensity(.3)
	inst.Light:SetColour(254/255, 242/255, 58/255)
	inst.Light:Enable(true)

	inst:AddTag("FX")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end
	
	inst.persists = false
	return inst
end

local function burnfx2_fn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
	inst.entity:AddNetwork()
	inst.entity:AddAnimState()
	inst.entity:AddLight()
	inst.AnimState:SetBank("lr_emperorbow_burn_fx")
	inst.AnimState:SetBuild("lr_emperorbow_burn_fx")
	inst.AnimState:PlayAnimation("purple_burn_pre")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetSortOrder(1)
	inst.Transform:SetScale(1.5, 1.5, 1.5)
	inst.Light:SetRadius(3)
	inst.Light:SetFalloff(0.8)
	inst.Light:SetIntensity(.3)
	inst.Light:SetColour(255/255, 0/255, 128/255)
	inst.Light:Enable(true)

	inst:AddTag("FX")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end
	
	inst.persists = false
	return inst
end

local function bombfx1_fn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
	inst.entity:AddNetwork()
	inst.entity:AddAnimState()
	inst.entity:AddLight()
	inst.entity:AddSoundEmitter()
	inst.AnimState:SetBank("lr_emperorbow_bomb_fx")
	inst.AnimState:SetBuild("lr_emperorbow_bomb_fx")
	inst.AnimState:PlayAnimation("yellowbomb")
	inst.Light:SetRadius(6)
	inst.Light:SetFalloff(0.8)
	inst.Light:SetIntensity(.3)
	inst.Light:SetColour(255/255, 156/255, 0/255)
	inst.Light:Enable(true)
	inst.Transform:SetScale(.6, .6, .6)

	inst:AddTag("FX")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end
	
	inst.SoundEmitter:PlaySound("dontstarve/common/blackpowder_explo")
	inst:ListenForEvent("animover", inst.Remove)
	inst.persists = false
	return inst
end

local function bombfx2_fn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
	inst.entity:AddNetwork()
	inst.entity:AddAnimState()
	inst.entity:AddLight()
	inst.entity:AddSoundEmitter()
	inst.AnimState:SetBank("lr_emperorbow_bomb_fx")
	inst.AnimState:SetBuild("lr_emperorbow_bomb_fx")
	inst.AnimState:PlayAnimation("yellowbomb")
	inst.Light:SetRadius(8)
	inst.Light:SetFalloff(0.8)
	inst.Light:SetIntensity(.3)
	inst.Light:SetColour(255/255, 0/255, 128/255)
	inst.Light:Enable(true)

	inst:AddTag("FX")

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end
	
	inst.SoundEmitter:PlaySound("dontstarve/common/blackpowder_explo")
	inst:ListenForEvent("animover", inst.Remove)
	inst.persists = false
	return inst
end

local ret = {}
local prefs = {}
for i = 1, NUM_VARIATIONS do
    local name = "lr_emperorbow_fx"..tostring(i)
    table.insert(prefs, name)
    table.insert(ret, MakeShadowFX(name, i))
end
table.insert(ret, MakeShadowFX("lr_emperorbow_fx", nil, prefs))
table.insert(ret, Prefab("lr_emperorbow_hit_fx1", hitfx1_fn, hitfx1_assets))
table.insert(ret, Prefab("lr_emperorbow_hit_fx2", hitfx2_fn, hitfx2_assets))
table.insert(ret, Prefab("lr_emperorbow_burn_fx1", burnfx1_fn, burnfx_assets))
table.insert(ret, Prefab("lr_emperorbow_burn_fx2", burnfx2_fn, burnfx_assets))
table.insert(ret, Prefab("lr_emperorbow_bomb_fx1", bombfx1_fn, bombfx_assets))
table.insert(ret, Prefab("lr_emperorbow_bomb_fx2", bombfx2_fn, bombfx_assets))
prefs = nil

return unpack(ret)
