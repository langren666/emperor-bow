---------------------[[ 服务器&客户端组件 蓄能物品 ]]---------------------
local IsServer = TheNet:GetIsServer()

local Lr_Accumulate_Item = Class(function(self, inst)
	self.inst = inst
	
	self.cycles = {1}
	self.cycle = 0
	self.currenttime = 0
	self.onfinish = nil
	self.running = false --是否正在蓄能
	self.event = nil --触发蓄能时的事件
	self.rpc = nil --触发蓄能时向主机发送RPC
	self.stopevent = nil --取消蓄能时的事件
	self.stoprpc = nil --取消蓄能时向主机发送的RPC
	
	self._tick = net_byte(inst.GUID, "lr_accumulate._tick", "lraccu_tickdirty")
	self._cycle = net_tinybyte(inst.GUID, "lr_accumulate._cycle", "lraccu_cycledirty")
	if not TheNet:IsDedicated() then
		inst:ListenForEvent("lraccu_tickdirty", function(inst)
			local player = rawget(_G, "ThePlayer")
			if player and player.HUD then
				player.HUD:ShowAccumulateMeter(player:GetPosition(), self.inst)
			end
		end)
		inst:ListenForEvent("lraccu_cycledirty", function(inst)
			local player = rawget(_G, "ThePlayer")
			if player and player.HUD then
				player.HUD:ShowAccumulateMeter(player:GetPosition(), self.inst)
			end
		end)
	end
end)

function Lr_Accumulate_Item:StartAccumulating() --开始蓄能
	if IsServer then
		if not self.running then
			self.running = true
			self.inst:StartUpdatingComponent(self)
		end
	else
		if self.event then
			ThePlayer:PushEvent(self.event, self.inst)
		end
		if self.rpc then
			SendModRPCToServer(self.rpc, self.inst)
		end
	end
end

function Lr_Accumulate_Item:StopAccumulating(pos) --主动停止蓄能 并且释放能力 pos为鼠标的位置
	if IsServer then
		if self.running then
			self.running = false
			self.inst:StopUpdatingComponent(self)
			self.onfinish(self.inst, self.cycle, self.currenttime, pos)
			self.currenttime = 0
			self.cycle = 0
			self._tick:set(0)
			self._cycle:set(0)
		end
	else
		if self.stopevent then
			ThePlayer:PushEvent(self.stopevent, self.inst)
		end
		if self.stoprpc then
			local mousept = TheInput:GetWorldPosition()
			SendModRPCToServer(self.stoprpc, self.inst, mousept.x .. " " .. mousept.z)
		end
	end
end

function Lr_Accumulate_Item:CancelAccumulating() --被动停止蓄能 不会释放能力 之前蓄能的时间和格数归零
	if not IsServer then
		return
	end
	if self.running then
		self.running = false
		self.inst:StopUpdatingComponent(self)
		self.currenttime = 0
		self.cycle = 0
		self._tick:set(0)
		self._cycle:set(0)
	end
end

function Lr_Accumulate_Item:SetOnFinish(fn) --当蓄能超过1时 停止蓄能将会触发这个函数
	self.onfinish = fn
end

function Lr_Accumulate_Item:OnUpdate(dt)
	local maxcycle = #self.cycles
	local curcycle = math.min(self.cycle + 1, maxcycle)
	self.currenttime = math.min(self.currenttime + dt, self.cycles[curcycle])
	if self.currenttime >= self.cycles[curcycle] and self.cycle < maxcycle then
		self.cycle = self.cycle + 1
		if self.cycle < maxcycle then
			self.currenttime = 0 --如果还没完全蓄满就重置时间接着蓄能
		end
	end
	curcycle = math.min(self.cycle + 1, maxcycle)
	self._tick:set(math.floor(self.currenttime / self.cycles[curcycle] / 0.01))
	self._cycle:set(self.cycle)
end

return Lr_Accumulate_Item