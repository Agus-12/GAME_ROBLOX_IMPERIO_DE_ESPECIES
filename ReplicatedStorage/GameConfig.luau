--!strict
-- ===== RONDA: v42 =====   <-- Ctrl+F con este texto para saber si este archivo
--                             es el de la ronda nueva (docs/09-SI-SALE-DOBLE.md)
-- ModuleScript -> ReplicatedStorage.GameConfig
-- Todos los numeros del juego viven aqui. Cambia esto para balancear.

local GameConfig = {}

-- ========== VERSION ==========
-- Numero de la ronda. El servidor lo estampa en la carpeta Remotes, el cliente
-- lo compara con el suyo, y si no coinciden sale un CARTEL EN PANTALLA diciendo
-- que archivo quedo viejo. Esto salio de un caso real: el usuario tenia el
-- ClientUI nuevo con un Main.luau de hace 8 rondas, y lo unico que veia era
-- "faltan remotes" sin ninguna pista de que pegar.
-- Al subir de ronda: cambia esto, MI_VERSION en ClientUI.luau y CAMBIOS-vN.md.
GameConfig.Build = "v42"

-- ========== ECONOMIA ==========
GameConfig.StartingCash = 500

GameConfig.Products = {
	Leaf = {
		Name = "Hoja de Especia",
		Color = Color3.fromRGB(86, 168, 72),
		BasePrice = 25,      -- precio base de venta por unidad
		GrowTime = 8,        -- segundos que tarda una parcela en dar hoja
		StackSize = 50,
	},
	Block = {
		Name = "Bloque Prensado",
		Color = Color3.fromRGB(222, 206, 170),
		BasePrice = 180,
		PressCost = 6,       -- hojas necesarias para 1 bloque
		PressTime = 5,       -- segundos por prensada
		StackSize = 25,
	},
}

-- ========== PRODUCCION ==========
GameConfig.Plots = {
	StartingPlots = 2,
	MaxPlots = 12,
	-- costo del plot N = BaseCost * (Growth ^ (N - StartingPlots))
	BaseCost = 750,
	Growth = 1.45,
}

-- ========== CRECIMIENTO DE PLANTAS ==========
-- Cada planta crece sola. 0 = recien cosechada, 1 = lista.
GameConfig.Growth = {
	-- segundos que tarda UNA planta en ir de 0 a lista
	TimePerPlant = 24,
	-- que tan cerca tienes que estar de la mesa para cosecharla con E.
	-- OJO: las mesas estan a 18 studs una de otra, asi que esto tiene que
	-- ser MENOR a 18 o cosechas varias mesas de un solo golpe.
	HarvestRadius = 14,
	-- hojas que da cada planta madura (6 macetas por mesa = 6 hojas)
	LeavesPerPlant = 1,
	-- colores por etapa (brote -> madura)
	StageColors = {
		Color3.fromRGB(150, 170, 90),   -- brote amarillento
		Color3.fromRGB(120, 175, 80),
		Color3.fromRGB(96, 178, 80),
		Color3.fromRGB(70, 200, 85),    -- madura, verde fuerte
	},
}

GameConfig.Press = {
	StartingLevel = 1,
	MaxLevel = 10,
	BaseCost = 1200,
	Growth = 1.6,
	-- cada nivel reduce PressTime 8% y sube output
	SpeedPerLevel = 0.08,
	OutputPerLevel = 1,
	-- que tan cerca tienes que estar de la maquina para poder prensar a mano
	UseRadius = 14,
}

