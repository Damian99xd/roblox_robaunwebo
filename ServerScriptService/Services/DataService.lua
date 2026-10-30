--!strict
-- ModuleScript: ServerScriptService/Services/DataService
-- Sesión exclusiva con lease persistida. Para producción de gran escala se recomienda
-- migrar a ProfileStore/ProfileService; este wrapper evita que dos servidores escriban a la vez.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("BrainrotConfig"))

type Profile = { Coins: number, Gems: number, Inventory: { [string]: number }, Equipped: { string }, Stats: { TotalStolen: number, SuccessfulHeists: number }, Settings: { AutoHatch: boolean }, _Revision: number }
local DataService = {}
DataService.Profiles = {} :: { [Player]: Profile }
local store = DataStoreService:GetDataStore(Config.DataStoreName)
local sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)
local closing = false

local function template(): Profile
	return { Coins=Config.StartingCoins, Gems=Config.StartingGems, Inventory={}, Equipped={}, Stats={TotalStolen=0,SuccessfulHeists=0}, Settings={AutoHatch=false}, _Revision=0 }
end
local function clean(raw: any): Profile
	local p=template(); if type(raw)~="table" then return p end
	for _,key in ipairs({"Coins","Gems"}) do local v=raw[key]; if type(v)=="number" and v>=0 and v<1e12 then (p :: any)[key]=math.floor(v) end end
	if type(raw.Inventory)=="table" then
		local count=0
		for id,entry in pairs(raw.Inventory) do
			if Config.Brainrots[id] and type(entry)=="table" and type(entry.Count)=="number" and entry.Count>0 then
				local n=math.min(math.floor(entry.Count),Config.MaxInventoryItems-count)
				if n>0 then p.Inventory[id]={Count=n,Shiny=entry.Shiny==true}; count+=n end
			end
		end
	end
	if type(raw.Equipped)=="table" then
		local seen={}
		for _,id in ipairs(raw.Equipped) do if #p.Equipped>=Config.MaxEquipped then break end; if Config.Brainrots[id] and p.Inventory[id] and not seen[id] then table.insert(p.Equipped,id); seen[id]=true end end
	end
	if type(raw.Stats)=="table" then for _,k in ipairs({"TotalStolen","SuccessfulHeists"}) do local v=raw.Stats[k]; if type(v)=="number" and v>=0 then p.Stats[k]=math.floor(v) end end end
	if type(raw.Settings)=="table" and type(raw.Settings.AutoHatch)=="boolean" then p.Settings.AutoHatch=raw.Settings.AutoHatch end
	p._Revision=type(raw._Revision)=="number" and raw._Revision or 0
	return p
end
local function key(player: Player): string return "User_"..player.UserId end
local function payload(p: Profile): any
	return {SchemaVersion=Config.SchemaVersion,Coins=p.Coins,Gems=p.Gems,Inventory=p.Inventory,Equipped=p.Equipped,Stats=p.Stats,Settings=p.Settings,_Revision=p._Revision+1,_SessionId=sessionId,_Lease=os.time()+Config.SessionLockSeconds}
end
local function retry<T>(label: string, fn: () -> T): (boolean,T?)
	local last: any
	for attempt=1,5 do local ok,result=pcall(fn); if ok then return true,result end; last=result; warn(label.." attempt "..attempt..": "..tostring(result)); task.wait(math.min(2^(attempt-1),8)) end
	return false,last
end

function DataService.Load(player: Player): boolean
	local ok,result=retry("Profile load",function()
		return store:UpdateAsync(key(player),function(old)
			local now=os.time()
			if type(old)=="table" and old._SessionId and old._SessionId~=sessionId and (tonumber(old._Lease) or 0)>now then return old end
			local data=clean(old); data._Revision=tonumber(type(old)=="table" and old._Revision) or 0
			local nextData=payload(data); nextData._Lease=now+Config.SessionLockSeconds; return nextData
		end)
	end)
	if not ok or type(result)~="table" or result._SessionId~=sessionId then return false end
	local p=clean(result); p._Revision=tonumber(result._Revision) or 0; DataService.Profiles[player]=p; return true
end
function DataService.Save(player: Player): boolean
	local p=DataService.Profiles[player]; if not p then return true end
	local expectedRevision=p._Revision
	local ok,result=retry("Profile save",function()
		return store:UpdateAsync(key(player),function(old)
			if type(old)~="table" or old._SessionId~=sessionId then return nil end
			local nextData=payload(p); nextData._Revision=expectedRevision+1; return nextData
		end)
	end)
	if ok and type(result)=="table" and result._SessionId==sessionId then p._Revision=tonumber(result._Revision) or p._Revision+1; return true end
	return false
end
function DataService.Release(player: Player)
	local p=DataService.Profiles[player]; if not p then return end
	DataService.Save(player)
	local ok=retry("Profile release",function() return store:UpdateAsync(key(player),function(old) if type(old)=="table" and old._SessionId==sessionId then old._SessionId=nil; old._Lease=0; return old end; return old end) end)
	if not ok then warn("Could not release profile lock for "..player.Name) end
	DataService.Profiles[player]=nil
end
function DataService.StartAutosave()
	task.spawn(function() while not closing do task.wait(Config.AutosaveSeconds); if closing then break end; for player in pairs(DataService.Profiles) do task.spawn(DataService.Save,player) end end end)
	task.spawn(function() while not closing do task.wait(Config.SessionHeartbeatSeconds); if closing then break end
		for player in pairs(DataService.Profiles) do task.spawn(function()
			retry("Profile heartbeat",function() return store:UpdateAsync(key(player),function(old) if type(old)~="table" or old._SessionId~=sessionId then return nil end; old._Lease=os.time()+Config.SessionLockSeconds; return old end) end)
		end) end
	end end)
end
function DataService.Shutdown()
	closing=true; local remaining=0
	for player in pairs(DataService.Profiles) do remaining+=1; task.spawn(function() DataService.Release(player); remaining-=1 end) end
	local deadline=os.clock()+25; while remaining>0 and os.clock()<deadline do task.wait(.1) end
end
return DataService
