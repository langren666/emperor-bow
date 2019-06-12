local assets = {
	Asset("ANIM", "anim/lr_bulleye.zip"),
}

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()

	inst:AddTag("FX")
	inst:AddTag("NOCLICK")

	inst.AnimState:SetBank("lr_bulleye")
	inst.AnimState:SetBuild("lr_bulleye")
	inst.AnimState:PlayAnimation("idle")
	inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
	inst.AnimState:SetLayer(LAYER_BACKGROUND)
	inst.AnimState:SetSortOrder(-1)
	inst.AnimState:SetScale(1.8, 1.8)
	inst:Hide()
	inst:DoTaskInTime(0, inst.Show)

	inst.persists = false
	return inst
end

return Prefab("lr_bulleye", fn, assets)