-- ========== CARGA DEL JUGADOR / MOCHILAS ==========
-- Lo que produces se guarda en la CAJA FUERTE de la bodega, no en tu
-- inventario. Para vender tienes que ir a la caja y sacar producto.
-- Aduanas solo te puede incautar lo que traigas cargando.
GameConfig.Carry = {
	BaseCapacity = 80,      -- cuanto cargas sin mochila
	VaultRadius = 16,       -- que tan cerca de la caja para poder usarla

	-- Se compran en la tienda, pestana Bodega. Cada una reemplaza a la anterior.
	Backpacks = {
		{Id = "morral",  Name = "Morral",           Cost = 2500,   Capacity = 180},
		{Id = "duffel",  Name = "Maleta de lona",   Cost = 12000,  Capacity = 400},
		{Id = "carrito", Name = "Diablito de carga", Cost = 55000,  Capacity = 900},
		{Id = "contene", Name = "Contenedor rodante", Cost = 250000, Capacity = 2000},
	},
}

-- ========== NIVELES DE BODEGA ==========
-- Empiezas en un garage cochambroso y terminas en una mega procesadora.
GameConfig.WarehouseTiers = {
	{
		Level = 1, Name = "Garage",
		Cost = 0,
		Size = Vector3.new(70, 20, 56),
		Plots = 4,            -- parcelas visibles en este nivel
		VaultLeaves = 100,   -- tope de HOJAS en la caja
		VaultBlocks = 50,    -- tope de BLOQUES en la caja
		WallColor = Color3.fromRGB(120, 112, 100),
		FloorColor = Color3.fromRGB(88, 86, 84),
		Desc = "Un garage rentado. Huele a humedad.",
	},
	{
		Level = 2, Name = "Bodega",
		Cost = 15000,
		Size = Vector3.new(100, 26, 78),
		Plots = 8,
		VaultLeaves = 250,   -- tope de HOJAS en la caja
		VaultBlocks = 120,    -- tope de BLOQUES en la caja
		WallColor = Color3.fromRGB(134, 126, 112),
		FloorColor = Color3.fromRGB(96, 94, 92),
		Desc = "Ya cabe maquinaria. Vas bien.",
	},
	{
		Level = 3, Name = "Almacen Industrial",
		Cost = 120000,
		Size = Vector3.new(140, 34, 104),
		Plots = 12,
		VaultLeaves = 600,   -- tope de HOJAS en la caja
		VaultBlocks = 300,    -- tope de BLOQUES en la caja
		WallColor = Color3.fromRGB(108, 116, 124),
		FloorColor = Color3.fromRGB(78, 82, 88),
		Desc = "Techo alto, montacargas, turnos de noche.",
	},
	{
		Level = 4, Name = "Mega Procesadora",
		Cost = 600000,
		Size = Vector3.new(190, 46, 140),
		Plots = 12,
		VaultLeaves = 1500,   -- tope de HOJAS en la caja
		VaultBlocks = 800,    -- tope de BLOQUES en la caja
		WallColor = Color3.fromRGB(70, 82, 96),
		FloorColor = Color3.fromRGB(58, 62, 70),
		Desc = "Ya no es un negocio. Es un imperio.",
	},
}

-- ========== VEHICULO INICIAL ==========
GameConfig.StarterBike = {
	Enabled = true,
	Name = "Bicicleta",
	Speed = 42,
	Color = Color3.fromRGB(180, 70, 60),
}

-- ========== EMPLEADOS ==========
GameConfig.Employees = {
	-- OJO: los cosechadores son UNO POR MESA. El maximo real no es este
	-- numero, es cuantas mesas tenga tu bodega (Max aqui es solo el tope
	-- absoluto del ultimo nivel). Cada uno se para en SU mesa y corta
	-- unicamente las plantas maduras de esa mesa.
	Harvester = {
		Name = "Cosechador",
		BaseCost = 1500,
		Growth = 1.55,
		Max = 12,       -- = mesas de la Mega Procesadora
		Interval = 8,   -- cada cuanto revisa su mesa
		PerCycle = 2,   -- cuantas plantas maduras corta por revision
	},
	Presser = {
		Name = "Prensador",
		BaseCost = 4000,
		Growth = 1.65,
		Max = 6,
		Interval = 12,
		PerCycle = 1,   -- bloques que produce por ciclo
	},
	Guard = {
		Name = "Guardia",
		BaseCost = 6000,
		Growth = 1.7,
		Max = 5,
		-- cada guardia reduce 12% la probabilidad de asalto a tu bodega
		RaidReduction = 0.12,
	},

	-- Tus trabajadores siguen produciendo cuando no estas conectado,
	-- pero solo se te acreditan hasta estas horas (para que no se rompa
	-- la economia si te desapareces una semana).
	OfflineMaxHours = 8,
}

