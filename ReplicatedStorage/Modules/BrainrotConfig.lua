--!strict
-- ModuleScript: ReplicatedStorage/Modules/BrainrotConfig
-- Catálogo compartido para presentación y reglas. Las operaciones se validan en servidor.
local Config = {}

Config.DataStoreName = "BrainrotHeist_Profile_v1"
Config.SchemaVersion = 1
Config.StartingCoins = 250
Config.StartingGems = 0
Config.MaxInventoryItems = 150
Config.MaxEquipped = 6
Config.PassiveTickSeconds = 5
Config.AutosaveSeconds = 60
Config.SessionLockSeconds = 180
Config.SessionHeartbeatSeconds = 45
Config.HatchCooldownSeconds = 1.25
Config.HatchRatePerMinute = 30
Config.HeistHoldSeconds = 4
Config.HeistRange = 14
Config.ExtractionRange = 14
Config.HeistCooldownSeconds = 20
Config.CarryWalkSpeed = 12
Config.ShinyChance = 0.01
Config.ShinyMultiplier = 2

Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Secret" }
Config.Rarities = {
	Common = { DisplayName = "Común", Color = Color3.fromRGB(182, 190, 205) },
	Rare = { DisplayName = "Raro", Color = Color3.fromRGB(81, 205, 255) },
	Epic = { DisplayName = "Épico", Color = Color3.fromRGB(178, 111, 255) },
	Legendary = { DisplayName = "Legendario", Color = Color3.fromRGB(255, 190, 76) },
	Secret = { DisplayName = "Secreto", Color = Color3.fromRGB(255, 83, 166) },
}

Config.Brainrots = {
	NPC = { DisplayName = "NPC de lunes", Rarity = "Common", Income = 1, Multiplier = 1, Icon = "rbxassetid://0", Model = "NPC" },
	CapyCEO = { DisplayName = "Capybara CEO", Rarity = "Rare", Income = 4, Multiplier = 1, Icon = "rbxassetid://0", Model = "CapyCEO" },
	Skibidi = { DisplayName = "Skibidi Turbo", Rarity = "Rare", Income = 6, Multiplier = 1, Icon = "rbxassetid://0", Model = "Skibidi" },
	BrrPatapim = { DisplayName = "Brr Patapim", Rarity = "Epic", Income = 15, Multiplier = 1, Icon = "rbxassetid://0", Model = "BrrPatapim" },
	Tricky = { DisplayName = "Tricky.exe", Rarity = "Epic", Income = 22, Multiplier = 1, Icon = "rbxassetid://0", Model = "Tricky" },
	TungTax = { DisplayName = "Tung Tung Tax", Rarity = "Legendary", Income = 55, Multiplier = 1, Icon = "rbxassetid://0", Model = "TungTax" },
	Tralalero = { DisplayName = "Tralalero Cósmico", Rarity = "Legendary", Income = 90, Multiplier = 1, Icon = "rbxassetid://0", Model = "Tralalero" },
	ElmoExe = { DisplayName = "Elmo.exe", Rarity = "Secret", Income = 250, Multiplier = 1, Icon = "rbxassetid://0", Model = "ElmoExe" },
}

-- Los pesos se normalizan en HatchingService. En los huevos estándar reflejan
-- aproximadamente Common 60%, Rare 25%, Epic 10%, Legendary 4.8%, Secret 0.2%.
Config.Eggs = {
	HuevoComun = { DisplayName = "Huevo Común", Currency = "Coins", Cost = 100, Drops = {
		{ Id = "NPC", Weight = 60 }, { Id = "CapyCEO", Weight = 15 }, { Id = "Skibidi", Weight = 10 },
		{ Id = "BrrPatapim", Weight = 8 }, { Id = "Tricky", Weight = 2 }, { Id = "TungTax", Weight = 4.8 }, { Id = "ElmoExe", Weight = 0.2 },
	} },
	HuevoCursed = { DisplayName = "Huevo Cursed Legendario", Currency = "Gems", Cost = 25, Drops = {
		{ Id = "BrrPatapim", Weight = 45 }, { Id = "Tricky", Weight = 25 }, { Id = "TungTax", Weight = 20 }, { Id = "Tralalero", Weight = 9 }, { Id = "ElmoExe", Weight = 1 },
	} },
	HuevoAlpha = { DisplayName = "Huevo Alpha Brainrot", Currency = "Coins", Cost = 2500, Drops = {
		{ Id = "Skibidi", Weight = 20 }, { Id = "BrrPatapim", Weight = 30 }, { Id = "TungTax", Weight = 30 }, { Id = "Tralalero", Weight = 18 }, { Id = "ElmoExe", Weight = 2 },
	} },
}

return Config
