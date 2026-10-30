--!strict
-- LocalScript: StarterPlayer/StarterPlayerScripts/ClientController.client.lua
-- UI y efectos locales. El cliente nunca decide RNG, saldo, propiedad ni fin del robo.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local SoundService=game:GetService("SoundService")
local player=Players.LocalPlayer
local Config=require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BrainrotConfig"))
local Remotes=ReplicatedStorage:WaitForChild("BrainrotRemotes")
local state:any={Coins=0,Gems=0,Inventory={},Equipped={},Income=0,Stats={TotalStolen=0}}
local gui=Instance.new("ScreenGui"); gui.Name="BrainrotHeistHUD"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui")
local function make(className: string,props: {[string]: any},parent: Instance): any
	local obj=Instance.new(className); for key,value in pairs(props) do (obj :: any)[key]=value end; obj.Parent=parent; return obj
end
local function round(parent: Instance,radius: number) make("UICorner",{CornerRadius=UDim.new(0,radius)},parent) end
local panel=make("Frame",{Name="Panel",Position=UDim2.fromOffset(16,80),Size=UDim2.fromOffset(340,476),BackgroundColor3=Color3.fromRGB(19,19,30),BackgroundTransparency=.04,BorderSizePixel=0},gui); round(panel,16); make("UIStroke",{Color=Color3.fromRGB(61,61,82),Thickness=1},panel)
make("TextLabel",{Position=UDim2.fromOffset(16,12),Size=UDim2.new(1,-32,0,29),BackgroundTransparency=1,Text="✳  BRAINROT HEIST",TextColor3=Color3.fromRGB(211,255,97),TextSize=19,Font=Enum.Font.GothamBlack,TextXAlignment=Enum.TextXAlignment.Left},panel)
local stats=make("TextLabel",{Position=UDim2.fromOffset(14,48),Size=UDim2.new(1,-28,0,44),BackgroundColor3=Color3.fromRGB(34,34,49),TextColor3=Color3.new(1,1,1),TextSize=13,Font=Enum.Font.GothamBold,Text="¢ 0    ◈ 0    +0/s",TextWrapped=true},panel); round(stats,9)
make("TextLabel",{Position=UDim2.fromOffset(16,101),Size=UDim2.new(1,-32,0,20),BackgroundTransparency=1,Text="TIENDA RNG · compra validada en servidor",TextColor3=Color3.fromRGB(157,157,180),TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},panel)
local eggs=make("Frame",{Position=UDim2.fromOffset(14,126),Size=UDim2.new(1,-28,0,128),BackgroundTransparency=1},panel); make("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},eggs)
make("TextLabel",{Position=UDim2.fromOffset(16,263),Size=UDim2.new(1,-32,0,23),BackgroundTransparency=1,Text="COLECCIÓN · pulsa para equipar / retirar",TextColor3=Color3.fromRGB(157,157,180),TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},panel)
local inventory=make("ScrollingFrame",{Position=UDim2.fromOffset(14,291),Size=UDim2.new(1,-28,0,164),BackgroundColor3=Color3.fromRGB(28,28,42),BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new()},panel); round(inventory,9); make("UIListLayout",{Padding=UDim.new(0,5),SortOrder=Enum.SortOrder.LayoutOrder},inventory)
local notice=make("TextLabel",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,20),Size=UDim2.fromOffset(450,44),BackgroundColor3=Color3.fromRGB(31,31,46),TextColor3=Color3.new(1,1,1),TextSize=14,Font=Enum.Font.GothamBold,Visible=false,ZIndex=20},gui); round(notice,10)
local barBg=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.78,0),Size=UDim2.fromOffset(320,30),BackgroundColor3=Color3.fromRGB(28,28,42),Visible=false,ZIndex=10},gui); round(barBg,8)
local bar=make("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=Color3.fromRGB(211,255,97),ZIndex=11},barBg); round(bar,8)
local barText=make("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="FORZANDO CÁMARA…",TextColor3=Color3.new(1,1,1),TextSize=12,Font=Enum.Font.GothamBold,ZIndex=12},barBg)
local function toast(text: string,kind: string?)
	notice.Text=text; notice.TextColor3=kind=="bad" and Color3.fromRGB(255,115,153) or Color3.new(1,1,1); notice.Visible=true
	task.delay(3,function() if notice.Parent then notice.Visible=false end end)
end
local function rebuild()
	stats.Text=string.format("¢ %d     ◈ %d     +%d/s     Robos %d",state.Coins or 0,state.Gems or 0,state.Income or 0,(state.Stats and state.Stats.TotalStolen) or 0)
	for _,child in ipairs(eggs:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	for id,egg in pairs(Config.Eggs) do
		local cost=egg.Currency=="Gems" and ("◈ "..egg.Cost) or ("¢ "..egg.Cost)
		local button=make("TextButton",{Name=id,Size=UDim2.new(1,0,0,37),BackgroundColor3=Color3.fromRGB(39,39,56),Text=egg.DisplayName.."     ·     "..cost,TextColor3=Color3.new(1,1,1),TextSize=12,Font=Enum.Font.GothamBold},eggs); round(button,8)
		button.Activated:Connect(function() local ok,result=Remotes.HatchRequest:InvokeServer(id); if not ok then toast(tostring(result),"bad") end end)
	end
	for _,child in ipairs(inventory:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
	for id,item in pairs(state.Inventory or {}) do
		local def=Config.Brainrots[id]; if def then
			local equipped=table.find(state.Equipped or {},id)~=nil; local shiny=item.Shiny and " ✨" or ""
			local button=make("TextButton",{Size=UDim2.new(1,-5,0,31),BackgroundColor3=equipped and Color3.fromRGB(63,78,43) or Color3.fromRGB(41,41,57),Text=def.DisplayName..shiny.." ×"..item.Count.."    +"..def.Income.."/s   "..(equipped and "EQUIPADO" or "EQUIPAR"),TextColor3=Color3.new(1,1,1),TextSize=11,Font=Enum.Font.GothamMedium},inventory); round(button,7)
			button.Activated:Connect(function() local ok,msg=Remotes.EquipRequest:InvokeServer(id); if not ok then toast(tostring(msg),"bad") end end)
		end
	end
	task.defer(function() inventory.CanvasSize=UDim2.fromOffset(0,inventory.UIListLayout.AbsoluteContentSize.Y+6) end)
end
Remotes.StateUpdate.OnClientEvent:Connect(function(newState: any) state=newState; rebuild() end)
Remotes.Notify.OnClientEvent:Connect(function(text: string,kind: string) toast(text,kind) end)
Remotes.HeistProgress.OnClientEvent:Connect(function(action: string,value: number)
	if action=="progress" then barBg.Visible=true; barText.Text="FORZANDO CÁMARA…"; TweenService:Create(bar,TweenInfo.new(.12),{Size=UDim2.new(value,0,1,0)}):Play()
	elseif action=="extract" then barBg.Visible=true; barText.Text="¡VUELVE A TU BASE!"; bar.Size=UDim2.new(1,0,1,0)
	else barBg.Visible=false; bar.Size=UDim2.new(0,0,1,0); if action=="complete" then toast("Botín entregado en tu base.","good") end end
end)
Remotes.HatchResult.OnClientEvent:Connect(function(id: string,info: any,shiny: boolean)
	local flash=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=shiny and Color3.fromRGB(255,231,110) or Config.Rarities[info.Rarity].Color,BackgroundTransparency=.2,ZIndex=30},gui)
	TweenService:Create(flash,TweenInfo.new(.55),{BackgroundTransparency=1}):Play(); task.delay(.6,function() flash:Destroy() end)
	local card=make("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,.43,0),Size=UDim2.fromOffset(360,110),BackgroundColor3=Color3.fromRGB(24,24,37),Text=(shiny and "✨ SHINY ✨\n" or "")..info.DisplayName.."\n"..Config.Rarities[info.Rarity].DisplayName.."  ·  +"..info.Income*(shiny and Config.ShinyMultiplier or 1).."/s",TextColor3=Color3.new(1,1,1),TextSize=22,Font=Enum.Font.GothamBlack,TextWrapped=true,ZIndex=31},gui); round(card,16); make("UIStroke",{Color=Config.Rarities[info.Rarity].Color,Thickness=3},card)
	-- Reemplaza SoundId por un audio publicado y permitido para la experiencia.
	local sound=Instance.new("Sound"); sound.SoundId=""; sound.Volume=.5; sound.Parent=SoundService; if sound.SoundId~="" then sound:Play() end; task.delay(3,function() card:Destroy(); sound:Destroy() end)
end)
-- Defensa express disponible en pantalla; servidor cancela una incursión activa del dueño.
local defend=make("TextButton",{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-18),Size=UDim2.fromOffset(158,44),BackgroundColor3=Color3.fromRGB(255,94,157),Text="🛡 DEFENDER BASE",TextColor3=Color3.fromRGB(38,18,30),TextSize=12,Font=Enum.Font.GothamBlack},gui); round(defend,10); defend.Activated:Connect(function() Remotes.DefendRequest:FireServer() end)
rebuild()
