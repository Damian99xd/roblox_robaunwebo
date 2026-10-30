--!strict
-- Script: ServerScriptService/Core/MainServer.server.lua
-- Instala remotes y conecta servicios. Configura puntos de base según README.md.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local CollectionService=game:GetService("CollectionService")
local ServerScriptService=game:GetService("ServerScriptService")
local Config=require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BrainrotConfig"))
local Services=ServerScriptService:WaitForChild("Services")
local DataService=require(Services:WaitForChild("DataService"))
local HatchingService=require(Services:WaitForChild("HatchingService"))
local HeistService=require(Services:WaitForChild("HeistService"))

local remotes=ReplicatedStorage:FindFirstChild("BrainrotRemotes") or Instance.new("Folder"); remotes.Name="BrainrotRemotes"; remotes.Parent=ReplicatedStorage
local function getRemote(className: string,name: string): Instance
	local obj=remotes:FindFirstChild(name); if not obj then obj=Instance.new(className); obj.Name=name; obj.Parent=remotes end
	assert(obj.ClassName==className,"Remote class mismatch: "..name); return obj
end
local HatchRequest=getRemote("RemoteFunction","HatchRequest") :: RemoteFunction
local EquipRequest=getRemote("RemoteFunction","EquipRequest") :: RemoteFunction
local HeistRequest=getRemote("RemoteFunction","HeistRequest") :: RemoteFunction
local DefendRequest=getRemote("RemoteEvent","DefendRequest") :: RemoteEvent
local Notify=getRemote("RemoteEvent","Notify") :: RemoteEvent
local StateUpdate=getRemote("RemoteEvent","StateUpdate") :: RemoteEvent
local HatchResult=getRemote("RemoteEvent","HatchResult") :: RemoteEvent
local HeistProgress=getRemote("RemoteEvent","HeistProgress") :: RemoteEvent

local function income(p: any): number
	local total=0
	for _,id in ipairs(p.Equipped) do local def=Config.Brainrots[id]; local item=p.Inventory[id]; if def and item then total+=def.Income*def.Multiplier*(item.Shiny and Config.ShinyMultiplier or 1) end end
	return total
end
local function sync(player: Player)
	local p=DataService.Profiles[player]; if not p then return end
	local leader=player:FindFirstChild("leaderstats")
	if not leader then leader=Instance.new("Folder"); leader.Name="leaderstats"; leader.Parent=player end
	for _,pair in ipairs({{"Dinero",p.Coins},{"Gems",p.Gems},{"HuevosRobados",p.Stats.TotalStolen}}) do
		local v=leader:FindFirstChild(pair[1]) :: IntValue?; if not v then v=Instance.new("IntValue"); v.Name=pair[1]; v.Parent=leader end; v.Value=pair[2]
	end
	StateUpdate:FireClient(player,{Coins=p.Coins,Gems=p.Gems,Inventory=p.Inventory,Equipped=p.Equipped,Stats=p.Stats,Income=income(p),Settings=p.Settings})
end
local function notify(player: Player,message: string,kind: string) if player.Parent then Notify:FireClient(player,message,kind) end end

HatchRequest.OnServerInvoke=function(player: Player,eggId: any)
	local p=DataService.Profiles[player]; if not p or type(eggId)~="string" then return false,"Solicitud inválida." end
	local ok,result=HatchingService.HatchEgg(player,eggId,p); if not ok then return false,result end
	sync(player); local info=Config.Brainrots[result :: string]; HatchResult:FireClient(player,result,info,p.Inventory[result :: string].Shiny)
	return true,result
end
EquipRequest.OnServerInvoke=function(player: Player,id: any)
	local p=DataService.Profiles[player]; if not p or type(id)~="string" or not Config.Brainrots[id] then return false,"Brainrot inválido." end
	local entry=p.Inventory[id]; if not entry or entry.Count<1 then return false,"No tienes ese Brainrot." end
	local index=table.find(p.Equipped,id)
	if index then table.remove(p.Equipped,index) elseif #p.Equipped<Config.MaxEquipped then table.insert(p.Equipped,id) else return false,"Límite de equipados alcanzado." end
	sync(player); return true
end
HeistRequest.OnServerInvoke=function(player: Player,ownerId: any)
	if type(ownerId)~="number" or ownerId%1~=0 then return false,"Base inválida." end
	return HeistService.Start(player,ownerId,DataService.Profiles)
end
DefendRequest.OnServerEvent:Connect(function(player: Player) HeistService.Defend(player) end)

local function bindStealPoint(point: Instance)
	if not point:IsA("BasePart") then warn("BrainrotStealPoint tag must be on a BasePart:",point:GetFullName()); return end
	local prompt=point:FindFirstChild("HeistPrompt") :: ProximityPrompt?
	if not prompt then prompt=Instance.new("ProximityPrompt"); prompt.Name="HeistPrompt"; prompt.ActionText="Iniciar incursión"; prompt.ObjectText="Base rival"; prompt.HoldDuration=0; prompt.MaxActivationDistance=Config.HeistRange; prompt.Parent=point end
	prompt.Triggered:Connect(function(player: Player)
		local ownerId=point:GetAttribute("OwnerUserId")
		if type(ownerId)~="number" then notify(player,"Esta base no tiene OwnerUserId configurado.","bad"); return end
		local ok,message=HeistService.Start(player,ownerId,DataService.Profiles); if not ok then notify(player,message or "No se pudo iniciar.","bad") end
	end)
end
for _,point in ipairs(CollectionService:GetTagged("BrainrotStealPoint")) do bindStealPoint(point) end
CollectionService:GetInstanceAddedSignal("BrainrotStealPoint"):Connect(bindStealPoint)

local function onPlayerAdded(player: Player)
	if not DataService.Load(player) then player:Kick("No fue posible abrir tu perfil. Intenta unirte de nuevo."); return end
	sync(player)
	player.CharacterAdded:Connect(function(character)
		local hum=character:WaitForChild("Humanoid",10); if hum then hum.Died:Connect(function() HeistService.Cancel(player,"fuiste derrotado") end) end
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _,p in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded,p) end
Players.PlayerRemoving:Connect(function(player) HeistService.Cleanup(player); HatchingService.Cleanup(player); DataService.Release(player) end)

DataService.StartAutosave()
task.spawn(function()
	while true do task.wait(Config.PassiveTickSeconds)
		for player,p in pairs(DataService.Profiles) do
			local amount=income(p)*Config.PassiveTickSeconds
			if amount>0 then p.Coins=math.min(p.Coins+amount,2_000_000_000); sync(player) end
		end
	end
end)
game:BindToClose(function() DataService.Shutdown() end)