-- ========== HEAT / POLICIA (Unidad de Aduanas) ==========
GameConfig.Heat = {
	Max = 100,
	PerLeafSold = 0.25,
	PerBlockSold = 2.0,
	DecayPerSecond = 0.6,     -- baja solo con el tiempo
	ArrestThreshold = 70,     -- arriba de esto, la Unidad te persigue
	FineRate = 0.18,          -- % de cash que pierdes si te agarran
	ConfiscatePercent = 0.5,  -- % de inventario confiscado
	JailTime = 20,            -- segundos
	LayLowRate = 3.0,         -- heat/seg que baja si estas en tu bodega quieto
}

-- ========== AGENTES DE ADUANAS (NPC que te persiguen) ==========
GameConfig.Agents = {
	Enabled = true,
	MaxActive = 3,            -- cuantos agentes maximo a la vez
	SpawnHeat = 55,           -- heat al que empiezan a salir
	SpawnDistance = 120,      -- a que distancia de ti aparecen
	WalkSpeed = 19,           -- un poco mas rapido que el jugador (16)
	CatchDistance = 8,        -- a esta distancia te detienen
	GiveUpDistance = 320,     -- si te alejas tanto, se rinden
	GiveUpTime = 45,          -- o si pasan tantos segundos sin agarrarte
	RepathInterval = 1.2,     -- cada cuanto recalculan tu posicion
	Health = 120,             -- se pueden tumbar a balazos
	ShirtColor = Color3.fromRGB(38, 52, 92),
	VestColor = Color3.fromRGB(28, 34, 58),
}

-- ========== ENCARGOS / MISIONES ==========
GameConfig.Missions = {
	Enabled = true,
	CooldownAfterFinish = 25,   -- segundos antes de ofrecer otra
	MaxActive = 1,

	Templates = {
		{
			Id = "rush_blocks",
			Title = "Entrega urgente",
			Desc = "El cliente quiere %d bloques en %s. Tienes %d min.",
			Kind = "deliver",
			Item = "Blocks",
			AmountMin = 3, AmountMax = 8,
			TimeLimit = 180,
			RewardMult = 2.2,      -- paga x veces el valor normal
			HeatMult = 0.6,        -- genera menos heat de lo normal
		},
		{
			Id = "bulk_leaves",
			Title = "Pedido a granel",
			Desc = "Necesitan %d hojas en %s. Tienes %d min.",
			Kind = "deliver",
			Item = "Leaves",
			AmountMin = 40, AmountMax = 120,
			TimeLimit = 240,
			RewardMult = 1.9,
			HeatMult = 0.5,
		},
		{
			Id = "hot_run",
			Title = "Entrega caliente",
			Desc = "Zona vigilada. %d bloques en %s. %d min. Paga bien.",
			Kind = "deliver",
			Item = "Blocks",
			AmountMin = 5, AmountMax = 12,
			TimeLimit = 150,
			RewardMult = 3.4,
			HeatMult = 1.8,        -- mucho heat, mucho dinero
		},
	},
}

