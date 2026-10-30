--!strict
-- Genera el mapa jugable en Workspace cuando comienza Play.
-- Puestos de robo y entrega quedan etiquetados/atribuidos para HeistService.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local CollectionService=game:GetService("CollectionService")
local ServerScriptService=game:GetService("ServerScriptService")
local Config=require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BrainrotConfig"))
local HatchingService=require(ServerScriptService:WaitForChild("Services"):WaitForChild("HatchingService"))
local DataService=require(ServerScriptService:WaitForChild("Services"):WaitForChild("DataService"))
local root=workspace:FindFirstChild("BrainrotHeistWorld")
if root then root:Destroy() end
root=Instance.new("Folder"); root.Name="BrainrotHeistWorld"; root.Parent=workspace
local basesFolder=Instance.new("Folder"); basesFolder.Name="PlayerBases"; basesFolder.Parent=root

local COLORS={Dark=Color3.fromRGB(21,22,38),Purple=Color3.fromRGB(137,79,255),Cyan=Color3.fromRGB(50,225,229),Lime=Color3.fromRGB(209,255,91),Pink=Color3.fromRGB(255,76,157)}
local function part(parent: Instance,name: string,size: Vector3,cf: CFrame,color: Color3,material: Enum.Material?): Part
	local p=Instance.new("Part"); p.Name=name; p.Size=size; p.CFrame=cf; p.Anchored=true; p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth; p.Color=color; p.Material=material or Enum.Material.SmoothPlastic; p.Parent=parent; return p
end
local function label(on: BasePart,text: string,color: Color3)
	local gui=Instance.new("BillboardGui"); gui.Name="WorldLabel"; gui.Size=UDim2.fromOffset(260,56); gui.StudsOffset=Vector3.new(0,3,0); gui.AlwaysOnTop=true; gui.Parent=on
	local t=Instance.new("TextLabel"); t.Size=UDim2.fromScale(1,1); t.BackgroundTransparency=1; t.Text=text; t.TextColor3=color; t.TextStrokeTransparency=.3; t.Font=Enum.Font.GothamBlack; t.TextScaled=true; t.Parent=gui
end
local function prompt(on: BasePart,action: string,object: string,hold: number): ProximityPrompt
	local p=Instance.new("ProximityPrompt"); p.ActionText=action; p.ObjectText=object; p.HoldDuration=hold; p.MaxActivationDistance=12; p.RequiresLineOfSight=false; p.Parent=on; return p
end

-- Arena foundation, safe lobby ring and spawn point.
part(root,"ArenaFloor",Vector3.new(300,2,300),CFrame.new(0,-1,0),Color3.fromRGB(29,30,48),Enum.Material.Asphalt)
local lobby=part(root,"SafeLobby",Vector3.new(58,2,58),CFrame.new(0,1,0),Color3.fromRGB(36,37,60),Enum.Material.SmoothPlastic)
for _,a in ipairs({0,90,180,270}) do local ring=part(root,"LobbyNeonRing",Vector3.new(62,.35,1),CFrame.new(0,2.2,0)*CFrame.Angles(0,math.rad(a),0),COLORS.Cyan,Enum.Material.Neon); ring.CanCollide=false end
local spawn=Instance.new("SpawnLocation"); spawn.Name="BrainrotSpawn"; spawn.Size=Vector3.new(8,1,8); spawn.CFrame=CFrame.new(0,3,0); spawn.Anchored=true; spawn.Neutral=true; spawn.Duration=0; spawn.Color=COLORS.Lime; spawn.Material=Enum.Material.Neon; spawn.Parent=root
local sign=part(root,"HologramSign",Vector3.new(1,1,1),CFrame.new(0,11,-24),COLORS.Purple,Enum.Material.Neon); sign.Transparency=1; sign.CanCollide=false; label(sign,"BRAINROT HEIST  //  STEAL • HATCH • ESCAPE",Color3.fromRGB(224,220,255))
part(root,"SignPillarL",Vector3.new(1,12,1),CFrame.new(-15,6,-24),COLORS.Cyan,Enum.Material.Neon); part(root,"SignPillarR",Vector3.new(1,12,1),CFrame.new(15,6,-24),COLORS.Pink,Enum.Material.Neon)

-- Central hatch station. Prompts call the same server-authoritative hatch remote as the HUD.
local station=Instance.new("Model"); station.Name="HatchStation"; station.Parent=root
part(station,"Platform",Vector3.new(36,2,18),CFrame.new(0,2,38),Color3.fromRGB(43,39,66),Enum.Material.Metal)
local remotes=ReplicatedStorage:WaitForChild("BrainrotRemotes")
for i,(eggId,egg) in ipairs((function() local a={}; for id,v in pairs(Config.Eggs) do table.insert(a,{id,v}) end; table.sort(a,function(x,y) return x[1]<y[1] end); return a end)()) do
	local x=(i-2)*11; local pedestal=part(station,"EggPedestal_"..eggId,Vector3.new(7,1,7),CFrame.new(x,3.5,38),Color3.fromRGB(53,52,75),Enum.Material.Metal)
	local orb=part(station,"EggOrb_"..eggId,Vector3.new(3.8,4.6,3.8),CFrame.new(x,6.1,38),i==1 and COLORS.Lime or (i==2 and COLORS.Pink or COLORS.Cyan),Enum.Material.Neon); orb.Shape=Enum.PartType.Ball; orb.CanCollide=false; label(orb,egg.DisplayName.."\n¢ "..egg.Cost,orb.Color)
	local pp=prompt(pedestal,"Incubar",egg.DisplayName,0.5)
	pp.Triggered:Connect(function(player: Player)
		local profile=DataService.Profiles[player]; if not profile then return end
		local ok,result=HatchingService.HatchEgg(player,eggId,profile)
		if not ok then local notify=remotes:FindFirstChild("Notify") :: RemoteEvent?; if notify then notify:FireClient(player,tostring(result),"bad") end; return end
		local info=Config.Brainrots[result :: string]
		local state=remotes:FindFirstChild("StateUpdate") :: RemoteEvent?; if state then state:FireClient(player,{Coins=profile.Coins,Gems=profile.Gems,Inventory=profile.Inventory,Equipped=profile.Equipped,Stats=profile.Stats,Income=0,Settings=profile.Settings}) end
		local hatch=remotes:FindFirstChild("HatchResult") :: RemoteEvent?; if hatch then hatch:FireClient(player,result,info,profile.Inventory[result :: string].Shiny) end
	end)
