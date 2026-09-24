--!strict
-- ModuleScript -> ServerScriptService.DataService
-- Guardado con DataStore + perfil en memoria.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

local DataService = {}

local STORE_NAME = "SpiceEmpire_v1"
local store = DataStoreService:GetDataStore(STORE_NAME)

local profiles: {[Player]: any} = {}

local function defaultProfile()
	return {
		Cash = Config.StartingCash,
		Leaves = 0,
		Blocks = 0,
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