-- ========== LLAMADAS DE ENCARGO ==========
-- En vez de aparecer solo, el encargo te LLAMA al celular y decides.
GameConfig.MissionCalls = {
	Enabled = true,
	-- rango de espera entre llamadas (segundos). 5 a 10 minutos.
	MinWait = 300,
	MaxWait = 600,
	-- primera llamada mas rapida para que no esperes tanto al entrar
	FirstCallWait = 90,
	-- cuanto suena antes de colgarse solo
	RingSeconds = 20,
	-- si rechazas, espera menos para volver a marcarte
	RejectPenalty = 120,
	CallerName = "DESCONOCIDO",
	Lines = {
		"Hey... tengo una entrega especial para ti. Las ganancias son buenas pero el riesgo es alto.",
		"Escucha bien, solo lo digo una vez. Tengo carga que mover y pagan bien. Hay vigilancia.",
		"Me pasaron tu numero. Necesito a alguien rapido y sin preguntas. La paga vale la pena.",
		"Tengo un cliente impaciente y buen billete de por medio. Pero la zona esta caliente.",
	},
}

-- ========== ASALTOS A TU BODEGA ==========
GameConfig.Raids = {
	CheckInterval = 90,       -- cada cuanto se tira el dado
	BaseChance = 0.18,        -- 18% base
	ChancePerBlock = 0.004,   -- mas inventario = mas atractivo
	WarnSeconds = 25,         -- cuanto avisa el telefono antes
	StealPercent = 0.35,      -- cuanto se llevan si LLEGAN a la caja
	DefendRadius = 60,        -- que tan cerca debes estar para que cuente

	-- ===== EL ASALTO FISICO =====
	-- Ya no es un dado invisible: llegan tipos de verdad, caminan hacia tu
	-- caja fuerte y hay que bajarlos a balazos antes de que la abran.
	RaidersBase = 2,          -- cuantos vienen de entrada
	RaidersPerTier = 1,       -- +1 por nivel de bodega (eres mas jugoso)
	RaiderHealth = 90,
	RaiderSpeed = 13,
	RaiderDamage = 9,         -- lo que te pegan si te les pones enfrente
	RaiderAttackRange = 12,
	RaiderAttackEvery = 1.4,
	CrackSeconds = 16,        -- lo que tardan en abrir la caja al llegar
	MaxRaidSeconds = 120,     -- red de seguridad: a los 2 min se limpia todo

	-- tus guardias contratados se plantan junto a la caja y disparan solos
	GuardDamage = 12,
	GuardRange = 70,
	GuardEvery = 1.3,
}

-- ========== ARMA ==========
GameConfig.Weapon = {
	Name = "Escuadra",
	Damage = 26,
	Range = 260,
	Cooldown = 0.26,
	GiveOnSpawn = true,       -- todos traen una desde que entran
}

-- ========== PVP / CREWS ==========
GameConfig.Crew = {
	MaxMembers = 6,
	NameMaxLength = 16,
	FriendlyFire = false,
	-- al matar a un jugador le robas parte de lo que trae encima
	StealOnKillPercent = 0.4,
	KillCashSteal = 0.1,
}

-- ========== CICLO DIA / NOCHE ==========
GameConfig.DayNight = {
	Enabled = true,          -- ponlo en false para dejar la hora fija
	DayLengthMinutes = 12,   -- minutos reales que dura un dia completo de juego
	StartHour = 14,          -- hora a la que arranca el servidor
	FixedHour = 14,          -- si Enabled = false, se queda en esta hora
}

-- ========== GARAJE (anexo pegado al costado izquierdo) ==========
-- Crece con la bodega: nivel 1 = cajon chico, nivel 4 = taller grande.
-- Cada nivel tiene sus medidas en la lista (1..4 = nivel de bodega).
GameConfig.Garage = {
	-- v42: el garaje ARRANCA CHICO (nivel 1 = 1 cajon) y crece con la bodega.
	-- Antes el nivel 1 ya traia 4 cajones de 44 de ancho: el jugador se perdia
	-- adentro y con 2 autos no cabia para maniobrar ("es muy pequeno").
	Widths  = {26, 44, 52, 68},   -- ancho del anexo por nivel de bodega
	Depths  = {22, 26, 30, 34},   -- fondo
	Heights = {11, 14, 16, 18},   -- alto del techo
	DoorWidth  = 9,               -- ancho del porton de cada cajon
	DoorHeight = 10,              -- alto del porton
	OpenRadius = 9,               -- a que distancia se abre solo el porton
	-- v36: era 20 (se abria desde adentro de la bodega: nunca se veian puertas).
	-- v42: 9. El porton se abre SOLO cuando llegas al frente y se VUELVE A CERRAR
	-- al entrar al garaje (a los 9 studs ya no te ve): asi SIEMPRE se ven las
	-- puertas cerradas, desde adentro y desde lejos, como un porton de verdad.
	-- Ademas cada cajon trae su propio detector (mide la distancia AL CAJON), o
	-- sea que solo se abre el porton de la puerta por la que vas entrando.
	Bays = {1, 2, 3, 4},          -- cajones POR NIVEL de bodega (1 = chico)
	-- Cuantos autos puedes tener segun el nivel: es el mismo numero de cajones.
	MaxCars = {1, 2, 3, 4},
}

