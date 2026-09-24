--!strict
-- Script (normal) -> ServerScriptService.Main
-- Nucleo del servidor: mapa, bodegas, produccion, venta, heat, aduanas,
-- asaltos, crews y PvP.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Si falta un script, 'WaitForChild' se queda esperando PARA SIEMPRE y el
-- servidor nunca arranca: nada de remotes, nada de bodegas, nada. El jugador
-- ve una pantalla muerta y en la consola no sale ni un error. Con timeout el
-- mensaje dice exactamente QUE script hay que pegar.
local function need(parent: Instance, name: string): any
	local m = parent:WaitForChild(name, 15)
	if not m then
		error("[SpiceEmpire] FALTA " .. parent.Name .. "." .. name ..
			". Pegalo en Studio (ver docs/01-INSTALACION.md) y vuelve a dar Play.", 0)
	end
	return m
end

local Config = require(need(ReplicatedStorage, "GameConfig"))
local CityGenerator = require(need(ServerScriptService, "CityGenerator"))
local DataService = require(need(ServerScriptService, "DataService"))

----------------------------------------------------------------------
-- REMOTES
----------------------------------------------------------------------
local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local function mkEvent(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = Remotes
	return r
end
local function mkFunc(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction")
	r.Name = name
	r.Parent = Remotes
	return r
end

local RE_State   = mkEvent("StateUpdate")     -- server -> client, perfil
local RE_Phone   = mkEvent("PhoneAlert")      -- server -> client, alertas
local RE_Toast   = mkEvent("Toast")           -- server -> client, mensajitos
local RE_Mission = mkEvent("MissionUpdate")    -- server -> client, encargo activo
local RE_OpenUp  = mkEvent("OpenUpgrades")     -- server -> client, abrir panel de mejoras
local RE_Sfx     = mkEvent("Sfx")              -- server -> client, efecto de sonido
local RE_OpenVault = mkEvent("OpenVault")      -- server -> client, abrir la caja fuerte
local RE_Shoot   = mkEvent("Shoot")            -- client -> server, disparo
local RE_Terr    = mkEvent("TerritoryUpdate")  -- server -> todos, estado de territorios
local RF_Action  = mkFunc("Action")           -- client -> server, todo lo demas
-- OJO: IncomingCall se creaba 1700 lineas mas abajo. Si cualquier cosa
-- fallaba antes de esa linea, el cliente se quedaba esperando este remote
-- para siempre (y con el, TODA la interfaz). Se crea aqui con los demas.
local RE_Call    = mkEvent("IncomingCall")    -- server -> client, te llama un cliente

-- ===== SELLO DE VERSION =====
-- El cliente lee este atributo y lo compara con el suyo: si el servidor que
-- corre es de OTRA ronda, sale un cartel en pantalla diciendo que archivo
-- quedo viejo. Paso de verdad: cliente v28 con un Main.luau de la v20 pegado
-- -> el usuario solo veia "faltan remotes" y no sabia que pegar.
Remotes:SetAttribute("Build", Config.Build or "?")
print("========== IMPERIO DE ESPECIAS " .. tostring(Config.Build) .. " ==========")
print("  remotes creados: " .. #Remotes:GetChildren())
if Config.Build == nil then
	warn("[SpiceEmpire] Tu GameConfig NO trae numero de version: es VIEJO. Pega el GameConfig de esta ronda.")
end

----------------------------------------------------------------------
-- MAPA
----------------------------------------------------------------------
-- La generacion del mapa va protegida: si algo truena aqui, el resto del
-- juego (perfiles, dinero, tienda) DEBE seguir funcionando igual.
local city
do
	local ok, result = pcall(CityGenerator.Build)
	if ok then
		city = result
		print("[SpiceEmpire] Ciudad generada.")
	else
		warn("[SpiceEmpire] ERROR generando la ciudad: " .. tostring(result))
		-- carpeta vacia de respaldo para que nada mas falle
		city = Workspace:FindFirstChild("City") or Instance.new("Folder")
		city.Name = "City"
		city.Parent = Workspace
		if not city:FindFirstChild("Buyers") then
			local b = Instance.new("Folder")
			b.Name = "Buyers"
			b.Parent = city
		end
	end
end

local warehouses: {[Player]: Model} = {}
local warehouseSlots: {[number]: Player?} = {}

-- ===== LOTES DE BODEGA =====
-- Rejilla de lotes detras de la ciudad. Antes era UNA fila con 140 studs de
-- separacion... pero una bodega de nivel 4 mide 190 de ancho MAS 46 del
-- taller MAS 34 de la oficina = 271. O sea que la oficina de uno se metia
-- dentro del taller del vecino y el taller tapaba la puerta de la oficina.
-- La rejilla (5 por fila) y el espaciado viven en GameConfig.WarehouseLots,
-- y CityGenerator.buildGround estira el suelo con esos mismos numeros.
local LOTS = Config.WarehouseLots
local WAREHOUSE_ORIGIN = LOTS.Origin
local WAREHOUSE_PER_ROW = math.max(1, LOTS.PerRow)
local WAREHOUSE_MAX_SLOTS = math.max(WAREHOUSE_PER_ROW, LOTS.MaxSlots)

local function warehouseSlotPos(slot: number): Vector3
	local col = (slot - 1) % WAREHOUSE_PER_ROW
	local row = math.floor((slot - 1) / WAREHOUSE_PER_ROW)
	return WAREHOUSE_ORIGIN + Vector3.new(col * LOTS.SpacingX, 0, -row * LOTS.SpacingZ)
end

-- definidas mas abajo (sistema de plantas / porton / empleados)
local initPlants
local setupGate
local syncWorkers
local syncWorkersInner
local syncGarage
local applyOfflineProduction
local giveWeapon
local territoryBonus

-- estado de encargos y llamadas (se declara aqui arriba porque
-- PlayerRemoving lo limpia antes de que se definan las funciones)
local activeMission: {[Player]: any} = {}
local missionCooldown: {[Player]: number} = {}
local pendingCall: {[Player]: any} = {}
local nextCallAt: {[Player]: number} = {}

local warnedCityGen = false

local function assignWarehouse(player: Player): Model
	local slot
	for i = 1, WAREHOUSE_MAX_SLOTS do
		if warehouseSlots[i] == nil then
			slot = i
			break
		end
	end
	slot = slot or 1
	warehouseSlots[slot] = player

	local profile = DataService.Get(player)
	local tier = (profile and profile.WarehouseTier) or 1

	local clone = CityGenerator.BuildWarehouse(tier)
	clone.Name = "Warehouse_" .. player.UserId
	clone:SetAttribute("OwnerId", player.UserId)
	clone:PivotTo(CFrame.new(warehouseSlotPos(slot)))
	clone.Parent = Workspace

	-- ¿el CityGenerator es de esta ronda? La rampa del porton (GateApron) llego
	-- en la v28. Si no esta, hay un CityGenerator viejo pegado: se avisa una vez.
	if not warnedCityGen and not clone:FindFirstChild("GateApron", true) then
		warnedCityGen = true
		warn("[SpiceEmpire] CityGenerator VIEJO: la bodega no trae la rampa GateApron. Pega el CityGenerator de esta ronda.")
	end

	-- letrero con el nombre
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.new(0, 260, 0, 50)
	sign.StudsOffset = Vector3.new(0, 30, 0)
	sign.AlwaysOnTop = false
	sign.MaxDistance = 500
	sign.LightInfluence = 0
	sign.Parent = clone.PrimaryPart
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 220, 140)
	lbl.TextStrokeTransparency = 0.3
	lbl.Text = "BODEGA DE " .. string.upper(player.Name)
	lbl.Parent = sign

	warehouses[player] = clone
	if initPlants then pcall(initPlants, clone) end
	if setupGate then pcall(setupGate, clone) end
	return clone
end

local function releaseWarehouse(player: Player)
	local w = warehouses[player]
	if w then w:Destroy() end
	warehouses[player] = nil
	for i, p in pairs(warehouseSlots) do
		if p == player then warehouseSlots[i] = nil end
	end
end

----------------------------------------------------------------------
-- ESTADO / SYNC
----------------------------------------------------------------------
local crews: {[string]: {Name: string, Owner: number, Members: {number}}} = {}

-- ===== DOS ALMACENES DISTINTOS =====
-- MOCHILA: lo que traes encima. Aqui cae lo que cosechas y prensas TU,
--          y es lo unico que te puede quitar Aduanas. Tope compartido.
-- CAJA FUERTE: el banco de la bodega. Tope SEPARADO por producto.
--          Solo se llena depositando tu, o con tus empleados.

local function vaultLeafCap(profile): number
	local T = Config.WarehouseTiers[profile.WarehouseTier or 1]
	local cap = (T and T.VaultLeaves) or Config.BaseStorage
	for id in pairs(profile.Properties) do
		for _, p in ipairs(Config.Properties) do
			if p.Id == id then cap += p.Storage end
		end
	end
	return cap
end

local function vaultBlockCap(profile): number
	local T = Config.WarehouseTiers[profile.WarehouseTier or 1]
	local cap = (T and T.VaultBlocks) or math.floor(Config.BaseStorage / 2)
	for id in pairs(profile.Properties) do
		for _, p in ipairs(Config.Properties) do
			if p.Id == id then cap += math.floor(p.Storage / 2) end
		end
	end
	return cap
end

local function storageCap(profile): number
	-- total informativo (hojas + bloques), solo para textos
	return vaultLeafCap(profile) + vaultBlockCap(profile)
end

-- ===== LA COMPUTADORA DEL ESCRITORIO =====
-- Escribe en la pantalla del monitor el estado real de la bodega.
local function updateWarehouseScreen(player: Player, profile)
	local model = warehouses[player]
	if not model then return end
	local screen = model:FindFirstChild("UpgradeScreen", true)
	if not screen then return end
	local gui = screen:FindFirstChild("ScreenGui")
	if not gui then return end
	local title = gui:FindFirstChild("ScreenTitle")
	local body = gui:FindFirstChild("ScreenBody")
	if not (title and body) then return end

	local cur = profile.WarehouseTier or 1
	local T = Config.WarehouseTiers[cur]
	local nextT = Config.WarehouseTiers[cur + 1]

	title.Text = "BODEGA  -  NIVEL " .. cur .. "/" .. #Config.WarehouseTiers

	if not nextT then
		-- OJO: aqui estaba 'T.StorageBonus', un campo que se quito de la
		-- config en la v22. En Lua eso no truena al compilar: da nil, y
		-- nil + numero revienta EN EJECUCION. Como esta funcion se llama
		-- dentro de un pcall, el error se tragaba en silencio y la pantalla
		-- de la bodega se quedaba congelada. Los topes reales son
		-- VaultLeaves / VaultBlocks.
		body.Text = string.format(
			"%s\n\nNIVEL MAXIMO ALCANZADO.\n\nCaja fuerte: %d hojas / %d bloques",
			T.Name, T.VaultLeaves, T.VaultBlocks)
		body.TextColor3 = Color3.fromRGB(150, 255, 190)
		return
	end

	local falta = nextT.Cost - profile.Cash
	if falta <= 0 then
		body.Text = string.format(
			"Actual: %s\n\nSIGUIENTE: %s\nCosto: $%s\n\nYA PUEDES MEJORAR.\nParate en el tapete.",
			T.Name, nextT.Name, Config.Abbrev(nextT.Cost))
		body.TextColor3 = Color3.fromRGB(150, 255, 190)
	else
		body.Text = string.format(
			"Actual: %s\n\nSIGUIENTE: %s\nCosto: $%s\n\nTe faltan $%s",
			T.Name, nextT.Name, Config.Abbrev(nextT.Cost), Config.Abbrev(falta))
		body.TextColor3 = Color3.fromRGB(150, 220, 255)
	end
end

-- ===== CARGA DEL JUGADOR =====
-- Cuanto puede traer encima (segun la mochila comprada)
local function carryCap(profile): number
	local cap = Config.Carry.BaseCapacity
	for _, b in ipairs(Config.Carry.Backpacks) do
		if b.Id == profile.Backpack then cap = b.Capacity end
	end
	return cap
end

local function carried(profile): number
	return (profile.CarryLeaves or 0) + (profile.CarryBlocks or 0)
end

-- nombre de la mochila actual, para la UI
local function backpackName(profile): string
	for _, b in ipairs(Config.Carry.Backpacks) do
		if b.Id == profile.Backpack then return b.Name end
	end
	return "Bolsillos"
end

-- pantallita de la caja fuerte
local function updateVaultScreen(player: Player, profile)
	local model = warehouses[player]
	if not model then return end
	local screen = model:FindFirstChild("VaultScreen", true)
	local gui = screen and screen:FindFirstChild("ScreenGui")
	local txt = gui and gui:FindFirstChild("VaultText")
	if not txt then return end

	txt.Text = string.format("CAJA FUERTE\nHojas  %d / %d\nBloques  %d / %d",
		profile.Leaves or 0, vaultLeafCap(profile),
		profile.Blocks or 0, vaultBlockCap(profile))
end

local function push(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	local crewName = nil
	if profile.CrewId and crews[profile.CrewId] then
		crewName = crews[profile.CrewId].Name
	end
	RE_State:FireClient(player, {
		Cash = profile.Cash,
		Leaves = profile.Leaves,
		Blocks = profile.Blocks,
		Plots = profile.Plots,
		PressLevel = profile.PressLevel,
		Employees = profile.Employees,
		Vehicles = profile.Vehicles,
		Properties = profile.Properties,
		Heat = profile.Heat,
		TotalEarned = profile.TotalEarned,
		Storage = storageCap(profile),
		WarehouseTier = profile.WarehouseTier or 1,
		CarryLeaves = profile.CarryLeaves or 0,
		CarryBlocks = profile.CarryBlocks or 0,
		CarryCap = carryCap(profile),
		VaultLeafCap = vaultLeafCap(profile),
		VaultBlockCap = vaultBlockCap(profile),
		Backpack = profile.Backpack or "",
		BackpackName = backpackName(profile),
		CrewName = crewName,
		Wanted = profile.Heat >= Config.Heat.ArrestThreshold,
	})
	pcall(updateWarehouseScreen, player, profile)
	pcall(updateVaultScreen, player, profile)
end

local function toast(player: Player, text: string, kind: string?)
	RE_Toast:FireClient(player, text, kind or "info")
end

-- pide al cliente que suene un efecto (los IDs viven en GameConfig.Sounds)
local function sfx(player: Player, key: string)
	RE_Sfx:FireClient(player, key)
end

local function alert(player: Player, title: string, body: string, kind: string?)
	RE_Phone:FireClient(player, {Title = title, Body = body, Kind = kind or "info", Time = os.time()})
end

----------------------------------------------------------------------
-- LEADERBOARD
----------------------------------------------------------------------
local function setupLeaderstats(player: Player, profile)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Efectivo"
	cash.Value = profile.Cash
	cash.Parent = ls

	local heat = Instance.new("IntValue")
	heat.Name = "Heat"
	heat.Value = math.floor(profile.Heat)
	heat.Parent = ls
end

local function syncLeaderstats(player: Player)
	local profile = DataService.Get(player)
	local ls = player:FindFirstChild("leaderstats")
	if not profile or not ls then return end
	local c = ls:FindFirstChild("Efectivo") :: IntValue?
	local h = ls:FindFirstChild("Heat") :: IntValue?
	if c then c.Value = math.floor(profile.Cash) end
	if h then h.Value = math.floor(profile.Heat) end
end

----------------------------------------------------------------------
-- JOIN / LEAVE
----------------------------------------------------------------------
-- declaradas arriba, se definen mas abajo
local onCharacter
local spawnBike

local setupDone: {[Player]: boolean} = {}

local function setupPlayer(player: Player)
	if setupDone[player] then return end
	setupDone[player] = true

	local profile = DataService.Load(player)
	setupLeaderstats(player, profile)
	local wh = assignWarehouse(player)
	if syncWorkers then pcall(syncWorkers, player) end
	if syncGarage then pcall(syncGarage, player) end
	task.spawn(function()
		task.wait(1.5)   -- dejar que cargue todo antes de avisarle
		pcall(applyOfflineProduction, player)
	end)

	-- el arma: se repone en cada respawn
	player.CharacterAdded:Connect(function()
		task.wait(0.6)
		pcall(giveWeapon, player)
	end)
	task.spawn(function()
		task.wait(1)
		pcall(giveWeapon, player)
	end)

	local function placeInWarehouse(char: Model)
		task.wait(0.4)
		local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
		if hrp and wh and wh.PrimaryPart then
			(hrp :: BasePart).CFrame = wh.PrimaryPart.CFrame + Vector3.new(0, 6, 0)
		end
		-- bici gratis para explorar el mapa
		task.wait(0.6)
		if spawnBike then pcall(spawnBike, player) end
	end

	player.CharacterAdded:Connect(function(char)
		placeInWarehouse(char)
		if onCharacter then onCharacter(player, char) end
	end)

	-- si el personaje YA existe (pasa en Studio: el player entra antes
	-- de que termine de generarse la ciudad), atiendelo tambien
	if player.Character then
		task.spawn(placeInWarehouse, player.Character)
		if onCharacter then onCharacter(player, player.Character) end
	end

	task.wait(0.3)
	push(player)
	alert(player, "Bienvenido", "Tu bodega esta lista. Cosecha hojas, prensalas y vendelas en la ciudad. Ojo con el Heat.", "info")
end

Players.PlayerAdded:Connect(setupPlayer)

-- jugadores que ya estaban en el servidor cuando arranco este script
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, p)
end

Players.PlayerRemoving:Connect(function(player)
	setupDone[player] = nil
	activeMission[player] = nil
	missionCooldown[player] = nil
	pendingCall[player] = nil
	nextCallAt[player] = nil
	releaseWarehouse(player)
	DataService.Release(player)
end)

----------------------------------------------------------------------
-- PRODUCCION
----------------------------------------------------------------------
-- Lo que cosechas TU cae en tu mochila, no en la caja.
local function addLeaves(player: Player, amount: number): number
	local profile = DataService.Get(player)
	if not profile then return 0 end
	local space = math.max(0, carryCap(profile) - carried(profile))
	local added = math.min(amount, space)
	profile.CarryLeaves = (profile.CarryLeaves or 0) + added
	return added
end

-- Lo que cosechan tus EMPLEADOS va directo a la caja fuerte.
local function addLeavesToVault(player: Player, amount: number): number
	local profile = DataService.Get(player)
	if not profile then return 0 end
	local space = math.max(0, vaultLeafCap(profile) - (profile.Leaves or 0))
	local added = math.min(amount, space)
	profile.Leaves = (profile.Leaves or 0) + added
	return added
end

local harvestCooldown: {[Player]: number} = {}

----------------------------------------------------------------------
-- CRECIMIENTO DE PLANTAS (individual, cada maceta su propio estado)
----------------------------------------------------------------------
local G = Config.Growth

-- aspecto de una planta segun cuanto ha crecido (0 = recien cortada, 1 = lista)
local function applyPlantVisual(plant: Model, g: number)
	local ripe = g >= 1
	local stageIdx = math.clamp(math.floor(g * #G.StageColors) + 1, 1, #G.StageColors)
	local col = G.StageColors[stageIdx]

	for _, d in ipairs(plant:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "Leaf" then
			local fx = d:GetAttribute("FullX") or 1
			local fy = d:GetAttribute("FullY") or 0.28
			local scale = 0.15 + 0.85 * g
			d.Size = Vector3.new(fx * scale, fy * math.max(0.4, scale), fx * scale)
			d.Color = col
			d.Transparency = (g < 0.06) and 0.5 or 0
		elseif d:IsA("BasePart") and d.Name == "Stem" then
			d.Size = Vector3.new(0.22, 0.5 + 1.3 * g, 0.22)
		elseif d:IsA("BasePart") and d.Name == "RipeGlow" then
			d.Transparency = ripe and 0.25 or 1
			local l = d:FindFirstChild("RipeLight")
			if l and l:IsA("PointLight") then
				l.Brightness = ripe and 1.1 or 0
			end
		end
	end
	plant:SetAttribute("Growth", g)
	plant:SetAttribute("Ripe", ripe)
end

local function eachPlant(wh: Model, fn)
	local plots = wh and wh:FindFirstChild("Plots")
	if not plots then return end
	for _, d in ipairs(plots:GetChildren()) do
		if d:IsA("Model") and d.Name == "Plant" then fn(d) end
	end
end

-- arranca las plantas escalonadas para que no maduren todas al mismo tiempo
function initPlants(wh: Model)
	local n = 0
	eachPlant(wh, function(plant)
		n += 1
		local start = (n <= 6) and (0.55 + (n % 3) * 0.14) or (n % 10) / 14
		start = math.clamp(start, 0, 0.97)
		plant:SetAttribute("PlantedAt", os.clock() - start * G.TimePerPlant)
		applyPlantVisual(plant, start)
	end)
end

-- reloj de crecimiento
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, wh in pairs(warehouses) do
			if wh and wh.Parent then
				eachPlant(wh, function(plant)
					if plant:GetAttribute("Ripe") then return end
					local at = plant:GetAttribute("PlantedAt")
					if not at then
						plant:SetAttribute("PlantedAt", now)
						return
					end
					local g = math.clamp((now - at) / G.TimePerPlant, 0, 1)
					applyPlantVisual(plant, g)
				end)
			end
		end
	end
end)

----------------------------------------------------------------------
-- PORTON AUTOMATICO DE LA BODEGA
----------------------------------------------------------------------
function setupGate(wh: Model)
	local gate = wh:FindFirstChild("Gate")
	local sensor = wh:FindFirstChild("GateSensor")
	if not gate or not sensor or not sensor:IsA("BasePart") then return end

	local leaves = {}
	for _, d in ipairs(gate:GetChildren()) do
		if d:IsA("BasePart") and (d.Name == "GateLeft" or d.Name == "GateRight") then
			table.insert(leaves, d)
		end
	end
	if #leaves == 0 then return end

	local isOpen = false

	-- version simple y confiable: guardamos la posicion cerrada real
	for _, leaf in ipairs(leaves) do
		leaf:SetAttribute("HomeX", leaf.Position.X)
	end

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function move(open: boolean)
		for _, leaf in ipairs(leaves) do
			local homeX = leaf:GetAttribute("HomeX")
			local closedX = leaf:GetAttribute("ClosedX") or 0
			local openX = leaf:GetAttribute("OpenX") or 0
			if homeX then
				local delta = open and (openX - closedX) or 0
				local targetX = homeX + delta
				local target = CFrame.new(targetX, leaf.Position.Y, leaf.Position.Z)

				pcall(function()
					TweenService:Create(leaf, info, {CFrame = target}):Play()
				end)

				-- mover tambien las nervaduras: van sueltas, no soldadas
				local ribs = leaf:FindFirstChild("Ribs")
				if ribs then
					for _, rib in ipairs(ribs:GetChildren()) do
						if rib:IsA("BasePart") then
							local ox = rib:GetAttribute("OffX") or 0
							local oy = rib:GetAttribute("OffY") or 0
							local oz = rib:GetAttribute("OffZ") or 0
							pcall(function()
								TweenService:Create(rib, info, {
									CFrame = CFrame.new(targetX + ox,
										leaf.Position.Y + oy, leaf.Position.Z + oz),
								}):Play()
							end)
						end
					end
				end
			end
		end
	end

	task.spawn(function()
		while wh.Parent do
			task.wait(0.4)
			local anyNear = false
			for _, pl in ipairs(Players:GetPlayers()) do
				local ch = pl.Character
				local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
				if hrp and hrp:IsA("BasePart") then
					-- el sensor ya es una caja del tamano del hueco: se mide
					-- contra su propia area (antes era un radio de 26 a ojo)
					local dx = math.abs(hrp.Position.X - sensor.Position.X)
					local dz = math.abs(hrp.Position.Z - sensor.Position.Z)
					if dx <= sensor.Size.X * 0.5 + 4 and dz <= sensor.Size.Z * 0.5 + 6 then
						anyNear = true
						break
					end
				end
			end
			if anyNear ~= isOpen then
				isOpen = anyNear
				move(anyNear)
			end
		end
	end)
end

local function doHarvest(player: Player)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false, "sin personaje" end

	local wh = warehouses[player]
	if not wh then return false, "sin bodega" end

	-- Se cosecha POR MESA. Antes se medía la distancia maceta por maceta y
	-- las del fondo de la mesa quedaban fuera del radio, asi que parado
	-- justo enfrente te decia "acercate a una mesa con plantas listas".
	local plots = wh:FindFirstChild("Plots")
	local bestPlot, bestD = nil, math.huge
	if plots then
		for _, d in ipairs(plots:GetChildren()) do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 4) == "Plot" then
				local dist = (d.Position - hrp.Position).Magnitude
				if dist < bestD then bestPlot, bestD = d, dist end
			end
		end
	end

	if not bestPlot or bestD > G.HarvestRadius then
		return false, "Acercate a una mesa de cultivo"
	end

	local myIdx = bestPlot:GetAttribute("PlotIndex")
	local ripeNear = {}
	eachPlant(wh, function(plant)
		if plant:GetAttribute("Ripe") and plant:GetAttribute("PlotIndex") == myIdx then
			table.insert(ripeNear, plant)
		end
	end)

	if #ripeNear == 0 then
		return false, "Esta mesa no tiene nada listo todavia"
	end

	local total = #ripeNear * G.LeavesPerPlant
	local added = addLeaves(player, total)
	if added == 0 then
		return false, "Tu mochila va llena. Guarda en la caja fuerte o compra una mochila mas grande"
	end

	local harvested = math.min(#ripeNear, math.max(1, math.ceil(added / G.LeavesPerPlant)))
	local now = os.clock()

	for k = 1, harvested do
		local plant = ripeNear[k]
		plant:SetAttribute("PlantedAt", now)
		plant:SetAttribute("Ripe", false)

		task.spawn(function()
			local pp = plant.PrimaryPart
			if pp then
				local flash = Instance.new("PointLight")
				flash.Color = Color3.fromRGB(150, 255, 170)
				flash.Brightness = 4
				flash.Range = 9
				flash.Parent = pp
				task.delay(0.35, function() flash:Destroy() end)
			end
			for _, d in ipairs(plant:GetChildren()) do
				if d:IsA("BasePart") and d.Name == "Leaf" then
					pcall(function()
						TweenService:Create(d,
							TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In),
							{Size = Vector3.new(0.12, 0.08, 0.12)}):Play()
					end)
				end
			end
			task.wait(0.3)
			applyPlantVisual(plant, 0)
		end)
	end

	push(player)
	return true, string.format("+%d hojas (%d plantas)", added, harvested)
end

local function doPress(player: Player)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end

	-- Tienes que estar FRENTE A LA MAQUINA. Antes se podia prensar desde
	-- cualquier punto del mapa, lo cual hacia que la prensa fuera un adorno.
	local wh0 = warehouses[player]
	local press = wh0 and wh0:FindFirstChild("PressBase", true)
	local char0 = player.Character
	local hrp0 = char0 and char0:FindFirstChild("HumanoidRootPart")
	if press and hrp0 then
		local d = (hrp0.Position - press.Position).Magnitude
		if d > (Config.Press.UseRadius or 14) then
			return false, "Acercate a la prensa para poder prensar"
		end
	end

	local cost = Config.Products.Block.PressCost
	local output = Config.Press.OutputPerLevel * profile.PressLevel
	local needed = cost * output

	-- Prensas lo que traes ENCIMA, no lo de la caja. La caja es el banco.
	local have = profile.CarryLeaves or 0
	if have < needed then
		return false, string.format("Necesitas %d hojas encima (traes %d)", needed, have)
	end

	profile.CarryLeaves = have - needed
	profile.CarryBlocks = (profile.CarryBlocks or 0) + output

	-- animar el piston de la prensa
	local wh = warehouses[player]
	local piston = wh and wh:FindFirstChild("Piston")
	-- El "Pressing" evita que dos prensadas encimadas se peleen por el
	-- tween. Sin esto, la segunda leia la posicion ya hundida como si
	-- fuera la de reposo y el piston se quedaba abajo para siempre.
	if piston and piston:IsA("BasePart") and not piston:GetAttribute("Pressing") then
		piston:SetAttribute("Pressing", true)
		task.spawn(function()
			-- altura de reposo fija, grabada al construir la bodega
			local homeY = piston:GetAttribute("HomeY") or piston.Position.Y
			local top = Vector3.new(piston.Position.X, homeY, piston.Position.Z)
			local down = top - Vector3.new(0, 3.2, 0)
			pcall(function()
				TweenService:Create(piston, TweenInfo.new(0.18, Enum.EasingStyle.Quad,
					Enum.EasingDirection.In), {Position = down}):Play()
			end)
			task.wait(0.22)
			local flash = Instance.new("PointLight")
			flash.Color = Color3.fromRGB(255, 170, 80)
			flash.Brightness = 5
			flash.Range = 22
			flash.Parent = piston
			task.delay(0.25, function() flash:Destroy() end)
			task.wait(0.15)
			pcall(function()
				TweenService:Create(piston, TweenInfo.new(0.5, Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out), {Position = top}):Play()
			end)
			task.wait(0.55)
			-- por si el tween se interrumpio, lo dejamos exacto en su sitio
			piston.Position = top
			piston:SetAttribute("Pressing", false)
		end)
	end

	push(player)
	return true, string.format("Prensaste %d bloque(s)", output)
end

----------------------------------------------------------------------
-- VENTA + HEAT
----------------------------------------------------------------------
local function findBuyer(id: string)
	for _, b in ipairs(Config.Buyers) do
		if b.Id == id then return b end
	end
	return nil
end

-- definida mas abajo (sistema de encargos)
local checkMissionOnSell

local function doSell(player: Player, buyerId: string)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end

	local buyer = findBuyer(buyerId)
	if not buyer then return false, "comprador invalido" end

	-- valida distancia real al pad
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false, "sin personaje" end

	local pad = city:FindFirstChild("Buyers") and city.Buyers:FindFirstChild(buyerId)
	if not pad then return false, "comprador no existe" end
	if (hrp.Position - (pad :: BasePart).Position).Magnitude > 28 then
		return false, "Estas muy lejos del comprador"
	end

	-- Se vende lo que traes CARGANDO, no lo que tienes guardado en la caja.
	local cl = profile.CarryLeaves or 0
	local cb = profile.CarryBlocks or 0
	if cl <= 0 and cb <= 0 then
		return false, "No traes nada encima. Saca producto de tu caja fuerte"
	end

	-- si tu crew domina esta plaza, te pagan mejor
	local terrBonus = territoryBonus and territoryBonus(player, buyerId) or 0
	local mult = buyer.PriceMult * (1 + terrBonus)

	local leafValue = cl * Config.Products.Leaf.BasePrice * mult
	local blockValue = cb * Config.Products.Block.BasePrice * mult
	local total = math.floor(leafValue + blockValue)

	local heatGain = (cl * Config.Heat.PerLeafSold
		+ cb * Config.Heat.PerBlockSold) * buyer.HeatMult

	local soldL, soldB = cl, cb
	profile.CarryLeaves = 0
	profile.CarryBlocks = 0

	-- bono si esta venta completa un encargo
	local bonus = checkMissionOnSell and checkMissionOnSell(player, buyerId, soldL, soldB) or 0
	total += bonus

	profile.Cash += total
	profile.TotalEarned += total
	profile.Heat = math.min(Config.Heat.Max, profile.Heat + heatGain)

	push(player)
	syncLeaderstats(player)

	if profile.Heat >= Config.Heat.ArrestThreshold then
		alert(player, "ALERTA", "La Unidad de Aduanas te tiene fichado. Escondete en tu Zona Segura.", "danger")
	end

	local extra = (terrBonus > 0)
		and string.format(" [+%d%% plaza propia]", math.floor(terrBonus * 100)) or ""
	return true, string.format("Vendiste %d hojas y %d bloques en %s por $%s%s (+%.0f heat)",
		soldL, soldB, buyer.Name, Config.Abbrev(total), extra, heatGain)
end

----------------------------------------------------------------------
-- ADUANAS (policia)
----------------------------------------------------------------------
local function arrest(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end

	sfx(player, "Arrest")

	-- Solo te pueden quitar lo que traes ENCIMA. Lo que esta guardado en la
	-- caja fuerte de la bodega no lo tocan: para eso existe la caja.
	local fine = math.floor(profile.Cash * Config.Heat.FineRate)
	local lostL = math.floor((profile.CarryLeaves or 0) * Config.Heat.ConfiscatePercent)
	local lostB = math.floor((profile.CarryBlocks or 0) * Config.Heat.ConfiscatePercent)

	profile.Cash -= fine
	profile.CarryLeaves = (profile.CarryLeaves or 0) - lostL
	profile.CarryBlocks = (profile.CarryBlocks or 0) - lostB
	profile.Heat = 0

	local station = city:FindFirstChild("CustomsStation")
	local jail = station and station:FindFirstChild("JailSpawn") :: BasePart?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if jail and hrp then
		hrp.CFrame = jail.CFrame + Vector3.new(0, 5, 0)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 0
			task.delay(Config.Heat.JailTime, function()
				if hum and hum.Parent then hum.WalkSpeed = 16 end
			end)
		end
	end

	push(player)
	syncLeaderstats(player)
	alert(player, "DETENIDO", string.format("Multa de $%s y decomiso de %d hojas / %d bloques. %ds en la celda.",
		Config.Abbrev(fine), lostL, lostB, Config.Heat.JailTime), "danger")
end

-- loop de heat
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			if not profile then continue end

			local decay = Config.Heat.DecayPerSecond

			-- si esta parado en su SafePad, baja mas rapido
			local wh = warehouses[player]
			local safe = wh and wh:FindFirstChild("SafePad") :: BasePart?
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- Antes era un radio fijo de 14 studs y el tapete mide 28x11: las
			-- esquinas del tapete quedaban FUERA de la zona segura, aunque se
			-- vieran dentro. Ahora se mide contra el tapete de verdad.
			if safe and hrp then
				local dx = math.abs(hrp.Position.X - safe.Position.X)
				local dz = math.abs(hrp.Position.Z - safe.Position.Z)
				if dx <= safe.Size.X * 0.5 + 1 and dz <= safe.Size.Z * 0.5 + 1 then
					decay = Config.Heat.LayLowRate
				end
			end

			if profile.Heat > 0 then
				profile.Heat = math.max(0, profile.Heat - decay)
			end

			-- persecucion
			if profile.Heat >= Config.Heat.ArrestThreshold then
				local roll = (profile.Heat - Config.Heat.ArrestThreshold) / (Config.Heat.Max - Config.Heat.ArrestThreshold)
				if math.random() < roll * 0.035 then
					arrest(player)
				end
			end

			syncLeaderstats(player)
		end
	end
end)

----------------------------------------------------------------------
-- EMPLEADOS FISICOS
----------------------------------------------------------------------
-- Antes los empleados eran puros numeros: contratabas y aparecian hojas
-- de la nada. Ahora existen de verdad: cada cosechador se para en SU mesa
-- y corta unicamente las plantas maduras de esa mesa. Si la mesa no tiene
-- nada listo, ese cosechador no produce.

local workerModels: {[Player]: {any}} = {}

-- cuantas mesas tiene tu bodega en este nivel
local function tableCount(profile): number
	local T = Config.WarehouseTiers[profile.WarehouseTier or 1]
	return T and T.Plots or 0
end

-- posicion de la mesa numero idx dentro de la bodega
local function plotPart(wh: Model, idx: number): BasePart?
	local plots = wh and wh:FindFirstChild("Plots")
	if not plots then return nil end
	local p = plots:FindFirstChild("Plot" .. idx)
	return (p and p:IsA("BasePart")) and p or nil
end

-- Borra y vuelve a poner los NPCs para que coincidan con lo contratado.
-- Candado: crear un rig cede el hilo, asi que dos llamadas casi
-- simultaneas (entrar + contratar, por ejemplo) se intercalaban y la
-- segunda no veia a los que la primera iba creando. De ahi los
-- cosechadores duplicados encimados.
local syncingWorkers: {[Player]: boolean} = {}

function syncWorkers(player: Player)
	if syncingWorkers[player] then return end
	syncingWorkers[player] = true
	local ok, err = pcall(function()
		syncWorkersInner(player)
	end)
	syncingWorkers[player] = false
	if not ok then warn("[SpiceEmpire] syncWorkers:", err) end
end

function syncWorkersInner(player: Player)
	local profile = DataService.Get(player)
	local wh = warehouses[player]
	if not (profile and wh and wh.Parent) then return end

	-- Limpiar los de antes. OJO: se barre la bodega buscando por atributo
	-- en vez de confiar en la lista. syncWorkers se llama desde tres lados
	-- (entrar, contratar, mejorar bodega) y si dos corrian casi al mismo
	-- tiempo la lista se perdia a medias y quedaban empleados duplicados
	-- encimados en la misma mesa.
	for _, d in ipairs(wh:GetDescendants()) do
		if d:IsA("Model") and (d:GetAttribute("Worker")
			or string.sub(d.Name, 1, 7) == "Worker_") then
			d:Destroy()
		end
	end
	for _, m in ipairs(workerModels[player] or {}) do
		if m and m.Parent then m:Destroy() end
	end
	workerModels[player] = {}

	local nH = math.min(profile.Employees.Harvester or 0, tableCount(profile))
	for i = 1, nH do
		local plot = plotPart(wh, i)
		if plot then
			-- Parado al costado de su mesa, viendo hacia ella.
			-- El piso de la bodega esta 3.7 studs abajo del Plot; si no se
			-- resta, el NPC queda flotando a la altura de la mesa.
			local pos = Vector3.new(plot.Position.X, plot.Position.Y - 3.7,
				plot.Position.Z + 6.2)
			local ok, npc = pcall(function()
				return CityGenerator.MakeWorker(wh, pos, Vector3.new(0, 0, -1), "Cosechador")
			end)
			if ok and npc then
				npc:SetAttribute("PlotIndex", i)
				table.insert(workerModels[player], npc)
			end
		end
	end

	local nP = profile.Employees.Presser or 0
	if nP > 0 then
		local press = wh:FindFirstChild("PressBase", true)
		if press then
			for i = 1, math.min(nP, 4) do
				-- PressBase esta 1.1 arriba del piso
				local base = Vector3.new(press.Position.X, press.Position.Y - 1.1,
					press.Position.Z)
				local off = Vector3.new(-6 + (i - 1) * 4, 0, 7)
				local ok, npc = pcall(function()
					return CityGenerator.MakeWorker(wh, base + off,
						Vector3.new(0, 0, -1), "Prensador")
				end)
				if ok and npc then table.insert(workerModels[player], npc) end
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(pl)
	for _, m in ipairs(workerModels[pl] or {}) do
		if m and m.Parent then m:Destroy() end
	end
	workerModels[pl] = nil
end)

-- Gesto de cosechar: el empleado se agacha tantito y baja los brazos,
-- como si cortara. Se mueven los Motor6D del rig R6 y se regresan solos.
local function playHarvestGesture(npc: Model)
	if not (npc and npc.Parent) then return end
	if npc:GetAttribute("Busy") then return end
	npc:SetAttribute("Busy", true)

	local torso = npc:FindFirstChild("Torso")
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if not torso then npc:SetAttribute("Busy", false) return end

	local rs = torso:FindFirstChild("Right Shoulder")
	local ls = torso:FindFirstChild("Left Shoulder")
	local root = hrp and hrp:FindFirstChild("RootJoint")
	if not (rs and rs:IsA("Motor6D")) then npc:SetAttribute("Busy", false) return end

	local rs0, ls0 = rs.C0, ls and ls.C0
	local root0 = root and root.C0

	task.spawn(function()
		local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		-- brazos abajo al frente
		pcall(function()
			TweenService:Create(rs, info,
				{C0 = rs0 * CFrame.Angles(0, 0, math.rad(-62))}):Play()
			if ls then
				TweenService:Create(ls, info,
					{C0 = ls0 * CFrame.Angles(0, 0, math.rad(62))}):Play()
			end
			-- se inclina hacia la mesa
			if root then
				TweenService:Create(root, info,
					{C0 = root0 * CFrame.Angles(math.rad(16), 0, 0)}):Play()
			end
		end)

		task.wait(0.55)

		pcall(function()
			local back = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(rs, back, {C0 = rs0}):Play()
			if ls then TweenService:Create(ls, back, {C0 = ls0}):Play() end
			if root then TweenService:Create(root, back, {C0 = root0}):Play() end
		end)

		task.wait(0.45)
		if npc and npc.Parent then npc:SetAttribute("Busy", false) end
	end)
end

-- ===== PRODUCCION MIENTRAS NO ESTABAS =====
-- Tus empleados siguen trabajando aunque cierres el juego. Al volver se
-- calcula cuanto habrian producido, con tope de OfflineMaxHours para que
-- no se rompa la economia si te desapareces una semana.
function applyOfflineProduction(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end

	local last = profile.LastSeen or os.time()
	local elapsed = math.max(0, os.time() - last)
	local capSecs = (Config.Employees.OfflineMaxHours or 8) * 3600
	elapsed = math.min(elapsed, capSecs)
	if elapsed < 60 then return end   -- no vale la pena por menos de un minuto

	local HC = Config.Employees.Harvester
	local PC = Config.Employees.Presser

	-- cosechadores (uno por mesa, igual que en vivo)
	local nH = math.min(profile.Employees.Harvester or 0, tableCount(profile))
	local leaves = 0
	if nH > 0 then
		local cycles = math.floor(elapsed / HC.Interval)
		leaves = cycles * nH * HC.PerCycle * G.LeavesPerPlant
	end

	local gotL = 0
	if leaves > 0 then gotL = addLeavesToVault(player, leaves) end

	-- prensadores
	local blocks = 0
	local nP = profile.Employees.Presser or 0
	if nP > 0 then
		local cycles = math.floor(elapsed / PC.Interval)
		local want = cycles * nP * PC.PerCycle
		local cost = Config.Products.Block.PressCost
		local canAfford = math.floor((profile.Leaves or 0) / cost)
		local room = vaultBlockCap(profile) - (profile.Blocks or 0)
		blocks = math.min(want, canAfford, math.max(0, room))
		if blocks > 0 then
			profile.Leaves -= blocks * cost
			profile.Blocks += blocks
		end
	end

	if gotL > 0 or blocks > 0 then
		push(player)
		local mins = math.floor(elapsed / 60)
		alert(player, "Tu gente trabajo sin ti",
			string.format("En %d min tus empleados metieron %d hojas y %d bloques a la caja.",
				mins, gotL, blocks), "good")
	end
end

-- ===== COSECHADORES =====
-- Cada uno revisa SOLO su mesa y corta lo que este maduro ahi.
task.spawn(function()
	while true do
		task.wait(Config.Employees.Harvester.Interval)
		local HC = Config.Employees.Harvester
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			local wh = warehouses[player]
			if profile and wh and wh.Parent and (profile.Employees.Harvester or 0) > 0 then
				local n = math.min(profile.Employees.Harvester, tableCount(profile))
				local got = 0
				local now = os.clock()

				-- para poder animar al que le toca esa mesa
				local byPlot = {}
				for _, m in ipairs(workerModels[player] or {}) do
					local pi = m and m.Parent and m:GetAttribute("PlotIndex")
					if pi then byPlot[pi] = m end
				end

				for idx = 1, n do
					-- juntar las plantas maduras de ESTA mesa
					local ripe = {}
					eachPlant(wh, function(plant)
						if plant:GetAttribute("PlotIndex") == idx
							and plant:GetAttribute("Ripe") then
							table.insert(ripe, plant)
						end
					end)

					local take = math.min(#ripe, HC.PerCycle)
					-- solo anima si la caja tiene sitio; si no, el empleado
					-- se quedaria haciendo la mimica sin producir nada
					local room = vaultLeafCap(profile) - (profile.Leaves or 0)
					if take > 0 and room > 0 and byPlot[idx] then
						playHarvestGesture(byPlot[idx])
					end
					for k = 1, take do
						-- tus empleados guardan en la caja, no en tu mochila
						local added = addLeavesToVault(player, G.LeavesPerPlant)
						if added <= 0 then break end     -- caja llena
						ripe[k]:SetAttribute("PlantedAt", now)
						ripe[k]:SetAttribute("Ripe", false)
						got += added
					end
				end

				if got > 0 then push(player) end
			end
		end
	end
end)

-- ===== PRENSADORES =====
task.spawn(function()
	while true do
		task.wait(Config.Employees.Presser.Interval)
		local PC = Config.Employees.Presser
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			if profile and (profile.Employees.Presser or 0) > 0 then
				local n = profile.Employees.Presser * PC.PerCycle
				-- no produzcas mas bloques de los que caben
				local room = vaultBlockCap(profile) - (profile.Blocks or 0)
				n = math.min(n, math.max(0, room))
				local needed = n * Config.Products.Block.PressCost
				if n > 0 and (profile.Leaves or 0) >= needed then
					profile.Leaves -= needed
					profile.Blocks += n
					push(player)
				end
			end
		end
	end
end)

-- renta de propiedades
task.spawn(function()
	while true do
		task.wait(Config.PropertyPayoutInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			if not profile then continue end
			local income = 0
			for id in pairs(profile.Properties) do
				for _, p in ipairs(Config.Properties) do
					if p.Id == id then income += p.Income end
				end
			end
			if income > 0 then
				profile.Cash += income
				push(player)
				syncLeaderstats(player)
				alert(player, "Rentas", string.format("Cobraste $%s de tus propiedades.", Config.Abbrev(income)), "money")
			end
		end
	end
end)

----------------------------------------------------------------------
-- ARMA
----------------------------------------------------------------------
-- Tool sencilla. El cliente avisa hacia donde apuntas y el servidor hace
-- el raycast: asi nadie puede inventarse impactos desde el cliente.

local shootCooldown: {[Player]: number} = {}

local function makeWeapon(): Tool
	local W = Config.Weapon
	local tool = Instance.new("Tool")
	tool.Name = W.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Clic para disparar"
	-- La pistola se veia enorme junto al personaje; todo el modelo se
	-- redujo al 62% y el agarre se reacomodo.
	tool.GripPos = Vector3.new(0, -0.15, 0.25)

	-- El Handle es la CACHA (lo que agarra la mano). Todo lo demas se le
	-- suelda encima. OJO: hay que colocar cada pieza ANTES de soldarla;
	-- el WeldConstraint congela el offset en el momento de crearse.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.211, 0.713, 0.384)
	handle.Color = Color3.fromRGB(28, 28, 32)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	local function piece(name, size, offset, color, mat, shape)
		local pp = Instance.new("Part")
		pp.Name = name
		pp.Size = size
		pp.Color = color
		pp.Material = mat or Enum.Material.Metal
		if shape then pp.Shape = shape end
		pp.CanCollide = false
		pp.Massless = true
		pp.TopSurface = Enum.SurfaceType.Smooth
		pp.BottomSurface = Enum.SurfaceType.Smooth
		pp.CFrame = handle.CFrame * CFrame.new(offset)
		pp.Parent = tool
		local wc = Instance.new("WeldConstraint")
		wc.Part0 = handle
		wc.Part1 = pp
		wc.Parent = pp
		return pp
	end

	local steel = Color3.fromRGB(58, 60, 66)
	local dark  = Color3.fromRGB(26, 26, 30)

	-- corredera y cañon
	piece("Slide",     Vector3.new(0.223, 0.26, 1.023), Vector3.new(0.0, 0.484, -0.186), steel)
	piece("SlideTop",  Vector3.new(0.186, 0.087, 0.961), Vector3.new(0.0, 0.639, -0.186), Color3.fromRGB(72, 74, 80))
	piece("Barrel",    Vector3.new(0.105, 0.105, 0.248), Vector3.new(0.0, 0.484, -0.794), dark,
		Enum.Material.Metal, Enum.PartType.Cylinder)
	-- el cilindro trae el eje en X: hay que acostarlo sobre Z
	local bar = tool:FindFirstChild("Barrel")
	if bar then
		bar.CFrame = handle.CFrame * CFrame.new(0, 0.78, -1.28) * CFrame.Angles(0, math.rad(90), 0)
	end

	-- armazon, guardamonte y gatillo
	piece("Frame",        Vector3.new(0.198, 0.186, 0.682), Vector3.new(0.0, 0.31, -0.062), dark)
	piece("TriggerGuard", Vector3.new(0.136, 0.211, 0.074), Vector3.new(0.0, 0.136, -0.322), dark)
	piece("GuardBar",     Vector3.new(0.136, 0.062, 0.31), Vector3.new(0.0, 0.043, -0.186), dark)
	piece("Trigger",      Vector3.new(0.062, 0.161, 0.056), Vector3.new(0.0, 0.174, -0.186),
		Color3.fromRGB(96, 98, 104))

	-- miras
	piece("SightRear",  Vector3.new(0.136, 0.062, 0.05), Vector3.new(0.0, 0.713, 0.236), Color3.fromRGB(180, 180, 190))
	piece("SightFront", Vector3.new(0.043, 0.068, 0.043), Vector3.new(0.0, 0.713, -0.632), Color3.fromRGB(180, 180, 190))

	-- cachas texturizadas y base del cargador
	piece("GripL", Vector3.new(0.037, 0.527, 0.31), Vector3.new(-0.118, -0.031, 0.019),
		Color3.fromRGB(62, 48, 40), Enum.Material.Wood)
	piece("GripR", Vector3.new(0.037, 0.527, 0.31), Vector3.new(0.118, -0.031, 0.019),
		Color3.fromRGB(62, 48, 40), Enum.Material.Wood)
	piece("MagBase", Vector3.new(0.236, 0.056, 0.409), Vector3.new(0.0, -0.372, 0.012),
		Color3.fromRGB(44, 44, 50))

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, 0.48, -0.93)
	muzzle.Parent = handle

	-- fogonazo, apagado hasta que disparas
	local flash = Instance.new("PointLight")
	flash.Name = "Flash"
	flash.Color = Color3.fromRGB(255, 200, 120)
	flash.Brightness = 0
	flash.Range = 12
	flash.Parent = handle

	return tool
end

function giveWeapon(player: Player)
	if not Config.Weapon.GiveOnSpawn then return end
	local bp = player:FindFirstChildOfClass("Backpack")
	if not bp then return end
	if bp:FindFirstChild(Config.Weapon.Name) then return end
	local char = player.Character
	if char and char:FindFirstChild(Config.Weapon.Name) then return end
	makeWeapon().Parent = bp
end

-- rayita del disparo, para que se vea de donde a donde
local function tracer(from: Vector3, to: Vector3)
	local dist = (to - from).Magnitude
	if dist < 0.5 then return end
	local p = Instance.new("Part")
	p.Name = "Tracer"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 220, 140)
	p.Size = Vector3.new(0.12, 0.12, dist)
	p.CFrame = CFrame.lookAt(from + (to - from) * 0.5, to)
	p.Parent = Workspace
	task.delay(0.06, function() p:Destroy() end)
end

RE_Shoot.OnServerEvent:Connect(function(player: Player, dir: Vector3)
	local W = Config.Weapon
	local now = os.clock()
	if shootCooldown[player] and now - shootCooldown[player] < W.Cooldown then return end
	shootCooldown[player] = now

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum and hum.Health > 0) then return end

	-- tiene que traer el arma equipada
	if not char:FindFirstChild(W.Name) then return end

	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.01 then return end
	local d = dir.Unit

	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {char}

	local from = hrp.Position + Vector3.new(0, 1, 0)

	-- estampido, discreto y posicional (lo oyen los de alrededor)
	local sdef = Config.Sounds and Config.Sounds.Shot
	if sdef and Config.Sounds.Enabled then
		local sd = Instance.new("Sound")
		sd.SoundId = sdef.Id
		sd.Volume = sdef.Volume or 0.3
		sd.PlaybackSpeed = (sdef.Pitch or 1) * (0.95 + math.random() * 0.1)
		sd.RollOffMaxDistance = 140
		sd.Parent = hrp
		sd:Play()
		task.delay(2, function() sd:Destroy() end)
	end

	-- fogonazo en la boca del cañon
	local tool = char:FindFirstChild(W.Name)
	local th = tool and tool:FindFirstChild("Handle")
	local fl = th and th:FindFirstChild("Flash")
	if fl then
		fl.Brightness = 4
		task.delay(0.05, function()
			if fl and fl.Parent then fl.Brightness = 0 end
		end)
	end

	local hit = Workspace:Raycast(from, d * W.Range, rp)
	local to = hit and hit.Position or (from + d * W.Range)
	tracer(from, to)

	if not hit then return end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	local target = model and model:FindFirstChildOfClass("Humanoid")
	if target and target.Health > 0 then
		target:TakeDamage(W.Damage)
	end
end)

----------------------------------------------------------------------
-- ASALTOS A LA BODEGA
----------------------------------------------------------------------
local activeRaid: {[Player]: boolean} = {}
local raidMobs: {[Player]: {Model}} = {}

local function clearRaid(player: Player)
	for _, m in ipairs(raidMobs[player] or {}) do
		if m and m.Parent then m:Destroy() end
	end
	raidMobs[player] = nil
	activeRaid[player] = nil
end

Players.PlayerRemoving:Connect(function(pl) clearRaid(pl) end)

local function runRaid(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	if activeRaid[player] then return end        -- uno a la vez
	activeRaid[player] = true

	local R = Config.Raids
	alert(player, "ASALTO EN CAMINO",
		string.format("Van a golpear tu bodega en %d segundos. Llega y defiendela.", R.WarnSeconds),
		"danger")

	task.delay(R.WarnSeconds, function()
		local p = DataService.Get(player)
		local wh = warehouses[player]
		if not (p and wh and wh.Parent) then clearRaid(player); return end

		local vault = wh:FindFirstChild("VaultBody", true)
		local gate = wh:FindFirstChild("GateSensor") or wh.PrimaryPart
		if not (vault and gate) then clearRaid(player); return end

		raidMobs[player] = {}

		-- ===== ENTRAN LOS ASALTANTES =====
		local n = R.RaidersBase + (p.WarehouseTier or 1) * R.RaidersPerTier
		local alive = 0
		local cracking = false
		local finished = false

		local function finish(defended: boolean)
			if finished then return end
			finished = true

			if defended then
				local reward = math.floor(300 + p.TotalEarned * 0.012)
				p.Cash += reward
				alert(player, "ASALTO REPELIDO",
					string.format("Los bajaste a todos. Te quedaste con $%s de lo que traian.",
						Config.Abbrev(reward)), "good")
				sfx(player, "Sell")
			else
				local lostL = math.floor((p.Leaves or 0) * R.StealPercent)
				local lostB = math.floor((p.Blocks or 0) * R.StealPercent)
				p.Leaves = (p.Leaves or 0) - lostL
				p.Blocks = (p.Blocks or 0) - lostB
				alert(player, "TE VACIARON LA CAJA",
					string.format("Abrieron la caja fuerte. Se llevaron %d hojas y %d bloques.",
						lostL, lostB), "danger")
				sfx(player, "Arrest")
			end

			push(player)
			syncLeaderstats(player)
			task.delay(3, function() clearRaid(player) end)
		end

		-- El piso de la bodega, para que no aparezcan flotando: el GateSensor
		-- tiene su centro a 8 studs de alto, si se usa de referencia salen
		-- por los aires.
		local floorPart = wh:FindFirstChild("Floor")
		local groundY = floorPart and (floorPart.Position.Y + floorPart.Size.Y / 2) or 2

		for i = 1, n do
			local ang = (i / n) * math.pi * 2
			local spawnPos = Vector3.new(
				gate.Position.X + math.cos(ang) * 14,
				groundY,
				gate.Position.Z + math.sin(ang) * 14 + 26)

			local ok, mob = pcall(function()
				return CityGenerator.MakeRaider(Workspace, spawnPos)
			end)
			if ok and mob then
				table.insert(raidMobs[player], mob)
				alive += 1

				local hum = mob:FindFirstChildOfClass("Humanoid")
				local mhrp = mob.PrimaryPart
				if hum and mhrp then
					hum.MaxHealth = R.RaiderHealth
					hum.Health = R.RaiderHealth
					hum.WalkSpeed = R.RaiderSpeed

					hum.Died:Connect(function()
						alive -= 1
						task.delay(2.5, function()
							if mob and mob.Parent then mob:Destroy() end
						end)
						if alive <= 0 then finish(true) end
					end)

					-- caminan hacia la caja; si llegan, la empiezan a abrir
					task.spawn(function()
						while mob.Parent and hum.Health > 0 and not finished do
							hum:MoveTo(vault.Position)

							local d = (mhrp.Position - vault.Position).Magnitude
							if d < 9 and not cracking then
								cracking = true
								alert(player, "ESTAN EN LA CAJA",
									string.format("Llegaron a tu caja fuerte. Tienes %d segundos.",
										R.CrackSeconds), "danger")
								task.delay(R.CrackSeconds, function()
									if not finished then finish(false) end
								end)
							end

							-- si andas cerca, te tiran
							local pchar = player.Character
							local phrp = pchar and pchar:FindFirstChild("HumanoidRootPart")
							local phum = pchar and pchar:FindFirstChildOfClass("Humanoid")
							if phrp and phum and phum.Health > 0
								and (phrp.Position - mhrp.Position).Magnitude <= R.RaiderAttackRange then
								phum:TakeDamage(R.RaiderDamage)
								tracer(mhrp.Position + Vector3.new(0, 1, 0), phrp.Position)
							end

							task.wait(R.RaiderAttackEvery)
						end
					end)
				end
			end
		end

		if alive == 0 then clearRaid(player); return end

		-- ===== TUS GUARDIAS CONTRATADOS =====
		local nG = p.Employees.Guard or 0
		for i = 1, nG do
			local gpos = Vector3.new(vault.Position.X - 6 + (i - 1) * 4, groundY,
				vault.Position.Z + 10)
			local ok, g = pcall(function()
				return CityGenerator.MakeGuard(wh, gpos, Vector3.new(0, 0, 1))
			end)
			if ok and g then
				table.insert(raidMobs[player], g)
				local ghrp = g.PrimaryPart
				task.spawn(function()
					while g.Parent and not finished do
						-- le dispara al asaltante vivo mas cercano
						local best, bestD = nil, R.GuardRange
						for _, m in ipairs(raidMobs[player] or {}) do
							if m and m.Parent and m.Name == "Raider" and m.PrimaryPart then
								local mh = m:FindFirstChildOfClass("Humanoid")
								if mh and mh.Health > 0 and ghrp then
									local d = (m.PrimaryPart.Position - ghrp.Position).Magnitude
									if d < bestD then best, bestD = m, d end
								end
							end
						end
						if best and ghrp then
							local bh = best:FindFirstChildOfClass("Humanoid")
							if bh then
								bh:TakeDamage(R.GuardDamage)
								tracer(ghrp.Position + Vector3.new(0, 1, 0),
									best.PrimaryPart.Position)
							end
						end
						task.wait(R.GuardEvery)
					end
				end)
			end
		end

		-- red de seguridad: que nunca se quede un asalto colgado
		task.delay(R.MaxRaidSeconds, function()
			if not finished then finish(false) end
			clearRaid(player)
		end)
	end)
end

task.spawn(function()
	while true do
		task.wait(Config.Raids.CheckInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			if not profile then continue end

			local chance = Config.Raids.BaseChance + profile.Blocks * Config.Raids.ChancePerBlock
			chance -= profile.Employees.Guard * Config.Employees.Guard.RaidReduction
			chance = math.clamp(chance, 0, 0.9)

			if math.random() < chance then
				runRaid(player)
			end
		end
	end
end)

----------------------------------------------------------------------
-- ENCARGOS / MISIONES
----------------------------------------------------------------------
local scheduleNextCall   -- definida abajo (sistema de llamadas)

local function missionState(player: Player)
	local m = activeMission[player]
	if not m then return nil end
	return {
		Title = m.Title,
		Text = m.Text,
		BuyerName = m.BuyerName,
		Item = m.Item,
		Amount = m.Amount,
		Reward = m.Reward,
		EndsAt = m.EndsAt,
	}
end

local function sendMission(player: Player)
	local m = missionState(player)
	RE_Mission:FireClient(player, m)
end

-- arma una propuesta de encargo (todavia NO la activa)
local function rollMission()
	local tpl = Config.Missions.Templates[math.random(1, #Config.Missions.Templates)]
	local buyer = Config.Buyers[math.random(1, #Config.Buyers)]
	local amount = math.random(tpl.AmountMin, tpl.AmountMax)

	local unitPrice = (tpl.Item == "Blocks")
		and Config.Products.Block.BasePrice
		or Config.Products.Leaf.BasePrice
	local reward = math.floor(amount * unitPrice * buyer.PriceMult * tpl.RewardMult)

	local minutes = math.floor(tpl.TimeLimit / 60)
	local text = string.format(tpl.Desc, amount, buyer.Name, minutes)

	return {
		Id = tpl.Id,
		Title = tpl.Title,
		Text = text,
		BuyerId = buyer.Id,
		BuyerName = buyer.Name,
		Item = tpl.Item,
		Amount = amount,
		Reward = reward,
		HeatMult = tpl.HeatMult,
		TimeLimit = tpl.TimeLimit,
	}
end

-- activa un encargo ya aceptado
local function startMission(player: Player, m: any)
	if not Config.Missions.Enabled then return end
	if activeMission[player] then return end

	m.EndsAt = os.time() + m.TimeLimit
	activeMission[player] = m

	sendMission(player)
	alert(player, "ENCARGO ACEPTADO: " .. m.Title,
		string.format("%s  Pago: $%s", m.Text, Config.Abbrev(m.Reward)), "money")
end

local function failMission(player: Player, reason: string)
	if not activeMission[player] then return end
	activeMission[player] = nil
	missionCooldown[player] = os.clock() + Config.Missions.CooldownAfterFinish
	sendMission(player)
	if scheduleNextCall then pcall(scheduleNextCall, player) end
	alert(player, "ENCARGO FALLIDO", reason, "danger")
end

-- revisa si una venta completa el encargo. Devuelve bono extra.
function checkMissionOnSell(player: Player, buyerId: string, soldL: number, soldB: number): number
	local m = activeMission[player]
	if not m then return 0 end
	if m.BuyerId ~= buyerId then return 0 end

	local delivered = (m.Item == "Blocks") and soldB or soldL
	if delivered < m.Amount then return 0 end

	local profile = DataService.Get(player)
	if not profile then return 0 end

	activeMission[player] = nil
	missionCooldown[player] = os.clock() + Config.Missions.CooldownAfterFinish
	sendMission(player)
	if scheduleNextCall then pcall(scheduleNextCall, player) end

	alert(player, "ENCARGO COMPLETADO",
		string.format("+$%s de bono por '%s'.", Config.Abbrev(m.Reward), m.Title), "good")

	return m.Reward
end

----------------------------------------------------------------------
-- LLAMADAS AL CELULAR: te marca un desconocido y tu decides
----------------------------------------------------------------------
-- RE_Call ya se creo arriba, junto a los otros remotes (no lo vuelvas a
-- crear aqui: dos RemoteEvent con el mismo nombre confunden al cliente).

local MC = Config.MissionCalls

function scheduleNextCall(player: Player, delaySec: number?)
	local wait_ = delaySec or math.random(MC.MinWait, MC.MaxWait)
	nextCallAt[player] = os.clock() + wait_
end
local scheduleCall = scheduleNextCall

local function hangUp(player: Player)
	pendingCall[player] = nil
	RE_Call:FireClient(player, nil)
end

local function ringPlayer(player: Player)
	if pendingCall[player] then return end
	if activeMission[player] then return end

	local m = rollMission()
	local line = MC.Lines[math.random(1, #MC.Lines)]

	pendingCall[player] = {
		Mission = m,
		ExpiresAt = os.clock() + MC.RingSeconds,
	}

	alert(player, "Llamada de " .. MC.CallerName,
		line .. "  [" .. m.Title .. " - $" .. Config.Abbrev(m.Reward) .. "]", "info")

	RE_Call:FireClient(player, {
		Caller = MC.CallerName,
		Line = line,
		Title = m.Title,
		Text = m.Text,
		BuyerName = m.BuyerName,
		Item = m.Item,
		Amount = m.Amount,
		Reward = m.Reward,
		Seconds = MC.RingSeconds,
	})
end

local function answerCall(player: Player, accept: boolean)
	local call = pendingCall[player]
	if not call then return false, "No hay ninguna llamada" end
	pendingCall[player] = nil
	RE_Call:FireClient(player, nil)

	if accept then
		startMission(player, call.Mission)
		return true, "Encargo aceptado"
	end

	scheduleCall(player, MC.RejectPenalty)
	alert(player, "Llamada rechazada", "Colgaste. Ya te volveran a marcar.", "info")
	return true, "Rechazaste el encargo"
end

-- loop: expiracion de encargos y de llamadas + programar nuevas
task.spawn(function()
	while true do
		task.wait(2)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			-- encargo activo que se vencio
			local m = activeMission[player]
			if m and os.time() > m.EndsAt then
				failMission(player, "Se acabo el tiempo para '" .. m.Title .. "'.")
			end

			-- llamada que nadie contesto
			local call = pendingCall[player]
			if call and now > call.ExpiresAt then
				pendingCall[player] = nil
				RE_Call:FireClient(player, nil)
				scheduleCall(player, MC.RejectPenalty)
				alert(player, "Llamada perdida",
					"No contestaste a " .. MC.CallerName .. ". Te vuelven a marcar al rato.",
					"danger")
			end

			-- toca marcarle?
			if MC.Enabled and not activeMission[player] and not pendingCall[player] then
				local at = nextCallAt[player]
				if not at then
					scheduleCall(player, MC.FirstCallWait)
				elseif now >= at then
					ringPlayer(player)
				end
			end
		end
	end
end)

----------------------------------------------------------------------
-- AGENTES DE ADUANAS: persecucion real con pathfinding
----------------------------------------------------------------------
local PathfindingService = game:GetService("PathfindingService")

local agentsFolder = Instance.new("Folder")
agentsFolder.Name = "Agents"
agentsFolder.Parent = Workspace

local activeAgents: {[Player]: {Model}} = {}

local function countAgents(player: Player): number
	local list = activeAgents[player]
	if not list then return 0 end
	local n = 0
	for _, a in ipairs(list) do
		if a.Parent then n += 1 end
	end
	return n
end

local function despawnAgent(player: Player, agent: Model)
	local list = activeAgents[player]
	if list then
		for i, a in ipairs(list) do
			if a == agent then table.remove(list, i) break end
		end
	end
	if agent.Parent then
		-- se desvanece en vez de desaparecer de golpe
		task.spawn(function()
			for _, d in ipairs(agent:GetDescendants()) do
				if d:IsA("BasePart") and d.Transparency < 1 then
					pcall(function()
						TweenService:Create(d, TweenInfo.new(0.8), {Transparency = 1}):Play()
					end)
				end
			end
			task.wait(0.9)
			agent:Destroy()
		end)
	end
end

-- busca un punto de spawn valido alrededor del jugador
local function findSpawnPoint(hrp: BasePart): Vector3?
	local A = Config.Agents
	for attempt = 1, 8 do
		local angle = math.random() * math.pi * 2
		local dist = A.SpawnDistance * (0.7 + math.random() * 0.6)
		local origin = hrp.Position + Vector3.new(math.cos(angle) * dist, 60, math.sin(angle) * dist)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {agentsFolder}

		local hit = Workspace:Raycast(origin, Vector3.new(0, -200, 0), params)
		if hit then
			return hit.Position + Vector3.new(0, 4, 0)
		end
	end
	return nil
end

local function spawnAgent(player: Player)
	local A = Config.Agents
	if not A.Enabled then return end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	if countAgents(player) >= A.MaxActive then return end

	local spawnPos = findSpawnPoint(hrp)
	if not spawnPos then return end

	local ok, agent = pcall(CityGenerator.BuildAgent)
	if not ok or not agent then
		warn("[SpiceEmpire] no se pudo crear el agente: " .. tostring(agent))
		return
	end

	agent:PivotTo(CFrame.new(spawnPos))
	agent.Parent = agentsFolder

	activeAgents[player] = activeAgents[player] or {}
	table.insert(activeAgents[player], agent)

	local hum = agent:FindFirstChildOfClass("Humanoid")
	local aHrp = agent.PrimaryPart
	if not hum or not aHrp then
		despawnAgent(player, agent)
		return
	end

	alert(player, "ADUANAS EN LA ZONA",
		"Un agente te esta buscando. Piérdete o escóndete en tu Zona Segura.", "danger")

	-- ===== LOOP DE PERSECUCION =====
	task.spawn(function()
		local startTime = os.clock()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2.5,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 6,
		})

		while agent.Parent and hum.Health > 0 do
			local profile = DataService.Get(player)
			local pchar = player.Character
			local phrp = pchar and pchar:FindFirstChild("HumanoidRootPart") :: BasePart?

			-- condiciones de rendirse
			if not profile or not phrp then break end
			if os.clock() - startTime > Config.Agents.GiveUpTime then
				alert(player, "LOS PERDISTE", "El agente dejó de seguirte.", "good")
				break
			end
			if profile.Heat < Config.Heat.ArrestThreshold * 0.5 then
				alert(player, "SE ENFRIÓ", "Aduanas dejó de buscarte.", "good")
				break
			end

			local dist = (phrp.Position - aHrp.Position).Magnitude
			if dist > Config.Agents.GiveUpDistance then
				alert(player, "LOS PERDISTE", "Te alejaste demasiado del agente.", "good")
				break
			end

			-- ¿te alcanzó?
			if dist <= Config.Agents.CatchDistance then
				arrest(player)
				despawnAgent(player, agent)
				return
			end

			-- recalcular ruta
			local okPath = pcall(function()
				path:ComputeAsync(aHrp.Position, phrp.Position)
			end)

			if okPath and path.Status == Enum.PathStatus.Success then
				local waypoints = path:GetWaypoints()
				-- seguimos solo los primeros para poder re-planear seguido
				for i = 2, math.min(#waypoints, 5) do
					if not agent.Parent or hum.Health <= 0 then return end
					local wp = waypoints[i]
					if wp.Action == Enum.PathWaypointAction.Jump then
						hum.Jump = true
					end
					hum:MoveTo(wp.Position)
					local reached = hum.MoveToFinished:Wait()
					if not reached then break end
				end
			else
				-- sin ruta: camina en linea recta
				hum:MoveTo(phrp.Position)
				task.wait(Config.Agents.RepathInterval)
			end

			task.wait(0.1)
		end

		despawnAgent(player, agent)
	end)

	-- si lo matan, recompensa
	hum.Died:Connect(function()
		local profile = DataService.Get(player)
		if profile then
			profile.Heat = math.max(0, profile.Heat - 18)
			push(player)
			alert(player, "AGENTE NEUTRALIZADO",
				"Bajaste 18 de Heat. Pero van a mandar más.", "good")
		end
		despawnAgent(player, agent)
	end)
end

-- loop que decide cuando mandar agentes
task.spawn(function()
	while true do
		task.wait(6)
		if Config.Agents.Enabled then
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataService.Get(player)
				if profile and profile.Heat >= Config.Agents.SpawnHeat then
					-- mas heat = mas probabilidad
					local over = (profile.Heat - Config.Agents.SpawnHeat)
						/ math.max(1, Config.Heat.Max - Config.Agents.SpawnHeat)
					if math.random() < 0.25 + over * 0.5 then
						pcall(spawnAgent, player)
					end
				end
			end
		end
	end
end)

-- limpiar agentes al salir
Players.PlayerRemoving:Connect(function(player)
	local list = activeAgents[player]
	if list then
		for _, a in ipairs(list) do
			if a.Parent then a:Destroy() end
		end
	end
	activeAgents[player] = nil
end)

----------------------------------------------------------------------
-- PVP: robar al matar
----------------------------------------------------------------------
function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.Died:Connect(function()
		local killerPlayer
		local creator = hum:FindFirstChild("creator") :: ObjectValue?
		if creator and creator.Value and creator.Value:IsA("Player") then
			killerPlayer = creator.Value
		end
		if not killerPlayer or killerPlayer == player then return end

		local victim = DataService.Get(player)
		local killer = DataService.Get(killerPlayer)
		if not victim or not killer then return end

		-- no robar entre miembros del mismo crew
		if victim.CrewId and victim.CrewId == killer.CrewId then return end

		local sL = math.floor(victim.Leaves * Config.Crew.StealOnKillPercent)
		local sB = math.floor(victim.Blocks * Config.Crew.StealOnKillPercent)
		local sC = math.floor(victim.Cash * Config.Crew.KillCashSteal)

		victim.Leaves -= sL; victim.Blocks -= sB; victim.Cash -= sC
		killer.Leaves += sL; killer.Blocks += sB; killer.Cash += sC

		push(player); push(killerPlayer)
		syncLeaderstats(player); syncLeaderstats(killerPlayer)

		alert(player, "TE TUMBARON", string.format("%s te quito %d hojas, %d bloques y $%s.",
			killerPlayer.Name, sL, sB, Config.Abbrev(sC)), "danger")
		alert(killerPlayer, "BOTIN", string.format("Le quitaste a %s: %d hojas, %d bloques, $%s.",
			player.Name, sL, sB, Config.Abbrev(sC)), "good")
	end)
end

-- (el enganche de personaje lo hace setupPlayer)

----------------------------------------------------------------------
-- CREWS
----------------------------------------------------------------------
local function createCrew(player: Player, name: string)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end
	if profile.CrewId then return false, "Ya perteneces a un crew" end

	name = string.sub(tostring(name), 1, Config.Crew.NameMaxLength)
	if #name < 3 then return false, "Nombre muy corto" end

	local id = "crew_" .. player.UserId
	local palette = Config.Territories.CrewColors
	local ci = 0
	for _ in pairs(crews) do ci += 1 end
	crews[id] = {
		Name = name,
		Owner = player.UserId,
		Members = {player.UserId},
		Color = palette[(ci % #palette) + 1],
	}
	profile.CrewId = id
	push(player)
	return true, "Crew '" .. name .. "' creado"
end

local function joinCrew(player: Player, ownerName: string)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end
	if profile.CrewId then return false, "Ya perteneces a un crew" end

	local owner = Players:FindFirstChild(tostring(ownerName))
	if not owner then return false, "Ese jugador no esta en el servidor" end

	local ownerProfile = DataService.Get(owner)
	if not ownerProfile or not ownerProfile.CrewId then return false, "Ese jugador no tiene crew" end

	local crew = crews[ownerProfile.CrewId]
	if not crew then return false, "crew invalido" end
	if #crew.Members >= Config.Crew.MaxMembers then return false, "El crew esta lleno" end

	table.insert(crew.Members, player.UserId)
	profile.CrewId = ownerProfile.CrewId
	push(player)
	alert(owner, "Nuevo miembro", player.Name .. " se unio a tu crew.", "good")
	return true, "Te uniste a " .. crew.Name
end

local function leaveCrew(player: Player)
	local profile = DataService.Get(player)
	if not profile or not profile.CrewId then return false, "No tienes crew" end
	local crew = crews[profile.CrewId]
	if crew then
		for i, uid in ipairs(crew.Members) do
			if uid == player.UserId then table.remove(crew.Members, i) break end
		end
		if #crew.Members == 0 then crews[profile.CrewId] = nil end
	end
	profile.CrewId = nil
	push(player)
	return true, "Saliste del crew"
end

----------------------------------------------------------------------
-- COMPRAS
----------------------------------------------------------------------
local function buyPlot(player: Player)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end
	if profile.Plots >= Config.Plots.MaxPlots then return false, "Ya tienes el maximo de parcelas" end

	local cost = Config.CostCurve(Config.Plots.BaseCost, Config.Plots.Growth, profile.Plots - Config.Plots.StartingPlots)
	if profile.Cash < cost then return false, "Te faltan $" .. Config.Abbrev(cost - profile.Cash) end

	profile.Cash -= cost
	profile.Plots += 1
	push(player); syncLeaderstats(player)
	return true, "Parcela comprada (" .. profile.Plots .. ")"
end

local function upgradePress(player: Player)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end
	if profile.PressLevel >= Config.Press.MaxLevel then return false, "Prensa al maximo" end

	local cost = Config.CostCurve(Config.Press.BaseCost, Config.Press.Growth, profile.PressLevel - 1)
	if profile.Cash < cost then return false, "Te faltan $" .. Config.Abbrev(cost - profile.Cash) end

	profile.Cash -= cost
	profile.PressLevel += 1
	push(player); syncLeaderstats(player)
	return true, "Prensa nivel " .. profile.PressLevel
end

local function hire(player: Player, role: string)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end
	local info = Config.Employees[role]
	if not info then return false, "rol invalido" end

	local owned = profile.Employees[role] or 0
	if owned >= info.Max then return false, "Maximo de " .. info.Name end

	-- Los cosechadores son UNO POR MESA: no puedes tener mas que mesas.
	if role == "Harvester" then
		local T = Config.WarehouseTiers[profile.WarehouseTier or 1]
		local mesas = T and T.Plots or 0
		if owned >= mesas then
			return false, string.format(
				"Ya tienes un cosechador por mesa (%d/%d). Mejora la bodega para tener mas mesas",
				owned, mesas)
		end
	end

	local cost = Config.CostCurve(info.BaseCost, info.Growth, owned)
	if profile.Cash < cost then return false, "Te faltan $" .. Config.Abbrev(cost - profile.Cash) end

	profile.Cash -= cost
	profile.Employees[role] = owned + 1
	push(player); syncLeaderstats(player)
	if syncWorkers then pcall(syncWorkers, player) end
	return true, "Contrataste un " .. info.Name
end

local function upgradeWarehouse(player: Player)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end

	local cur = profile.WarehouseTier or 1
	local nextTier = Config.WarehouseTiers[cur + 1]
	if not nextTier then return false, "Tu bodega ya esta al maximo" end

	if profile.Cash < nextTier.Cost then
		return false, "Te faltan $" .. Config.Abbrev(nextTier.Cost - profile.Cash)
	end

	profile.Cash -= nextTier.Cost
	profile.WarehouseTier = cur + 1

	-- reconstruir la bodega en el mismo lugar
	local oldWh = warehouses[player]
	local cf = oldWh and oldWh.PrimaryPart and oldWh.PrimaryPart.CFrame
	releaseWarehouse(player)
	local newWh = assignWarehouse(player)
	if cf and newWh then
		newWh:PivotTo(cf)
	end
	-- la bodega es nueva: hay que volver a parar a los empleados en sus mesas
	if syncWorkers then pcall(syncWorkers, player) end

	-- reubicar al jugador dentro
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and newWh and newWh.PrimaryPart then
		hrp.CFrame = newWh.PrimaryPart.CFrame + Vector3.new(0, 8, 0)
	end

	push(player); syncLeaderstats(player)
	alert(player, "BODEGA MEJORADA",
		string.format("Ahora tienes: %s. %s", nextTier.Name, nextTier.Desc), "good")
	return true, "Mejoraste a " .. nextTier.Name
end

-- ===== BICICLETA INICIAL =====
function spawnBike(player: Player)
	local B = Config.StarterBike
	if not B.Enabled then return false, "desactivada" end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false, "sin personaje" end

	local old = Workspace:FindFirstChild("Bike_" .. player.UserId)
	if old then old:Destroy() end

	-- Aparece afuera de la bodega y SIEMPRE derecha.
	-- Solo tomamos la rotacion en Y, nunca la inclinacion del piso.
	local basePos
	local wh = warehouses[player]
	if wh and wh.PrimaryPart then
		local whCF = wh.PrimaryPart.CFrame
		local size = wh.PrimaryPart.Size
		basePos = (whCF * CFrame.new(0, 0, size.Z * 0.5 + 18)).Position
	else
		basePos = (hrp.CFrame * CFrame.new(7, 0, -7)).Position
	end
	basePos = Vector3.new(basePos.X, basePos.Y + 3, basePos.Z)

	-- mira en la misma direccion horizontal que el jugador
	local flatLook = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(0, 0, 1) end
	local spawnCF = CFrame.lookAt(basePos, basePos + flatLook.Unit)

	local model = Instance.new("Model")
	model.Name = "Bike_" .. player.UserId

	local function bp(name, size, cf, color, mat, shape)
		local pp = Instance.new("Part")
		pp.Name = name
		pp.Size = size
		pp.CFrame = cf
		pp.Color = color
		pp.Material = mat or Enum.Material.Metal
		if shape then pp.Shape = shape end
		pp.CanCollide = false          -- choca el chasis invisible, no las piezas
		pp.Massless = true
		pp.TopSurface = Enum.SurfaceType.Smooth
		pp.BottomSurface = Enum.SurfaceType.Smooth
		pp.Parent = model
		return pp
	end

	-- ===== CHASIS INVISIBLE =====
	-- Es lo unico con masa y colision. Asi la bici nunca se atora ni se
	-- retuerce: se comporta como un solo cuerpo solido.
	-- La altura TIENE que llegar hasta abajo de las ruedas, si no la bici
	-- se queda flotando (la caja se apoya en el piso antes que las llantas).
	-- Ruedas: centro en Y = -0.95, radio 1.3  ->  fondo en -2.25
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(1.9, 4.5, 5)
	chassis.CFrame = spawnCF
	chassis.Transparency = 1
	-- SIN colision y ANCLADO. Las versiones anteriores fallaban por esto:
	-- mientras la bici fuera un cuerpo fisico, el solver de Roblox podia
	-- empujarla (contra una pared la levantaba; con el jugador encima la
	-- mandaba a volar). Anclada, la fisica sencillamente no la toca.
	chassis.CanCollide = false
	chassis.Anchored = true
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.2, 0, 1, 1)
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- ===== CUADRO =====
	bp("TopTube", Vector3.new(0.3, 0.3, 4.2),
		spawnCF * CFrame.new(0, 0.55, 0), B.Color)
	bp("DownTube", Vector3.new(0.3, 0.3, 3.4),
		spawnCF * CFrame.new(0, -0.35, -0.45) * CFrame.Angles(math.rad(34), 0, 0), B.Color)
	bp("SeatTube", Vector3.new(0.3, 2, 0.3),
		spawnCF * CFrame.new(0, 0.7, 1.5), B.Color)
	bp("ChainStay", Vector3.new(0.26, 0.26, 2.4),
		spawnCF * CFrame.new(0, -0.7, 1.5), B.Color)
	bp("Fork", Vector3.new(0.28, 2.6, 0.28),
		spawnCF * CFrame.new(0, 0.1, -2.1) * CFrame.Angles(math.rad(-16), 0, 0),
		Color3.fromRGB(60, 60, 66))

	-- ===== ASIENTO =====
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(1.3, 0.35, 1.7)
	seat.CFrame = spawnCF * CFrame.new(0, 1.85, 1.5)
	seat.MaxSpeed = B.Speed
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Color = Color3.fromRGB(28, 28, 32)
	seat.Material = Enum.Material.Fabric
	seat.HeadsUpDisplay = false
	seat.CanCollide = false
	seat.Massless = true
	seat.Parent = model

	-- ===== MANUBRIO =====
	bp("Stem", Vector3.new(0.25, 0.25, 0.9),
		spawnCF * CFrame.new(0, 1.55, -1.9), Color3.fromRGB(50, 50, 56))
	bp("Handlebar", Vector3.new(3.2, 0.25, 0.25),
		spawnCF * CFrame.new(0, 1.8, -2.1), Color3.fromRGB(40, 40, 46))
	for _, gx in ipairs({-1.4, 1.4}) do
		bp("Grip", Vector3.new(0.75, 0.32, 0.32),
			spawnCF * CFrame.new(gx, 1.8, -2.1), Color3.fromRGB(22, 22, 26),
			Enum.Material.Rubber)
	end

	-- ===== PEDALES =====
	bp("Crank", Vector3.new(0.55, 0.55, 0.16),
		spawnCF * CFrame.new(0, -0.95, 0.3), Color3.fromRGB(70, 70, 78),
		Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, px in ipairs({-0.5, 0.5}) do
		bp("Pedal", Vector3.new(0.85, 0.14, 0.45),
			spawnCF * CFrame.new(px, -1.25, 0.3), Color3.fromRGB(30, 30, 34),
			Enum.Material.Plastic)
	end

	-- ===== RUEDAS (decorativas, giran solas al avanzar) =====
	local wheelParts = {}
	for wi, off in ipairs({Vector3.new(0, -0.95, -2.2), Vector3.new(0, -0.95, 2.2)}) do
		-- OJO: el cilindro de Roblox ya trae el eje en X (caras redondas a
		-- los lados), que es justo como va una llanta. NO hay que rotarlo:
		-- el CFrame.Angles(0,0,90) las dejaba acostadas como platos.
		local wheel = bp(wi == 1 and "WheelFront" or "WheelRear",
			Vector3.new(0.32, 2.6, 2.6),
			spawnCF * CFrame.new(off),
			Color3.fromRGB(26, 26, 28), Enum.Material.Rubber, Enum.PartType.Cylinder)
		local rim = bp("Rim", Vector3.new(0.36, 1.5, 1.5),
			wheel.CFrame, Color3.fromRGB(180, 182, 188),
			Enum.Material.Metal, Enum.PartType.Cylinder)
		table.insert(wheelParts, {wheel = wheel, rim = rim, offset = off})
	end

	-- ===== TODO ANCLADO =====
	-- Ni soldaduras ni masa: CERO fisica. Guardamos la posicion de cada
	-- pieza respecto al chasis y las reacomodamos nosotros cada frame.
	-- Asi el motor de fisica no puede lanzar la bici por los aires.
	local isWheel = {}
	for _, w in ipairs(wheelParts) do
		isWheel[w.wheel] = true
		isWheel[w.rim] = true
	end

	local rigidParts = {}
	for _, c in ipairs(model:GetDescendants()) do
		if c:IsA("BasePart") then
			c.Anchored = true
			if c ~= chassis and not isWheel[c] then
				table.insert(rigidParts, {part = c, off = spawnCF:ToObjectSpace(c.CFrame)})
			end
		end
	end

	-- ===== CONTROL (cinematico, sin fisica) =====
	-- Se probaron 3 versiones con fisica (bisagras, luego velocidad, luego
	-- velocidad en plano) y las 3 acabaron flotando o trepandose a los
	-- edificios: el solver de Roblox resuelve los choques empujando hacia
	-- arriba. Aqui la bici NO colisiona con nada; calculamos su posicion
	-- nosotros con raycasts. Es 100% predecible.
	model.Parent = Workspace

	local RIDE_H = 2.25       -- altura del centro del chasis sobre el piso
	local MAX_STEP = 1.6      -- escalon maximo que puede subir (banqueta si, pared no)
	local GRAVITY = 70

	local heading = math.atan2(-flatLook.Unit.X, -flatLook.Unit.Z)
	local pos = spawnCF.Position
	local speed = 0
	local spin = 0
	local vertVel = 0
	local lean = 0

	local function rayParams(char)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local list = {model}
		if char then table.insert(list, char) end
		rp.FilterDescendantsInstances = list
		return rp
	end

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent or not chassis.Parent then
			if conn then conn:Disconnect() end
			return
		end
		dt = math.min(dt, 0.1)   -- si hay lag, que no pegue un brinco

		local occupant = seat.Occupant
		local char = occupant and occupant.Parent
		local rp = rayParams(char)
		local maxSpeed = B.Speed or 40
		local steer = 0

		if occupant then
			local throttle = seat.Throttle
			steer = seat.Steer

			local target = throttle * maxSpeed
			local rate = (math.abs(target) > math.abs(speed)) and 26 or 48
			speed = speed + math.clamp(target - speed, -rate * dt, rate * dt)
			if math.abs(speed) < 0.4 then speed = 0 end

			if math.abs(speed) > 1 then
				local turnRate = 2.1 * (speed >= 0 and 1 or -1)
					* math.clamp(math.abs(speed) / maxSpeed, 0.25, 1)
				heading = heading - steer * turnRate * dt
			end
		else
			speed = 0
		end

		local look = Vector3.new(-math.sin(heading), 0, -math.cos(heading))

		-- 1) ¿pared enfrente?
		if math.abs(speed) > 0.5 then
			local dir = (speed >= 0) and look or -look
			local hit = Workspace:Raycast(pos - Vector3.new(0, 0.9, 0), dir * 3.4, rp)
			if hit and hit.Normal.Y < 0.5 then
				speed = 0
			end
		end

		-- 2) a donde queremos avanzar
		local newPos = pos + look * (speed * dt)

		-- 3) buscar el piso debajo del destino
		local down = Workspace:Raycast(
			newPos + Vector3.new(0, MAX_STEP + 1, 0),
			Vector3.new(0, -80, 0), rp)

		if down then
			local groundY = down.Position.Y + RIDE_H
			if groundY - pos.Y > MAX_STEP then
				-- el "piso" de adelante esta demasiado alto: es una pared
				-- o un edificio. No avanzamos ni nos elevamos.
				newPos = pos
				speed = 0
			else
				newPos = Vector3.new(newPos.X, groundY, newPos.Z)
			end
			vertVel = 0
		else
			-- en el aire: cae
			vertVel = vertVel - GRAVITY * dt
			newPos = newPos + Vector3.new(0, vertVel * dt, 0)
		end

		pos = newPos

		-- 4) colocar la bici
		local targetLean = -steer * math.clamp(math.abs(speed) / maxSpeed, 0, 1) * 0.28
		lean = lean + (targetLean - lean) * math.min(1, dt * 8)
		chassis.CFrame = CFrame.new(pos)
			* CFrame.Angles(0, heading, 0)
			* CFrame.Angles(0, 0, lean)
		-- 5) todas las piezas siguen al chasis
		local cf = chassis.CFrame
		for _, r in ipairs(rigidParts) do
			r.part.CFrame = cf * r.off
		end

		-- 6) las ruedas ademas giran
		spin = spin + speed * dt * 0.75
		for _, w in ipairs(wheelParts) do
			local wcf = chassis.CFrame * CFrame.new(w.offset)
				* CFrame.Angles(spin, 0, 0)
			w.wheel.CFrame = wcf
			w.rim.CFrame = wcf
		end
	end)

	model.AncestryChanged:Connect(function(_, parent)
		if not parent and conn then conn:Disconnect() end
	end)

	return true, "Tu bicicleta esta afuera de la bodega"
end

----------------------------------------------------------------------
-- CAJA FUERTE
----------------------------------------------------------------------
-- Todo lo que produces vive aqui. Para vender tienes que venir por ello.
-- Lo que esta adentro esta a salvo de Aduanas.

local function nearVault(player: Player): boolean
	local wh = warehouses[player]
	local vault = wh and wh:FindFirstChild("VaultBody", true)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (vault and hrp) then return false end
	return (hrp.Position - vault.Position).Magnitude <= Config.Carry.VaultRadius
end

-- saca producto de la caja y te lo echas encima
local function vaultWithdraw(player: Player, kind: string, amount: number)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end
	if not nearVault(player) then return false, "Acercate a tu caja fuerte" end

	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then return false, "Cantidad invalida" end

	local field = (kind == "blocks") and "Blocks" or "Leaves"
	local carryField = (kind == "blocks") and "CarryBlocks" or "CarryLeaves"
	local nice = (kind == "blocks") and "bloques" or "hojas"

	local have = profile[field] or 0
	if have <= 0 then return false, "No tienes " .. nice .. " en la caja" end

	-- no puedes sacar mas de lo que hay ni mas de lo que te cabe
	local space = carryCap(profile) - carried(profile)
	if space <= 0 then return false, "Ya vas lleno. Compra una mochila mas grande" end

	local take = math.min(amount, have, space)
	profile[field] = have - take
	profile[carryField] = (profile[carryField] or 0) + take

	push(player)
	return true, string.format("Sacaste %d %s", take, nice)
end

-- guarda en la caja lo que traes encima
local function vaultDeposit(player: Player, kind: string, amount: number)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end
	if not nearVault(player) then return false, "Acercate a tu caja fuerte" end

	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then return false, "Cantidad invalida" end

	local field = (kind == "blocks") and "Blocks" or "Leaves"
	local carryField = (kind == "blocks") and "CarryBlocks" or "CarryLeaves"
	local nice = (kind == "blocks") and "bloques" or "hojas"

	local have = profile[carryField] or 0
	if have <= 0 then return false, "No traes " .. nice .. " encima" end

	local cap = (kind == "blocks") and vaultBlockCap(profile) or vaultLeafCap(profile)
	local space = cap - (profile[field] or 0)
	if space <= 0 then
		return false, string.format("Tu caja no admite mas %s (%d/%d)", nice, cap, cap)
	end

	local put = math.min(amount, have, space)
	profile[carryField] = have - put
	profile[field] = (profile[field] or 0) + put

	push(player)
	return true, string.format("Guardaste %d %s", put, nice)
end

local function buyBackpack(player: Player, id: string)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end
	if profile.Backpack == id then return false, "Ya tienes esa mochila" end

	for i, b in ipairs(Config.Carry.Backpacks) do
		if b.Id == id then
			-- no dejar comprar una mas chica que la que ya traes
			local curCap = carryCap(profile)
			if b.Capacity <= curCap then
				return false, "Ya tienes una mas grande"
			end
			if profile.Cash < b.Cost then
				return false, "Te faltan $" .. Config.Abbrev(b.Cost - profile.Cash)
			end
			profile.Cash -= b.Cost
			profile.Backpack = id
			push(player); syncLeaderstats(player)
			return true, "Compraste: " .. b.Name .. " (cargas " .. b.Capacity .. ")"
		end
	end
	return false, "mochila invalida"
end

local function buyVehicle(player: Player, id: string)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end
	if profile.Vehicles[id] then return false, "Ya tienes ese vehiculo" end

	for _, v in ipairs(Config.Vehicles) do
		if v.Id == id then
			if profile.Cash < v.Cost then return false, "Te faltan $" .. Config.Abbrev(v.Cost - profile.Cash) end
			profile.Cash -= v.Cost
			profile.Vehicles[id] = true
			push(player); syncLeaderstats(player)
			if syncGarage then pcall(syncGarage, player) end
			return true, "Compraste: " .. v.Name .. " (esta en tu garaje)"
		end
	end
	return false, "vehiculo invalido"
end

local function buyProperty(player: Player, id: string)
	local profile = DataService.Get(player)
	if not profile then return false, "sin perfil" end
	if profile.Properties[id] then return false, "Ya tienes esa propiedad" end

	for _, p in ipairs(Config.Properties) do
		if p.Id == id then
			if profile.Cash < p.Cost then return false, "Te faltan $" .. Config.Abbrev(p.Cost - profile.Cash) end
			profile.Cash -= p.Cost
			profile.Properties[id] = true
			push(player); syncLeaderstats(player)
			return true, "Compraste: " .. p.Name
		end
	end
	return false, "propiedad invalida"
end

-- spawnea un carro simple manejable
----------------------------------------------------------------------
-- GARAJE
----------------------------------------------------------------------
-- Los autos que compras se quedan estacionados en su cajon. Al sacarlos,
-- el de adelante desaparece del cajon y aparece uno manejable afuera.

local parkedCars: {[Player]: {Model}} = {}

-- carroceria decorativa (sin fisica), para el auto estacionado
local function buildParkedCar(info: any, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Parked_" .. info.Id

	local function pc(name, size, off, col, mat, shape)
		local pp = Instance.new("Part")
		pp.Name = name
		pp.Size = size
		pp.CFrame = cf * CFrame.new(off)
		pp.Color = col
		pp.Material = mat or Enum.Material.SmoothPlastic
		if shape then pp.Shape = shape end
		pp.Anchored = true
		pp.CanCollide = false
		pp.Parent = m
		return pp
	end

	local col = info.Color or Color3.fromRGB(150, 40, 40)
	local body = pc("Body", Vector3.new(8, 2.6, 16), Vector3.new(0, 2.6, 0), col)
	m.PrimaryPart = body
	pc("Cabin", Vector3.new(7, 2.4, 7.5), Vector3.new(0, 5.1, -0.6), col)
	pc("Glass", Vector3.new(7.1, 1.5, 7.6), Vector3.new(0, 5.6, -0.6),
		Color3.fromRGB(120, 155, 175), Enum.Material.Glass)
	pc("Hood", Vector3.new(7.6, 0.4, 5), Vector3.new(0, 3.9, 5.2),
		Color3.fromRGB(36, 36, 40))
	for _, lx in ipairs({-2.6, 2.6}) do
		pc("Headlight", Vector3.new(1.6, 0.8, 0.3), Vector3.new(lx, 3.2, 8),
			Color3.fromRGB(255, 244, 210), Enum.Material.Neon)
		pc("Taillight", Vector3.new(1.4, 0.7, 0.3), Vector3.new(lx, 3.2, -8),
			Color3.fromRGB(215, 60, 50), Enum.Material.Neon)
	end
	for _, off in ipairs({
		Vector3.new(-4.1, 1.5, 5), Vector3.new(4.1, 1.5, 5),
		Vector3.new(-4.1, 1.5, -5), Vector3.new(4.1, 1.5, -5)}) do
		pc("Wheel", Vector3.new(1, 3, 3), off, Color3.fromRGB(28, 28, 32),
			Enum.Material.Rubber, Enum.PartType.Cylinder)
	end
	return m
end

function syncGarage(player: Player)
	local profile = DataService.Get(player)
	local wh = warehouses[player]
	if not (profile and wh and wh.Parent) then return end

	for _, d in ipairs(wh:GetDescendants()) do
		if d:IsA("Model") and string.sub(d.Name, 1, 7) == "Parked_" then d:Destroy() end
	end
	for _, m in ipairs(parkedCars[player] or {}) do
		if m and m.Parent then m:Destroy() end
	end
	parkedCars[player] = {}

	-- el que anda afuera no se estaciona
	local out = Workspace:FindFirstChild("Car_" .. player.UserId)
	local outId = out and out:GetAttribute("VehicleId")

	for _, v in ipairs(Config.Vehicles) do
		if profile.Vehicles[v.Id] and v.Id ~= outId then
			local bay = wh:FindFirstChild("Bay" .. (v.Bay or 1), true)
			if bay then
				local cf = CFrame.new(bay.Position + Vector3.new(0, 0, 0))
				local ok, m = pcall(function() return buildParkedCar(v, cf) end)
				if ok and m then
					m.Parent = wh
					table.insert(parkedCars[player], m)
				end
			end
		end
	end
end

local function spawnVehicle(player: Player, id: string)
	local profile = DataService.Get(player)
	if not profile or not profile.Vehicles[id] then return false, "No tienes ese vehiculo" end

	local info
	for _, v in ipairs(Config.Vehicles) do if v.Id == id then info = v end end
	if not info then return false, "invalido" end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false, "sin personaje" end

	local old = Workspace:FindFirstChild("Car_" .. player.UserId)
	if old then old:Destroy() end

	local model = Instance.new("Model")
	model.Name = "Car_" .. player.UserId
	model:SetAttribute("VehicleId", id)

	-- Sale por la rampa del garaje, no de la nada junto a ti.
	local wh0 = warehouses[player]
	local exit = wh0 and wh0:FindFirstChild("GarageExit", true)
	local baseCF = exit and CFrame.new(exit.Position + Vector3.new(0, 3, 0))
		or (hrp.CFrame * CFrame.new(0, 2, -14))

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(8, 3, 16)
	body.CFrame = baseCF
	body.Color = Color3.fromRGB(150, 40, 40)
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model
	model.PrimaryPart = body

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(4, 1, 4)
	seat.CFrame = body.CFrame * CFrame.new(0, 2, 0)
	seat.MaxSpeed = info.Speed
	seat.Torque = 40
	seat.TurnSpeed = 18
	seat.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = seat
	weld.Part1 = body
	weld.Parent = seat

	for _, off in ipairs({Vector3.new(-4.2,-1.5,5), Vector3.new(4.2,-1.5,5), Vector3.new(-4.2,-1.5,-5), Vector3.new(4.2,-1.5,-5)}) do
		local w = Instance.new("Part")
		w.Shape = Enum.PartType.Ball
		w.Size = Vector3.new(3, 3, 3)
		w.Color = Color3.fromRGB(30, 30, 30)
		w.CFrame = body.CFrame * CFrame.new(off)
		w.Parent = model

		local att0 = Instance.new("Attachment", body)
		att0.Position = off
		local att1 = Instance.new("Attachment", w)

		local hinge = Instance.new("HingeConstraint")
		hinge.Attachment0 = att0
		hinge.Attachment1 = att1
		hinge.Parent = body
	end

	body.Color = info.Color or Color3.fromRGB(150, 40, 40)
	model.Parent = Workspace

	-- el cajon queda vacio mientras el auto anda afuera
	if syncGarage then pcall(syncGarage, player) end
	return true, "Sacaste tu " .. info.Name .. " del garaje"
end

----------------------------------------------------------------------
-- ROUTER DE ACCIONES
----------------------------------------------------------------------
local cooldowns: {[Player]: number} = {}

RF_Action.OnServerInvoke = function(player: Player, action: string, arg1: any, arg2: any)
	-- anti spam
	local now = os.clock()
	if cooldowns[player] and now - cooldowns[player] < 0.08 then
		return {ok = false, msg = "Mas despacio"}
	end
	cooldowns[player] = now

	if type(action) ~= "string" then return {ok = false, msg = "accion invalida"} end

	local ok, msg
	if action == "sync" then
		-- el cliente acaba de cargar y pide su estado
		if not DataService.Get(player) then
			setupPlayer(player)
		end
		push(player)
		if sendMission then pcall(sendMission, player) end
		return {ok = true}
	elseif action == "harvest" then ok, msg = doHarvest(player)
	elseif action == "press" then ok, msg = doPress(player)
	elseif action == "sell" then ok, msg = doSell(player, tostring(arg1))
	elseif action == "buyPlot" then ok, msg = buyPlot(player)
	elseif action == "upgradePress" then ok, msg = upgradePress(player)
	elseif action == "hire" then ok, msg = hire(player, tostring(arg1))
	elseif action == "buyVehicle" then ok, msg = buyVehicle(player, tostring(arg1))
	elseif action == "buyProperty" then ok, msg = buyProperty(player, tostring(arg1))
	elseif action == "spawnVehicle" then ok, msg = spawnVehicle(player, tostring(arg1))
	elseif action == "upgradeWarehouse" then ok, msg = upgradeWarehouse(player)
	elseif action == "spawnBike" then ok, msg = spawnBike(player)
	elseif action == "withdraw" then ok, msg = vaultWithdraw(player, arg1, arg2)
	elseif action == "deposit" then ok, msg = vaultDeposit(player, arg1, arg2)
	elseif action == "buyBackpack" then ok, msg = buyBackpack(player, arg1)
	elseif action == "answerCall" then ok, msg = answerCall(player, arg1 == true)
	elseif action == "hangUp" then hangUp(player); ok, msg = true, "Colgaste"
	elseif action == "createCrew" then ok, msg = createCrew(player, tostring(arg1))
	elseif action == "joinCrew" then ok, msg = joinCrew(player, tostring(arg1))
	elseif action == "leaveCrew" then ok, msg = leaveCrew(player)
	elseif action == "teleportHome" then
		local wh = warehouses[player]
		if not wh then
			-- red de seguridad: si por lo que sea no tiene bodega, asignala
			wh = assignWarehouse(player)
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			ok, msg = false, "Tu personaje no esta listo"
		elseif wh and wh.PrimaryPart then
			hrp.CFrame = wh.PrimaryPart.CFrame + Vector3.new(0, 8, 0)
			ok, msg = true, "En tu bodega"
		else
			ok, msg = false, "No se encontro tu bodega"
		end
	else
		ok, msg = false, "Accion desconocida"
	end

	-- sonido segun lo que se hizo
	if ok then
		local SFX_BY_ACTION = {
			harvest = "Harvest",
			press = "Press",
			sell = "Sell",
			upgradeWarehouse = "Upgrade",
			buyPlot = "Buy",
			upgradePress = "Buy",
			hire = "Buy",
			buyVehicle = "Buy",
			buyProperty = "Buy",
			buyBackpack = "Buy",
			withdraw = "Buy",
			deposit = "Buy",
		}
		local key = SFX_BY_ACTION[action]
		if key then sfx(player, key) end
	elseif msg then
		sfx(player, "Error")
	end

	if msg then toast(player, msg, ok and "good" or "bad") end
	return {ok = ok, msg = msg}
end

-- respaldo: re-sincroniza a todos cada 5s por si un cliente perdio un push
task.spawn(function()
	while true do
		task.wait(5)
		for _, pl in ipairs(Players:GetPlayers()) do
			if DataService.Get(pl) then push(pl) end
		end
	end
end)

----------------------------------------------------------------------
-- TAPETE DE MEJORAS (el escritorio con la computadora)
----------------------------------------------------------------------
-- Si te paras en el tapete amarillo, se abre solo el panel de mejoras.
-- Usa histeresis (5 para entrar, 9 para salir) para que no parpadee
-- cuando te quedas justo en la orilla.
local onPad: {[Player]: boolean} = {}
local onVaultPad: {[Player]: boolean} = {}

task.spawn(function()
	while true do
		task.wait(0.4)
		for _, pl in ipairs(Players:GetPlayers()) do
			local model = warehouses[pl]
			local char = pl.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local pad = model and model:FindFirstChild("UpgradePad", true)
			local vpad = model and model:FindFirstChild("VaultPad", true)

			if hrp and pad then
				local d = (hrp.Position - pad.Position).Magnitude
				if d < 5 and not onPad[pl] then
					onPad[pl] = true
					RE_OpenUp:FireClient(pl)
				elseif d > 9 and onPad[pl] then
					onPad[pl] = false
				end
			else
				onPad[pl] = nil
			end

			-- mismo truco para el tapete de la caja fuerte
			if hrp and vpad then
				local d = (hrp.Position - vpad.Position).Magnitude
				if d < 6 and not onVaultPad[pl] then
					onVaultPad[pl] = true
					RE_OpenVault:FireClient(pl)
				elseif d > 10 and onVaultPad[pl] then
					onVaultPad[pl] = false
				end
			else
				onVaultPad[pl] = nil
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(pl)
	onPad[pl] = nil
	onVaultPad[pl] = nil
end)

----------------------------------------------------------------------
-- TERRITORIOS
----------------------------------------------------------------------
-- Cada zona de compradores se puede tomar. Te paras dentro del radio y
-- aguantas; si hay gente de otro crew tambien adentro, la zona queda EN
-- DISPUTA y nadie avanza hasta que se corran a balazos.

local TR = Config.Territories
-- [buyerId] = {CrewId, CrewName, Color, Progress, ByCrew, Contested}
local territories: {[string]: any} = {}

for _, b in ipairs(Config.Buyers) do
	territories[b.Id] = {
		CrewId = nil, CrewName = nil, Color = nil,
		Progress = 0, ByCrew = nil, Contested = false,
	}
end

-- cuanto vale de mas vender en tu propia zona
function territoryBonus(player: Player, buyerId: string): number
	if not TR.Enabled then return 0 end
	local profile = DataService.Get(player)
	local t = territories[buyerId]
	if not (profile and profile.CrewId and t and t.CrewId) then return 0 end
	if t.CrewId ~= profile.CrewId then return 0 end
	return TR.PriceBonus
end

local function buyerPad(buyerId: string): BasePart?
	local buyers = city and city:FindFirstChild("Buyers")
	local pad = buyers and buyers:FindFirstChild(buyerId)
	return (pad and pad:IsA("BasePart")) and pad or nil
end

local function paintFlag(buyerId: string)
	local t = territories[buyerId]
	local flag = city and city:FindFirstChild("Flag_" .. buyerId, true)
	if not (t and flag) then return end

	local col = t.Color or Color3.fromRGB(120, 124, 132)
	flag.Color = col
	local zl = flag:FindFirstChild("ZoneLight")
	if zl then zl.Color = col end

	local sign = flag:FindFirstChild("OwnerSign")
	local lbl = sign and sign:FindFirstChild("OwnerText")
	if lbl then
		local info
		for _, b in ipairs(Config.Buyers) do
			if b.Id == buyerId then info = b end
		end
		local zone = info and info.Name or buyerId
		if t.Contested then
			lbl.Text = zone .. "\nEN DISPUTA"
			lbl.TextColor3 = Color3.fromRGB(255, 190, 90)
		elseif t.CrewName then
			lbl.Text = zone .. "\n" .. string.upper(t.CrewName)
			lbl.TextColor3 = col
		else
			lbl.Text = zone .. "\nSIN DUEÑO"
			lbl.TextColor3 = Color3.fromRGB(215, 215, 225)
		end
	end
end

local function pushTerritories()
	local snapshot = {}
	for _, b in ipairs(Config.Buyers) do
		local t = territories[b.Id]
		table.insert(snapshot, {
			Id = b.Id,
			Name = b.Name,
			CrewName = t.CrewName,
			Contested = t.Contested,
			Progress = math.floor((t.Progress / TR.CaptureSeconds) * 100),
		})
	end
	RE_Terr:FireAllClients(snapshot)
end

if TR.Enabled then
	-- ===== BUCLE DE CAPTURA =====
	task.spawn(function()
		while true do
			task.wait(1)
			local dirty = false

			for _, b in ipairs(Config.Buyers) do
				local t = territories[b.Id]
				local pad = buyerPad(b.Id)
				if pad then
					-- quien esta dentro, agrupado por crew
					local present: {[string]: number} = {}
					local anyLoner = false
					for _, pl in ipairs(Players:GetPlayers()) do
						local prof = DataService.Get(pl)
						local ch = pl.Character
						local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
						local hum = ch and ch:FindFirstChildOfClass("Humanoid")
						if prof and hrp and hum and hum.Health > 0
							and (hrp.Position - pad.Position).Magnitude <= TR.Radius then
							if prof.CrewId then
								present[prof.CrewId] = (present[prof.CrewId] or 0) + 1
							else
								anyLoner = true
							end
						end
					end

					local crewsIn = 0
					local soloCrew = nil
					for cid in pairs(present) do
						crewsIn += 1
						soloCrew = cid
					end

					local wasContested = t.Contested
					t.Contested = (crewsIn > 1)
						or (crewsIn == 1 and anyLoner and soloCrew ~= t.CrewId)

					if t.Contested then
						-- nadie avanza mientras haya bronca
					elseif crewsIn == 1 and soloCrew ~= t.CrewId then
						t.ByCrew = soloCrew
						t.Progress += 1
						if t.Progress >= TR.CaptureSeconds then
							local crew = crews[soloCrew]
							t.CrewId = soloCrew
							t.CrewName = crew and crew.Name or "?"
							t.Color = crew and crew.Color or nil
							t.Progress = 0
							t.ByCrew = nil
							paintFlag(b.Id)
							for _, pl in ipairs(Players:GetPlayers()) do
								local prof = DataService.Get(pl)
								if prof and prof.CrewId == soloCrew then
									alert(pl, "TERRITORIO TOMADO",
										"Tu crew ahora controla " .. b.Name .. ".", "good")
								elseif prof and prof.CrewId then
									alert(pl, "PERDIERON UNA PLAZA",
										(t.CrewName or "Otro crew") .. " tomo " .. b.Name .. ".",
										"danger")
								end
							end
						end
						dirty = true
					else
						if t.Progress > 0 then
							t.Progress = math.max(0, t.Progress - TR.DecayPerSecond)
							dirty = true
						end
					end

					if wasContested ~= t.Contested then
						paintFlag(b.Id)
						dirty = true
					end
				end
			end

			if dirty then pushTerritories() end
		end
	end)

	-- ===== RENTA DE TERRITORIOS =====
	task.spawn(function()
		while true do
			task.wait(TR.IncomeInterval)
			local perCrew: {[string]: number} = {}
			for _, b in ipairs(Config.Buyers) do
				local t = territories[b.Id]
				if t.CrewId then
					perCrew[t.CrewId] = (perCrew[t.CrewId] or 0) + TR.IncomePer
				end
			end
			for _, pl in ipairs(Players:GetPlayers()) do
				local prof = DataService.Get(pl)
				if prof and prof.CrewId and perCrew[prof.CrewId] then
					local inc = perCrew[prof.CrewId]
					prof.Cash += inc
					push(pl); syncLeaderstats(pl)
					alert(pl, "Plaza", string.format(
						"Tus territorios dejaron $%s.", Config.Abbrev(inc)), "money")
				end
			end
		end
	end)

	-- estado inicial para quien acaba de entrar
	task.spawn(function()
		while true do
			task.wait(10)
			pushTerritories()
		end
	end)
end

print("[SpiceEmpire] Servidor listo.")
