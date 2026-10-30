--!strict
-- ModuleScript: ServerScriptService/Services/HatchingService
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BrainrotConfig"))
local HatchingService={}
local lastHatch: {[Player]: number}={}
local random=Random.new()
local function inventoryCount(inv: {[string]: any}): number local total=0; for _,item in pairs(inv) do total+=item.Count end; return total end
local function weightedPick(drops: {any}): string
	local total=0; for _,drop in ipairs(drops) do total+=drop.Weight end
	local roll=random:NextNumber(0,total); local cursor=0
	for _,drop in ipairs(drops) do cursor+=drop.Weight; if roll<cursor then return drop.Id end end
	return drops[#drops].Id
end
function HatchingService.HatchEgg(player: Player, eggType: string, profile: any): (boolean,string?)
	local egg=Config.Eggs[eggType]; if not egg then return false,"Huevo desconocido." end
	local now=os.clock(); local previous=lastHatch[player] or 0
	if now-previous<Config.HatchCooldownSeconds then return false,"Espera antes de volver a incubar." end
	if now-previous<60/Config.HatchRatePerMinute then return false,"Alcanzaste el límite de incubaciones." end
	if inventoryCount(profile.Inventory)>=Config.MaxInventoryItems then return false,"Inventario lleno." end
	local currency=egg.Currency=="Gems" and "Gems" or "Coins"
	if profile[currency]<egg.Cost then return false,"No tienes suficientes "..(currency=="Gems" and "Gemas." or "monedas.") end
	profile[currency]-=egg.Cost; lastHatch[player]=now
	local id=weightedPick(egg.Drops); local shiny=random:NextNumber()<Config.ShinyChance
	local entry=profile.Inventory[id]
	if not entry then entry={Count=0,Shiny=shiny}; profile.Inventory[id]=entry end
	entry.Count+=1; entry.Shiny=entry.Shiny or shiny
	return true,id
end
function HatchingService.Cleanup(player: Player) lastHatch[player]=nil end
return HatchingService