-- ========== AMBIENTACION EXTERIOR ==========
-- Adornos de afuera de la bodega (macetas, botes, poste de luz, toldo...).
-- Todo esto se puede apagar sin tocar el codigo.
GameConfig.Ambience = {
	Enabled    = true,   -- si es false, la bodega queda pelona
	LampPosts  = true,   -- poste de luz en el lote (se prende de noche)
	Props      = true,   -- macetas, botes de basura, banquitas
	Roof       = true,   -- aires acondicionados y ventilas en el techo
}

-- ========== CIUDAD (generacion del mapa) ==========
GameConfig.City = {
	BlockSize = 160,      -- tamano de cada cuadra
	RoadWidth = 34,
	GridX = 5,            -- cuadras a lo ancho
	GridZ = 5,            -- cuadras a lo largo
	BuildingsPerBlock = {min = 2, max = 4},
	BuildingHeight = {min = 18, max = 80},
	Seed = 20260923,
}

-- ========== LOTES DE BODEGA ==========
-- Donde se siembran las bodegas de los jugadores, detras de la ciudad.
-- OJO: una bodega NO mide lo que dice su Size. El nivel 4 mide 190 de ancho
-- y ademas se le pegan DOS anexos por fuera: el taller (46 a la izquierda)
-- y la oficina (34 a la derecha). Total real: 271 studs.
-- Con SpacingX = 140 (lo que habia antes) la oficina de uno se metia DENTRO
-- del taller del vecino. Por eso los lotes ahora son una rejilla y el
-- generador estira el suelo para que todos caigan sobre pasto.
GameConfig.WarehouseLots = {
	Enabled = true,
	MaxSlots = 20,
	PerRow = 5,
	-- esquina nor-oeste del primer lote (el mas pegado a la ciudad)
	Origin = Vector3.new(-600, 0, -660),
	SpacingX = 340,          -- > 271 (ancho del nivel 4 con anexos) + pasillo
	SpacingZ = 260,          -- > 156 (fondo del nivel 4 con muelle)
	-- margen extra de pasto alrededor de los lotes
	GroundPad = 90,
	-- medio ancho / medio fondo maximos de una bodega con sus anexos:
	-- los usa buildGround para saber cuanto estirar el suelo
	HalfWidth = 150,
	HalfDepth = 95,
}

-- Compradores repartidos por la ciudad. Multiplicador y riesgo.
GameConfig.Buyers = {
	{Id = "docks",   Name = "Muelles",        PriceMult = 0.85, HeatMult = 0.5, Cell = Vector2.new(0, 0)},
	{Id = "market",  Name = "Mercado Viejo",  PriceMult = 1.00, HeatMult = 1.0, Cell = Vector2.new(4, 0)},
	{Id = "downtown",Name = "Centro",         PriceMult = 1.35, HeatMult = 1.8, Cell = Vector2.new(2, 2)},
	{Id = "uptown",  Name = "Zona Alta",      PriceMult = 1.60, HeatMult = 2.4, Cell = Vector2.new(0, 4)},
	{Id = "border",  Name = "Cruce Norte",    PriceMult = 1.90, HeatMult = 3.2, Cell = Vector2.new(4, 4)},
}

