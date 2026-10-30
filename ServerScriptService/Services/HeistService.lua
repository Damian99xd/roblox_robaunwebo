--!strict
-- ModuleScript: ServerScriptService/Services/HeistService
-- Los puntos deben etiquetarse BrainrotStealPoint y tener OwnerUserId (number).
-- Cada base incluye BasePart DeliveryPoint. El cliente no decide si el progreso terminó.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local CollectionService=game:GetService("CollectionService")
local Config=require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BrainrotConfig"))
local HeistService={}
local active: {[Player]: any}={}; local cooldown: {[Player]: number}={}; local originalSpeed: {[Player]: number}={}
local Remotes=ReplicatedStorage:WaitForChild("BrainrotRemotes")
local function notify(p: Player,msg: string,kind: string) if p.Parent then Remotes.Notify:FireClient(p,msg,kind) end end
local function stealPoint(ownerId: number): BasePart?
	for _,obj in ipairs(CollectionService:GetTagged("BrainrotStealPoint")) do if obj:IsA("BasePart") and obj:GetAttribute("OwnerUserId")==ownerId then return obj end end
	return nil
end
local function deliveryPoint(ownerId: number): BasePart?
	for _,obj in ipairs(CollectionService:GetTagged("BrainrotDeliveryPoint")) do if obj:IsA("BasePart") and obj:GetAttribute("OwnerUserId")==ownerId then return obj end end
	return nil
end
local function root(player: Player): BasePart? local c=player.Character; return c and c:FindFirstChild("HumanoidRootPart") :: BasePart? end
local function profileOf(profiles: {[Player]: any},player: Player): any return profiles[player] end
local function clearCarry(player: Player)
	local c=player.Character; if c then local part=c:FindFirstChild("CarriedHeistEgg"); if part then part:Destroy() end end
	player:SetAttribute("CarryingStolenEgg",false)
	local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid"); if hum and originalSpeed[player] then hum.WalkSpeed=originalSpeed[player] end; originalSpeed[player]=nil
