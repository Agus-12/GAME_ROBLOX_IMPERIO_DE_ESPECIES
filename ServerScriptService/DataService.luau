--!strict
-- ===== RONDA: v46 =====   <-- Ctrl+F con este texto para saber si este archivo
--                             es el de la ronda nueva (docs/09-SI-SALE-DOBLE.md)
-- ModuleScript -> ServerScriptService.DataService
-- Guardado con DataStore + perfil en memoria.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local cfgModule = ReplicatedStorage:WaitForChild("GameConfig", 15)
if not cfgModule then
	error("[SpiceEmpire] FALTA ReplicatedStorage.GameConfig. Pegalo en Studio " ..
		"(ver docs/01-INSTALACION.md) y vuelve a dar Play.", 0)
end
local Config = require(cfgModule)

local DataService = {}

local STORE_NAME = "SpiceEmpire_v1"
local store = DataStoreService:GetDataStore(STORE_NAME)

local profiles: {[Player]: any} = {}

local function defaultProfile()
	return {
		Cash = Config.StartingCash,
		-- lo que esta GUARDADO en la caja fuerte de la bodega (a salvo de Aduanas)
		Leaves = 0,
		Blocks = 0,
		-- lo que traes CARGANDO encima (esto si te lo pueden incautar)
		CarryLeaves = 0,
		CarryBlocks = 0,
		Backpack = "",   -- id de la mochila comprada; "" = capacidad base
		Plots = Config.Plots.StartingPlots,
		WarehouseTier = 1,
		PressLevel = Config.Press.StartingLevel,
		Employees = {Harvester = 0, Presser = 0, Guard = 0},
		Vehicles = {},      -- [id] = true
		Properties = {},    -- [id] = true
		Heat = 0,
		TotalEarned = 0,
		CrewId = nil,
		LastPayout = os.time(),
		-- para calcular lo que produjeron tus empleados mientras no estabas
		LastSeen = os.time(),
	}
end

local function deepMerge(target, source)
	for k, v in pairs(source) do
		if target[k] == nil then
			target[k] = v
		elseif type(v) == "table" and type(target[k]) == "table" then
			deepMerge(target[k], v)
		end
	end
	return target
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.Load(player: Player)
	local key = "p_" .. player.UserId
	local data
	local ok, err = pcall(function()
		data = store:GetAsync(key)
	end)
	if not ok then
		warn("[DataService] fallo al cargar", player.Name, err)
	end

	local profile = defaultProfile()
	if type(data) == "table" then
		deepMerge(data, profile)
		profile = data
	end

	profiles[player] = profile
	return profile
end

function DataService.Save(player: Player)
	local profile = profiles[player]
	if not profile then return end
	-- sello de tiempo: al volver, Main calcula lo que produjeron tus
	-- empleados durante tu ausencia a partir de este valor
	profile.LastSeen = os.time()
	if RunService:IsStudio() then
		-- en Studio el DataStore suele estar apagado; no truenes
		local ok = pcall(function()
			store:SetAsync("p_" .. player.UserId, profile)
		end)
		if not ok then return end
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("p_" .. player.UserId, profile)
	end)
	if not ok then
		warn("[DataService] fallo al guardar", player.Name, err)
	end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
end

-- autosave
task.spawn(function()
	while true do
		task.wait(120)
		for player in pairs(profiles) do
			DataService.Save(player)
		end
	end
end)

game:BindToClose(function()
	for player in pairs(profiles) do
		DataService.Save(player)
	end
	task.wait(2)
end)

return DataService