-- ========== TERRITORIOS ==========
-- Cada zona de compradores es un territorio que los crews se pelean.
-- Te paras dentro, aguantas el tiempo de captura y la zona es tuya.
GameConfig.Territories = {
	Enabled = true,
	Radius = 46,             -- que tan grande es la zona
	CaptureSeconds = 25,     -- cuanto hay que aguantar parado
	DecayPerSecond = 1.5,    -- que tan rapido se pierde el avance al salirte
	PriceBonus = 0.20,       -- +20% al vender en tu propio territorio
	IncomePer = 140,         -- renta por territorio
	IncomeInterval = 120,    -- cada cuanto se cobra
	-- colores que se van repartiendo a los crews segun se crean
	CrewColors = {
		Color3.fromRGB(235, 90, 90),
		Color3.fromRGB(90, 150, 255),
		Color3.fromRGB(120, 230, 130),
		Color3.fromRGB(240, 190, 70),
		Color3.fromRGB(200, 120, 245),
		Color3.fromRGB(90, 225, 230),
	},
}

-- ========== DIALOGOS DE NPC ==========
GameConfig.Dialogue = {
	Radius = 22,   -- a que distancia aparece el dialogo

	Greet = {
		"Hey... traes algo para mi?",
		"Que onda. Tienes mercancia?",
		"Llegas tarde. Que me trajiste?",
		"Shhh... habla bajo. Que traes?",
		"Te estaba esperando. Muestrame.",
	},
	Empty = {
		"Vienes con las manos vacias? Largate.",
		"No traes nada. No me hagas perder el tiempo.",
		"Sin mercancia no hay negocio, amigo.",
	},
	Sold = {
		"Buen material. Aqui esta tu parte.",
		"Negocio limpio. Vuelve pronto.",
		"Esto se vende solo. Toma.",
		"Con gusto. Y ni una palabra a nadie.",
	},
	Lookout = {
		"Todo tranquilo por aca, jefe.",
		"Nadie se ha acercado. Sigo al pendiente.",
		"Vi una patrulla dar la vuelta. Ojo.",
		"La mercancia esta segura. Por ahora.",
	},
	Hot = {
		"Traes a la Aduana encima. Vete de aqui.",
		"Estas muy caliente. No te conozco.",
		"Andan preguntando por ti. Desaparece un rato.",
	},
}

-- ========== TIENDAS ==========
GameConfig.Vehicles = {
	-- Bay = en que cajon del garaje se estaciona. Color = pintura.
	{Id = "van",     Name = "Van de Carga",  Cost = 8000,   Speed = 60,  Capacity = 40,
		Bay = 1, Color = Color3.fromRGB(216, 216, 220)},
	{Id = "sedan",   Name = "Sedan Gris",    Cost = 20000,  Speed = 85,  Capacity = 20,
		Bay = 2, Color = Color3.fromRGB(122, 126, 134)},
	{Id = "pickup",  Name = "Pickup Rural",  Cost = 45000,  Speed = 75,  Capacity = 80,
		Bay = 3, Color = Color3.fromRGB(94, 122, 88)},
	{Id = "sport",   Name = "Deportivo",     Cost = 150000, Speed = 130, Capacity = 10,
		Bay = 4, Color = Color3.fromRGB(186, 46, 46)},
}

GameConfig.Properties = {
	{Id = "apto",    Name = "Departamento",   Cost = 25000,  Income = 30,  Storage = 50},
	{Id = "casa",    Name = "Casa Suburbio",  Cost = 90000,  Income = 110, Storage = 150},
	{Id = "bodega2", Name = "Bodega Extra",   Cost = 200000, Income = 0,   Storage = 600},
	{Id = "mansion", Name = "Mansion",        Cost = 750000, Income = 900, Storage = 300},
}
GameConfig.PropertyPayoutInterval = 60