end
local function attachCarry(player: Player)
	local c=player.Character; local hand=c and (c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")); if not hand or not hand:IsA("BasePart") then return end
	local egg=Instance.new("Part"); egg.Name="CarriedHeistEgg"; egg.Shape=Enum.PartType.Ball; egg.Size=Vector3.new(1.25,1.5,1.25); egg.Material=Enum.Material.Neon; egg.Color=Color3.fromRGB(193,91,255); egg.CanCollide=false; egg.Massless=true; egg.CFrame=hand.CFrame*CFrame.new(0,-.55,-.8); egg.Parent=c
	local weld=Instance.new("WeldConstraint"); weld.Part0=hand; weld.Part1=egg; weld.Parent=egg
	local hum=c:FindFirstChildOfClass("Humanoid"); if hum then originalSpeed[player]=hum.WalkSpeed; hum.WalkSpeed=math.min(hum.WalkSpeed,Config.CarryWalkSpeed) end
end
local function cancel(player: Player,reason: string)
	local heist=active[player]; if not heist then return end; active[player]=nil; clearCarry(player)
	Remotes.HeistProgress:FireClient(player,"cancel",0); notify(player,"Incursión cancelada: "..reason,"bad"); if heist.Owner.Parent then notify(heist.Owner,player.Name.." fue detenido: "..reason,"good") end
end
local function countInventory(inv: {[string]: any}): number local n=0; for _,item in pairs(inv) do n+=item.Count end; return n end
local function removeOne(profile: any,id: string)
	local item=profile.Inventory[id]; if not item or item.Count<1 then return false end
	item.Count-=1; if item.Count==0 then profile.Inventory[id]=nil; local i=table.find(profile.Equipped,id); if i then table.remove(profile.Equipped,i) end end; return true
end
function HeistService.Start(player: Player,ownerId: number,profiles: {[Player]: any}): (boolean,string?)
	local now=os.clock(); if active[player] then return false,"Ya tienes una incursión activa." end
	if now-(cooldown[player] or 0)<Config.HeistCooldownSeconds then return false,"Debes esperar antes de otra incursión." end
	local owner=Players:GetPlayerByUserId(ownerId); if not owner or owner==player then return false,"Base inválida." end
	local point=stealPoint(ownerId); local r=root(player); if not point or not r or (r.Position-point.Position).Magnitude>Config.HeistRange then return false,"Acércate a la incubadora rival." end
	local ownerProfile=profileOf(profiles,owner); local available={}
	for _,id in ipairs(ownerProfile and ownerProfile.Equipped or {}) do local item=ownerProfile.Inventory[id]; if item and item.Count>0 then table.insert(available,id) end end
	if #available==0 then return false,"No hay Brainrots expuestos en esa base." end
	local target=available[Random.new():NextInteger(1,#available)]; local record={Owner=owner,OwnerId=ownerId,Point=point,Target=target,Started=os.clock(),Phase="Steal"}; active[player]=record; cooldown[player]=now
	notify(owner,player.Name.." está intentando robar en tu base. ¡Pulsa Defender!","bad")
	task.spawn(function()
		while active[player]==record and record.Phase=="Steal" do
			local elapsed=os.clock()-record.Started; local currentRoot=root(player)
			if not currentRoot or not point.Parent or (currentRoot.Position-point.Position).Magnitude>Config.HeistRange then cancel(player,"saliste del área"); return end
			Remotes.HeistProgress:FireClient(player,"progress",math.clamp(elapsed/Config.HeistHoldSeconds,0,1))
			if elapsed>=Config.HeistHoldSeconds then break end; task.wait(.1)
		end
		if active[player]~=record then return end
		local tp=profileOf(profiles,player); if not tp or countInventory(tp.Inventory)>=Config.MaxInventoryItems then cancel(player,"inventario lleno"); return end
		local destination=deliveryPoint(player.UserId); if not destination then cancel(player,"tu base no tiene DeliveryPoint"); return end
		record.Phase="Extract"; player:SetAttribute("CarryingStolenEgg",true); attachCarry(player)
		Remotes.HeistProgress:FireClient(player,"extract",0); notify(player,"¡Botín asegurado! Llévalo a tu DeliveryPoint.","good")
		local prompt=destination:FindFirstChild("DeliverHeistPrompt") :: ProximityPrompt?
		if not prompt then prompt=Instance.new("ProximityPrompt"); prompt.Name="DeliverHeistPrompt"; prompt.ActionText="Entregar botín"; prompt.ObjectText="Huevo robado"; prompt.HoldDuration=.5; prompt.MaxActivationDistance=10; prompt.Parent=destination end
		local connection: RBXScriptConnection?; connection=prompt.Triggered:Connect(function(actor)
			if actor~=player or active[player]~=record or record.Phase~="Extract" then return end
			local pr=root(player); if not pr or (pr.Position-destination.Position).Magnitude>Config.ExtractionRange then return end
			local thiefProfile=profileOf(profiles,player); local victimProfile=profileOf(profiles,owner)
			if not thiefProfile or not victimProfile or countInventory(thiefProfile.Inventory)>=Config.MaxInventoryItems then cancel(player,"inventario lleno"); return end
			if not removeOne(victimProfile,record.Target) then cancel(player,"el Brainrot ya no está disponible"); return end
			local old=thiefProfile.Inventory[record.Target]; if old then old.Count+=1 else thiefProfile.Inventory[record.Target]={Count=1,Shiny=false} end
			thiefProfile.Stats.TotalStolen+=1; thiefProfile.Stats.SuccessfulHeists+=1; active[player]=nil; clearCarry(player)
			Remotes.HeistProgress:FireClient(player,"complete",1); notify(player,"¡Incursión exitosa! Añadiste "..record.Target.." a tu colección.","good"); notify(owner,player.Name.." escapó con un Brainrot de tu base.","bad")
			if connection then connection:Disconnect() end
		end)
		-- El dueño puede defender en ambas fases; morir/desconectarse cancela vía MainServer.
	end)
	return true
end
function HeistService.Defend(owner: Player)
	for thief,record in pairs(active) do if record.Owner==owner then cancel(thief,"el dueño defendió la base"); return true end end
	return false
end
function HeistService.Cancel(player: Player,reason: string) cancel(player,reason); cooldown[player]=nil end
function HeistService.Cleanup(player: Player)
	cancel(player,"jugador desconectado"); cooldown[player]=nil; originalSpeed[player]=nil
end
return HeistService