end

-- Eight perimeter base plots. Plots are claimed deterministically on join and reset on leave.
local plotPositions={Vector3.new(-82,0,-82),Vector3.new(0,0,-105),Vector3.new(82,0,-82),Vector3.new(105,0,0),Vector3.new(82,0,82),Vector3.new(0,0,105),Vector3.new(-82,0,82),Vector3.new(-105,0,0)}
local plots: {Model}={}
for i,pos in ipairs(plotPositions) do
	local base=Instance.new("Model"); base.Name="Base_"..i; base.Parent=basesFolder; table.insert(plots,base)
	part(base,"BaseFloor",Vector3.new(38,2,32),CFrame.new(pos+Vector3.new(0,1,0)),Color3.fromRGB(37,38,57),Enum.Material.Metal)
	local back=part(base,"BackWall",Vector3.new(38,12,1),CFrame.new(pos+Vector3.new(0,7,-15)),Color3.fromRGB(47,42,70),Enum.Material.Slate)
	local title=part(base,"BaseName",Vector3.new(1,1,1),CFrame.new(pos+Vector3.new(0,13,-15)),COLORS.Cyan,Enum.Material.Neon); title.Transparency=1; title.CanCollide=false; label(title,"BASE SIN ASIGNAR",COLORS.Cyan)
	local incubator=part(base,"Incubator",Vector3.new(8,4,8),CFrame.new(pos+Vector3.new(0,4,0)),COLORS.Purple,Enum.Material.Neon); incubator.Shape=Enum.PartType.Cylinder; incubator.Orientation=Vector3.new(0,0,90)
	local steal=part(base,"StealPoint",Vector3.new(5,1,5),CFrame.new(pos+Vector3.new(0,2,10)),COLORS.Pink,Enum.Material.Neon); steal.Transparency=.35; steal:SetAttribute("OwnerUserId",0); CollectionService:AddTag(steal,"BrainrotStealPoint")
	local delivery=part(base,"DeliveryPoint",Vector3.new(7,1,7),CFrame.new(pos+Vector3.new(0,2,5)),COLORS.Lime,Enum.Material.Neon); delivery:SetAttribute("OwnerUserId",0); CollectionService:AddTag(delivery,"BrainrotDeliveryPoint"); label(delivery,"ZONA DE EXTRACCIÓN",COLORS.Lime)
	local barrier=part(base,"ZoneMarker",Vector3.new(40,.25,1),CFrame.new(pos+Vector3.new(0,2,17)),COLORS.Pink,Enum.Material.Neon); barrier.CanCollide=false; barrier.Transparency=.2
	base.PrimaryPart=back
end

local playerPlot: {[Player]: Model}={}
local function claim(player: Player)
	for _,base in ipairs(plots) do if base:GetAttribute("OwnerUserId")==nil then
		base:SetAttribute("OwnerUserId",player.UserId); playerPlot[player]=base
		local steal=base:FindFirstChild("StealPoint") :: BasePart; local delivery=base:FindFirstChild("DeliveryPoint") :: BasePart
		steal:SetAttribute("OwnerUserId",player.UserId); delivery:SetAttribute("OwnerUserId",player.UserId)
		local labelGui=base:FindFirstChild("BaseName") :: BasePart; local billboard=labelGui:FindFirstChild("WorldLabel") :: BillboardGui; local text=billboard:FindFirstChildOfClass("TextLabel"); if text then text.Text=player.DisplayName.."'S BASE" end
		local character=player.Character or player.CharacterAdded:Wait(); local hrp=character:WaitForChild("HumanoidRootPart",10) :: BasePart?; if hrp then hrp.CFrame=base.PrimaryPart.CFrame*CFrame.new(0,5,12) end
		return
	end end
	player:Kick("El servidor está lleno: no hay parcelas libres.")
end
local function release(player: Player)
	local base=playerPlot[player]; if not base then return end; playerPlot[player]=nil; base:SetAttribute("OwnerUserId",nil)
	for _,name in ipairs({"StealPoint","DeliveryPoint"}) do local p=base:FindFirstChild(name) :: BasePart?; if p then p:SetAttribute("OwnerUserId",0) end end
	local signPart=base:FindFirstChild("BaseName") :: BasePart?; local bb=signPart and signPart:FindFirstChild("WorldLabel") :: BillboardGui?; local text=bb and bb:FindFirstChildOfClass("TextLabel"); if text then text.Text="BASE SIN ASIGNAR" end
end
Players.PlayerAdded:Connect(claim); Players.PlayerRemoving:Connect(release)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(claim,player) end