-- ========== DISTANCIAS DE INTERACCION ==========
-- A que distancia de cada maquina aparece su boton. El CLIENTE dibuja el
-- boton con estos numeros y el SERVIDOR valida con los mismos: si se
-- separan, pasa lo peor: el boton sale pero al pulsarlo te dice "estas
-- muy lejos". Antes vivian duplicados (16 en el cliente, 14 en el
-- servidor) y habia 2 studs de zona muerta.
GameConfig.Interact = {
	Computer = 13,   -- computadora del escritorio / mejoras
	Garage   = 26,   -- cajon del garaje
	Buyer    = 30,   -- comprador en la ciudad
	Dialogue = 22,   -- globito de dialogo del NPC
}

-- La caja fuerte tiene un tope POR PRODUCTO (ver VaultLeaves/VaultBlocks
-- en cada nivel de bodega). Esto es solo el piso minimo por si falta el dato.
GameConfig.BaseStorage = 100

-- ========== HELPERS ==========
function GameConfig.CostCurve(base: number, growth: number, owned: number): number
	return math.floor(base * (growth ^ owned))
end

function GameConfig.Abbrev(n: number): string
	local units = {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}
	for _, u in ipairs(units) do
		if n >= u[1] then
			return string.format("%.1f%s", n / u[1], u[2])
		end
	end
	return tostring(math.floor(n))
end

----------------------------------------------------------------------
-- SONIDOS
----------------------------------------------------------------------
-- Estos son sonidos que YA vienen dentro de Roblox, por eso funcionan
-- sin subir nada. Si quieres unos mejores: pestaña "Creador" -> Audio,
-- busca el que te guste, copia su ID y pegalo aqui asi:
--     Harvest = { Id = "rbxassetid://1234567890", Volume = 0.6, Pitch = 1 },
GameConfig.Sounds = {
	Enabled = true,

	-- cortar hojas: hojarasca crujiendo
	Harvest = { Id = "rbxassetid://9114515257", Volume = 0.55, Pitch = 1.20 },
	-- la prensa: marrazo sobre viga de acero
	Press   = { Id = "rbxassetid://9125672726", Volume = 0.50, Pitch = 0.85 },
	-- venta cerrada: caja registradora de verdad
	Sell    = { Id = "rbxassetid://9113728042", Volume = 0.65, Pitch = 1.00 },
	-- comprar / contratar: clic de boton
	Buy     = { Id = "rbxassetid://12221967",   Volume = 0.60, Pitch = 1.00 },
	-- mejorar bodega: monedas cayendo en la maquina
	Upgrade = { Id = "rbxassetid://9113704038", Volume = 0.70, Pitch = 1.00 },
	-- no se pudo: el mismo clic pero grave
	Error   = { Id = "rbxassetid://12221967",   Volume = 0.45, Pitch = 0.55 },
	-- al acercarte a la computadora del escritorio
	Computer  = { Id = "rbxassetid://12221967",   Volume = 0.45, Pitch = 1.40 },
	-- al acercarte a la caja fuerte (mecanismo metalico)
	VaultOpen = { Id = "rbxassetid://9116321214", Volume = 0.55, Pitch = 0.90 },
	-- el disparo de la Escuadra
	Shot      = { Id = "rbxassetid://9125672726", Volume = 0.28, Pitch = 1.85 },
	-- voz de los NPC: un blip corto que suena por letra mientras escriben.
	-- Con el tono aleatorio suena a "guiri guiri guiri" sin decir nada.
	Talk    = { Id = "rbxassetid://16480579431", Volume = 0.28, Pitch = 1.00 },
	-- te agarro Aduanas: esposas
	Arrest  = { Id = "rbxassetid://9114764731", Volume = 0.80, Pitch = 1.00 },

	-- porton de la bodega / del taller: metal subiendo
	Gate    = { Id = "rbxassetid://9125672726", Volume = 0.60, Pitch = 0.55 },
}

return GameConfig
