--!strict
-- ===== RONDA: v49 =====   <-- Ctrl+F con este texto para saber si este archivo
--                             es el de la ronda nueva (docs/09-SI-SALE-DOBLE.md)
-- ModuleScript -> ServerScriptService.CityGenerator
-- Genera la ciudad completa por codigo: calles, cuadras, edificios,
-- puntos de compradores, la bodega del jugador y la estacion de Aduanas.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

local CityGenerator = {}

local C = Config.City
local CELL = C.BlockSize + C.RoadWidth

local rng = Random.new(C.Seed)

-- Todas las luces/neones que deben apagarse de dia se marcan con este tag.
local NIGHT_TAG = "NightLight"
local CollectionService = game:GetService("CollectionService")

-- marca una luz (PointLight/SpotLight) para que el ciclo la apague de dia.
-- v46: si se le da un brillo de DIA, la luz NUNCA se apaga: de dia queda bajita
-- (para que el interior no se vea negro, que fue el reporte de la v42) y de noche
-- se queda en el brillo de noche, SUAVE (el reporte de la v46: "de noche la
-- bodega y la cochera estan demasiado iluminadas por dentro").
local function tagLight(light: Instance, brightness: number, brilloDia: number?)
	light:SetAttribute("NightBrightness", brightness)
	if brilloDia then light:SetAttribute("DayBrightness", brilloDia) end
	CollectionService:AddTag(light, NIGHT_TAG)
end

-- marca una part Neon para que se apague de dia
local function tagNeon(p: BasePart, litColor: Color3, offColor: Color3)
	p:SetAttribute("LitColor", litColor)
	p:SetAttribute("OffColor", offColor)
	CollectionService:AddTag(p, NIGHT_TAG)
end

local PALETTE = {
	Color3.fromRGB(104, 110, 120),
	Color3.fromRGB(128, 120, 108),
	Color3.fromRGB(86, 96, 108),
	Color3.fromRGB(142, 134, 120),
	Color3.fromRGB(96, 88, 84),
	Color3.fromRGB(70, 78, 88),
}

-- asigna una propiedad sin tronar si es solo-lectura o no existe
local function safeSet(obj: Instance, prop: string, value: any)
	local ok = pcall(function()
		(obj :: any)[prop] = value
	end)
	if not ok then
		warn(("[CityGenerator] no se pudo asignar %s (propiedad protegida)"):format(prop))
	end
end

local function part(props: {[string]: any}): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.Concrete
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

-- Centro del mundo de una celda de la grid
function CityGenerator.CellToWorld(cx: number, cz: number): Vector3
	local offX = (C.GridX - 1) * CELL * 0.5
	local offZ = (C.GridZ - 1) * CELL * 0.5
	return Vector3.new(cx * CELL - offX, 0, cz * CELL - offZ)
end

-- OJO (v44): el tamano de un BillboardGui es en PIXELES FIJOS: se ve igual de
-- grandote a un metro que a cien, y con varios juntos tapaban la pantalla (fue el
-- reporte del usuario: "los nombres asi en grandote muy estorboso"). Por eso los
-- rotulos de los edificios ahora van con textoPlano (pegados a la parte) y aqui
-- se les puede pedir un tamano mas chico.
local function makeBillboard(parent: BasePart, text: string, color: Color3,
	height: number?, ancho: number?, alto: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, ancho or 150, 0, alto or 38)
	bb.StudsOffset = Vector3.new(0, height or 6, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 250
	bb.LightInfluence = 0
	bb.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.TextColor3 = color
	lbl.TextStrokeTransparency = 0.2
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	lbl.Text = text
	lbl.Parent = bb
end

-- ===== v44: TEXTO PLANO PEGADO A LA PARTE (lo pidio el usuario) =====
-- El usuario: "en lugar de tener esos textos ahi arriba de los garages, miro como
-- un letrero negro: ahi podemos poner 'garaje de <nombre>' o 'sin propietario'...
-- en el garage vi un letrero flotante de 'caja 1': ahi ya hay uno negro, poner
-- ahi 'caja 1' pero en TEXTO PLANO".
--
-- El problema de fondo: los avisos se hacian con BillboardGui, que se dibuja
-- SIEMPRE del mismo tamano en pantalla (200x50 pixeles, a cualquier distancia):
-- con varios letreros juntos tapaban media pantalla y se encimaban entre si.
-- Un SurfaceGui, en cambio, va PEGADO a la cara de la parte: crece y se encoge
-- con la distancia, como un letrero de verdad. Y sobre el tablero negro que ya
-- existe, se ve igualito a un rotulo pintado.
local function textoPlano(parte: BasePart, texto: string, color: Color3?, opts: {[string]: any}?): SurfaceGui?
	local o = opts or {}

	-- En una parte ALTA (mas alta que ancha, como la torre de Aduanas) el texto no
	-- se estira a lo alto: va en una BANDA a media altura, como los rotulos de los
	-- edificios de verdad.
	local alto = 1
	if o.banda == nil then
		local sz = parte.Size
		if sz.Y > sz.X and sz.Y > sz.Z then alto = 0.16 end
	else
		alto = o.banda
	end

	-- caras: por defecto se pinta en las DOS caras grandes (asi se lee vengas de
	-- donde vengas). En partes planas de una sola cara (un piso, un letrero
	-- clavado) se pide  unaCara = true.
	-- v49: si no se pide una cara, se pintan LAS DOS CARAS GRANDES de la pieza.
	-- Antes eran siempre Back y Front, y en una placa larga en Z (la del paso al
	-- garaje mide 3.2 x 2.0 x 16.4) eso pinta el texto en la cara de 3.2: "TALLER"
	-- salia de 0.8 studs, chiquito, por mas que se pidiera mas grande.
	local caras
	if o.unaCara then
		caras = { o.face or Enum.NormalId.Back }
	elseif o.face then
		caras = { o.face, o.face == Enum.NormalId.Back and Enum.NormalId.Front or o.face }
	else
		-- (Top/Bottom NO cuentan: nadie lee un letrero que mira al cielo)
		local sz = parte.Size
		if sz.Z * sz.Y > sz.X * sz.Y then
			caras = { Enum.NormalId.Left, Enum.NormalId.Right }
		else
			caras = { Enum.NormalId.Back, Enum.NormalId.Front }
		end
	end

	local primero
	for i, cara in ipairs(caras) do
		local ok, g = pcall(function()
			local sg = Instance.new("SurfaceGui")
			sg.Name = (i == 1) and (o.name or "Rotulo") or ((o.name or "Rotulo") .. "Rev")
			sg.Face = cara
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			-- v46: era 45. El usuario: "los letreros aun tienen la letra demasiada
		-- pequeña". Sube el default a 58 (mas pixeles por stud = letra mas
		-- nitida; los rotulos grandes piden todavia mas, ver abajo).
		sg.PixelsPerStud = o.pixels or 58
			sg.LightInfluence = o.light or 0
			sg.AlwaysOnTop = false
			sg.ZOffset = 0.5
			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			if alto >= 1 then
				lbl.Size = UDim2.fromScale(1, 1)
				lbl.Position = UDim2.fromScale(0, 0)
			else
				lbl.Size = UDim2.fromScale(1, alto)
				lbl.Position = UDim2.fromScale(0, 0.5 - alto * 0.5)
			end
			lbl.Font = o.font or Enum.Font.GothamBold
			lbl.TextWrapped = false
			-- v49: EL TAMAÑO DE LA LETRA SE CALCULA AQUI, no se deja a TextScaled.
			-- El usuario lo reporto TRES veces ("la letra sigue re chiquita") y cada
			-- vez le movia el tablero; el problema de fondo es que con TextScaled el
			-- resultado depende del motor y no se puede MEDIR. Con o.letra se pide el
			-- alto de la letra en studs y aqui se convierte a pixeles del tablero
			-- (pixeles = studs x PixelsPerStud). TextScaled queda de respaldo para
			-- los rotulos viejos que no piden tamaño.
			local ancho, altoCara = 0, 0
			if cara == Enum.NormalId.Left or cara == Enum.NormalId.Right then
				ancho, altoCara = parte.Size.Z, parte.Size.Y
			elseif cara == Enum.NormalId.Top or cara == Enum.NormalId.Bottom then
				ancho, altoCara = parte.Size.X, parte.Size.Z
			else
				ancho, altoCara = parte.Size.X, parte.Size.Y
			end
			local nLetras = 0
			for _ in string.gmatch(texto, "[%w]") do nLetras = nLetras + 1 end
			local conLetra = (tonumber(o.letra) or 0) > 0
			if conLetra then
				-- la letra de verdad mide ~0.7 de la "eme" de la fuente
				local em = (tonumber(o.letra) or 0) / 0.7
				local cabeEm = math.min(altoCara * alto * 0.94,
					(ancho * 0.94) / (0.62 * math.max(1, nLetras)))
				em = math.min(em, cabeEm)
				lbl.TextSize = math.max(8, math.floor(em * (o.pixels or 58)))
				lbl.TextScaled = false
			else
				lbl.TextScaled = true
			end
			lbl.TextColor3 = color or Color3.fromRGB(236, 232, 222)
			-- v46: el contorno pasa de 0.75 a 0.5: mas marcado = se lee de lejos
			lbl.TextStrokeTransparency = o.stroke or 0.5
			lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
			lbl.Text = texto
			lbl.Name = "Texto"
			lbl.Parent = sg
			sg.Parent = parte
			return sg
		end)
		if ok and g and not primero then primero = g end
	end
	return primero
end
CityGenerator.TextoPlano = textoPlano

-- ===== v44: EL ROTULO DEL GARAJE =====
-- El usuario: "tal vez ahi podemos poner 'garaje de' y el nombre del usuario, o
-- 'sin propietario' los que no tienen". Escribe (o reescribe) el texto PINTADO en
-- el tablero negro que ya esta arriba de los portones del garaje.
function CityGenerator.RotularGaraje(model: Model, texto: string): boolean
	local sign = model:FindFirstChild("GarageSign", true)
	if not sign or not sign:IsA("BasePart") then return false end
	-- v48: UN SOLO renglon. Partirlo en dos ("GARAJE DE" / "NOMBRE") fue el error
	-- de la v46: cada renglon cabia en la mitad del tablero y la letra salia
	-- chiquita.
	-- v49: ADEMAS ya NO se prende TextScaled. Eso era lo que dejaba el tamaño en
	-- manos del motor (que es lo que se veia chiquito y no se podia medir): ahora
	-- el tamaño lo puso textoPlano con su letra en studs y aqui SOLO se cambia el
	-- texto.
	local dos = string.upper(texto)

	-- v46: el renglon se parte con "\n" y el TextLabel va en TextScaled SIN
	-- envolver, para que la letra crezca hasta llenar el tablero. Con TextWrapped
	-- (lo que habia) el texto se quedaba chiquito flotando en medio del tablero.
	local sg = sign:FindFirstChild("Rotulo")
	if not sg then
		local nuevo = textoPlano(sign, dos, Color3.fromRGB(255, 226, 150),
			{ pixels = 128, stroke = 0.35, letra = 3.0 })
		return nuevo ~= nil
	end
	-- v48: el tablero YA viene con su rotulo puesto en BuildWarehouse, asi que
	-- este camino (el normal) solo le cambiaba el TEXTO y se quedaba con la
	-- resolucion de fabrica: la letra se veia borrosa/chica aunque aqui se
	-- pidiera 120 pixeles por stud. Ahora se le sube a las dos caras.
	for _, g in ipairs(sign:GetChildren()) do
		if g:IsA("SurfaceGui") then
			if (g.PixelsPerStud or 0) < 128 then g.PixelsPerStud = 128 end
			local l = g:FindFirstChild("Texto")
			if l and l:IsA("TextLabel") then
				l.Text = dos
				l.TextWrapped = false
				-- si el rotulo es viejo (sin tamaño medido), se le calcula aqui
				if (l.TextSize or 0) <= 0 then
					-- rotulo viejo (de otra ronda) sin tamaño medido: se le calcula
					l.TextSize = math.max(8, math.floor(3.2 * (g.PixelsPerStud or 58)))
					l.TextScaled = false
				end
			end
		end
	end
	local lbl = sg:FindFirstChild("Texto")
	if lbl and lbl:IsA("TextLabel") then
		lbl.Text = dos
		lbl.TextWrapped = false
		return true
	end
	return false
end

-- Poste de luz para iluminar la ciudad de noche
local function makeStreetLight(parent: Instance, pos: Vector3)
	-- v42: el poste era un tubo delgado con una placa luminosa de 3x3 encima.
	-- De cerca (y de noche) parecia una placa FLOTANDO despegada del tubo
	-- (reporte del usuario). Ahora es un farol de verdad: poste + BRAZO que sale
	-- del tope + luminaria colgando del brazo, todo pegado.
	local poleH = 17.4
	local pole = part({
		Name = "LightPole",
		Size = Vector3.new(0.85, poleH, 0.85),
		Position = pos + Vector3.new(0, poleH / 2, 0),
		Color = Color3.fromRGB(40, 40, 44),
		Material = Enum.Material.Metal,
	})
	pole.Parent = parent

	-- brazo: sale del TOPE del poste hacia un lado (los dos se tocan)
	local arm = part({
		Name = "LightArm",
		Size = Vector3.new(2.8, 0.45, 0.45),
		Position = pos + Vector3.new(1.4, poleH - 0.2, 0),
		Color = Color3.fromRGB(40, 40, 44),
		Material = Enum.Material.Metal,
	})
	arm.Parent = parent

	-- luminaria: colgando del extremo del brazo (toca el brazo por arriba)
	local head = part({
		Name = "LightHead",
		Size = Vector3.new(2.1, 0.6, 1.5),
		Position = pos + Vector3.new(2.4, poleH - 0.75, 0),
		Color = Color3.fromRGB(255, 220, 150),
		Material = Enum.Material.Neon,
	})
	head.Parent = parent

	-- y una visera oscura arriba de la luminaria (se ve como farol, no como placa)
	local visor = part({
		Name = "LightVisor",
		Size = Vector3.new(2.3, 0.25, 1.7),
		Position = pos + Vector3.new(2.4, poleH - 0.42, 0),
		Color = Color3.fromRGB(52, 52, 58),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	visor.Parent = parent

	local light = Instance.new("PointLight")
	light.Brightness = 2.6
	light.Range = 46
	light.Color = Color3.fromRGB(255, 214, 160)
	light.Shadows = false
	light.Parent = head
	tagLight(light, 2.6)
	tagNeon(head, Color3.fromRGB(255, 220, 150), Color3.fromRGB(120, 118, 110))
end

----------------------------------------------------------------------
-- TERRENO Y CALLES
----------------------------------------------------------------------
local function buildGround(folder: Folder)
	-- ===== v44: LA CIUDAD Y EL PASTO SON DOS COSAS DISTINTAS =====
	-- BUG del usuario: "algunas de las otras parcelas tienen las bodegas ENCIMA
	-- DE LA CALLE". Pasaba esto: el suelo se estira para cubrir los LOTES DE
	-- BODEGA (mas abajo), pero las CALLES se dibujaban del mismo tamano que el
	-- suelo. O sea que al estirar el pasto hacia los lotes, las calles tambien se
	-- estiraban y cruzaban por encima de los lotes: la bodega del lote 3+ quedaba
	-- parada sobre la calle.
	-- Ahora son dos rectangulos separados: la CIUDAD (donde van las calles) y el
	-- SUELO (que puede ser mas grande). Las calles solo existen dentro de la
	-- ciudad y las banquetas tambien.
	local cityW = C.GridX * CELL + CELL * 3
	local cityD = C.GridZ * CELL + CELL * 3
	local w, d = cityW, cityD

	-- ... y las calles ni siquiera llegan hasta el borde del pasto: viven
	-- DENTRO de la rejilla de cuadras. Se sacan de donde caen las calles de las
	-- orillas (la primera y la ultima) para que el asfalto cubra los cruceros
	-- completos y no se pase ni un centimetro hacia los lotes de bodega.
	local rd = C.RoadWidth * 0.5
	local ejeX0 = CityGenerator.CellToWorld(0, 0).X - CELL * 0.5 - rd
	local ejeX1 = CityGenerator.CellToWorld(C.GridX - 1, 0).X - CELL * 0.5 + rd
	local ejeZ0 = CityGenerator.CellToWorld(0, 0).Z - CELL * 0.5 - rd
	local ejeZ1 = CityGenerator.CellToWorld(0, C.GridZ - 1).Z - CELL * 0.5 + rd
	local calleW = ejeX1 - ejeX0          -- largo de las calles horizontales
	local calleD = ejeZ1 - ejeZ0          -- largo de las verticales
	local calleCX = (ejeX0 + ejeX1) * 0.5
	local calleCZ = (ejeZ0 + ejeZ1) * 0.5
	local gx0, gx1 = -w * 0.5, w * 0.5
	local gz0, gz1 = -d * 0.5, d * 0.5

	-- ... y tambien tiene que cubrir los LOTES DE BODEGA, que viven detras de
	-- la ciudad. Con una sola fila pegada se salia del suelo y el jugador
	-- caia al vacio al salir por el porton de su bodega.
	local lots = Config.WarehouseLots
	if lots and lots.Enabled then
		local cols = math.max(1, math.min(lots.PerRow, lots.MaxSlots))
		local rows = math.max(1, math.ceil(lots.MaxSlots / lots.PerRow))
		local pad = lots.GroundPad or 80
		local hw = lots.HalfWidth or 150
		local hd = lots.HalfDepth or 95
		local lx0 = lots.Origin.X - hw
		local lx1 = lots.Origin.X + (cols - 1) * lots.SpacingX + hw
		local lz0 = lots.Origin.Z - (rows - 1) * lots.SpacingZ - hd
		local lz1 = lots.Origin.Z + hd
		gx0 = math.min(gx0, lx0 - pad); gx1 = math.max(gx1, lx1 + pad)
		gz0 = math.min(gz0, lz0 - pad); gz1 = math.max(gz1, lz1 + pad)
	end

	local gw, gd = gx1 - gx0, gz1 - gz0
	local gcx, gcz = (gx0 + gx1) * 0.5, (gz0 + gz1) * 0.5

	-- Techo del suelo en y = 0.2, justo debajo de calles (0.05) y banquetas.
	-- No es coplanar con nada -> se acabo el parpadeo, y sigue siendo visible.
	local ground = part({
		Name = "Ground",
		Size = Vector3.new(gw, 6, gd),
		Position = Vector3.new(gcx, -2.8, gcz),
		Color = Color3.fromRGB(74, 96, 62),
		Material = Enum.Material.Grass,
	})
	ground.Parent = folder

	-- calles horizontales y verticales
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	roads.Parent = folder

	for cz = 0, C.GridZ - 1 do
		local z = CityGenerator.CellToWorld(0, cz).Z
		local r = part({
			Name = "RoadZ" .. cz,
			Size = Vector3.new(calleW, 1, C.RoadWidth),
			Position = Vector3.new(calleCX, 0.55, z - CELL * 0.5),
			Color = Color3.fromRGB(48, 48, 52),
			Material = Enum.Material.Asphalt,
		})
		r.Parent = roads

		-- raya amarilla
		local line = part({
			Name = "Line",
			Size = Vector3.new(calleW, 0.2, 1.2),
			Position = Vector3.new(calleCX, 1.12, z - CELL * 0.5),
			Color = Color3.fromRGB(220, 190, 70),
			Material = Enum.Material.SmoothPlastic,
		})
		line.Parent = roads
	end

	for cx = 0, C.GridX - 1 do
		local x = CityGenerator.CellToWorld(cx, 0).X
		local r = part({
			Name = "RoadX" .. cx,
			Size = Vector3.new(C.RoadWidth, 1, calleD),
			Position = Vector3.new(x - CELL * 0.5, 0.55, calleCZ),
			Color = Color3.fromRGB(48, 48, 52),
			Material = Enum.Material.Asphalt,
		})
		r.Parent = roads

		local line = part({
			Name = "Line",
			Size = Vector3.new(1.2, 0.2, calleD),
			Position = Vector3.new(x - CELL * 0.5, 1.12, calleCZ),
			Color = Color3.fromRGB(220, 190, 70),
			Material = Enum.Material.SmoothPlastic,
		})
		line.Parent = roads
	end
end

----------------------------------------------------------------------
-- EDIFICIOS
----------------------------------------------------------------------
----------------------------------------------------------------------
-- EDIFICIOS REALISTAS
----------------------------------------------------------------------
local FACADE = {
	Color3.fromRGB(96, 102, 112),   -- concreto gris
	Color3.fromRGB(132, 124, 110),  -- piedra arena
	Color3.fromRGB(78, 86, 98),     -- gris azulado
	Color3.fromRGB(148, 138, 124),  -- beige
	Color3.fromRGB(110, 78, 68),    -- ladrillo
	Color3.fromRGB(62, 70, 80),     -- oscuro
	Color3.fromRGB(158, 152, 142),  -- claro
}

local GLASS_TINT = {
	Color3.fromRGB(88, 128, 150),
	Color3.fromRGB(70, 104, 128),
	Color3.fromRGB(104, 140, 160),
	Color3.fromRGB(60, 88, 110),
}

local WINDOW_LIT = {
	Color3.fromRGB(255, 228, 172),
	Color3.fromRGB(255, 242, 214),
	Color3.fromRGB(198, 226, 255),
	Color3.fromRGB(255, 206, 148),
}

-- ventanas en una fachada: filas de cristales individuales con marco
local function addWindowGrid(parent: Instance, center: Vector3, sizeX: number, sizeZ: number,
	baseY: number, height: number, litColor: Color3, litChance: number)

	local floorH = 7
	local floors = math.max(1, math.floor(height / floorH))
	local winW, winH = 3.2, 3.6

	for _, face in ipairs({"X+", "X-", "Z+", "Z-"}) do
		local faceWidth = (face == "Z+" or face == "Z-") and sizeX or sizeZ
		local cols = math.max(1, math.floor((faceWidth - 4) / (winW + 2.2)))
		local spacing = (faceWidth - 4) / cols

		for f = 0, floors - 1 do
			local y = baseY + f * floorH + floorH * 0.5
			if y > baseY + height - 2 then break end

			for c = 0, cols - 1 do
				local offset = -faceWidth * 0.5 + 2 + spacing * (c + 0.5)
				local pos, sz

				if face == "Z+" then
					pos = center + Vector3.new(offset, y, sizeZ * 0.5)
					sz = Vector3.new(winW, winH, 0.4)
				elseif face == "Z-" then
					pos = center + Vector3.new(offset, y, -sizeZ * 0.5)
					sz = Vector3.new(winW, winH, 0.4)
				elseif face == "X+" then
					pos = center + Vector3.new(sizeX * 0.5, y, offset)
					sz = Vector3.new(0.4, winH, winW)
				else
					pos = center + Vector3.new(-sizeX * 0.5, y, offset)
					sz = Vector3.new(0.4, winH, winW)
				end

				local lit = rng:NextNumber() < litChance
				local tint = GLASS_TINT[rng:NextInteger(1, #GLASS_TINT)]
				local w = part({
					Name = "Window",
					Size = sz,
					Position = pos,
					Color = lit and litColor or tint,
					Material = lit and Enum.Material.Neon or Enum.Material.Glass,
					Transparency = lit and 0 or 0.35,
					Reflectance = lit and 0 or 0.25,
					CanCollide = false,
				})
				w.Parent = parent
				if lit then
					-- de dia se vuelve vidrio normal, de noche se enciende
					w:SetAttribute("LitColor", litColor)
					w:SetAttribute("OffColor", tint)
					w:SetAttribute("IsWindow", true)
					CollectionService:AddTag(w, NIGHT_TAG)
				end
			end
		end
	end
end

-- Rascacielos: torre escalonada de vidrio
local function buildTower(parent: Instance, center: Vector3, sizeX: number, sizeZ: number, h: number)
	local color = FACADE[rng:NextInteger(1, #FACADE)]
	local lit = WINDOW_LIT[rng:NextInteger(1, #WINDOW_LIT)]

	local tiers = rng:NextInteger(2, 3)
	local y = 0
	local cx, cz = sizeX, sizeZ

	for t = 1, tiers do
		local th = (t == tiers) and (h - y) or (h / tiers) * rng:NextNumber(0.8, 1.15)
		th = math.max(8, math.min(th, h - y))
		if th <= 0 then break end

		local body = part({
			Name = "Tier",
			Size = Vector3.new(cx, th, cz),
			Position = center + Vector3.new(0, y + th * 0.5, 0),
			Color = color,
			Material = Enum.Material.Concrete,
		})
		body.Parent = parent

		addWindowGrid(parent, center, cx, cz, y, th, lit, 0.55)

		-- cornisa entre niveles
		local ledge = part({
			Name = "Ledge",
			Size = Vector3.new(cx + 1.6, 1, cz + 1.6),
			Position = center + Vector3.new(0, y + th, 0),
			Color = Color3.fromRGB(70, 70, 76),
			Material = Enum.Material.Concrete,
		})
		ledge.Parent = parent

		y += th
		cx, cz = cx * rng:NextNumber(0.68, 0.84), cz * rng:NextNumber(0.68, 0.84)
		if y >= h then break end
	end

	-- antena
	local mast = part({
		Name = "Mast",
		Size = Vector3.new(0.7, rng:NextNumber(8, 20), 0.7),
		Position = center + Vector3.new(0, h + 8, 0),
		Color = Color3.fromRGB(45, 45, 50),
		Material = Enum.Material.Metal,
	})
	mast.Parent = parent
end

-- Edificio de departamentos: fachada con balcones
local function buildApartment(parent: Instance, center: Vector3, sizeX: number, sizeZ: number, h: number)
	local color = FACADE[rng:NextInteger(1, #FACADE)]
	local lit = WINDOW_LIT[rng:NextInteger(1, #WINDOW_LIT)]

	local body = part({
		Name = "Body",
		Size = Vector3.new(sizeX, h, sizeZ),
		Position = center + Vector3.new(0, h * 0.5, 0),
		Color = color,
		Material = Enum.Material.Brick,
	})
	body.Parent = parent

	addWindowGrid(parent, center, sizeX, sizeZ, 0, h, lit, 0.6)

	-- balcones en la cara frontal
	local floors = math.max(1, math.floor(h / 7))
	for f = 1, floors - 1 do
		local y = f * 7
		if rng:NextNumber() < 0.65 then
			local bal = part({
				Name = "Balcony",
				Size = Vector3.new(sizeX * 0.7, 0.5, 3),
				Position = center + Vector3.new(0, y, sizeZ * 0.5 + 1.5),
				Color = Color3.fromRGB(88, 88, 94),
				Material = Enum.Material.Concrete,
			})
			bal.Parent = parent

			local rail = part({
				Name = "Rail",
				Size = Vector3.new(sizeX * 0.7, 2.4, 0.3),
				Position = center + Vector3.new(0, y + 1.4, sizeZ * 0.5 + 2.9),
				Color = Color3.fromRGB(60, 62, 68),
				Material = Enum.Material.Metal,
				Transparency = 0.25,
			})
			rail.Parent = parent
		end
	end

	-- azotea con pretil y tinaco
	local parapet = part({
		Name = "Parapet",
		Size = Vector3.new(sizeX + 0.8, 2.4, sizeZ + 0.8),
		Position = center + Vector3.new(0, h + 1.2, 0),
		Color = Color3.fromRGB(78, 78, 84),
		Material = Enum.Material.Concrete,
	})
	parapet.Parent = parent

	local tank = part({
		Name = "WaterTank",
		Size = Vector3.new(4, 4, 4),
		Position = center + Vector3.new(sizeX * 0.25, h + 4, sizeZ * 0.2),
		Color = Color3.fromRGB(40, 55, 90),
		Material = Enum.Material.Metal,
	})
	tank.Parent = parent
end

-- Local comercial bajo: planta baja de vidrio + toldo
local function buildShop(parent: Instance, center: Vector3, sizeX: number, sizeZ: number, h: number)
	local color = FACADE[rng:NextInteger(1, #FACADE)]

	local body = part({
		Name = "Body",
		Size = Vector3.new(sizeX, h, sizeZ),
		Position = center + Vector3.new(0, h * 0.5, 0),
		Color = color,
		Material = Enum.Material.Concrete,
	})
	body.Parent = parent

	-- escaparate de vidrio en planta baja
	local storefront = part({
		Name = "Storefront",
		Size = Vector3.new(sizeX * 0.85, 6, 0.5),
		Position = center + Vector3.new(0, 4, sizeZ * 0.5),
		Color = Color3.fromRGB(150, 190, 210),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Reflectance = 0.3,
		CanCollide = false,
	})
	storefront.Parent = parent

	-- toldo de color
	local awningColors = {
		Color3.fromRGB(160, 60, 55), Color3.fromRGB(50, 90, 130),
		Color3.fromRGB(70, 120, 70), Color3.fromRGB(180, 140, 60),
	}
	local awning = part({
		Name = "Awning",
		Size = Vector3.new(sizeX * 0.9, 0.4, 4),
		Position = center + Vector3.new(0, 8, sizeZ * 0.5 + 2),
		Color = awningColors[rng:NextInteger(1, #awningColors)],
		Material = Enum.Material.Fabric,
	})
	awning.Parent = parent

	-- letrero luminoso
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(sizeX * 0.5, 2.2, 0.4),
		Position = center + Vector3.new(0, 10.5, sizeZ * 0.5 + 0.3),
		Color = Color3.fromRGB(255, 190, 110),
		Material = Enum.Material.Neon,
	})
	sign.Parent = parent

	local sl = Instance.new("PointLight")
	sl.Brightness = 1.4
	sl.Range = 18
	sl.Color = Color3.fromRGB(255, 200, 130)
	sl.Parent = sign
	tagLight(sl, 1.4)

	if h > 12 then
		addWindowGrid(parent, center, sizeX, sizeZ, 10, h - 10, WINDOW_LIT[rng:NextInteger(1, #WINDOW_LIT)], 0.5)
	end
end

local function buildBuilding(parent: Instance, center: Vector3, sizeX: number, sizeZ: number)
	local h = rng:NextNumber(C.BuildingHeight.min, C.BuildingHeight.max)
	local footprint = math.min(sizeX, sizeZ)

	-- el tipo depende de la altura y el terreno disponible
	local roll = rng:NextNumber()
	if h > 55 and footprint > 22 then
		buildTower(parent, center, sizeX, sizeZ, h)
	elseif h < 22 or roll < 0.22 then
		buildShop(parent, center, sizeX, sizeZ, math.max(12, math.min(h, 26)))
	elseif roll < 0.62 then
		buildApartment(parent, center, sizeX, sizeZ, h)
	else
		buildTower(parent, center, sizeX, sizeZ, h)
	end

	-- luz roja de aviacion en los altos
	if h > 55 then
		local beacon = part({
			Name = "Beacon",
			Size = Vector3.new(1.6, 1.6, 1.6),
			Position = center + Vector3.new(0, h + 18, 0),
			Color = Color3.fromRGB(255, 60, 60),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
		})
		beacon.Parent = parent
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(255, 60, 60)
		pl.Brightness = 3
		pl.Range = 22
		pl.Parent = beacon
	end
end

-- Celdas que tienen mercado: se les reserva la franja frontal de la cuadra
local BUYER_CELLS = {}
for _, info in ipairs(Config.Buyers) do
	BUYER_CELLS[info.Cell.X .. "_" .. info.Cell.Y] = info
end

-- profundidad (en Z local) que ocupa el mercado dentro de la cuadra
local MARKET_DEPTH = 56

local function buildBlock(parent: Instance, cx: number, cz: number)
	local center = CityGenerator.CellToWorld(cx, cz)
	local hasMarket = BUYER_CELLS[cx .. "_" .. cz] ~= nil

	local folder = Instance.new("Folder")
	folder.Name = string.format("Block_%d_%d", cx, cz)
	folder.Parent = parent

	-- banqueta (toda la cuadra)
	local side = part({
		Name = "Sidewalk",
		Size = Vector3.new(C.BlockSize, 1.6, C.BlockSize),
		Position = center + Vector3.new(0, 0.8, 0),
		Color = Color3.fromRGB(150, 150, 146),
		Material = Enum.Material.Pavement,
	})
	side.Parent = folder

	-- postes de luz en las 4 esquinas
	local off = C.BlockSize * 0.5 - 5
	for _, cpos in ipairs({
		Vector3.new(-off, 1.6, -off), Vector3.new(off, 1.6, -off),
		Vector3.new(-off, 1.6, off),  Vector3.new(off, 1.6, off),
	}) do
		makeStreetLight(folder, center + cpos)
	end

	-- ===== zona edificable =====
	-- si hay mercado, los edificios solo van en la parte TRASERA de la cuadra,
	-- dejando libre la franja frontal (hacia +Z) donde va el callejon.
	local usable = C.BlockSize - 24
	local depth = usable
	local zShift = 0

	if hasMarket then
		depth = usable - MARKET_DEPTH
		zShift = -MARKET_DEPTH * 0.5   -- empuja los edificios hacia atras
	end

	local n = rng:NextInteger(C.BuildingsPerBlock.min, C.BuildingsPerBlock.max)
	local cols = math.max(1, math.ceil(math.sqrt(n)))
	local cellW = usable / cols
	local cellD = depth / cols

	local placed = 0
	for gx = 0, cols - 1 do
		for gz = 0, cols - 1 do
			if placed >= n then break end
			placed += 1
			local bx = center.X - usable * 0.5 + cellW * (gx + 0.5)
			local bz = center.Z - depth * 0.5 + cellD * (gz + 0.5) + zShift
			local sx = cellW * rng:NextNumber(0.55, 0.8)
			local sz = cellD * rng:NextNumber(0.55, 0.8)
			buildBuilding(folder, Vector3.new(bx, 1.6, bz), sx, sz)
		end
	end

	-- ===== paredes laterales del callejon =====
	-- dos edificios altos flanqueando el mercado: lo hacen sentir un callejon real
	if hasMarket then
		local alleyZ = center.Z + usable * 0.5 - MARKET_DEPTH * 0.5
		for _, sx in ipairs({-1, 1}) do
			local wallX = center.X + sx * (usable * 0.5 - 14)
			local h = rng:NextNumber(38, 62)
			local wall = part({
				Name = "AlleyWall",
				Size = Vector3.new(26, h, MARKET_DEPTH + 10),
				Position = Vector3.new(wallX, 1.6 + h * 0.5, alleyZ),
				Color = FACADE[rng:NextInteger(1, #FACADE)],
				Material = Enum.Material.Brick,
			})
			wall.Parent = folder

			-- ventanas en la cara que da al callejon
			addWindowGrid(folder, Vector3.new(wallX, 0, alleyZ), 26, MARKET_DEPTH + 10,
				1.6, h, WINDOW_LIT[rng:NextInteger(1, #WINDOW_LIT)], 0.4)

			-- escalera de incendios
			for f = 1, math.floor(h / 12) do
				local plat = part({
					Name = "FireEscape",
					Size = Vector3.new(4, 0.4, 10),
					Position = Vector3.new(wallX - sx * 14, 1.6 + f * 12, alleyZ),
					Color = Color3.fromRGB(58, 60, 64),
					Material = Enum.Material.DiamondPlate,
				})
				plat.Parent = folder

				local rail = part({
					Name = "FeRail",
					Size = Vector3.new(0.3, 3, 10),
					Position = Vector3.new(wallX - sx * 16, 1.6 + f * 12 + 1.5, alleyZ),
					Color = Color3.fromRGB(52, 54, 58),
					Material = Enum.Material.Metal,
					Transparency = 0.3,
				})
				rail.Parent = folder
			end
		end
	end
end

----------------------------------------------------------------------
-- COMPRADORES
----------------------------------------------------------------------
-- ====================================================================
-- NPC HUMANOIDE REAL (R15-style, con Humanoid para que se vea vivo)
-- ====================================================================
local NPC_LOOKS = {
	{skin = Color3.fromRGB(205, 160, 120), shirt = Color3.fromRGB(58, 62, 74), pants = Color3.fromRGB(38, 40, 48), hair = Color3.fromRGB(35, 25, 18)},
	{skin = Color3.fromRGB(160, 116, 84),  shirt = Color3.fromRGB(96, 42, 42), pants = Color3.fromRGB(30, 34, 44), hair = Color3.fromRGB(20, 16, 14)},
	{skin = Color3.fromRGB(120, 84, 60),   shirt = Color3.fromRGB(42, 68, 92), pants = Color3.fromRGB(44, 44, 50), hair = Color3.fromRGB(28, 20, 16)},
	{skin = Color3.fromRGB(232, 195, 160), shirt = Color3.fromRGB(56, 74, 52), pants = Color3.fromRGB(52, 48, 42), hair = Color3.fromRGB(96, 68, 38)},
}

local function makeBuyerNPC(parent: Instance, pos: Vector3, info: any, facing: Vector3?, style: string?)
	local look = NPC_LOOKS[rng:NextInteger(1, #NPC_LOOKS)]
	local isGuard = (style == "guard")
	local isPolice = (style == "police")   -- v42: oficial que cuida el lote clausurado
	if isGuard then
		-- el vigilante va todo de negro, no de comerciante
		look = {
			skin  = Color3.fromRGB(196, 150, 112),
			shirt = Color3.fromRGB(26, 28, 34),
			pants = Color3.fromRGB(20, 22, 28),
			hair  = Color3.fromRGB(18, 18, 20),
		}
	elseif isPolice then
		-- oficial: uniforme azul marino, gorra y placa
		look = {
			skin  = NPC_LOOKS[rng:NextInteger(1, #NPC_LOOKS)].skin,
			shirt = Color3.fromRGB(40, 62, 118),
			pants = Color3.fromRGB(28, 38, 68),
			hair  = Color3.fromRGB(24, 20, 18),
		}
	elseif style == "raider" then
		-- asaltante: encapuchado, todo oscuro
		look = {
			skin  = Color3.fromRGB(150, 116, 90),
			shirt = Color3.fromRGB(34, 20, 24),
			pants = Color3.fromRGB(24, 24, 28),
			hair  = Color3.fromRGB(12, 12, 14),
		}
	elseif style == "worker" then
		-- tus empleados: overol de trabajo y chaleco reflejante
		look = {
			skin  = NPC_LOOKS[rng:NextInteger(1, #NPC_LOOKS)].skin,
			shirt = Color3.fromRGB(238, 186, 48),
			pants = Color3.fromRGB(54, 62, 86),
			hair  = Color3.fromRGB(38, 28, 22),
		}
	end

	local npc = Instance.new("Model")
	npc.Name = "NPC_" .. info.Id

	-- ===== RIG R6 AUTENTICO =====
	-- Roblox anima automaticamente cualquier modelo con esta estructura exacta.
	local function rigPart(name: string, size: Vector3, offset: Vector3, color: Color3, mat: Enum.Material?)
		local pp = Instance.new("Part")
		pp.Name = name
		pp.Size = size
		pp.CFrame = CFrame.new(pos + offset)
		pp.Color = color
		pp.Material = mat or Enum.Material.SmoothPlastic
		pp.Anchored = false
		pp.CanCollide = false
		pp.TopSurface = Enum.SurfaceType.Smooth
		pp.BottomSurface = Enum.SurfaceType.Smooth
		pp.Parent = npc
		return pp
	end

	local hrp = rigPart("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), look.shirt)
	hrp.Transparency = 1
	npc.PrimaryPart = hrp

	local torso = rigPart("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), look.shirt, Enum.Material.Fabric)
	local head  = rigPart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), look.skin)

	local la = rigPart("Left Arm",  Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), look.skin)
	local ra = rigPart("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0),  look.skin)
	local ll = rigPart("Left Leg",  Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), look.pants, Enum.Material.Fabric)
	local rl = rigPart("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0),  look.pants, Enum.Material.Fabric)

	-- cara
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- gorro/cabello encima de la cabeza
	local hair = Instance.new("Part")
	hair.Name = "Hair"
	hair.Size = Vector3.new(2.05, 0.55, 1.05)
	hair.CFrame = CFrame.new(pos + Vector3.new(0, 5.1, 0))
	hair.Color = look.hair
	hair.Material = Enum.Material.Fabric
	hair.CanCollide = false
	hair.Massless = true
	hair.Parent = npc
	local hw = Instance.new("WeldConstraint")
	hw.Part0 = head; hw.Part1 = hair; hw.Parent = hair

	local function attach(to: BasePart, name: string, size: Vector3, off: Vector3,
		color: Color3, mat: Enum.Material?)
		local a = Instance.new("Part")
		a.Name = name
		a.Size = size
		a.CFrame = CFrame.new(pos + off)
		a.Color = color
		a.Material = mat or Enum.Material.Fabric
		a.CanCollide = false
		a.Massless = true
		a.Parent = npc
		local w = Instance.new("WeldConstraint")
		w.Part0 = to; w.Part1 = a; w.Parent = a
		return a
	end

	if isPolice then
		-- chaleco antibalas encima del uniforme
		attach(torso, "Vest", Vector3.new(2.16, 1.9, 1.16), Vector3.new(0, 2.95, 0),
			Color3.fromRGB(26, 34, 58), Enum.Material.Fabric)
		-- placa dorada en el pecho
		attach(torso, "Badge", Vector3.new(0.42, 0.5, 0.1), Vector3.new(0.72, 3.35, -0.6),
			Color3.fromRGB(232, 196, 88), Enum.Material.Foil)
		-- cinturon con equipo
		attach(torso, "Belt", Vector3.new(2.24, 0.42, 1.24), Vector3.new(0, 2.15, 0),
			Color3.fromRGB(32, 30, 34), Enum.Material.Leather)
		attach(torso, "Holster", Vector3.new(0.5, 0.9, 0.6), Vector3.new(-1.0, 2.0, 0.2),
			Color3.fromRGB(24, 24, 28), Enum.Material.Leather)
		local radio = attach(torso, "Radio", Vector3.new(0.36, 0.72, 0.3), Vector3.new(-0.8, 3.75, -0.6),
			Color3.fromRGB(16, 16, 18), Enum.Material.Plastic)
		radio:SetAttribute("EsRadio", true)
		-- gorra de policia con visera
		attach(head, "Cap", Vector3.new(2.08, 0.5, 1.08), Vector3.new(0, 5.14, 0),
			Color3.fromRGB(30, 48, 92), Enum.Material.Fabric)
		attach(head, "CapBrim", Vector3.new(2.0, 0.16, 0.85), Vector3.new(0, 4.93, -0.86),
			Color3.fromRGB(18, 24, 44), Enum.Material.Fabric)
		attach(head, "CapBadge", Vector3.new(0.3, 0.22, 0.12), Vector3.new(0, 5.42, -0.5),
			Color3.fromRGB(232, 196, 88), Enum.Material.Foil)
	elseif isGuard then
		-- chamarra de cuero abierta
		attach(torso, "Jacket", Vector3.new(2.16, 1.9, 1.16), Vector3.new(0, 2.9, 0),
			Color3.fromRGB(30, 30, 36), Enum.Material.Leather)
		-- lentes oscuros
		attach(head, "Shades", Vector3.new(1.5, 0.34, 0.16), Vector3.new(0, 4.62, -0.52),
			Color3.fromRGB(12, 12, 14), Enum.Material.Glass)
		-- gorra
		attach(head, "Cap", Vector3.new(2.06, 0.5, 1.06), Vector3.new(0, 5.12, 0),
			Color3.fromRGB(22, 22, 26), Enum.Material.Fabric)
		attach(head, "CapBrim", Vector3.new(2.0, 0.16, 0.8), Vector3.new(0, 4.92, -0.85),
			Color3.fromRGB(22, 22, 26), Enum.Material.Fabric)
		-- cinturon tactico
		attach(torso, "Belt", Vector3.new(2.2, 0.36, 1.2), Vector3.new(0, 2.15, 0),
			Color3.fromRGB(44, 40, 36), Enum.Material.Leather)
		-- radio en el hombro
		attach(torso, "Radio", Vector3.new(0.34, 0.7, 0.28), Vector3.new(-0.78, 3.7, -0.6),
			Color3.fromRGB(16, 16, 18), Enum.Material.Plastic)
	else
		-- mandil del comerciante
		attach(torso, "Apron", Vector3.new(2.1, 1.6, 1.1), Vector3.new(0, 2.8, 0),
			Color3.fromRGB(62, 54, 48), Enum.Material.Fabric)
	end

	-- ===== HUMANOID =====
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.WalkSpeed = 0            -- no se mueve de su puesto
	hum.JumpPower = 0
	hum.AutoRotate = false
	hum.MaxHealth = 100
	hum.Health = 100
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = npc

	-- ===== MOTOR6D (articulaciones R6) =====
	local function joint(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
	end

	joint("RootJoint", hrp, torso,
		CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(180)),
		CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(180)))
	joint("Neck", torso, head,
		CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(180)),
		CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(180)))
	joint("Left Shoulder", torso, la,
		CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0))
	joint("Right Shoulder", torso, ra,
		CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0))
	joint("Left Hip", torso, ll,
		CFrame.new(-1, -1, 0) * CFrame.Angles(0, math.rad(-90), 0),
		CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, math.rad(-90), 0))
	joint("Right Hip", torso, rl,
		CFrame.new(1, -1, 0) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.rad(90), 0))

	-- ===== ANIMACION IDLE (la oficial de Roblox) =====
	local animator = Instance.new("Animator")
	animator.Parent = hum

	local idleAnim = Instance.new("Animation")
	idleAnim.Name = "Idle"
	idleAnim.AnimationId = "rbxassetid://180435571"
	idleAnim.Parent = npc

	-- ===== POSTURA DEL VIGILANTE =====
	-- Brazos cruzados y una pierna flexionada, como alguien recargado.
	if isGuard then
		local ls = torso:FindFirstChild("Left Shoulder")
		local rs = torso:FindFirstChild("Right Shoulder")
		local lh = torso:FindFirstChild("Left Hip")
		if ls and ls:IsA("Motor6D") then
			ls.C0 = CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), 0)
				* CFrame.Angles(math.rad(-16), 0, math.rad(62))
		end
		if rs and rs:IsA("Motor6D") then
			rs.C0 = CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0)
				* CFrame.Angles(math.rad(-16), 0, math.rad(-62))
		end
		if lh and lh:IsA("Motor6D") then
			lh.C0 = CFrame.new(-1, -1, 0) * CFrame.Angles(0, math.rad(-90), 0)
				* CFrame.Angles(0, 0, math.rad(-12))
		end
	end

	-- ===== ORIENTAR =====
	if facing then
		npc:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos + Vector3.new(0, 3, 0) + facing))
	end

	-- anclar el root para que no se caiga, el resto queda libre para animar
	hrp.Anchored = true

	npc:SetAttribute("BuyerId", info.Id)
	npc:SetAttribute("BuyerName", info.Name)
	CollectionService:AddTag(npc, "BuyerNPC")

	npc.Parent = parent

	-- reproducir idle (debe ser despues de estar en el Workspace)
	task.spawn(function()
		task.wait(0.4)
		if isGuard or isPolice then
			-- el vigilante/oficial conserva su pose: solo voltea lento, vigilando
			local neck = torso:FindFirstChild("Neck")
			local t = rng:NextNumber(0, 6)
			while npc.Parent do
				t += 0.09
				if neck and neck:IsA("Motor6D") then
					local turn = math.sin(t * 0.35) * 0.5
					local nod = math.sin(t * 0.9) * 0.025
					neck.C0 = CFrame.new(0, 1, 0)
						* CFrame.Angles(math.rad(-90), 0, math.rad(180))
						* CFrame.Angles(nod, 0, turn)
				end
				task.wait(0.09)
			end
			return
		end
		local ok = pcall(function()
			local track = animator:LoadAnimation(idleAnim)
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Idle
			track:Play()
		end)
		if not ok then
			-- respaldo: balanceo manual si la animacion no carga
			local neck = torso:FindFirstChild("Neck")
			local t = 0
			while npc.Parent do
				t += 0.08
				if neck and neck:IsA("Motor6D") then
					neck.C0 = CFrame.new(0, 1, 0)
						* CFrame.Angles(math.rad(-90), 0, math.rad(180))
						* CFrame.Angles(0, 0, math.sin(t) * 0.09)
				end
				task.wait(0.08)
			end
		end
	end)

	return npc
end

-- ====================================================================
-- BASURA Y AMBIENTACION DE CALLEJON
-- ====================================================================
local function makeTrashCan(parent: Instance, pos: Vector3)
	local can = part({
		Name = "TrashCan",
		Size = Vector3.new(2.6, 3.4, 2.6),
		Position = pos + Vector3.new(0, 1.7, 0),
		Color = Color3.fromRGB(52, 58, 52),
		Material = Enum.Material.Metal,
	})
	can.Parent = parent

	local lid = part({
		Name = "Lid",
		Size = Vector3.new(2.9, 0.3, 2.9),
		Position = pos + Vector3.new(0, 3.5, 0),
		Color = Color3.fromRGB(40, 45, 40),
		Material = Enum.Material.Metal,
		Orientation = Vector3.new(0, 0, rng:NextNumber(-8, 8)),
	})
	lid.Parent = parent
end

local function makeDumpster(parent: Instance, pos: Vector3, rot: number)
	local body = part({
		Name = "Dumpster",
		Size = Vector3.new(8, 4.5, 4),
		Position = pos + Vector3.new(0, 2.25, 0),
		Color = Color3.fromRGB(46, 72, 56),
		Material = Enum.Material.Metal,
		Orientation = Vector3.new(0, rot, 0),
	})
	body.Parent = parent

	local lid = part({
		Name = "DumpsterLid",
		Size = Vector3.new(8.2, 0.4, 4.2),
		Position = pos + Vector3.new(0, 4.6, 0),
		Color = Color3.fromRGB(38, 60, 46),
		Material = Enum.Material.Metal,
		Orientation = Vector3.new(0, rot, rng:NextNumber(0, 25)),
	})
	lid.Parent = parent
end

local TRASH_COLORS = {
	Color3.fromRGB(180, 175, 165), Color3.fromRGB(140, 120, 90),
	Color3.fromRGB(90, 100, 110),  Color3.fromRGB(160, 60, 55),
	Color3.fromRGB(70, 90, 70),
}

local function scatterTrash(parent: Instance, center: Vector3, radius: number, count: number)
	for i = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, radius)
		local p = center + Vector3.new(math.cos(a) * r, 0.15, math.sin(a) * r)

		local kind = rng:NextInteger(1, 3)
		local sz
		if kind == 1 then
			sz = Vector3.new(rng:NextNumber(0.6, 1.4), 0.15, rng:NextNumber(0.6, 1.4)) -- papel
		elseif kind == 2 then
			sz = Vector3.new(0.5, 0.9, 0.5)  -- lata/botella
		else
			sz = Vector3.new(rng:NextNumber(1, 2), 0.5, rng:NextNumber(1, 2)) -- bolsa
		end

		local t = part({
			Name = "Trash",
			Size = sz,
			Position = p + Vector3.new(0, sz.Y * 0.5, 0),
			Color = TRASH_COLORS[rng:NextInteger(1, #TRASH_COLORS)],
			Material = Enum.Material.Plastic,
			Orientation = Vector3.new(0, rng:NextNumber(0, 360), rng:NextNumber(-6, 6)),
			CanCollide = false,
		})
		t.Parent = parent
	end
end

-- reja de alambre tipo ciudad
local function makeChainFence(parent: Instance, from: Vector3, to: Vector3, height: number?)
	local h = height or 12
	local dir = (to - from)
	local len = dir.Magnitude
	if len < 1 then return end
	local mid = from:Lerp(to, 0.5)
	local cf = CFrame.lookAt(mid, mid + dir.Unit)

	-- malla (una part semitransparente con textura de rejilla simulada)
	local mesh = part({
		Name = "FenceMesh",
		Size = Vector3.new(0.2, h, len),
		Color = Color3.fromRGB(150, 155, 160),
		Material = Enum.Material.DiamondPlate,
		Transparency = 0.45,
		CanCollide = false,   -- si choca, te atoras en el callejon
	})
	mesh.CFrame = cf * CFrame.new(0, h * 0.5, 0) * CFrame.Angles(0, math.rad(90), 0)
	mesh.Parent = parent

	-- postes cada 12 studs
	local n = math.max(2, math.floor(len / 12))
	for i = 0, n do
		local p = from:Lerp(to, i / n)
		local post = part({
			Name = "FencePost",
			Size = Vector3.new(0.6, h + 0.6, 0.6),
			Position = p + Vector3.new(0, (h + 0.6) * 0.5, 0),
			Color = Color3.fromRGB(110, 115, 120),
			Material = Enum.Material.Metal,
		})
		post.Parent = parent
	end

	-- riel superior
	local rail = part({
		Name = "FenceRail",
		Size = Vector3.new(0.35, 0.35, len),
		Color = Color3.fromRGB(120, 125, 130),
		Material = Enum.Material.Metal,
	})
	rail.CFrame = cf * CFrame.new(0, h, 0) * CFrame.Angles(0, math.rad(90), 0)
	rail.Parent = parent
end

local function buildBuyers(folder: Folder)
	local buyers = Instance.new("Folder")
	buyers.Name = "Buyers"
	buyers.Parent = folder

	local props = Instance.new("Folder")
	props.Name = "BuyerProps"
	props.Parent = folder

	local usable = C.BlockSize - 24

	for _, info in ipairs(Config.Buyers) do
		local center = CityGenerator.CellToWorld(info.Cell.X, info.Cell.Y)
		-- el mercado vive en la franja frontal RESERVADA de la cuadra
		-- (buildBlock ya movio los edificios hacia atras y puso las paredes)
		local pos = center + Vector3.new(0, 1.6, usable * 0.5 - MARKET_DEPTH * 0.5)

		-- ===== piso del callejon =====
		local alley = part({
			Name = "AlleyFloor",
			Size = Vector3.new(usable - 28, 0.4, MARKET_DEPTH),
			Position = pos + Vector3.new(0, 0.2, 0),
			Color = Color3.fromRGB(64, 62, 60),
			Material = Enum.Material.Concrete,
		})
		alley.Parent = props

		-- manchas de humedad
		for i = 1, 6 do
			local stain = part({
				Name = "Stain",
				Size = Vector3.new(rng:NextNumber(3, 9), 0.06, rng:NextNumber(3, 9)),
				Position = pos + Vector3.new(rng:NextNumber(-30, 30), 0.45, rng:NextNumber(-22, 22)),
				Color = Color3.fromRGB(46, 45, 46),
				Material = Enum.Material.Concrete,
				Transparency = 0.3,
				CanCollide = false,
			})
			stain.Parent = props
		end

		-- ===== reja al fondo del callejon (lado de los edificios) =====
		-- Se mete hasta la pared del fondo y se acorta a los lados para
		-- que no atraviese los edificios ni el puesto.
		makeChainFence(props,
			pos + Vector3.new(-(usable * 0.5 - 22), 0.4, -MARKET_DEPTH * 0.5 + 1),
			pos + Vector3.new(usable * 0.5 - 22, 0.4, -MARKET_DEPTH * 0.5 + 1), 11)

		-- ===== BASURA =====
		makeDumpster(props, pos + Vector3.new(-26, 0.4, -14), rng:NextNumber(-12, 12))
		makeTrashCan(props, pos + Vector3.new(28, 0.4, -12))
		makeTrashCan(props, pos + Vector3.new(31, 0.4, -17))
		makeTrashCan(props, pos + Vector3.new(-31, 0.4, 8))
		scatterTrash(props, pos + Vector3.new(0, 0.4, -4), 26, 26)

		-- tarimas recargadas
		for i = 1, 3 do
			local pallet = part({
				Name = "Pallet",
				Size = Vector3.new(0.4, 6, 4),
				Position = pos + Vector3.new(-(usable * 0.5 - 18), 3.4, -18 + i * 5),
				Color = Color3.fromRGB(112, 84, 54),
				Material = Enum.Material.WoodPlanks,
				Orientation = Vector3.new(0, 0, rng:NextNumber(-12, -5)),
			})
			pallet.Parent = props
		end

		-- ===== PUESTO, pegado al fondo del callejon =====
		local stallZ = -MARKET_DEPTH * 0.5 + 14

		local deck = part({
			Name = "Deck",
			Size = Vector3.new(24, 0.8, 16),
			Position = pos + Vector3.new(0, 0.8, stallZ),
			Color = Color3.fromRGB(96, 72, 48),
			Material = Enum.Material.WoodPlanks,
		})
		deck.Parent = props

		local counter = part({
			Name = "Counter",
			Size = Vector3.new(14, 3.5, 1.8),
			Position = pos + Vector3.new(0, 2.9, stallZ + 5),
			Color = Color3.fromRGB(78, 58, 40),
			Material = Enum.Material.Wood,
		})
		counter.Parent = props

		local top = part({
			Name = "CounterTop",
			Size = Vector3.new(15, 0.4, 2.8),
			Position = pos + Vector3.new(0, 4.8, stallZ + 5),
			Color = Color3.fromRGB(122, 94, 64),
			Material = Enum.Material.Wood,
		})
		top.Parent = props

		-- postes y lona
		for _, dx in ipairs({-11, 11}) do
			for _, dz in ipairs({-7, 7}) do
				local post = part({
					Name = "Post",
					Size = Vector3.new(0.6, 11, 0.6),
					Position = pos + Vector3.new(dx, 6, stallZ + dz),
					Color = Color3.fromRGB(70, 52, 36),
					Material = Enum.Material.Wood,
				})
				post.Parent = props
			end
		end

		local canopy = part({
			Name = "Canopy",
			Size = Vector3.new(25, 0.4, 17),
			Position = pos + Vector3.new(0, 11.6, stallZ),
			Color = Color3.fromRGB(122, 48, 44),
			Material = Enum.Material.Fabric,
		})
		canopy.Parent = props

		-- cajas
		for i = 1, 5 do
			local crate = part({
				Name = "Crate",
				Size = Vector3.new(2.4, 2.4, 2.4),
				Position = pos + Vector3.new(rng:NextNumber(-9, 9), 2.4, stallZ + rng:NextNumber(-6, -2)),
				Color = Color3.fromRGB(128, 96, 62),
				Material = Enum.Material.WoodPlanks,
				Orientation = Vector3.new(0, rng:NextNumber(0, 360), 0),
			})
			crate.Parent = props
		end

		-- lampara
		local lamp = part({
			Name = "Lamp",
			Size = Vector3.new(2, 0.6, 2),
			Position = pos + Vector3.new(0, 11, stallZ),
			Color = Color3.fromRGB(255, 225, 170),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		lamp.Parent = props

		local lampLight = Instance.new("PointLight")
		lampLight.Brightness = 2.6
		lampLight.Range = 40
		lampLight.Color = Color3.fromRGB(255, 220, 165)
		lampLight.Parent = lamp
		tagLight(lampLight, 2.6)
		tagNeon(lamp, Color3.fromRGB(255, 225, 170), Color3.fromRGB(140, 138, 130))

		-- ===== NPC detras del mostrador, mirando hacia la calle (+Z) =====
		makeBuyerNPC(props, pos + Vector3.new(0, 1.2, stallZ + 2), info, Vector3.new(0, 0, 1))

		-- ===== ZONA DE VENTA, frente al mostrador =====
		local pad = part({
			Name = info.Id,
			Size = Vector3.new(14, 0.3, 8),
			Position = pos + Vector3.new(0, 0.55, stallZ + 11),
			Color = Color3.fromRGB(240, 190, 90),
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CanCollide = false,
		})
		pad:SetAttribute("BuyerId", info.Id)

		-- ===== MASTIL DEL TERRITORIO =====
		-- La bandera la pinta Main segun que crew domine la zona.
		local flagPos = pos + Vector3.new(14, 0, 0)
		local base = part({
			Name = "FlagBase",
			Size = Vector3.new(4, 0.8, 4),
			Position = flagPos + Vector3.new(0, 0.4, 0),
			Color = Color3.fromRGB(78, 80, 86),
			Material = Enum.Material.Concrete,
		})
		base.Parent = props

		local pole = part({
			Name = "FlagPole",
			Size = Vector3.new(0.5, 22, 0.5),
			Position = flagPos + Vector3.new(0, 11.8, 0),
			Color = Color3.fromRGB(168, 170, 178),
			Material = Enum.Material.Metal,
		})
		pole.Parent = props

		local cloth = part({
			Name = "Flag_" .. info.Id,
			Size = Vector3.new(0.25, 5, 8),
			Position = flagPos + Vector3.new(0, 18.5, 4.2),
			Color = Color3.fromRGB(120, 124, 132),
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
		cloth:SetAttribute("BuyerId", info.Id)
		cloth.Parent = props

		local zoneLight = Instance.new("PointLight")
		zoneLight.Name = "ZoneLight"
		zoneLight.Color = Color3.fromRGB(150, 150, 160)
		zoneLight.Brightness = 1.1
		zoneLight.Range = 22
		zoneLight.Parent = cloth

		local sign = Instance.new("BillboardGui")
		sign.Name = "OwnerSign"
		sign.Size = UDim2.new(0, 260, 0, 46)
		sign.StudsOffset = Vector3.new(0, 4, 0)
		sign.AlwaysOnTop = false
		sign.MaxDistance = 320
		sign.LightInfluence = 0
		sign.Parent = cloth

		local slbl = Instance.new("TextLabel")
		slbl.Name = "OwnerText"
		slbl.Size = UDim2.fromScale(1, 1)
		slbl.BackgroundTransparency = 1
		slbl.Font = Enum.Font.GothamBold
		slbl.TextScaled = true
		slbl.TextColor3 = Color3.fromRGB(235, 235, 245)
		slbl.TextStrokeTransparency = 0.4
		slbl.Text = info.Name .. "\nSIN DUEÑO"
		slbl.Parent = sign
		pad:SetAttribute("PriceMult", info.PriceMult)
		pad:SetAttribute("HeatMult", info.HeatMult)
		pad.Parent = buyers

		-- haz de luz
		local beam = part({
			Name = "Beam",
			Size = Vector3.new(2.5, 90, 2.5),
			Position = pos + Vector3.new(0, 56, stallZ),
			Color = Color3.fromRGB(255, 190, 80),
			Material = Enum.Material.Neon,
			Transparency = 0.86,
			CanCollide = false,
		})
		beam.Parent = props

		-- letrero
		local signBoard = part({
			Name = "SignBoard",
			Size = Vector3.new(12, 2.6, 0.4),
			Position = pos + Vector3.new(0, 13.2, stallZ),
			Color = Color3.fromRGB(40, 34, 30),
			Material = Enum.Material.Wood,
		})
		signBoard.Parent = props

		-- v44: chico (el letrero de 200x50 estorbaba al caminar por el mercado)
		makeBillboard(signBoard, string.format("%s x%.2f", info.Name, info.PriceMult),
			Color3.fromRGB(255, 214, 130), 2, 120, 30)
	end
end

----------------------------------------------------------------------
-- BODEGA DEL JUGADOR + ESTACION DE ADUANAS
----------------------------------------------------------------------
-- ====================================================================
-- BODEGA POR NIVELES (Garage -> Mega Procesadora)
-- ====================================================================
function CityGenerator.BuildWarehouse(tierIndex: number): Model
	local T = Config.WarehouseTiers[math.clamp(tierIndex, 1, #Config.WarehouseTiers)]
	local W, H, D = T.Size.X, T.Size.Y, T.Size.Z

	local model = Instance.new("Model")
	model.Name = "Warehouse"
	model:SetAttribute("Tier", T.Level)

	-- ===== LA OFICINA (zona segura) =====
	-- Va AFUERA, como anexo pegado a la pared derecha, y se entra por una
	-- puerta que atraviesa esa pared. Antes estaba metida dentro de la nave
	-- y se comia el espacio de trabajo.
	local OFF_X0 = W * 0.5               -- pared compartida con la nave
	local OFF_X1 = W * 0.5 + 34
	local OFF_Z0 = -D * 0.5 + 12
	local OFF_Z1 = -D * 0.5 + 38
	local OFF_CX = (OFF_X0 + OFF_X1) / 2
	local OFF_CZ = (OFF_Z0 + OFF_Z1) / 2
	local OFF_DOOR = 8                   -- ancho del hueco en la pared

	-- ===== EL GARAJE (anexo pegado a la pared izquierda) =====
	-- Los mismos numeros que usa el bloque del garaje mas abajo, pero
	-- declarados aqui arriba porque la PARED IZQUIERDA necesita saber donde
	-- va su hueco. Si no, se construye de una sola pieza y el garaje queda
	-- SELLADO: los autos de adentro se ven desde el nave pero no hay puerta.
	-- Las medidas salen de GameConfig.Garage y CRECEN con el nivel de bodega
	-- (nivel 1 = cajon chico, nivel 4 = taller grande).
	local GC = Config.Garage
	local TIER = math.max(1, math.min(4, tierIndex or 1))
	local GAR_W = (GC.Widths and GC.Widths[TIER]) or 52
	local GAR_D = (GC.Depths and GC.Depths[TIER]) or 30
	local garH  = (GC.Heights and GC.Heights[TIER]) or 15
	local GAR_X = -W * 0.5 - GAR_W / 2
	local GAR_Z = -D * 0.5 + 24
	local GAR_DOOR = 14                  -- ancho del hueco hacia el garaje

	-- lo que estorbaria el paso hacia la oficina o hacia el garaje
	local function blocksOfficeDoor(x: number, z: number): boolean
		if x > 0 and math.abs(z - OFF_CZ) < 13 then return true end
		if x < 0 and math.abs(z - GAR_Z) < GAR_DOOR / 2 + 6 then return true end
		return false
	end

	-- ===== PISO =====
	local floor = part({
		Name = "Floor",
		Size = Vector3.new(W, 2, D),
		Position = Vector3.new(0, 1, 0),
		Color = T.FloorColor,
		Material = Enum.Material.Concrete,
	})
	floor.Parent = model
	model.PrimaryPart = floor

	-- linea amarilla de seguridad en el piso
	local stripe = part({
		Name = "SafetyStripe",
		Size = Vector3.new(W - 8, 0.1, 0.8),
		Position = Vector3.new(0, 2.05, D * 0.5 - 10),
		Color = Color3.fromRGB(215, 185, 60),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	stripe.Parent = model

	-- ===== PAREDES (fondo + izquierda + derecha) =====
	-- El fondo va de una pieza. La IZQUIERDA y la DERECHA van en tramos,
	-- porque cada una lleva un hueco: el garaje (izquierda) y la oficina
	-- (derecha). Antes la izquierda era una sola pieza y el garaje quedaba
	-- sellado por dentro: se veia desde la nave pero no se podia entrar.
	local wallT = 2

	local back = part({
		Name = "Wall1",
		Size = Vector3.new(W, H, wallT),
		Position = Vector3.new(0, H * 0.5 + 2, -D * 0.5),
		Color = T.WallColor,
		Material = Enum.Material.CorrodedMetal,
	})
	back.Parent = model

	-- Pared IZQUIERDA (Wall2) en tramos, con el hueco del garaje
	do
		local zFront, zBack = D * 0.5, -D * 0.5
		local dz0 = GAR_Z - GAR_DOOR / 2
		local dz1 = GAR_Z + GAR_DOOR / 2
		local doorH = 12

		for _, sg in ipairs({{zBack, dz0}, {dz1, zFront}}) do
			local len = sg[2] - sg[1]
			if len > 0.1 then
				local pw = part({
					Name = "Wall2",
					Size = Vector3.new(wallT, H, len),
					Position = Vector3.new(-W * 0.5, H * 0.5 + 2, (sg[1] + sg[2]) / 2),
					Color = T.WallColor,
					Material = Enum.Material.CorrodedMetal,
				})
				pw.Parent = model
			end
		end

		-- dintel del paso al garaje
		local lint2 = part({
			Name = "Wall2",
			Size = Vector3.new(wallT, H - doorH, GAR_DOOR),
			Position = Vector3.new(-W * 0.5, 2 + doorH + (H - doorH) / 2, GAR_Z),
			Color = T.WallColor,
			Material = Enum.Material.CorrodedMetal,
		})
		lint2.Parent = model

		-- marco metalico del paso (es de taller, no de casa)
		for _, dz in ipairs({dz0, dz1}) do
			local jamb = part({
				Name = "GarageDoorJamb",
				Size = Vector3.new(wallT + 1.2, doorH, 1.2),
				Position = Vector3.new(-W * 0.5, 2 + doorH / 2, dz),
				Color = Color3.fromRGB(84, 88, 94),
				Material = Enum.Material.Metal,
			})
			jamb.Parent = model
		end
		local head2 = part({
			Name = "GarageDoorHead",
			Size = Vector3.new(wallT + 1.2, 2.0, GAR_DOOR + 2.4),
			Position = Vector3.new(-W * 0.5, 2 + doorH + 1.0, GAR_Z),
			Color = Color3.fromRGB(84, 88, 94),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		head2.Parent = model
		textoPlano(head2, "TALLER", Color3.fromRGB(255, 205, 120),
			{ pixels = 110, letra = 1.15 })
	end

	-- La pared DERECHA va en tramos, para dejar el hueco por donde se pasa
	-- a la oficina. Si se hiciera de una pieza no habria manera de entrar.
	do
		local zFront = D * 0.5
		local zBack = -D * 0.5
		local dz0 = OFF_CZ - OFF_DOOR / 2
		local dz1 = OFF_CZ + OFF_DOOR / 2
		local doorH = 11

		local segs = {
			{zBack, dz0},     -- del fondo hasta el hueco
			{dz1, zFront},    -- del hueco al frente
		}
		for i, sg in ipairs(segs) do
			local len = sg[2] - sg[1]
			if len > 0.1 then
				local pw = part({
					Name = "Wall3",
					Size = Vector3.new(wallT, H, len),
					Position = Vector3.new(W * 0.5, H * 0.5 + 2, (sg[1] + sg[2]) / 2),
					Color = T.WallColor,
					Material = Enum.Material.CorrodedMetal,
				})
				pw.Parent = model
			end
		end

		-- dintel sobre la puerta
		local lint = part({
			Name = "Wall3",
			Size = Vector3.new(wallT, H - doorH, OFF_DOOR),
			Position = Vector3.new(W * 0.5, 2 + doorH + (H - doorH) / 2, OFF_CZ),
			Color = T.WallColor,
			Material = Enum.Material.CorrodedMetal,
		})
		lint.Parent = model

		-- marco de la puerta
		for _, dz in ipairs({dz0, dz1}) do
			local jamb = part({
				Name = "OfficeDoorJamb",
				Size = Vector3.new(wallT + 1, doorH, 1.2),
				Position = Vector3.new(W * 0.5, 2 + doorH / 2, dz),
				Color = Color3.fromRGB(72, 58, 46),
				Material = Enum.Material.Wood,
			})
			jamb.Parent = model
		end
		local head = part({
			Name = "OfficeDoorHead",
			-- v49: la placa era de 1 stud de alto: la letra salia de 0.7. Ahora 2.
			Size = Vector3.new(wallT + 1, 2, OFF_DOOR + 2.4),
			Position = Vector3.new(W * 0.5, 2 + doorH + 1.0, OFF_CZ),
			Color = Color3.fromRGB(72, 58, 46),
			Material = Enum.Material.Wood,
			CanCollide = false,
		})
		head.Parent = model
		textoPlano(head, "OFICINA", Color3.fromRGB(150, 230, 255),
			{ pixels = 110, letra = 1.15 })
	end

	-- ===== FACHADA DEL FRENTE con hueco de porton =====
	-- El frente ya no es un agujero: es una pared de verdad con su
	-- porton al centro, para que se vea como edificio y no como cochera.
	local gateW = math.min(30, W * 0.34)
	local gateH = math.min(H - 4, 20)
	local sideW = (W - gateW) * 0.5
	local frontZ = D * 0.5

	-- columnas a los lados del porton
	for _, sx in ipairs({-1, 1}) do
		local col = part({
			Name = "FrontWall",
			Size = Vector3.new(sideW, H, wallT),
			Position = Vector3.new(sx * (gateW * 0.5 + sideW * 0.5), H * 0.5 + 2, frontZ),
			Color = T.WallColor,
			Material = Enum.Material.Brick,
		})
		col.Parent = model
	end

	-- dintel arriba del porton
	local lintel = part({
		Name = "FrontWall",
		Size = Vector3.new(gateW, H - gateH, wallT),
		Position = Vector3.new(0, 2 + gateH + (H - gateH) * 0.5, frontZ),
		Color = T.WallColor,
		Material = Enum.Material.Brick,
	})
	lintel.Parent = model

	-- marco metalico del porton
	for _, sx in ipairs({-1, 1}) do
		local jamb = part({
			Name = "GateFrame",
			Size = Vector3.new(1.2, gateH, 2.6),
			Position = Vector3.new(sx * gateW * 0.5, 2 + gateH * 0.5, frontZ),
			Color = Color3.fromRGB(92, 96, 102),
			Material = Enum.Material.Metal,
		})
		jamb.Parent = model
	end
	local header = part({
		Name = "GateFrame",
		Size = Vector3.new(gateW + 2.4, 1.4, 2.6),
		Position = Vector3.new(0, 2 + gateH, frontZ),
		Color = Color3.fromRGB(92, 96, 102),
		Material = Enum.Material.Metal,
	})
	header.Parent = model

	-- === PORTON DE DOS HOJAS (se abren al acercarte) ===
	local doors = Instance.new("Folder")
	doors.Name = "Gate"
	doors.Parent = model

	for _, sx in ipairs({-1, 1}) do
		local leaf = part({
			Name = sx < 0 and "GateLeft" or "GateRight",
			Size = Vector3.new(gateW * 0.5, gateH, 0.6),
			Position = Vector3.new(sx * gateW * 0.25, 2 + gateH * 0.5, frontZ),
			Color = Color3.fromRGB(128, 132, 138),
			Material = Enum.Material.CorrodedMetal,
		})
		leaf:SetAttribute("ClosedX", sx * gateW * 0.25)
		leaf:SetAttribute("OpenX", sx * (gateW * 0.5 + gateW * 0.46))
		leaf.Parent = doors

		-- nervaduras horizontales para que no sea una tabla lisa.
		-- OJO: NO se sueldan. La hoja se mueve por CFrame y las partes
		-- soldadas a un ancla no siguen el movimiento: se quedaban pegadas.
		-- Las guardamos como hijas de la hoja y las movemos junto con ella.
		local ribs = Instance.new("Folder")
		ribs.Name = "Ribs"
		ribs.Parent = leaf

		for r = 1, 5 do
			local rib = part({
				Name = "GateRib",
				Size = Vector3.new(gateW * 0.5 - 0.6, 0.5, 0.9),
				Position = Vector3.new(sx * gateW * 0.25,
					2 + gateH * (r / 6), frontZ),
				Color = Color3.fromRGB(100, 104, 110),
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
			-- guardamos su desfase respecto a la hoja
			rib:SetAttribute("OffX", rib.Position.X - leaf.Position.X)
			rib:SetAttribute("OffY", rib.Position.Y - leaf.Position.Y)
			rib:SetAttribute("OffZ", rib.Position.Z - leaf.Position.Z)
			rib.Parent = ribs
		end
	end

	-- sensor: al pisarlo se abre el porton
	local gateSensor = part({
		Name = "GateSensor",
		Size = Vector3.new(gateW + 8, 12, 26),
		Position = Vector3.new(0, 8, frontZ),
		Transparency = 1,
		CanCollide = false,
	})
	gateSensor.Parent = model

	-- letrero arriba del porton
	textoPlano(lintel, string.upper(T.Name), Color3.fromRGB(255, 200, 120),
		{ pixels = 96, letra = 2.2 })

	-- luces del porton
	for _, sx in ipairs({-1, 1}) do
		local lamp = part({
			Name = "GateLamp",
			Size = Vector3.new(1.6, 0.8, 1.2),
			Position = Vector3.new(sx * (gateW * 0.5 + 3), 2 + gateH - 1, frontZ - 1.5),
			Color = Color3.fromRGB(255, 220, 160),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		lamp.Parent = model
		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(255, 205, 150)
		pl.Brightness = 0.7      -- v36: era 1.1 (se veia quemado)
		pl.Range = 15
		pl.Parent = lamp
		tagLight(lamp, 2, Color3.fromRGB(255, 220, 160))
	end

	-- ===== RAMPON DE LA ENTRADA =====
	-- El piso de la bodega esta a 2 studs y la calle a 0.2: habia un escalon
	-- de 1.8. El jugador lo sube de milagro, pero la bici no (su MAX_STEP es
	-- 1.6) y se quedaba atorada afuera del porton. Con la rampa entra y sale.
	do
		local drop = 1.8
		local run = 5.5
		local ang = math.atan(drop / run)
		local largo = math.sqrt(drop * drop + run * run) + 0.4
		-- la rampa va cargada al lado IZQUIERDO del porton: es el hueco que
		-- queda libre entre el marco y el muelle de carga
		local rw = math.min(12, gateW * 0.55)
		local rx = -gateW * 0.30
		local apron = part({
			Name = "GateApron",
			Size = Vector3.new(rw, 0.4, largo),
			Position = Vector3.new(rx, 2 - drop / 2 - 0.2 * math.cos(ang), frontZ + run / 2),
			Color = Color3.fromRGB(104, 102, 98),
			Material = Enum.Material.Concrete,
		})
		apron.CFrame = CFrame.new(apron.Position) * CFrame.Angles(ang, 0, 0)
		apron.Parent = model

		-- guardas de orilla, para que se vea que es una rampa y no una tabla
		for _, sx in ipairs({-1, 1}) do
			local rail = part({
				Name = "ApronRail",
				Size = Vector3.new(0.4, 0.5, largo),
				Position = Vector3.new(rx + sx * rw / 2, 2 - drop / 2 + 0.15, frontZ + run / 2),
				Color = Color3.fromRGB(196, 168, 70),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
			rail.CFrame = CFrame.new(rail.Position) * CFrame.Angles(ang, 0, 0)
			rail.Parent = model
		end
	end

	-- ===== TECHO A DOS AGUAS con vigas =====
	local roof = part({
		Name = "Roof",
		Size = Vector3.new(W + 4, 1.5, D + 4),
		Position = Vector3.new(0, H + 2.75, 0),
		Color = Color3.fromRGB(62, 66, 72),
		Material = Enum.Material.Metal,
	})
	roof.Parent = model

	-- vigas estructurales
	local beams = math.floor(D / 16)
	for i = 0, beams do
		local bz = -D * 0.5 + (D / beams) * i
		local beam = part({
			Name = "Beam",
			Size = Vector3.new(W, 1, 1),
			Position = Vector3.new(0, H + 1.2, bz),
			Color = Color3.fromRGB(78, 82, 88),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		beam.Parent = model
	end

	-- ===== MUELLE DE CARGA =====
	local dock = part({
		Name = "LoadingDock",
		Size = Vector3.new(W * 0.5, 4, 14),
		Position = Vector3.new(W * 0.2, 2, D * 0.5 + 7),
		Color = Color3.fromRGB(96, 94, 90),
		Material = Enum.Material.Concrete,
	})
	dock.Parent = model

	-- topes de hule del muelle
	for i = -1, 1 do
		local bumper = part({
			Name = "Bumper",
			Size = Vector3.new(3, 1.2, 1),
			Position = Vector3.new(W * 0.2 + i * 10, 4.6, D * 0.5 + 14),
			Color = Color3.fromRGB(38, 38, 42),
			Material = Enum.Material.Rubber,
		})
		bumper.Parent = model
	end

	-- ===== ESTANTERIA INDUSTRIAL (mas en niveles altos) =====
	-- Antes eran tablas flotando a 3 studs de la pared: el codigo decia
	-- "postes" pero nunca los creaba. Ahora el rack va PEGADO al muro,
	-- con sus cuatro postes, largueros y cajas alineadas en los entrepanos.
	local shelfRows = T.Level
	for r = 1, shelfRows do
		local sz = -D * 0.5 + 16 + (r - 1) * 15
		if sz > D * 0.5 - 24 then break end

		for _, sx in ipairs({-1, 1}) do
			local rackD = 5.0                      -- fondo del rack
			local rackX = sx * (W * 0.5 - rackD / 2 - 0.4)   -- casi tocando el muro
			-- el rack que taparia la puerta de la oficina se salta
			if not blocksOfficeDoor(rackX, sz) then
			local rackW = 11

			-- postes verticales
			for _, px in ipairs({-rackD / 2 + 0.3, rackD / 2 - 0.3}) do
				for _, pz in ipairs({-rackW / 2 + 0.3, rackW / 2 - 0.3}) do
					local post = part({
						Name = "ShelfPost",
						Size = Vector3.new(0.45, 13, 0.45),
						Position = Vector3.new(rackX + px, 8.5, sz + pz),
						Color = Color3.fromRGB(168, 118, 44),
						Material = Enum.Material.Metal,
					})
					post.Parent = model
				end
			end

			for lvl = 0, 2 do
				local y = 3.4 + lvl * 4.6

				-- entrepano
				local shelf = part({
					Name = "Shelf",
					Size = Vector3.new(rackD, 0.35, rackW),
					Position = Vector3.new(rackX, y, sz),
					Color = Color3.fromRGB(150, 110, 50),
					Material = Enum.Material.Metal,
				})
				shelf.Parent = model

				-- larguero de seguridad al frente
				local rail = part({
					Name = "ShelfRail",
					Size = Vector3.new(0.22, 0.5, rackW),
					Position = Vector3.new(rackX - sx * (rackD / 2 - 0.12), y + 0.4, sz),
					Color = Color3.fromRGB(190, 140, 50),
					Material = Enum.Material.Metal,
					CanCollide = false,
				})
				rail.Parent = model

				-- cajas alineadas encima (no regadas al azar)
				for c = 0, 2 do
					if rng:NextNumber() < 0.72 then
						local bz = sz - rackW / 2 + 1.9 + c * 3.5
						local bh = rng:NextNumber() < 0.35 and 2.0 or 2.8
						local box = part({
							Name = "StoredCrate",
							Size = Vector3.new(3.0, bh, 3.0),
							Position = Vector3.new(rackX, y + 0.18 + bh / 2, bz),
							Color = Color3.fromRGB(128, 96, 62),
							Material = Enum.Material.WoodPlanks,
							CanCollide = false,
						})
						box.Parent = model

						-- fleje y etiqueta, para que no sean cubos pelones
						local strap = part({
							Name = "CrateStrap",
							Size = Vector3.new(3.1, 0.18, 0.3),
							Position = Vector3.new(rackX, y + 0.18 + bh * 0.62, bz),
							Color = Color3.fromRGB(70, 56, 40),
							Material = Enum.Material.Fabric,
							CanCollide = false,
						})
						strap.Parent = model

						local tagp = part({
							Name = "CrateLabel",
							Size = Vector3.new(0.08, 0.7, 1.1),
							Position = Vector3.new(rackX - sx * 1.52,
								y + 0.18 + bh * 0.5, bz),
							Color = Color3.fromRGB(226, 220, 198),
							Material = Enum.Material.SmoothPlastic,
							CanCollide = false,
						})
						tagp.Parent = model
					end
				end
			end
			end
		end
	end

	-- ===== ZONA DE PRENSA =====
	local pressX = -W * 0.5 + 22
	-- Tapete de hule de taller. Antes esto era un cuadro de neon naranja
	-- que se veia horrible y encandilaba toda la zona de la prensa.
	local press = part({
		Name = "PressPad",
		Size = Vector3.new(16, 0.14, 16),
		Position = Vector3.new(pressX, 2.07, -D * 0.5 + 20),
		Color = Color3.fromRGB(38, 40, 44),
		Material = Enum.Material.Pebble,
		CanCollide = false,
	})
	-- franjas de peligro amarillas en la orilla, como en los talleres
	for _, sx in ipairs({-1, 1}) do
		local edge = part({
			Name = "PressPadEdge",
			Size = Vector3.new(0.9, 0.16, 16),
			Position = Vector3.new(pressX + sx * 7.5, 2.08, -D * 0.5 + 20),
			Color = Color3.fromRGB(196, 158, 44),
			Material = Enum.Material.Pebble,
			CanCollide = false,
		})
		edge.Parent = model
	end
	press.Parent = model
	makeBillboard(press, "PRENSA [R]", Color3.fromRGB(255, 170, 110), 11, 110, 30)

	-- ===== MAQUINA DE PRENSA (industrial, no un cubo) =====
	local pmZ = -D * 0.5 + 14

	-- base pesada
	local pbase = part({
		Name = "PressBase",
		Size = Vector3.new(12, 2.2, 9),
		Position = Vector3.new(pressX, 3.1, pmZ),
		Color = Color3.fromRGB(58, 62, 68),
		Material = Enum.Material.DiamondPlate,
	})
	pbase.Parent = model

	-- yunque donde cae el piston
	local anvil = part({
		Name = "PressAnvil",
		Size = Vector3.new(6, 1.2, 5),
		Position = Vector3.new(pressX, 4.8, pmZ),
		Color = Color3.fromRGB(150, 128, 70),
		Material = Enum.Material.Metal,
	})
	anvil.Parent = model

	-- 4 columnas guia
	for _, dx in ipairs({-4.6, 4.6}) do
		for _, dz in ipairs({-3.2, 3.2}) do
			local post = part({
				Name = "PressPost",
				Size = Vector3.new(0.9, 11, 0.9),
				Position = Vector3.new(pressX + dx, 9.5, pmZ + dz),
				Color = Color3.fromRGB(96, 100, 108),
				Material = Enum.Material.Metal,
			})
			post.Parent = model
		end
	end

	-- cabezal de arriba
	local head = part({
		Name = "PressHead",
		Size = Vector3.new(11, 2.6, 8),
		Position = Vector3.new(pressX, 16.2, pmZ),
		Color = Color3.fromRGB(72, 76, 84),
		Material = Enum.Material.DiamondPlate,
	})
	head.Parent = model

	-- motor lateral
	local motor = part({
		Name = "PressMotor",
		Size = Vector3.new(3.2, 3.2, 3.2),
		Position = Vector3.new(pressX + 7, 15.5, pmZ),
		Color = Color3.fromRGB(180, 120, 50),
		Material = Enum.Material.Metal,
	})
	motor.Parent = model

	-- manguera hidraulica
	local hose = part({
		Name = "PressHose",
		Size = Vector3.new(0.5, 6, 0.5),
		Position = Vector3.new(pressX + 7, 11.5, pmZ + 2),
		Color = Color3.fromRGB(28, 28, 32),
		Material = Enum.Material.Rubber,
		CanCollide = false,
	})
	hose.Parent = model

	-- vastago + piston (esto es lo que se anima)
	local rod = part({
		Name = "PressRod",
		Size = Vector3.new(1.6, 5, 1.6),
		Position = Vector3.new(pressX, 12.4, pmZ),
		Color = Color3.fromRGB(190, 194, 200),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	rod.Parent = model

	local piston = part({
		Name = "Piston",
		Size = Vector3.new(5.5, 2.4, 4.6),
		Position = Vector3.new(pressX, 9.2, pmZ),
		Color = Color3.fromRGB(196, 150, 60),
		Material = Enum.Material.Metal,
	})
	-- Altura de reposo. Main la usa para regresar el piston SIEMPRE al
	-- mismo sitio; antes leia la posicion actual y si prensabas dos veces
	-- seguidas se quedaba hundido para siempre.
	piston:SetAttribute("HomeY", 9.2)
	piston.Parent = model

	-- foco de estado
	local statusLamp = part({
		Name = "PressStatus",
		Size = Vector3.new(0.9, 0.9, 0.9),
		Position = Vector3.new(pressX - 5.4, 15.4, pmZ - 3.6),
		Color = Color3.fromRGB(90, 255, 130),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	statusLamp.Parent = model

	-- tarima con bloques ya prensados (decoracion)
	local pallet = part({
		Name = "Pallet",
		Size = Vector3.new(6, 0.5, 5),
		Position = Vector3.new(pressX - 10, 2.4, pmZ + 4),
		Color = Color3.fromRGB(124, 92, 58),
		Material = Enum.Material.Wood,
	})
	pallet.Parent = model
	for bi = 0, 3 do
		local blk = part({
			Name = "StackedBlock",
			Size = Vector3.new(2.4, 1.1, 1.8),
			Position = Vector3.new(pressX - 10 + (bi % 2) * 2.6 - 1.3,
				3.2 + math.floor(bi / 2) * 1.2, pmZ + 4),
			Color = Color3.fromRGB(222, 206, 170),
			Material = Enum.Material.Sand,
		})
		blk.Parent = model
	end

	local pressLight = Instance.new("PointLight")
	pressLight.Color = Color3.fromRGB(255, 150, 90)
	pressLight.Brightness = 0.9
	pressLight.Range = 16
	pressLight.Parent = press

	-- ===== ZONA SEGURA: LA OFICINA (anexo exterior) =====
	-- Cuarto propio pegado por fuera a la pared derecha. Se entra por la
	-- puerta que se abrio en esa pared, asi que no le quita espacio a la
	-- nave. Adentro: cama, buro, sillon, mesita y tapete.
	local safeX = OFF_CX
	local offW = OFF_X1 - OFF_X0
	local offD = OFF_Z1 - OFF_Z0
	local wallH = 13
	local officeCol = Color3.fromRGB(116, 106, 96)

	local function owall(name, size, pos)
		local wpart = part({
			Name = name, Size = size, Position = pos,
			Color = officeCol, Material = Enum.Material.Brick,
		})
		wpart.Parent = model
		return wpart
	end

	-- piso del anexo
	local offFloor = part({
		Name = "OfficeSlab",
		Size = Vector3.new(offW, 2, offD),
		Position = Vector3.new(OFF_CX, 1, OFF_CZ),
		Color = Color3.fromRGB(84, 82, 80),
		Material = Enum.Material.Concrete,
	})
	offFloor.Parent = model

	-- tres muros (el cuarto lado es la pared de la nave)
	owall("OfficeWall", Vector3.new(offW, wallH, 1),
		Vector3.new(OFF_CX, 2 + wallH / 2, OFF_Z0))
	owall("OfficeWall", Vector3.new(offW, wallH, 1),
		Vector3.new(OFF_CX, 2 + wallH / 2, OFF_Z1))
	-- El muro exterior (OFF_X1) va EN TRAMOS para dejar DOS VENTANAS DE VERDAD.
	-- Antes la ventana era un vidrio pegado SOBRE el muro: se veia raro, como
	-- calcomania. Ahora hay hueco de verdad, con marco, travesanos y repisa.
	do
		local winW, winH, sillY = 8, 4.6, 7.4      -- ancho, alto y altura del marco
		local wA = OFF_CZ - 6.5                     -- centro de la ventana de atras
		local wB = OFF_CZ + 6.5                     -- centro de la ventana de adelante
		local function oseg(z0, z1, y0, y1)
			local len = z1 - z0
			if len <= 0.1 or (y1 - y0) <= 0.1 then return end
			local pw = part({
				Name = "OfficeWall",
				Size = Vector3.new(1, y1 - y0, len),
				Position = Vector3.new(OFF_X1, (y0 + y1) / 2, (z0 + z1) / 2),
				Color = officeCol, Material = Enum.Material.Brick,
			})
			pw.Parent = model
		end
		-- tres tramos de altura completa...
		oseg(OFF_Z0, wA - winW / 2, 2, 2 + wallH)
		oseg(wA + winW / 2, wB - winW / 2, 2, 2 + wallH)
		oseg(wB + winW / 2, OFF_Z1, 2, 2 + wallH)
		-- ...y en cada ventana: el antepecho de abajo y el dintel de arriba
		for _, wc in ipairs({wA, wB}) do
			oseg(wc - winW / 2, wc + winW / 2, 2, sillY)
			oseg(wc - winW / 2, wc + winW / 2, sillY + winH, 2 + wallH)

			-- marco de madera (4 lados)
			local frameCol = Color3.fromRGB(78, 56, 40)
			local function ofr(name, size, pos)
				local f = part({
					Name = name, Size = size, Position = pos,
					Color = frameCol, Material = Enum.Material.Wood,
					CanCollide = false,
				})
				f.Parent = model
				return f
			end
			ofr("OfficeWindowFrame", Vector3.new(1.2, 0.4, winW + 0.8),
				Vector3.new(OFF_X1, sillY + 0.2, wc))
			ofr("OfficeWindowFrame", Vector3.new(1.2, 0.4, winW + 0.8),
				Vector3.new(OFF_X1, sillY + winH - 0.2, wc))
			for _, zz in ipairs({wc - winW / 2, wc + winW / 2}) do
				ofr("OfficeWindowFrame", Vector3.new(1.2, winH, 0.4),
					Vector3.new(OFF_X1, sillY + winH / 2, zz))
			end
			-- travesanos (se ve a "ventana", no a hoyo)
			ofr("OfficeWindowMullion", Vector3.new(0.9, winH - 0.6, 0.35),
				Vector3.new(OFF_X1, sillY + winH / 2, wc))
			ofr("OfficeWindowMullion", Vector3.new(0.9, 0.35, winW - 0.6),
				Vector3.new(OFF_X1, sillY + winH / 2, wc))
			-- repisa que sobresale hacia afuera
			local sill = part({
				Name = "OfficeWindowSill",
				Size = Vector3.new(2.4, 0.4, winW + 1.6),
				Position = Vector3.new(OFF_X1 + 0.6, sillY - 0.1, wc),
				Color = Color3.fromRGB(96, 70, 50), Material = Enum.Material.Wood,
				CanCollide = false,
			})
			sill.Parent = model
			-- el vidrio: se ve para adentro y de noche se ilumina
			local glass = part({
				Name = "OfficeWindowGlass",
				Size = Vector3.new(0.35, winH - 0.6, winW - 0.6),
				Position = Vector3.new(OFF_X1, sillY + winH / 2, wc),
				Color = Color3.fromRGB(168, 196, 214),
				Material = Enum.Material.Glass,
				Transparency = 0.5,
				Reflectance = 0.3,
				CanCollide = false,
			})
			glass:SetAttribute("IsWindow", true)
			glass.Parent = model
			tagNeon(glass, Color3.fromRGB(255, 226, 170), Color3.fromRGB(168, 196, 214))
		end
	end

	local ceil = part({
		Name = "OfficeCeiling",
		Size = Vector3.new(offW + 1, 0.8, offD + 1),
		Position = Vector3.new(OFF_CX, 2 + wallH, OFF_CZ),
		Color = Color3.fromRGB(90, 86, 82),
		Material = Enum.Material.Concrete,
	})
	ceil.Parent = model

	-- piso de duela
	local woodFloor = part({
		Name = "OfficeFloor",
		Size = Vector3.new(offW - 1.5, 0.12, offD - 1.5),
		Position = Vector3.new(OFF_CX, 2.06, OFF_CZ),
		Color = Color3.fromRGB(96, 72, 52),
		Material = Enum.Material.WoodPlanks,
		CanCollide = false,
	})
	woodFloor.Parent = model

	-- (la ventana ya se construye arriba, con hueco de verdad en el muro)

	-- ===== SAFEPAD: el detector del Heat (ya sin neon) =====
	local safe = part({
		Name = "SafePad",
		Size = Vector3.new(offW - 6, 0.12, 11),
		Position = Vector3.new(OFF_CX, 2.14, OFF_CZ + 5),
		Color = Color3.fromRGB(64, 58, 72),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	safe.Parent = model
	for _, off in ipairs({-5.6, 5.6}) do
		local edge = part({
			Name = "RugEdge", Size = Vector3.new(offW - 6, 0.14, 0.6),
			Position = Vector3.new(OFF_CX, 2.15, OFF_CZ + 5 + off),
			Color = Color3.fromRGB(96, 84, 108), Material = Enum.Material.Fabric,
			CanCollide = false,
		})
		edge.Parent = model
	end

	local safeLight = Instance.new("PointLight")
	safeLight.Color = Color3.fromRGB(255, 226, 180)
	safeLight.Brightness = 0.95
	safeLight.Range = 30
	safeLight.Parent = ceil

	local function furn(name, size, pos, col, mat)
		local pp = part({
			Name = name, Size = size, Position = pos,
			Color = col, Material = mat or Enum.Material.Wood,
		})
		pp.Parent = model
		return pp
	end

	-- ===== CAMA, contra el muro del fondo =====
	local bedX = OFF_X1 - 6
	local bedZ = OFF_Z0 + 6.5
	furn("BedFrame", Vector3.new(7, 1.1, 9), Vector3.new(bedX, 2.7, bedZ),
		Color3.fromRGB(78, 58, 42))
	furn("Mattress", Vector3.new(6.4, 1.1, 8.4), Vector3.new(bedX, 3.7, bedZ),
		Color3.fromRGB(196, 192, 186), Enum.Material.Fabric)
	furn("Blanket", Vector3.new(6.5, 0.4, 5.2), Vector3.new(bedX, 4.3, bedZ + 1.4),
		Color3.fromRGB(86, 96, 128), Enum.Material.Fabric)
	furn("Pillow2", Vector3.new(4.4, 0.8, 1.9), Vector3.new(bedX, 4.5, bedZ - 3.2),
		Color3.fromRGB(226, 224, 220), Enum.Material.Fabric)
	furn("BedHead", Vector3.new(7, 4, 0.6), Vector3.new(bedX, 4.6, bedZ - 4.4),
		Color3.fromRGB(68, 50, 38))

	furn("NightStand", Vector3.new(2.6, 3, 2.6), Vector3.new(bedX - 5.2, 3.6, bedZ - 3.2),
		Color3.fromRGB(72, 56, 44))
	local lampS = part({
		Name = "DeskLamp", Size = Vector3.new(1.3, 1.3, 1.3),
		Position = Vector3.new(bedX - 5.2, 5.7, bedZ - 3.2),
		Color = Color3.fromRGB(255, 226, 170), Material = Enum.Material.Neon,
		CanCollide = false,
	})
	lampS.Parent = model
	local ll2 = Instance.new("PointLight")
	ll2.Color = Color3.fromRGB(255, 220, 160)
	ll2.Brightness = 0.7
	ll2.Range = 14
	ll2.Parent = lampS

	-- ===== SILLON, del otro lado del cuarto =====
	local cz = OFF_Z1 - 5.5
	local cloth = Color3.fromRGB(86, 68, 64)
	local function couchPart(name, size, pos, col)
		local pp = part({
			Name = name, Size = size, Position = pos,
			Color = col or cloth, Material = Enum.Material.Fabric,
		})
		pp.Parent = model
		return pp
	end
	couchPart("Couch",     Vector3.new(9.4, 1.1, 4.2), Vector3.new(safeX, 3.0, cz))
	couchPart("CouchBack", Vector3.new(9.4, 2.6, 0.7), Vector3.new(safeX, 4.4, cz + 1.75))
	for _, ax in ipairs({-4.55, 4.55}) do
		couchPart("CouchArm", Vector3.new(0.8, 1.9, 4.2), Vector3.new(safeX + ax, 3.9, cz))
	end
	for _, cxx in ipairs({-2.3, 2.3}) do
		couchPart("Cushion", Vector3.new(4.1, 0.6, 3.6),
			Vector3.new(safeX + cxx, 3.8, cz - 0.2), Color3.fromRGB(104, 84, 78))
	end
	for _, lx in ipairs({-4.2, 4.2}) do
		for _, lz in ipairs({-1.6, 1.6}) do
			furn("CouchLeg", Vector3.new(0.4, 0.5, 0.4),
				Vector3.new(safeX + lx, 2.3, cz + lz), Color3.fromRGB(58, 44, 36))
		end
	end

	furn("CoffeeTable", Vector3.new(5, 0.3, 2.6), Vector3.new(safeX, 3.4, cz - 4.6),
		Color3.fromRGB(72, 56, 44))
	for _, tx in ipairs({-2.1, 2.1}) do
		for _, tz in ipairs({-1, 1}) do
			furn("TableLegSmall", Vector3.new(0.3, 1.2, 0.3),
				Vector3.new(safeX + tx, 2.7, cz - 4.6 + tz), Color3.fromRGB(58, 44, 36))
		end
	end

	-- ===== CAJA FUERTE =====
	-- Pegada a la pared del fondo, junto al escritorio con la computadora.
	-- Lo que esta adentro esta a salvo de la Unidad de Aduanas.
	local vaultX = 17
	local vaultZ = -D * 0.5 + 3.6

	local vaultBody = part({
		Name = "VaultBody",
		Size = Vector3.new(10, 11, 6),
		Position = Vector3.new(vaultX, 7.5, vaultZ),
		Color = Color3.fromRGB(58, 64, 74),
		Material = Enum.Material.DiamondPlate,
	})
	vaultBody.Parent = model
	-- v44: pintado en la cara de la caja (antes flotaba encima y tapaba la bodega)
	-- v49: la caja es un cubo ALTISIMO (10 x 11): sin banda el texto se estiraba
	-- en once studs de alto y el motor lo dejaba en ~2. Ahora va en una banda a
	-- media caja con la letra pedida (1.5 studs = 6.5% del alto, se lee de lejos)
	textoPlano(vaultBody, "CAJA FUERTE [C]", Color3.fromRGB(130, 255, 190),
		{ pixels = 64, banda = 0.14, letra = 1.5 })

	local vaultFrame = part({
		Name = "VaultFrame",
		Size = Vector3.new(8.4, 9.4, 0.5),
		Position = Vector3.new(vaultX, 7.5, vaultZ + 3.1),
		Color = Color3.fromRGB(38, 42, 50),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	vaultFrame.Parent = model

	local vaultDoor = part({
		Name = "VaultDoor",
		Size = Vector3.new(0.7, 7.6, 7.6),
		Position = Vector3.new(vaultX, 7.5, vaultZ + 3.4),
		Color = Color3.fromRGB(96, 104, 116),
		Material = Enum.Material.Metal,
		CanCollide = false,
		Shape = Enum.PartType.Cylinder,
	})
	vaultDoor.CFrame = CFrame.new(vaultDoor.Position) * CFrame.Angles(0, math.rad(90), 0)
	vaultDoor.Parent = model

	local wheel = part({
		Name = "VaultWheel",
		Size = Vector3.new(0.5, 3.2, 3.2),
		Position = Vector3.new(vaultX, 7.5, vaultZ + 3.9),
		Color = Color3.fromRGB(190, 160, 70),
		Material = Enum.Material.Metal,
		CanCollide = false,
		Shape = Enum.PartType.Cylinder,
	})
	wheel.CFrame = CFrame.new(wheel.Position) * CFrame.Angles(0, math.rad(90), 0)
	wheel.Parent = model
	for i = 0, 3 do
		local spoke = part({
			Name = "VaultSpoke",
			Size = Vector3.new(0.35, 0.35, 3.6),
			Position = Vector3.new(vaultX, 7.5, vaultZ + 4.0),
			Color = Color3.fromRGB(210, 180, 90),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		spoke.CFrame = CFrame.new(spoke.Position) * CFrame.Angles(0, 0, math.rad(i * 45))
		spoke.Parent = model
	end

	for _, hy in ipairs({10.4, 4.6}) do
		local hinge = part({
			Name = "VaultHinge",
			Size = Vector3.new(1, 1.2, 1.6),
			Position = Vector3.new(vaultX + 4.1, hy, vaultZ + 3.2),
			Color = Color3.fromRGB(40, 44, 52),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		hinge.Parent = model
	end

	local vaultScreen = part({
		Name = "VaultScreen",
		Size = Vector3.new(4.6, 2.4, 0.12),
		Position = Vector3.new(vaultX, 11.6, vaultZ + 3.15),
		Color = Color3.fromRGB(12, 20, 16),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	vaultScreen.Parent = model

	local vsGui = Instance.new("SurfaceGui")
	vsGui.Name = "ScreenGui"
	vsGui.Face = Enum.NormalId.Front
	vsGui.CanvasSize = Vector2.new(300, 160)
	vsGui.LightInfluence = 0
	vsGui.AlwaysOnTop = false
	vsGui.Parent = vaultScreen

	local vsBg = Instance.new("Frame")
	vsBg.Size = UDim2.fromScale(1, 1)
	vsBg.BackgroundColor3 = Color3.fromRGB(10, 18, 15)
	vsBg.BorderSizePixel = 0
	vsBg.Parent = vsGui

	local vsBody = Instance.new("TextLabel")
	vsBody.Name = "VaultText"
	vsBody.Size = UDim2.fromScale(1, 1)
	vsBody.BackgroundTransparency = 1
	vsBody.Font = Enum.Font.GothamBold
	vsBody.TextSize = 24
	vsBody.TextWrapped = true
	vsBody.TextColor3 = Color3.fromRGB(130, 255, 190)
	vsBody.Text = "CAJA FUERTE"
	vsBody.Parent = vsGui

	-- Tapete de acceso. Ya NO es neon: era el cuadrito azul que se veia
	-- tirado entre la boveda y el sillon.
	local vaultPad = part({
		Name = "VaultPad",
		Size = Vector3.new(9, 0.12, 6),
		Position = Vector3.new(vaultX, 2.07, vaultZ + 7),
		Color = Color3.fromRGB(52, 56, 62),
		Material = Enum.Material.Pebble,
		CanCollide = false,
	})
	vaultPad.Parent = model

	local vLight = Instance.new("PointLight")
	vLight.Color = Color3.fromRGB(120, 255, 190)
	vLight.Brightness = 0.7
	vLight.Range = 13
	vLight.Parent = vaultScreen

	-- ===== GARAJE =====
	-- Anexo pegado al costado izquierdo de la nave, con un cajon por
	-- vehiculo. Main estaciona ahi los autos que compraste.
	-- Las medidas (GAR_W/GAR_D/GAR_X/GAR_Z/garH) se calculan ARRIBA, porque
	-- la pared izquierda de la nave necesita saber donde va su hueco.
	local garFloor = part({
		Name = "GarageFloor",
		Size = Vector3.new(GAR_W, 2, GAR_D),
		Position = Vector3.new(GAR_X, 1, GAR_Z),
		Color = Color3.fromRGB(78, 78, 82),
		Material = Enum.Material.Concrete,
	})
	garFloor.Parent = model

	local gwCol = Color3.fromRGB(118, 112, 104)
	local function gw(size, pos)
		local pp = part({
			Name = "GarageWall", Size = size, Position = pos,
			Color = gwCol, Material = Enum.Material.Brick,
		})
		pp.Parent = model
		return pp
	end

	-- fondo y costado exterior: de una pieza
	gw(Vector3.new(GAR_W, garH, 1), Vector3.new(GAR_X, 2 + garH / 2, GAR_Z - GAR_D / 2))
	gw(Vector3.new(1, garH, GAR_D), Vector3.new(GAR_X - GAR_W / 2, 2 + garH / 2, GAR_Z))

	-- ===== EL FRENTE (+Z) VA EN TRAMOS: UN HUECO POR CAJON =====
	-- Antes esta pared era UNA pieza solida: el garaje era una caja cerrada y
	-- los coches no tenian por donde entrar ni salir. Ahora cada cajon tiene su
	-- porton, que se abre solo cuando te acercas (lo maneja Main).
	-- v42: los cajones salen del NIVEL de bodega (1 cajon al empezar, 4 al final)
	local BAYS  = math.max(1, math.min(GC.Bays or 4, Config.BaysDelNivel(TIER)))
	local bayW  = GAR_W / BAYS
	local doorW = math.max(6, math.min(GC.DoorWidth or 9, bayW - 2))
	local doorH = math.min(GC.DoorHeight or 11, garH - 1.5)
	local frontZ = GAR_Z + GAR_D / 2

	-- dintel corrido arriba de los portones + pilares entre cajones
	gw(Vector3.new(GAR_W, garH - doorH - 0.6, 1.2),
		Vector3.new(GAR_X, 2 + doorH + 0.6 + (garH - doorH - 0.6) / 2, frontZ))
	for i = 0, BAYS do
		local px = GAR_X - GAR_W / 2 + bayW * i
		local w = (i == 0 or i == BAYS) and 1.4 or 1.6
		gw(Vector3.new(w, doorH + 0.6, 1.2), Vector3.new(px, 2 + (doorH + 0.6) / 2, frontZ))
	end

	local garCeil = part({
		Name = "GarageCeiling",
		Size = Vector3.new(GAR_W + 1, 0.8, GAR_D),
		Position = Vector3.new(GAR_X, 2 + garH, GAR_Z),
		Color = Color3.fromRGB(92, 90, 88),
		Material = Enum.Material.Concrete,
	})
	garCeil.Parent = model

	-- ===== UN CAJON =====
	-- El porton va en un Model 'GarageDoor' para que Main lo pueda subir
	-- completo (las duelas y la ventanita se mueven juntas).
	-- OJO (v46): el ancho del porton NO puede ser un numero fijo. GameConfig dice
	-- 12, pero el hueco entre pilares mide casi todo el cajon (24.6 con un solo
	-- cajon): el porton tapaba la mitad y a los lados quedaban dos huecos negros,
	-- o sea el usuario veia "el garage sigue sin porton". Se calcula el hueco de
	-- ESTE cajon (los pilares que lo flanquean comen medio ancho cada uno) y el
	-- porton lo tapa completo, menos 0.3 de holgura.
	local function anchoDeHueco(i: number): number
		local wIzq = ((i - 1) == 0 or (i - 1) == BAYS) and 1.4 or 1.6
		local wDer = (i == BAYS) and 1.4 or 1.6
		return bayW - (wIzq + wDer) * 0.5
	end

	for i = 1, BAYS do
		local bx = GAR_X - GAR_W / 2 + bayW * (i - 0.5)
		-- el porton de ESTE cajon
		local anchoPorton = math.max(6, anchoDeHueco(i) - 0.3)
		-- y el alto: la abertura va del piso hasta el dintel (2 + doorH + 0.6)
		local altoPorton = doorH + 0.45

		-- marca del cajon en el piso
		local slot = part({
			Name = "Bay" .. i,
			Size = Vector3.new(9, 0.12, 18),
			Position = Vector3.new(bx, 2.06, GAR_Z),
			Color = Color3.fromRGB(60, 62, 68),
			Material = Enum.Material.Pebble,
			CanCollide = false,
		})
		slot:SetAttribute("BayIndex", i)
		slot.Parent = model

		for _, ex in ipairs({-4.6, 4.6}) do
			local line = part({
				Name = "BayLine",
				Size = Vector3.new(0.35, 0.14, 18),
				Position = Vector3.new(bx + ex, 2.07, GAR_Z),
				Color = Color3.fromRGB(216, 196, 90),
				Material = Enum.Material.Pebble,
				CanCollide = false,
			})
			line.Parent = model
		end

		-- umbral amarillo en la entrada del cajon
		local th = part({
			Name = "GarageThreshold",
			Size = Vector3.new(anchoPorton + 0.6, 0.14, 1.4),
			Position = Vector3.new(bx, 2.09, frontZ),
			Color = Color3.fromRGB(216, 196, 90),
			Material = Enum.Material.Pebble,
			CanCollide = false,
		})
		th.Parent = model

		-- ===== PORTON (cortina metalica) =====
		local doorModel = Instance.new("Model")
		doorModel.Name = "GarageDoor"
		doorModel:SetAttribute("BayIndex", i)
		doorModel:SetAttribute("DoorHeight", doorH)
		doorModel:SetAttribute("HomeY", 2 + doorH / 2)
		doorModel:SetAttribute("HomeZ", frontZ - 0.35)
		doorModel.Parent = model

		local slab = part({
			Name = "DoorSlab",
			-- v46: alto = altoPorton (doorH + 0.45): antes quedaba una franja de
			-- 0.6 libre abajo del dintel por donde se veia el taller
			Size = Vector3.new(anchoPorton, altoPorton, 0.5),
			Position = Vector3.new(bx, 2 + altoPorton / 2, frontZ - 0.35),
			Color = Color3.fromRGB(170, 172, 178),
			Material = Enum.Material.Metal,
		})
		slab:SetAttribute("HomeY", slab.Position.Y)
		doorModel.PrimaryPart = slab
		slab.Parent = doorModel
		-- Main guarda de donde sale cada pieza para poder subir el porton
		-- completo (duelas, ventanita y manija) de un solo tiron
		local function rememberCF(piece)
			piece:SetAttribute("HomeCF", piece.CFrame)
			-- v42: tambien se guarda el TAMANO original. Al abrir, el porton se
			-- ENROLLA (se encoge hacia arriba) en vez de subir por encima del
			-- techo, donde ya no se veia: eso parecia "garaje sin puertas".
			piece:SetAttribute("HomeSize", piece.Size)
		end
		rememberCF(slab)

		-- duelas horizontales (el rayado de las cortinas de taller)
		for d = 1, 7 do
			local slat = part({
				Name = "DoorSlat",
				Size = Vector3.new(anchoPorton - 0.4, 0.16, 0.62),
				Position = Vector3.new(bx, 2 + (altoPorton / 8) * d, frontZ - 0.4),
				Color = Color3.fromRGB(126, 128, 134),
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
			slat.Parent = doorModel
		rememberCF(slat)
		end

		-- ===== v49: franja de seguridad abajo (rojo/blanco) =====
		-- El usuario no veia el porton: era una hoja gris que se perdia en el
		-- hueco oscuro. Con esta franja, el porton CERRADO se ve a leguas.
		for i = 0, 5 do
			local franja = part({
				Name = "DoorStripe",
				Size = Vector3.new(anchoPorton / 6, 0.9, 0.14),
				Position = Vector3.new(bx - anchoPorton / 2 + anchoPorton / 12 + i * (anchoPorton / 6),
					3.15, frontZ - 0.68),
				Color = (i % 2 == 0) and Color3.fromRGB(198, 52, 44)
					or Color3.fromRGB(236, 232, 224),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
			franja.Parent = doorModel
			rememberCF(franja)
		end

		-- ventanita del porton
		local dwin = part({
			Name = "DoorWindow",
			-- v49: mas grande (1.5 -> 2.2 de alto) para que se lea de lejos
			Size = Vector3.new(math.max(3.4, anchoPorton * 0.42), 2.2, 0.34),
			Position = Vector3.new(bx, 2 + altoPorton - 2.6, frontZ - 0.5),
			Color = Color3.fromRGB(150, 180, 200),
			Material = Enum.Material.Glass,
			Transparency = 0.35,
			Reflectance = 0.25,
			CanCollide = false,
		})
		dwin.Parent = doorModel
		rememberCF(dwin)

		-- manija
		local handle = part({
			Name = "DoorHandle",
			-- v49: mas grande para que se lea de lejos
			Size = Vector3.new(2.6, 0.5, 0.35),
			Position = Vector3.new(bx, 3.6, frontZ - 0.75),
			Color = Color3.fromRGB(58, 60, 66),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		handle.Parent = doorModel
		rememberCF(handle)

		-- numero del cajon (al reverso, adentro del taller)
		local plate = part({
			Name = "BayPlate",
			Size = Vector3.new(5.4, 2.3, 0.2),
			Position = Vector3.new(bx, 12, GAR_Z - GAR_D / 2 + 0.7),
			Color = Color3.fromRGB(44, 46, 54),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		plate.Parent = model
		-- v44: el usuario pidio justo esto: "vi un letrero flotante de caja 1;
		-- ahi ya hay uno negro, poner ahi caja 1 pero en texto plano"
		textoPlano(plate, "CAJA " .. i, Color3.fromRGB(214, 218, 228),
			{ pixels = 110, letra = 1.5 })

		-- lampara del techo del cajon (se prende de noche)
		local gl = part({
			Name = "GarageLamp",
			Size = Vector3.new(6, 0.4, 3),
			Position = Vector3.new(bx, 2 + garH - 0.8, GAR_Z),
			Color = Color3.fromRGB(226, 220, 205),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		gl.Parent = model
		local gll = Instance.new("PointLight")
		-- v42: "la cochera tiene muy baja la iluminacion por dentro": la luz estaba
		-- en 0.55 Y se apagaba de dia, asi que el taller se veia negro.
		-- v46: se paso de tuerca al reves -> "de noche la cochera esta DEMASIADO
		-- iluminada". Ahora tiene los dos brillos: 0.75 de dia (se ve sin sol) y
		-- 0.45 de noche (se ve, pero no quema), y el alcance baja de 24 a 18 para
		-- que no se salga por la puerta a iluminar la calle.
		gll.Brightness = 0.75
		gll.Range = 18
		tagLight(gll, 0.45, 0.75)
		gll.Color = Color3.fromRGB(255, 246, 225)
		gll.Parent = gl

		-- lampara de fachada arriba del porton (se prende de noche)
		local fLamp = part({
			Name = "GarageWallLamp",
			Size = Vector3.new(2.6, 0.5, 1.1),
			Position = Vector3.new(bx, 2 + doorH + 2.2, frontZ + 0.9),
			Color = Color3.fromRGB(255, 236, 200),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		fLamp.Parent = model
		local fl = Instance.new("PointLight")
		-- v42: 0.8 dejaba la cochera muy oscura. v46: 1.2 con alcance 28 metia luz
		-- de mas al taller por la puerta; baja a 1.0 y 22.
		fl.Brightness = 1.0
		fl.Range = 22
		fl.Color = Color3.fromRGB(255, 240, 205)
		fl.Parent = fLamp
		-- v46: de noche eran 1.6 y esa lampara esta ARRIBA DE LA PUERTA: con el
		-- porton abierto metia luz al taller. Baja a 1.05 (solo alumbra la fachada).
		tagLight(fl, 1.05)
	end

	-- marcador invisible: Main mide la distancia a este punto para abrir los
	-- portones solos (si mide contra cada porton, es mas lento y mas fragil)
	local trig = part({
		Name = "GarageTrigger",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(GAR_X, 4, frontZ + 2),
		Transparency = 1,
		CanCollide = false,
	})
	trig.Parent = model

	-- ===== AMBIENTACION INTERNA DEL TALLER =====
	if Config.Ambience and Config.Ambience.Enabled and Config.Ambience.Props then
		-- banco de trabajo contra el muro del fondo
		local bench = part({
			Name = "GarageBench",
			Size = Vector3.new(8, 0.5, 3),
			Position = Vector3.new(GAR_X - 5, 5.2, GAR_Z - GAR_D / 2 + 2.6),
			Color = Color3.fromRGB(120, 92, 60),
			Material = Enum.Material.Wood,
		})
		bench.Parent = model
		for _, lx in ipairs({GAR_X - 8.6, GAR_X - 1.4}) do
			local leg = part({
				Name = "BenchLeg",
				Size = Vector3.new(0.6, 3.2, 2.6),
				Position = Vector3.new(lx, 3.6, GAR_Z - GAR_D / 2 + 2.6),
				Color = Color3.fromRGB(74, 74, 78),
				Material = Enum.Material.Metal,
			})
			leg.Parent = model
		end
		local box = part({
			Name = "Toolbox",
			Size = Vector3.new(2.6, 1.4, 1.4),
			Position = Vector3.new(GAR_X - 5, 6.2, GAR_Z - GAR_D / 2 + 2.6),
			Color = Color3.fromRGB(196, 62, 52),
			Material = Enum.Material.Metal,
		})
		box.Parent = model

		-- llantas de refaccion apiladas
		for st = 1, 3 do
			local tire = part({
				Name = "SpareTire",
				Size = Vector3.new(1.1, 3.4 - st * 0.15, 3.4 - st * 0.15),
				Position = Vector3.new(GAR_X + GAR_W / 2 - 4, 2.8 + (st - 1) * 0.9,
					GAR_Z - GAR_D / 2 + 3),
				Color = Color3.fromRGB(32, 32, 36),
				Material = Enum.Material.Rubber,
				Shape = Enum.PartType.Cylinder,
			})
			tire.CFrame = CFrame.new(tire.Position) * CFrame.Angles(0, 0, math.rad(90))
			tire.Parent = model
		end

		-- bote metalico del taller
		local bin = part({
			Name = "GarageBin",
			Size = Vector3.new(3, 4, 3),
			Position = Vector3.new(GAR_X - GAR_W / 2 + 3.4, 4.2, GAR_Z + GAR_D / 2 - 3.5),
			Color = Color3.fromRGB(72, 96, 74),
			Material = Enum.Material.CorrodedMetal,
		})
		bin.Parent = model
	end

	local exit = part({
		Name = "GarageExit",
		Size = Vector3.new(10, 0.3, 10),
		Position = Vector3.new(GAR_X, 2.05, GAR_Z + GAR_D / 2 + 12),
		Transparency = 1,
		CanCollide = false,
	})
	exit.Parent = model

	-- v45: el tablero era de 12 x 2.4 y ahi tiene que caber "GARAJE DE <NOMBRE>".
	-- v46: agrandarlo NO alcanzo (el usuario: "los letreros aun tienen la letra
	-- demasiada pequeña"): el texto se escalaba con TextWrapped en un tablero de
	-- 17 de ancho, o sea cada renglon cabia de sobra y la letra salia pequeñita
	-- en medio de un tablero enorme. Ahora el tablero es MAS CHICO (13 x 3.2) y
	-- el texto va en TextScaled SIN envolver: crece hasta llenar el tablero
	-- (letras de ~1 stud de alto contra ~0.3 de antes), que es como se lee un
	-- rotulo de verdad.
	-- v47: el tablero estaba en y = 14.5 (o sea de 12.9 a 16.1) y la pared del
	-- frente del garaje llega a 14: MAS DE UN TERCIO del tablero quedaba metido en
	-- la pared y el techo (la letra salia CORTADA por abajo, y a eso el usuario le
	-- llamo "la letra se ve super pequeña"). Ahora el tablero se PARA sobre el
	-- techo (13.9..17.9), agarrado con dos postes: se ve completo de frente, de
	-- lado y de lejos, como el rotulo de una tienda.
	local techY = 2 + garH                       -- el techo de la cochera
	-- v48: TERCER reporte del usuario ("aun siguen las letras muy pequeñas").
	-- Lo que estaba mal: el tablero medía 15 x 4 con DOS renglones ("GARAJE DE" /
	-- "NOMBRE"), asi que cada renglon cabia en 2 studs y la letra salia de ~1.7.
	-- Ahora el tablero mide 26 x 5.4 (todo el ancho de la cochera), el texto va en
	-- UN SOLO renglon y el tablero se RECARGA 12 grados hacia la calle: parado en
	-- el patio lo ves de frente, no de canto. La letra pasa de ~1.7 a ~3.2 studs
	-- (el test lo mide con ancho, alto y numero de letras).
	-- donde va el frente del garaje (la cara de afuera de los portones)
	local frenteG = GAR_Z + GAR_D / 2 + 0.3
	local garSign = part({
		Name = "GarageSign",
		-- v49: el tablero se fue AL FRENTE DEL GARAJE, pegado ARRIBA del porton
		-- (era el reporte de siempre: "la letra sigue re chiquita"). Cuando estaba
		-- arriba del techo (v48) la letra ya medía 3 studs en la calle, pero a 15
		-- studs de altura y escondido entre el arbol y el techo nadie lo lee. Aqui
		-- mide 3.1 studs y se lee justo donde entras al cajon, como el rotulo de
		-- una cochera de verdad.
		-- OJO: el techo del garaje llega a y=14.4 (14 + la losa). El tablero
		-- DESCANSA ahi (14.4..18.8): se ve el porton abajo y el rotulo arriba,
		-- como la fachada de una cochera de verdad.
		Size = Vector3.new(24, 4.4, 0.4),
		CFrame = CFrame.new(Vector3.new(GAR_X, 16.6, frenteG)),
		Color = Color3.fromRGB(38, 42, 50),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	garSign.Parent = model
	-- dos abrazaderas chiquitas al frente del garaje (para que no parezca flotando)
	for _, sx in ipairs({-1, 1}) do
		local brazo = part({
			Name = "GarageSignPost",
			Size = Vector3.new(0.5, 1.6, 1.6),
			Position = Vector3.new(GAR_X + sx * (24 * 0.5 - 2.0), 14.2, frenteG - 0.9),
			Color = Color3.fromRGB(58, 62, 70),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		brazo.Parent = model
	end
	-- v44: era un letrero FLOTANTE de 200x50 pixeles encima del tablero negro
	-- (el usuario lo reporto como "textos en grandote muy estorboso"). Ahora el
	-- texto va PINTADO en el tablero negro que ya estaba ahi. Main lo reescribe
	-- con "GARAJE DE <dueno>" o "SIN PROPIETARIO" (funcion RotularGaraje).
	-- 128 px por stud y LETRA DE 3 STUDS medida en el script (v49): la mas grande
	-- que cabe en la placa. Antes se dejaba a TextScaled y el motor la dejaba
	-- chiquita; ahora el tamaño se calcula y se comprueba en las pruebas.
	textoPlano(garSign, "GARAJE", Color3.fromRGB(255, 205, 120),
		{ pixels = 128, letra = 3.0, unaCara = false })

	-- ===== v48: DETALLES DE BODEGA (que se vea de verdad, no una caja) =====
	-- Reporte del usuario: "las bodegas me gustaria que se vieran mas realistas,
	-- unas mejores texturas". Todo esto es GEOMETRIA con materiales de Roblox (no
	-- hay imagenes ni IDs que subir): zocalo de concreto al pie de las paredes,
	-- costillas metalicas en la fachada, ventanas altas, columnas de acero
	-- adentro, viga de carga en el techo, canoa y respiraderos, franjas de
	-- seguridad, placa de acero en el anden, juntas de colado y manchas de aceite
	-- en el patio. Nada de esto tiene colision de mas (lo decorativo no choca).
	local frente = D * 0.5
	local acero = Color3.fromRGB(96, 100, 108)
	local aceroOsc = Color3.fromRGB(58, 60, 66)
	local concreto = Color3.fromRGB(112, 108, 100)
	local seguridad = Color3.fromRGB(226, 178, 40)

	-- zocalo al pie de las tres paredes (el concreto se ve gastado por abajo)
	for _, zk in ipairs({{0, -D * 0.5}, {-W * 0.5, 0}, {W * 0.5, 0}}) do
		local horizontal = math.abs(zk[2] + D * 0.5) < 0.1
		local zoc = part({
			Name = "WallSkirt",
			-- OJO: 0.4 de alto y SIN colision. Un zocalo mas alto choca a la altura
			-- del torso y el validador lo trata como muro: tapaba el paso del
			-- porton y de la oficina (etapa 7: "no se puede caminar al garaje").
			Size = horizontal and Vector3.new(W, 0.4, 0.5) or Vector3.new(0.5, 0.4, D),
			Position = Vector3.new(zk[1], 2.2, zk[2] + (horizontal and 0.9 or 0)),
			Color = concreto,
			Material = Enum.Material.Concrete,
			CanCollide = false,
		})
		zoc.Parent = model
	end

	-- costillas metalicas de la fachada (el "canal" de una bodega de verdad)
	do
		local n = math.max(4, math.floor(W / 7))
		for i = 1, n do
			local rx = -W * 0.5 + (W / (n + 1)) * i
			local rib = part({
				Name = "WallRib",
				Size = Vector3.new(0.5, H - 1.6, 0.45),
				Position = Vector3.new(rx, 2 + (H - 1.6) * 0.5 + 1.6, frente + 0.3),
				Color = acero,
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
			rib.Parent = model
		end
		-- franja de color a media pared (rompe el color plano)
		local banda = part({
			Name = "WallBand",
			Size = Vector3.new(W, 1.1, 0.4),
			Position = Vector3.new(0, 2 + H * 0.62, frente + 0.35),
			Color = Color3.fromRGB(176, 78, 60),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		banda.Parent = model
	end

	-- ventanas altas (luz de dia) en los costados: vidrio traslucido
	for _, vx in ipairs({-W * 0.5 - 0.2, W * 0.5 + 0.2}) do
		for i = 1, 2 do
			local win = part({
				Name = "Clerestory",
				Size = Vector3.new(0.3, 2.2, D * 0.22),
				Position = Vector3.new(vx, 2 + H - 3.2, -D * 0.16 + (i - 1) * D * 0.34),
				Color = Color3.fromRGB(150, 190, 210),
				Material = Enum.Material.Glass,
				Transparency = 0.45,
			})
			win.CanCollide = false
			win.Parent = model
		end
	end

	-- columnas de acero adentro, pegadas a las paredes (con placa en la base)
	do
		local n = math.max(2, math.floor(D / 26))
		for i = 1, n do
			local cz = -D * 0.5 + (D / (n + 1)) * i
			-- OJO: una columna frente a una puerta la TAPA (y el validador la caza:
			-- "no se puede caminar al garaje / a la oficina"). Se salta ese lugar.
			local estorba = (math.abs(cz - GAR_Z) < GAR_DOOR / 2 + 3)
				or (math.abs(cz - OFF_CZ) < OFF_DOOR / 2 + 3)
			for _, cx in ipairs(estorba and {} or {-W * 0.5 + 0.9, W * 0.5 - 0.9}) do
				local col = part({
					Name = "SteelColumn",
					Size = Vector3.new(0.9, H - 1.2, 0.9),
					Position = Vector3.new(cx, 2 + (H - 1.2) * 0.5, cz),
					Color = aceroOsc,
					Material = Enum.Material.DiamondPlate,
				})
				col.Parent = model
				local placa = part({
					Name = "ColumnBase",
					Size = Vector3.new(1.7, 0.4, 1.7),
					Position = Vector3.new(cx, 2.2, cz),
					Color = acero,
					Material = Enum.Material.DiamondPlate,
				})
				placa.Parent = model
			end
		end
	end

	-- viga de carga en el techo (con su polipasto)
	do
		local viga = part({
			Name = "HoistBeam",
			Size = Vector3.new(W - 4, 0.8, 0.8),
			Position = Vector3.new(0, 2 + H - 1.4, -D * 0.1),
			Color = acero,
			Material = Enum.Material.Metal,
		})
		viga.Parent = model
		local trole = part({
			Name = "HoistTrolley",
			Size = Vector3.new(1.4, 1.2, 1.6),
			Position = Vector3.new(-W * 0.15, 2 + H - 2.4, -D * 0.1),
			Color = seguridad,
			Material = Enum.Material.Metal,
		})
		trole.Parent = model
	end

	-- canoa (desague del techo) + respiraderos
	for _, sx in ipairs({-1, 1}) do
		local canoa = part({
			Name = "RoofGutter",
			Size = Vector3.new(W + 1.6, 0.6, 0.6),
			Position = Vector3.new(0, 2 + H + 0.5, sx * (D * 0.5 + 0.4)),
			Color = aceroOsc,
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		canoa.Parent = model
	end
	for i = 1, 2 do
		local tubo = part({
			Name = "RoofStack",
			Size = Vector3.new(0.8, 3.2, 0.8),
			Position = Vector3.new(-W * 0.32 + i * W * 0.3, 2 + H + 1.6, -D * 0.28),
			Color = aceroOsc,
			Material = Enum.Material.Metal,
			Shape = Enum.PartType.Cylinder,
		})
		tubo.CFrame = CFrame.new(tubo.Position) * CFrame.Angles(0, 0, math.rad(90))
		tubo.Parent = model
	end

	-- ===== piso: franjas de seguridad, placa de acero del anden y manchas =====
	for i = 1, 2 do
		local franja = part({
			Name = "FloorStripe",
			Size = Vector3.new(W - 12, 0.14, 0.7),
			Position = Vector3.new(0, 2.08, -D * 0.5 + 10 + i * 12),
			Color = seguridad,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		franja.Parent = model
	end
	do
		local placaAcero = part({
			Name = "DockSteelPlate",
			Size = Vector3.new(11, 0.18, 7),
			Position = Vector3.new(W * 0.5 - 12, 2.09, -D * 0.5 + 4.5),
			Color = acero,
			Material = Enum.Material.DiamondPlate,
			CanCollide = false,
		})
		placaAcero.Parent = model
	end
	-- OJO (v49): el usuario vio "unos palitos negros" en el piso de la nave. Eran
	-- ESTAS manchas. Un Part cilindrico tiene su EJE en X: el largo va en X y el
	-- DIAMETRO en Y y Z. Con size (4.6, 0.1, 4.6) el "disco" era en realidad un
	-- TUBO de 4.6 de largo y 0.1 de grueso, y como el CFrame se aplica DESPUES,
	-- el giro de 90 en Z lo dejaba PARADO: un palito negro de 4.6 studs.
	-- Ahora va al reves: el GROSOR (0.12) en X y el diametro (4.6) en Y y Z, con
	-- el mismo giro: disco plano de 4.6 tirado en el piso.
	for i = 1, 2 do
		local mancha = part({
			Name = "OilStain",
			Size = Vector3.new(0.12, 4.6, 4.6),
			Position = Vector3.new(-W * 0.1 + i * 7, 2.08, -D * 0.15 + i * 4),
			Color = Color3.fromRGB(38, 36, 40),
			Material = Enum.Material.Slate,
			Shape = Enum.PartType.Cylinder,
			CanCollide = false,
		})
		mancha.CFrame = CFrame.new(mancha.Position) * CFrame.Angles(0, 0, math.rad(90))
		mancha.Parent = model
	end

	-- tuberia pegada a la pared izquierda + extintor (vida de taller)
	do
		-- OJO (v49): este tubo iba a 1.1 del piso y 0.4 de grueso: se veia como un
		-- "palito" parado junto a la pared. Ahora baja hasta el piso y va pegado a
		-- la pared, como una bajante de agua de verdad.
		local tubo = part({
			Name = "WallPipe",
			Size = Vector3.new(0.45, H - 6, 0.45),
			Position = Vector3.new(-W * 0.5 + 0.55, 2 + (H - 6) * 0.5, D * 0.5 - 6),
			Color = aceroOsc,
			Material = Enum.Material.CorrodedMetal,
			CanCollide = false,
		})
		tubo.Parent = model
		local ext = part({
			Name = "Extinguisher",
			Size = Vector3.new(0.9, 1.7, 0.9),
			Position = Vector3.new(W * 0.5 - 1.6, 5.6, D * 0.5 - 8),
			Color = Color3.fromRGB(196, 46, 40),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		ext.Parent = model
	end

	-- ===== LAMPARAS DE TECHO =====
	local lampCount = math.max(3, math.floor(W / 45))
	for i = 1, lampCount do
		local lx = -W * 0.5 + (W / (lampCount + 1)) * i
		local lamp = part({
			Name = "Lamp",
			Size = Vector3.new(8, 0.5, 8),
			Position = Vector3.new(lx, H, 0),
			Color = Color3.fromRGB(226, 220, 205),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		lamp.Parent = model

		local l = Instance.new("PointLight")
		-- OJO: con Range 60 y varias lamparas la luz se SUMA y quema
		-- toda la bodega. Alcance corto = cada lampara ilumina lo suyo.
		l.Brightness = 0.85
		l.Range = 26
		l.Color = Color3.fromRGB(255, 244, 220)
		l.Parent = lamp
	end

	-- ===== MESAS DE CULTIVO CON LUZ UV =====
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = model

	local plotCount = T.Plots
	local perRow = 4
	local startZ = -D * 0.5 + 40

	for i = 1, plotCount do
		local row = math.floor((i - 1) / perRow)
		local col = (i - 1) % perRow
		local px = -27 + col * 18
		local pz = startZ + row * 22
		if pz > D * 0.5 - 14 then break end

		local base = Vector3.new(px, 2, pz)

		-- === MESA DE CULTIVO ===
		-- patas
		for _, dx in ipairs({-5.5, 5.5}) do
			for _, dz in ipairs({-3.5, 3.5}) do
				local leg = part({
					Name = "TableLeg",
					Size = Vector3.new(0.35, 3.2, 0.35),
					Position = base + Vector3.new(dx, 1.6, dz),
					Color = Color3.fromRGB(96, 100, 106),
					Material = Enum.Material.Metal,
				})
				leg.Parent = plots
			end
		end

		-- tablero de la mesa
		local table_ = part({
			Name = "GrowTable",
			Size = Vector3.new(12, 0.4, 8),
			Position = base + Vector3.new(0, 3.4, 0),
			Color = Color3.fromRGB(120, 126, 134),
			Material = Enum.Material.Metal,
		})
		table_.Parent = plots

		-- la zona interactiva (invisible, es solo el marcador)
		local p = part({
			Name = "Plot" .. i,
			Size = Vector3.new(12, 0.2, 8),
			Position = base + Vector3.new(0, 3.7, 0),
			Color = Color3.fromRGB(120, 200, 120),
			Material = Enum.Material.Neon,
			Transparency = 0.85,
			CanCollide = false,
		})
		p:SetAttribute("PlotIndex", i)
		p.Parent = plots

		-- === MACETAS CON PLANTAS INDIVIDUALES ===
		-- Cada planta es su propio Model con estado. Crece sola y cuando
		-- esta lista se pone verde fuerte y prende su foquito.
		for mx = -1, 1 do
			for mz = 0, 1 do
				local potPos = base + Vector3.new(mx * 3.6, 4.2, -1.8 + mz * 3.6)

				local plant = Instance.new("Model")
				plant.Name = "Plant"
				plant:SetAttribute("PlotIndex", i)
				plant:SetAttribute("Ripe", false)
				plant:SetAttribute("Growth", 0)
				plant.Parent = plots

				-- maceta de barro
				local pot = part({
					Name = "Pot",
					Size = Vector3.new(2, 1.5, 2),
					Position = potPos,
					Color = Color3.fromRGB(140, 86, 62),
					Material = Enum.Material.Slate,
					CanCollide = false,
				})
				pot.Parent = plant
				plant.PrimaryPart = pot

				-- tierra
				local soil = part({
					Name = "Soil",
					Size = Vector3.new(1.7, 0.3, 1.7),
					Position = potPos + Vector3.new(0, 0.8, 0),
					Color = Color3.fromRGB(58, 44, 32),
					Material = Enum.Material.Ground,
					CanCollide = false,
				})
				soil.Parent = plant

				-- tallo
				local stem = part({
					Name = "Stem",
					Size = Vector3.new(0.22, 1.8, 0.22),
					Position = potPos + Vector3.new(0, 1.8, 0),
					Color = Color3.fromRGB(64, 108, 52),
					Material = Enum.Material.Grass,
					CanCollide = false,
				})
				stem.Parent = plant

				-- hojas: 3 capas
				for lvl = 0, 2 do
					local sc = 1.5 - lvl * 0.35
					local leafP = part({
						Name = "Leaf",
						Size = Vector3.new(sc, 0.28, sc),
						Position = potPos + Vector3.new(0, 1.9 + lvl * 0.55, 0),
						Color = Color3.fromRGB(88 + lvl * 14, 168 + lvl * 10, 72),
						Material = Enum.Material.Grass,
						Orientation = Vector3.new(0, lvl * 32, 0),
						CanCollide = false,
					})
					-- guardamos el tamaño de planta adulta para poder
					-- escalarla segun cuanto ha crecido
					leafP:SetAttribute("FullX", sc)
					leafP:SetAttribute("FullY", 0.28)
					leafP:SetAttribute("BaseY", 1.9 + lvl * 0.55)
					leafP.Parent = plant
				end

				-- foquito verde que se prende cuando esta lista
				local ripeGlow = part({
					Name = "RipeGlow",
					Size = Vector3.new(0.45, 0.45, 0.45),
					Position = potPos + Vector3.new(0, 3.9, 0),
					Color = Color3.fromRGB(120, 255, 150),
					Material = Enum.Material.Neon,
					Transparency = 1,
					CanCollide = false,
				})
				ripeGlow.Parent = plant

				local gl = Instance.new("PointLight")
				gl.Name = "RipeLight"
				gl.Color = Color3.fromRGB(120, 255, 150)
				gl.Brightness = 0
				gl.Range = 7
				gl.Parent = ripeGlow
			end
		end

		-- === BARRA DE LUZ UV SOBRE LA MESA ===
		-- soportes verticales
		for _, dx in ipairs({-5, 5}) do
			local pole = part({
				Name = "UVPole",
				Size = Vector3.new(0.25, 7, 0.25),
				Position = base + Vector3.new(dx, 7.2, 0),
				Color = Color3.fromRGB(88, 92, 98),
				Material = Enum.Material.Metal,
			})
			pole.Parent = plots
		end

		-- carcasa de la lampara
		local housing = part({
			Name = "UVHousing",
			Size = Vector3.new(11, 0.6, 3),
			Position = base + Vector3.new(0, 10.4, 0),
			Color = Color3.fromRGB(190, 192, 198),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		housing.Parent = plots

		-- tubo UV morado
		local uvTube = part({
			Name = "UVTube",
			Size = Vector3.new(10, 0.45, 2),
			Position = base + Vector3.new(0, 10, 0),
			Color = Color3.fromRGB(176, 116, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		uvTube.Parent = plots

		local uvLight = Instance.new("SpotLight")
		uvLight.Color = Color3.fromRGB(186, 130, 255)
		uvLight.Brightness = 0.45
		uvLight.Range = 9
		uvLight.Angle = 110
		uvLight.Face = Enum.NormalId.Bottom
		uvLight.Parent = uvTube

		-- cable colgante
		local cable = part({
			Name = "Cable",
			Size = Vector3.new(0.12, 2.2, 0.12),
			Position = base + Vector3.new(4, 11.6, 0),
			Color = Color3.fromRGB(30, 30, 34),
			Material = Enum.Material.Rubber,
			CanCollide = false,
		})
		cable.Parent = plots
	end

	-- ===== ESCRITORIO DE MEJORAS (con computadora) =====
	local nextTier = Config.WarehouseTiers[T.Level + 1]
	-- Pegado a la pared del fondo. Antes estaba a 9 studs y se veia flotando
	-- en medio del cuarto.
	local deskZ = -D * 0.5 + 4.2
	local deskX = 0

	-- zona invisible que detecta que estas ahi
	local upgradePad = part({
		Name = "UpgradePad",
		Size = Vector3.new(14, 8, 10),
		Position = Vector3.new(deskX, 5, deskZ + 3),
		Transparency = 1,
		CanCollide = false,
	})
	upgradePad.Parent = model

	-- tapete
	local rug = part({
		Name = "DeskRug",
		Size = Vector3.new(13, 0.12, 9),
		Position = Vector3.new(deskX, 2.1, deskZ + 2),
		Color = Color3.fromRGB(58, 52, 70),
		Material = Enum.Material.Fabric,
		CanCollide = false,
	})
	rug.Parent = model

	-- escritorio
	local desk = part({
		Name = "Desk",
		Size = Vector3.new(9, 0.4, 4.5),
		Position = Vector3.new(deskX, 5.2, deskZ),
		Color = Color3.fromRGB(72, 58, 46),
		Material = Enum.Material.Wood,
	})
	desk.Parent = model
	for _, dx in ipairs({-4, 4}) do
		for _, dz in ipairs({-1.8, 1.8}) do
			local dl = part({
				Name = "DeskLeg",
				Size = Vector3.new(0.35, 3.2, 0.35),
				Position = Vector3.new(deskX + dx, 3.4, deskZ + dz),
				Color = Color3.fromRGB(70, 74, 80),
				Material = Enum.Material.Metal,
			})
			dl.Parent = model
		end
	end

	-- torre de la compu
	local tower = part({
		Name = "PCTower",
		Size = Vector3.new(1.6, 3.2, 3),
		Position = Vector3.new(deskX + 3.4, 4, deskZ - 0.4),
		Color = Color3.fromRGB(34, 36, 42),
		Material = Enum.Material.Metal,
	})
	tower.Parent = model
	local towerLed = part({
		Name = "PCLed",
		Size = Vector3.new(0.25, 0.25, 0.25),
		Position = Vector3.new(deskX + 3.4, 5.2, deskZ - 1.9),
		Color = Color3.fromRGB(90, 200, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	towerLed.Parent = model

	-- base y poste del monitor
	local mStand = part({
		Name = "MonitorStand",
		Size = Vector3.new(2, 0.2, 1.4),
		Position = Vector3.new(deskX, 5.5, deskZ),
		Color = Color3.fromRGB(40, 42, 48),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	mStand.Parent = model
	local mPost = part({
		Name = "MonitorPost",
		Size = Vector3.new(0.35, 1.6, 0.35),
		Position = Vector3.new(deskX, 6.3, deskZ),
		Color = Color3.fromRGB(40, 42, 48),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	mPost.Parent = model

	-- carcasa del monitor
	local monitor = part({
		Name = "MonitorBody",
		Size = Vector3.new(6.4, 4, 0.4),
		Position = Vector3.new(deskX, 9, deskZ),
		Color = Color3.fromRGB(26, 28, 34),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	monitor.Parent = model

	-- LA PANTALLA: aqui se dibuja el menu de mejoras
	local screen = part({
		Name = "UpgradeScreen",
		Size = Vector3.new(6, 3.6, 0.12),
		Position = Vector3.new(deskX, 9, deskZ + 0.3),
		Color = Color3.fromRGB(14, 18, 30),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	screen.Parent = model

	local screenGui = Instance.new("SurfaceGui")
	screenGui.Name = "ScreenGui"
	screenGui.Face = Enum.NormalId.Front
	screenGui.CanvasSize = Vector2.new(400, 240)
	screenGui.LightInfluence = 0
	screenGui.AlwaysOnTop = false
	screenGui.Parent = screen

	local scrBg = Instance.new("Frame")
	scrBg.Size = UDim2.fromScale(1, 1)
	scrBg.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
	scrBg.BorderSizePixel = 0
	scrBg.Parent = screenGui

	local scrTitle = Instance.new("TextLabel")
	scrTitle.Name = "ScreenTitle"
	scrTitle.Size = UDim2.new(1, 0, 0, 54)
	scrTitle.BackgroundColor3 = Color3.fromRGB(40, 90, 190)
	scrTitle.BorderSizePixel = 0
	scrTitle.Font = Enum.Font.GothamBold
	scrTitle.TextScaled = true
	scrTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	scrTitle.Text = "SISTEMA DE BODEGA"
	scrTitle.Parent = screenGui

	local scrBody = Instance.new("TextLabel")
	scrBody.Name = "ScreenBody"
	scrBody.Size = UDim2.new(1, -20, 1, -70)
	scrBody.Position = UDim2.new(0, 10, 0, 62)
	scrBody.BackgroundTransparency = 1
	scrBody.Font = Enum.Font.Gotham
	scrBody.TextSize = 22
	scrBody.TextWrapped = true
	scrBody.TextYAlignment = Enum.TextYAlignment.Top
	scrBody.TextColor3 = Color3.fromRGB(150, 220, 255)
	if nextTier then
		scrBody.Text = string.format(
			"Nivel actual: %s\n\nDisponible: %s\n\nAcercate y presiona  G  para abrir las mejoras.",
			T.Name, nextTier.Name)
	else
		scrBody.Text = string.format("Nivel actual: %s\n\nNIVEL MAXIMO ALCANZADO.", T.Name)
	end
	scrBody.Parent = screenGui

	-- silla
	-- Silla de oficina completa: asiento, respaldo, columna y base de
	-- estrella con rueditas. Antes era un asiento suelto flotando.
	local chairZ = deskZ + 3.6
	local seat = part({
		Name = "DeskChair",
		Size = Vector3.new(2.3, 0.35, 2.3),
		Position = Vector3.new(deskX, 4.3, chairZ),
		Color = Color3.fromRGB(36, 38, 44),
		Material = Enum.Material.Fabric,
	})
	seat.Parent = model

	local chairBack = part({
		Name = "ChairBack",
		Size = Vector3.new(2.3, 3.0, 0.35),
		Position = Vector3.new(deskX, 5.9, chairZ + 1.1),
		Color = Color3.fromRGB(32, 34, 40),
		Material = Enum.Material.Fabric,
	})
	chairBack.Parent = model

	-- columna central
	local post = part({
		Name = "ChairPost",
		Size = Vector3.new(0.45, 1.9, 0.45),
		Position = Vector3.new(deskX, 3.2, chairZ),
		Color = Color3.fromRGB(110, 112, 120),
		Material = Enum.Material.Metal,
	})
	post.Parent = model

	-- base de estrella
	for k = 0, 4 do
		local a = (k / 5) * math.pi * 2
		local leg = part({
			Name = "ChairFoot",
			Size = Vector3.new(0.3, 0.2, 2.0),
			Position = Vector3.new(deskX + math.sin(a) * 0.9, 2.3,
				chairZ + math.cos(a) * 0.9),
			Color = Color3.fromRGB(80, 82, 90),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		leg.CFrame = CFrame.new(leg.Position) * CFrame.Angles(0, a, 0)
		leg.Parent = model

		local wheel = part({
			Name = "ChairWheel",
			Size = Vector3.new(0.35, 0.35, 0.35),
			Position = Vector3.new(deskX + math.sin(a) * 1.8, 2.15,
				chairZ + math.cos(a) * 1.8),
			Color = Color3.fromRGB(28, 28, 32),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Shape = Enum.PartType.Ball,
		})
		wheel.Parent = model
	end

	-- lampara del escritorio
	local deskLight = Instance.new("PointLight")
	deskLight.Color = Color3.fromRGB(140, 200, 255)
	deskLight.Brightness = 0.9
	deskLight.Range = 14
	deskLight.Parent = screen

	-- v44: pintado en la pantalla del monitor (antes flotaba encima)
	if nextTier then
		textoPlano(monitor, "MEJORAS [G]", Color3.fromRGB(160, 200, 255),
			{ pixels = 64, letra = 1.0 })
	else
		textoPlano(monitor, "NIVEL MAXIMO", Color3.fromRGB(160, 200, 255),
			{ pixels = 64, letra = 1.0 })
	end

	-- ===== VIGILANTE junto a la entrada, mirando a la calle =====
	-- Va del lado del muelle, pegado a la pared pero VIENDO HACIA AFUERA (+Z).
	-- acera de concreto: sin esto el vigilante queda flotando, porque
	-- afuera de la bodega ya no hay piso y el terreno esta mas abajo.
	local curb = part({
		Name = "GuardCurb",
		Size = Vector3.new(34, 2, 18),
		Position = Vector3.new(-W * 0.5 + 12, 1, D * 0.5 + 7),
		Color = Color3.fromRGB(104, 102, 98),
		Material = Enum.Material.Concrete,
	})
	curb.Parent = model

	-- borde de la banqueta
	local curbEdge = part({
		Name = "CurbEdge",
		Size = Vector3.new(34, 0.4, 0.6),
		Position = Vector3.new(-W * 0.5 + 12, 2.2, D * 0.5 + 16),
		Color = Color3.fromRGB(150, 148, 142),
		Material = Enum.Material.Concrete,
		CanCollide = false,
	})
	curbEdge.Parent = model

	local guardPos = Vector3.new(-W * 0.5 + 12, 2, D * 0.5 + 4)
	local guard = makeBuyerNPC(model, guardPos,
		{Id = "guard", Name = "El Vigilante"}, Vector3.new(0, 0, 1), "guard")
	guard.Name = "Lookout"
	CollectionService:RemoveTag(guard, "BuyerNPC")
	CollectionService:AddTag(guard, "LookoutNPC")
	guard:SetAttribute("BuyerName", "El Vigilante")

	-- lo recargamos: ligera inclinacion SIN perder hacia donde mira.
	-- Usamos guardPos directo (no PrimaryPart.Position) para no depender
	-- de que el rig ya este resuelto.
	pcall(function()
		local anchor = guardPos + Vector3.new(0, 3, 0)
		guard:PivotTo(
			CFrame.lookAt(anchor, anchor + Vector3.new(0, 0, 1))
			* CFrame.Angles(0, 0, math.rad(-7))
		)
	end)

	-- barril donde se recarga
	local barrel = part({
		Name = "Barrel",
		Size = Vector3.new(3, 4, 3),
		Position = guardPos + Vector3.new(-6.5, 2, -1.5),
		Color = Color3.fromRGB(96, 58, 44),
		Material = Enum.Material.CorrodedMetal,
	})
	barrel.Parent = model

	-- cigarro encendido en la mano
	local smoke = part({
		Name = "Cig",
		Size = Vector3.new(0.16, 0.16, 0.6),
		Position = guardPos + Vector3.new(1.5, 2.3, 0.4),
		Color = Color3.fromRGB(255, 120, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	smoke.Parent = model

	local cigLight = Instance.new("PointLight")
	cigLight.Color = Color3.fromRGB(255, 130, 60)
	cigLight.Brightness = 0.8
	cigLight.Range = 6
	cigLight.Parent = smoke

	-- botes y basura afuera
	makeTrashCan(model, Vector3.new(-W * 0.5 + 4, 2, D * 0.5 + 10))
	scatterTrash(model, Vector3.new(-W * 0.5 + 10, 2, D * 0.5 + 8), 9, 10)

	-- ===== LETRERO EXTERIOR =====
	local signPost = part({
		Name = "SignPost",
		Size = Vector3.new(W * 0.4, 5, 0.6),
		Position = Vector3.new(0, H + 6, D * 0.5 + 1),
		Color = Color3.fromRGB(34, 32, 36),
		Material = Enum.Material.Metal,
	})
	signPost.Parent = model

	-- ======================================================================
	-- AMBIENTACION EXTERIOR + ILUMINACION DE NOCHE
	-- ======================================================================
	-- Todo lo que lleva tagLight/tagNeon se PRENDE SOLO cuando anochece y se
	-- apaga de dia (lo maneja el ciclo en SetupLighting). Antes afuera quedaba
	-- boca de lobo: ni una luz en el lote.
	local AMB = Config.Ambience
	if AMB and AMB.Enabled then
		local frontZ2 = D * 0.5
		local colLamp = Color3.fromRGB(255, 236, 200)

		-- ---------- lampara de pared (utilidad reutilizable) ----------
		local function wallLamp(name, pos, rotateY: number?)
			local arm = part({
				Name = name .. "Arm",
				Size = Vector3.new(0.4, 0.4, 1.2),
				Position = pos,
				Color = Color3.fromRGB(58, 60, 66),
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
			arm.Parent = model
			local bulb = part({
				Name = name,
				Size = Vector3.new(0.8, 0.5, 1.6),
				Position = pos + Vector3.new(0, -0.5, 0),
				Color = colLamp,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			bulb.Parent = model
			if rotateY then
				arm.CFrame = CFrame.new(arm.Position) * CFrame.Angles(0, rotateY, 0)
				bulb.CFrame = CFrame.new(bulb.Position) * CFrame.Angles(0, rotateY, 0)
			end
			local pl = Instance.new("PointLight")
			pl.Brightness = 1.7
			pl.Range = 32
			pl.Color = Color3.fromRGB(255, 240, 205)
			pl.Parent = bulb
			tagLight(pl, 1.7)
			return bulb
		end

		-- ---------- lamparas de las esquinas de la fachada ----------
		wallLamp("LotWallLamp", Vector3.new(-W * 0.5 + 3, H + 1.5, frontZ2 + 0.9))
		wallLamp("LotWallLamp", Vector3.new(W * 0.5 - 3, H + 1.5, frontZ2 + 0.9))

		-- ---------- letrero luminoso sobre el porton ----------
		local gSign = part({
			Name = "GateSign",
			Size = Vector3.new(math.min(26, W * 0.5), 4.2, 0.5),
			Position = Vector3.new(0, H + 4.2, frontZ2 + 1.2),
			Color = Color3.fromRGB(28, 26, 32),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		gSign.Parent = model
		textoPlano(gSign, "IMPERIO DE ESPECIAS", Color3.fromRGB(255, 206, 110),
			{ pixels = 90, letra = 1.7 })
		local signGlow = part({
			Name = "GateSignGlow",
			Size = Vector3.new(math.min(26, W * 0.5) + 1.2, 0.35, 0.35),
			Position = Vector3.new(0, H + 2.2, frontZ2 + 1.2),
			Color = Color3.fromRGB(255, 200, 120),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		signGlow.Parent = model
		local sg = Instance.new("PointLight")
		-- v46: 1.4 con alcance 34 se metia al taller; baja a 1.0 y 26
		sg.Brightness = 1.0
		sg.Range = 26
		sg.Color = Color3.fromRGB(255, 214, 150)
		sg.Parent = signGlow
		tagLight(sg, 1.0)

		-- ---------- reflector en el techo apuntando al patio ----------
		local flood = part({
			Name = "RoofFloodLight",
			Size = Vector3.new(1.6, 0.6, 1.6),
			Position = Vector3.new(-W * 0.28, H + 3.4, -D * 0.1),
			Color = Color3.fromRGB(230, 226, 210),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		flood.CFrame = CFrame.new(flood.Position) * CFrame.Angles(math.rad(38), math.rad(180), 0)
		flood.Parent = model
		local fl2 = Instance.new("SpotLight")
		-- v46: 2.4 / 90 lavaba el patio y entraba a la nave; baja a 1.8 / 66
		fl2.Brightness = 1.8
		fl2.Range = 66
		fl2.Angle = 75
		fl2.Face = Enum.NormalId.Back
		fl2.Color = Color3.fromRGB(255, 244, 220)
		fl2.Parent = flood
		tagLight(fl2, 1.8)

		-- ---------- luces DE ADENTRO de la nave (de noche) ----------
		for i = -1, 1 do
			local lamp = part({
				Name = "NaveLamp",
				Size = Vector3.new(4, 0.4, 8),
				Position = Vector3.new(0, H - 1.2, i * (D * 0.24)),
				Color = Color3.fromRGB(232, 226, 210),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			lamp.Parent = model
			local pl = Instance.new("PointLight")
			-- v46: eran 1.1 de noche con alcance 42 (tres lamparas de esas): la nave
			-- se veia lavada por dentro. Ahora 0.5 de noche y 0.75 de dia (nunca
			-- apagada: de dia el interior tambien se ve) y alcance 30.
			pl.Brightness = 0.75
			pl.Range = 30
			pl.Color = Color3.fromRGB(255, 246, 228)
			pl.Parent = lamp
			tagLight(pl, 0.5, 0.75)
		end

		-- ---------- aires acondicionados en el techo ----------
		if AMB.Roof then
			for _, rx in ipairs({-W * 0.22, W * 0.2}) do
				local ac = part({
					Name = "RoofAC",
					Size = Vector3.new(6, 3, 5),
					Position = Vector3.new(rx, H + 1.5, -D * 0.18),
					Color = Color3.fromRGB(176, 178, 182),
					Material = Enum.Material.Metal,
				})
				ac.Parent = model
				local grill = part({
					Name = "RoofACGrill",
					Size = Vector3.new(4.6, 0.2, 3.6),
					Position = Vector3.new(rx, H + 3.1, -D * 0.18),
					Color = Color3.fromRGB(96, 98, 104),
					Material = Enum.Material.CorrodedMetal,
					CanCollide = false,
				})
				grill.Parent = model
			end
			-- ventilas
			for _, vx in ipairs({0, W * 0.34}) do
				local vent = part({
					Name = "RoofVent",
					Size = Vector3.new(2.2, 2.6, 2.2),
					Position = Vector3.new(vx, H + 1.3, D * 0.2),
					Color = Color3.fromRGB(140, 142, 148),
					Material = Enum.Material.Metal,
				})
				vent.Parent = model
			end
		end

		-- ---------- patio de concreto frente al porton ----------
		local apron = part({
			Name = "LotApron",
			Size = Vector3.new(math.min(W + 40, 200), 0.3, 30),
			Position = Vector3.new(0, 0.36, frontZ2 + 16),
			-- v49: mas claro: el patio era casi del color del pasto de noche
			Color = Color3.fromRGB(118, 116, 110),
			Material = Enum.Material.Asphalt,
			CanCollide = false,
		})
		apron.Parent = model
		-- franjas de estacionamiento
		for i = -2, 2 do
			local stripe = part({
				Name = "ApronStripe",
				Size = Vector3.new(0.5, 0.32, 9),
				Position = Vector3.new(i * 11, 0.37, frontZ2 + 12),
				Color = Color3.fromRGB(224, 214, 176),
				Material = Enum.Material.Asphalt,
				CanCollide = false,
			})
			stripe.Parent = model
		end
	-- ===== el PATIO (LotApron): juntas de colado y un par de manchas =====
	do
		local patio = model:FindFirstChild("LotApron", true)
		if patio and patio:IsA("BasePart") then
			local ancho = patio.Size.X
			for i = -2, 2 do
				local junta = part({
					Name = "ApronJoint",
					Size = Vector3.new(0.35, 0.16, patio.Size.Z),
					Position = patio.Position + Vector3.new(i * (ancho / 6), 0.06, 0),
					Color = Color3.fromRGB(60, 58, 56),
					Material = Enum.Material.Concrete,
					CanCollide = false,
				})
				junta.Parent = model
			end
			for i = 1, 2 do
				local mancha = part({
					Name = "ApronStain",
					Size = Vector3.new(6, 0.1, 5),
					Position = patio.Position + Vector3.new(i * 12 - 18, 0.08, -3 + i * 3),
					Color = Color3.fromRGB(44, 42, 44),
					Material = Enum.Material.Asphalt,
					CanCollide = false,
				})
				mancha.Parent = model
			end
		end
	end


		if AMB.Props then
			-- ---------- macetas grandes a los lados del porton ----------
			for _, px in ipairs({-W * 0.5 + 8, W * 0.5 - 8}) do
				local pot = part({
					Name = "Planter",
					Size = Vector3.new(4, 3, 4),
					Position = Vector3.new(px, 1.6, frontZ2 + 4),
					-- v49: era RGB(96,70,52) y de noche se veia un cubo NEGRO
					-- (el usuario reporto "cubos negros" en el patio). Mas claro.
					Color = Color3.fromRGB(146, 118, 92),
					Material = Enum.Material.Concrete,
				})
				pot.Parent = model
				local bush = part({
					Name = "PlanterBush",
					Size = Vector3.new(4.4, 3, 4.4),
					Position = Vector3.new(px, 4.4, frontZ2 + 4),
					Color = Color3.fromRGB(58, 108, 62),
					Material = Enum.Material.Grass,
					CanCollide = false,
				})
				bush.Parent = model
				local top = part({
					Name = "PlanterTop",
					Size = Vector3.new(3, 2.2, 3),
					Position = Vector3.new(px, 6.2, frontZ2 + 4),
					Color = Color3.fromRGB(72, 126, 72),
					Material = Enum.Material.Grass,
					CanCollide = false,
				})
				top.Parent = model
			end

			-- ---------- bolardos amarillos en la orilla del patio ----------
			for i = -3, 3 do
				local bol = part({
					Name = "Bollard",
					Size = Vector3.new(1.1, 3.4, 1.1),
					Position = Vector3.new(i * 14, 1.9, frontZ2 + 30),
					Color = Color3.fromRGB(214, 176, 62),
					Material = Enum.Material.Metal,
				})
				bol.Parent = model
				local cap = part({
					Name = "BollardCap",
					Size = Vector3.new(1.3, 0.4, 1.3),
					Position = Vector3.new(i * 14, 3.7, frontZ2 + 30),
					Color = Color3.fromRGB(48, 48, 54),
					Material = Enum.Material.Metal,
					CanCollide = false,
				})
				cap.Parent = model
			end

			-- ---------- toldo sobre la puerta de la oficina ----------
			local canW = 12
			local canopy = part({
				Name = "OfficeCanopy",
				Size = Vector3.new(3.4, 0.4, canW),
				Position = Vector3.new(W * 0.5 + 36.4, 15.6, OFF_CZ),
				Color = Color3.fromRGB(126, 46, 44),
				Material = Enum.Material.Fabric,
				CanCollide = false,
			})
			canopy.CFrame = CFrame.new(canopy.Position) * CFrame.Angles(0, 0, math.rad(-12))
			canopy.Parent = model
			for _, cz in ipairs({OFF_CZ - canW / 2 + 1, OFF_CZ + canW / 2 - 1}) do
				local post = part({
					Name = "CanopyPost",
					Size = Vector3.new(0.5, 13, 0.5),
					Position = Vector3.new(W * 0.5 + 37.8, 8.5, cz),
					Color = Color3.fromRGB(78, 78, 84),
					Material = Enum.Material.Metal,
				})
				post.Parent = model
			end
			wallLamp("OfficeDoorLamp", Vector3.new(W * 0.5 + 34.6, 13.6, OFF_CZ + 5))

			-- ---------- botes de basura y escombros ----------
			local dump = part({
				Name = "Dumpster",
				Size = Vector3.new(6, 4, 4),
				Position = Vector3.new(W * 0.5 + 12, 4.2, frontZ2 + 12),
				Color = Color3.fromRGB(74, 118, 88),
				Material = Enum.Material.CorrodedMetal,
			})
			dump.Parent = model
			local lid = part({
				Name = "DumpsterLid",
				Size = Vector3.new(6.4, 0.4, 4.4),
				Position = Vector3.new(W * 0.5 + 12, 6.3, frontZ2 + 12),
				Color = Color3.fromRGB(40, 72, 52),
				Material = Enum.Material.CorrodedMetal,
				CanCollide = false,
			})
			lid.Parent = model

			-- ---------- banquita junto a la puerta ----------
			local benchSeat = part({
				Name = "LotBench",
				Size = Vector3.new(6, 0.5, 2),
				Position = Vector3.new(-W * 0.5 + 16, 2.9, frontZ2 + 6),
				Color = Color3.fromRGB(112, 84, 56),
				Material = Enum.Material.Wood,
			})
			benchSeat.Parent = model
			for _, bx in ipairs({-W * 0.5 + 13.6, -W * 0.5 + 18.4}) do
				local leg2 = part({
					Name = "BenchFoot",
					Size = Vector3.new(0.6, 2.4, 1.6),
					Position = Vector3.new(bx, 1.4, frontZ2 + 6),
					Color = Color3.fromRGB(64, 64, 70),
					Material = Enum.Material.Metal,
				})
				leg2.Parent = model
			end
		end

		-- ---------- poste de luz del lote ----------
		if AMB.LampPosts then
			local px = W * 0.5 + 26
			local pz = frontZ2 + 26
			local mast = part({
				Name = "LampPost",
				Size = Vector3.new(1, 26, 1),
				Position = Vector3.new(px, 13.2, pz),   -- arranca en el pasto (y=0.2)
				Color = Color3.fromRGB(74, 76, 82),
				Material = Enum.Material.Metal,
			})
			mast.Parent = model
			local arm = part({
				Name = "LampPostArm",
				Size = Vector3.new(1, 0.7, 6),
				Position = Vector3.new(px - 2.5, 28, pz),
				Color = Color3.fromRGB(74, 76, 82),
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
			arm.Parent = model
			local head = part({
				Name = "LampPostHead",
				Size = Vector3.new(3, 0.6, 4),
				Position = Vector3.new(px - 4.6, 27.6, pz),
				Color = colLamp,
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			head.Parent = model
			local hl = Instance.new("PointLight")
			hl.Brightness = 2.2
			hl.Range = 52
			hl.Color = Color3.fromRGB(255, 238, 200)
			hl.Parent = head
			tagLight(hl, 2.2)
		end
	end

	return model
end

----------------------------------------------------------------------
-- VEHICULOS
----------------------------------------------------------------------
-- Un solo constructor para los dos casos:
--   parked = true  -> adorno estacionado en el cajon (anclado, sin fisica)
--   parked = false -> auto manejable (chasis con fisica, ruedas con bisagra
--                     y asiento de conductor)
-- Antes los dos eran un ladrillo con 4 bolas. Ahora: carroceria por tipo
-- (van / sedan / pickup / deportivo), vidrios, faros que se prenden de
-- noche, rines, espejos, placas y defensas.
local CAR_SPEC = {
	van    = {len = 18, wid = 8.6, clr = 1.9, bodyH = 4.6, cabZ = {-6.0, 3.0}, cabH = 4.4,
		         bed = nil,  rack = true,  spoiler = false},
	sedan  = {len = 17.5, wid = 8.2, clr = 1.5, bodyH = 3.2, cabZ = {-4.4, 3.6}, cabH = 3.4,
		         bed = nil,  rack = false, spoiler = false},
	pickup = {len = 18.5, wid = 8.6, clr = 2.0, bodyH = 3.6, cabZ = {0.6, 5.2}, cabH = 3.6,
		         bed = {-7.4, 0.2},  rack = true,  spoiler = false},
	sport  = {len = 17, wid = 8.8, clr = 1.2, bodyH = 2.8, cabZ = {-4.0, 2.6}, cabH = 2.6,
		         bed = nil,  rack = false, spoiler = true},
}

function CityGenerator.BuildCar(info: any, cf: CFrame, parked: boolean?): Model
	local spec = CAR_SPEC[info and info.Id] or CAR_SPEC.sedan
	local col = (info and info.Color) or Color3.fromRGB(150, 40, 40)
	local L, Wd, CLR = spec.len, spec.wid, spec.clr

	local m = Instance.new("Model")
	m.Name = (parked and "Parked_" or "Car_") .. tostring((info and info.Id) or "car")

	-- helper: crea una pieza relativa al centro del carro (+Z = hacia adelante)
	local function cp(name, size, off, color, mat, opts)
		local o = opts or {}
		local pp = part({
			Name = name,
			Size = size,
			CFrame = cf * CFrame.new(off) * (o.rot or CFrame.new()),
			Color = color,
			Material = mat or Enum.Material.SmoothPlastic,
			Transparency = o.tr or 0,
			Reflectance = o.ref or 0,
			Shape = o.shape or Enum.PartType.Block,
		})
		pp.CanCollide = o.collide == true
		pp.Massless = true
		if parked then
			pp.Anchored = true
		else
			pp.Anchored = false
		end
		pp.Parent = m
		return pp
	end

	local dark = Color3.fromRGB(32, 34, 38)
	local chrome = Color3.fromRGB(178, 182, 190)
	local glass = Color3.fromRGB(140, 172, 190)

	-- ===== chasis (la pieza que manda) =====
	local body = cp("Body", Vector3.new(Wd, spec.bodyH, L * 0.78), Vector3.new(0, CLR + spec.bodyH / 2, 0), col)
	body.Reflectance = 0.14
	body.CanCollide = not parked
	m.PrimaryPart = body

	-- falda (oscura) para que tenga altura visual
	cp("Skirt", Vector3.new(Wd + 0.15, spec.bodyH * 0.45, L * 0.8),
		Vector3.new(0, CLR + spec.bodyH * 0.24, 0), dark)

	-- cofre y cajuela
	local hoodZ = L * 0.30
	cp("Hood", Vector3.new(Wd - 0.5, 0.45, L * 0.26),
		Vector3.new(0, CLR + spec.bodyH + 0.1, hoodZ), col)
	if spec.bed then
		-- batea de la pickup
		cp("BedFloor", Vector3.new(Wd - 0.6, 0.4, math.abs(spec.bed[1] - spec.bed[2])),
			Vector3.new(0, CLR + spec.bodyH + 0.1, (spec.bed[1] + spec.bed[2]) / 2), dark)
		for _, bz in ipairs({spec.bed[1], spec.bed[2]}) do
			cp("BedWall", Vector3.new(Wd - 0.6, 1.6, 0.4),
				Vector3.new(0, CLR + spec.bodyH + 0.9, bz), col)
		end
		for _, bx in ipairs({-(Wd / 2 - 0.4), Wd / 2 - 0.4}) do
			cp("BedWall", Vector3.new(0.4, 1.6, math.abs(spec.bed[1] - spec.bed[2])),
				Vector3.new(bx, CLR + spec.bodyH + 0.9, (spec.bed[1] + spec.bed[2]) / 2), col)
		end
	else
		cp("Trunk", Vector3.new(Wd - 0.5, 0.5, L * 0.16),
			Vector3.new(0, CLR + spec.bodyH + 0.05, -L * 0.30), col)
	end

	-- ===== cabina =====
	local cz0, cz1 = spec.cabZ[1], spec.cabZ[2]
	local cabLen = cz1 - cz0
	local cabC = (cz0 + cz1) / 2
	local cabY = CLR + spec.bodyH + spec.cabH / 2
	cp("Cabin", Vector3.new(Wd - 0.7, spec.cabH, cabLen), Vector3.new(0, cabY, cabC), col)
	cp("Roof", Vector3.new(Wd - 1.0, 0.3, cabLen - 0.6),
		Vector3.new(0, cabY + spec.cabH / 2 + 0.15, cabC), col)

	-- vidrios (parabrisas inclinado, medallon y laterales)
	local wsY = CLR + spec.bodyH + spec.cabH * 0.45
	cp("Windshield", Vector3.new(Wd - 1.5, spec.cabH * 1.15, 0.25),
		Vector3.new(0, wsY + 0.25, cz1 + 0.15), glass, Enum.Material.Glass,
		{ tr = 0.45, ref = 0.3, rot = CFrame.Angles(math.rad(-22), 0, 0) })
	cp("RearGlass", Vector3.new(Wd - 1.5, spec.cabH * 1.05, 0.25),
		Vector3.new(0, wsY + 0.2, cz0 - 0.15), glass, Enum.Material.Glass,
		{ tr = 0.45, ref = 0.3, rot = CFrame.Angles(math.rad(20), 0, 0) })
	for _, sx in ipairs({-(Wd / 2 - 0.35), Wd / 2 - 0.35}) do
		cp("SideGlass", Vector3.new(0.2, spec.cabH * 0.65, cabLen - 1.2),
			Vector3.new(sx, cabY + 0.2, cabC), glass, Enum.Material.Glass,
			{ tr = 0.45, ref = 0.3 })
	end

	-- espejos
	for _, sx in ipairs({-(Wd / 2 + 0.5), Wd / 2 + 0.5}) do
		cp("Mirror", Vector3.new(1.1, 0.6, 0.5), Vector3.new(sx, cabY - 0.4, cz1 + 0.2), dark)
	end

	-- ===== defensas, parrilla y luces =====
	local bumperY = CLR + spec.bodyH * 0.35
	cp("BumperF", Vector3.new(Wd + 0.2, 1.0, 0.8), Vector3.new(0, bumperY, L * 0.40), dark)
	cp("BumperR", Vector3.new(Wd + 0.2, 1.0, 0.8), Vector3.new(0, bumperY, -L * 0.40), dark)
	cp("Grille", Vector3.new(Wd - 1.6, 0.9, 0.4),
		Vector3.new(0, CLR + spec.bodyH * 0.75, L * 0.40), dark)
	cp("ChromeBar", Vector3.new(Wd - 1.4, 0.18, 0.3),
		Vector3.new(0, CLR + spec.bodyH * 0.75 + 0.5, L * 0.42), chrome, Enum.Material.Metal)

	for _, sx in ipairs({-(Wd / 2 - 1.0), Wd / 2 - 1.0}) do
		local hl = cp("Headlight", Vector3.new(1.7, 0.75, 0.35),
			Vector3.new(sx, CLR + spec.bodyH * 0.78, L * 0.41),
			Color3.fromRGB(255, 246, 214), Enum.Material.Neon)
		local pl = Instance.new("PointLight")
		pl.Brightness = 1.4
		pl.Range = 30
		pl.Color = Color3.fromRGB(255, 240, 200)
		pl.Parent = hl
		tagLight(pl, 1.4)

		cp("Taillight", Vector3.new(1.5, 0.65, 0.35),
			Vector3.new(sx, CLR + spec.bodyH * 0.78, -L * 0.41),
			Color3.fromRGB(210, 48, 44), Enum.Material.Neon)
	end

	-- placas
	cp("PlateF", Vector3.new(2.4, 0.7, 0.2),
		Vector3.new(0, bumperY, L * 0.41), Color3.fromRGB(228, 228, 220))
	cp("PlateR", Vector3.new(2.4, 0.7, 0.2),
		Vector3.new(0, bumperY, -L * 0.41), Color3.fromRGB(228, 228, 220))

	-- tubo de escape
	cp("Exhaust", Vector3.new(0.7, 0.5, 0.9),
		Vector3.new(-Wd * 0.22, CLR + 0.35, -L * 0.42), chrome, Enum.Material.Metal)

	if spec.spoiler then
		cp("Spoiler", Vector3.new(Wd - 1.0, 0.25, 1.8),
			Vector3.new(0, CLR + spec.bodyH + 1.1, -L * 0.36), dark)
		for _, sx in ipairs({-(Wd / 2 - 1.2), Wd / 2 - 1.2}) do
			cp("SpoilerPost", Vector3.new(0.4, 1.1, 0.4),
				Vector3.new(sx, CLR + spec.bodyH + 0.6, -L * 0.36), dark)
		end
	end
	if spec.rack then
		cp("RoofRack", Vector3.new(Wd - 1.4, 0.25, cabLen - 1.0),
			Vector3.new(0, cabY + spec.cabH / 2 + 0.5, cabC), chrome, Enum.Material.Metal)
	end

	-- ===== ruedas =====
	local wheelR = CLR + 0.1
	local wheelY = wheelR          -- la llanta toca el piso: cf va a nivel de piso
	local wOff = {{-Wd / 2 - 0.15, L * 0.28}, {Wd / 2 + 0.15, L * 0.28},
		          {-Wd / 2 - 0.15, -L * 0.28}, {Wd / 2 + 0.15, -L * 0.28}}
	-- OJO (v46): aqui estaba el "las ruedas al revers" de la van del garaje.
	-- Un Part cilindrico de Roblox YA trae su eje en el X del Size, o sea las caras
	-- redondas miran a los lados: asi se ve una llanta montada en un carro que va
	-- hacia +Z. Con aquel 'CFrame.Angles(0, 0, 90)' la llanta quedaba PARADA
	-- (las caras redondas al cielo): vistas de lado se veian como discos tirados y
	-- el carro parecia flotando. Se quita la rotacion (queda como la de la bici).
	for i, wp in ipairs(wOff) do
		local tire = cp("Wheel", Vector3.new(1.5, wheelR * 2, wheelR * 2),
			Vector3.new(wp[1], wheelY, wp[2]), Color3.fromRGB(26, 26, 30),
			Enum.Material.Rubber, { shape = Enum.PartType.Cylinder, collide = not parked })
		-- ===== RIN (v42) =====
		-- Antes era UN disco cromado que tapaba toda la llanta: de lejos se veia
		-- "como plato" (reporte del usuario). Ahora, igual que la bici: aro mas
		-- chico + maza + 5 rayos, o sea se lee como RIN de verdad.
		local wheelCF = tire.CFrame
		local rim = cp("Rim", Vector3.new(1.62, wheelR * 1.34, wheelR * 1.34),
			Vector3.new(wp[1], wheelY, wp[2]), Color3.fromRGB(120, 124, 132),
			Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
		local hub = cp("Hub", Vector3.new(1.7, wheelR * 0.56, wheelR * 0.56),
			Vector3.new(wp[1], wheelY, wp[2]), chrome, Enum.Material.Metal,
			{ shape = Enum.PartType.Cylinder })
		for k = 1, 5 do
			-- los rayos van en el PLANO de la llanta: se gira alrededor del eje X
			-- del cilindro (el mismo truco que la bici)
			cp("Spoke", Vector3.new(1.66, wheelR * 1.1, 0.26),
				Vector3.new(wp[1], wheelY, wp[2]), Color3.fromRGB(150, 154, 162),
				Enum.Material.Metal,
				{ rot = CFrame.Angles(math.rad(k * 36), 0, 0) })
		end
		-- el rim, la maza y los rayos giran PEGADOS a la llanta (weld al tire),
		-- si no se quedan fijos y el carro se ve patinando

		if not parked then
			-- bisagra para que gire al manejar (mismo truco que antes, pero
			-- ahora la rueda es un cilindro de verdad)
			local att0 = Instance.new("Attachment", body)
			att0.Position = Vector3.new(wp[1], wheelY, wp[2]) - Vector3.new(0, CLR + spec.bodyH / 2, 0)
			local att1 = Instance.new("Attachment", tire)
			local hinge = Instance.new("HingeConstraint")
			hinge.Attachment0 = att0
			hinge.Attachment1 = att1
			hinge.Parent = body
			tire:SetAttribute("WheelIndex", i)
		end
	end

	-- ===== asiento (solo el manejable) =====
	if not parked then
		local seat = Instance.new("VehicleSeat")
		seat.Name = "Seat"
		seat.Size = Vector3.new(3, 0.6, 3)
		seat.CFrame = cf * CFrame.new(0, CLR + spec.bodyH + 0.3, cabC - 0.6)
		seat.MaxSpeed = (info and info.Speed) or 80
		seat.Torque = 60
		seat.TurnSpeed = 20
		seat.Transparency = 0.15
		seat.Color = Color3.fromRGB(48, 48, 54)
		-- v36: boton de verdad para subirse. Antes habia que "tocar" el asiento
		-- y en celular eso casi no funciona (nadie sabia donde picarle).
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Conducir"
		prompt.ActionText = "Conducir"
		prompt.ObjectText = "Vehiculo"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = seat
		prompt.Triggered:Connect(function(quien)
			local c = quien and quien.Character
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			if hum and not seat.Occupant then seat:Sit(hum) end
		end)
		seat.Parent = m
		-- el asiento NO lleva weld constraint: el chasis lo carga solo
		-- OJO (v42): la rueda completa (Wheel, Rim, Hub, Spoke) NO se suelda al
		-- chasis: va soldada a la LLANTA, que es la que gira con la bisagra. Si se
		-- soldaba al chasis, el rin se quedaba quieto y parecia que patinaba.
		local rueda = { Wheel = true, Rim = true, Hub = true, Spoke = true }
		local porSoldar = {}
		for _, d in ipairs(m:GetChildren()) do
			if d:IsA("BasePart") and d ~= seat and d ~= body and not rueda[d.Name] then
				table.insert(porSoldar, d)
			end
		end
		for _, d in ipairs(porSoldar) do
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = body
			wc.Part1 = d
			wc.Parent = body
		end
		-- y cada pieza de la rueda, soldada a su llanta
		for _, tire in ipairs(m:GetChildren()) do
			if tire:IsA("BasePart") and tire.Name == "Wheel" then
				local cerca = {}
				for _, d in ipairs(m:GetChildren()) do
					if d:IsA("BasePart") and (d.Name == "Rim" or d.Name == "Hub" or d.Name == "Spoke") then
						local dd = (d.Position - tire.Position).Magnitude
						if dd < 1.2 then table.insert(cerca, d) end
					end
				end
				for _, d in ipairs(cerca) do
					local wc2 = Instance.new("WeldConstraint")
					wc2.Part0 = tire
					wc2.Part1 = d
					wc2.Parent = tire
				end
			end
		end
		local swc = Instance.new("WeldConstraint")
		swc.Part0 = body
		swc.Part1 = seat
		swc.Parent = body
	else
		-- estacionado: que las ruedas no se vean flotando
		for _, d in ipairs(m:GetChildren()) do
			if d:IsA("BasePart") then d.Anchored = true end
		end
	end

	m.PrimaryPart = body
	return m
end

local function buildWarehouseTemplate(folder: Folder)
	local model = CityGenerator.BuildWarehouse(1)
	model.Name = "WarehouseTemplate"
	model.Parent = folder
	return model
end

local function buildPoliceStation(folder: Folder)
	local center = CityGenerator.CellToWorld(2, 0)
	local pos = center + Vector3.new(0, 2.4, 0)

	local station = Instance.new("Model")
	station.Name = "CustomsStation"

	local base = part({
		Name = "Base",
		Size = Vector3.new(60, 3, 50),
		Position = pos,
		Color = Color3.fromRGB(60, 78, 120),
		Material = Enum.Material.Concrete,
	})
	base.Parent = station
	station.PrimaryPart = base

	local tower = part({
		Name = "Tower",
		Size = Vector3.new(20, 40, 20),
		Position = pos + Vector3.new(0, 21, 0),
		Color = Color3.fromRGB(70, 90, 140),
		Material = Enum.Material.Concrete,
	})
	tower.Parent = station

	-- v44: pintado en la torre (dos caras: se lee desde cualquier lado)
	textoPlano(tower, "UNIDAD DE ADUANAS", Color3.fromRGB(150, 190, 255),
		{ pixels = 64, letra = 2.0 })
	textoPlano(tower, "UNIDAD DE ADUANAS", Color3.fromRGB(150, 190, 255),
		{ pixels = 30, face = Enum.NormalId.Left, name = "RotuloIzq" })

	-- celda (donde apareces si te agarran)
	local jail = part({
		Name = "JailSpawn",
		Size = Vector3.new(14, 1, 14),
		Position = pos + Vector3.new(0, 1, -30),
		Color = Color3.fromRGB(180, 70, 70),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
	})
	jail.Parent = station

	station.Parent = folder
end

----------------------------------------------------------------------
-- ENTRADA PRINCIPAL
----------------------------------------------------------------------
-- ====================================================================
-- AGENTE DE ADUANAS: personaje con Humanoid real para poder perseguir
-- ====================================================================
-- Crea un empleado tuyo parado en un punto. Lo usa Main para poner un
-- cosechador en cada mesa y prensadores junto a la maquina.
function CityGenerator.MakeWorker(parent: Instance, pos: Vector3, facing: Vector3?, tag: string?): Model
	local info = {Id = tag or "Worker", Name = tag or "Trabajador"}
	local npc = makeBuyerNPC(parent, pos, info, facing, "worker")
	-- Tus empleados NO son compradores: sin esto el cliente les sacaba el
	-- globo de dialogo de "tienes mercancia?" y el "presiona F para vender".
	CollectionService:RemoveTag(npc, "BuyerNPC")
	npc:SetAttribute("BuyerId", nil)
	npc:SetAttribute("Worker", true)
	npc.Name = "Worker_" .. (tag or "X")
	return npc
end

-- Asaltante que viene por tu caja fuerte.
function CityGenerator.MakeRaider(parent: Instance, pos: Vector3): Model
	local npc = makeBuyerNPC(parent, pos, {Id = "Raider", Name = "Asaltante"},
		nil, "raider")
	CollectionService:RemoveTag(npc, "BuyerNPC")
	npc:SetAttribute("BuyerId", nil)
	npc.Name = "Raider"
	return npc
end

-- Oficial que cuida un lote CLAUSURADO (v42). No vende nada: solo esta
-- plantado en la entrada del lote vigilando, y Main le hace decir sus lineas
-- cuando el jugador se acerca ("esta area esta clausurada...").
function CityGenerator.MakeOfficer(parent: Instance, pos: Vector3, facing: Vector3?): Model
	local npc = makeBuyerNPC(parent, pos, {Id = "Officer" .. tostring(math.floor(pos.X)) .. tostring(math.floor(pos.Z)), Name = "Oficial"},
		facing, "police")
	CollectionService:RemoveTag(npc, "BuyerNPC")
	npc:SetAttribute("BuyerId", nil)
	npc:SetAttribute("Officer", true)
	npc.Name = "Officer"
	return npc
end

-- ===== v42: BODEGAS VECINAS =====
-- El usuario reporto que su parcela se veia "practicamente vacia": los demas
-- lotes estaban pelones. Aqui se pintan de OTRO color (cada lote de su estilo)
-- para que no parezcan clones.
local VARIANTES = {
	{Wall = Color3.fromRGB(128, 136, 152), Floor = Color3.fromRGB(94, 98, 106), Roof = Color3.fromRGB(72, 80, 94)},   -- acero azul
	{Wall = Color3.fromRGB(154, 108, 92),  Floor = Color3.fromRGB(106, 90, 84),  Roof = Color3.fromRGB(98, 64, 56)},   -- ladrillo
	{Wall = Color3.fromRGB(112, 140, 118), Floor = Color3.fromRGB(90, 100, 94),  Roof = Color3.fromRGB(66, 86, 72)},   -- verde taller
	{Wall = Color3.fromRGB(178, 164, 134), Floor = Color3.fromRGB(120, 114, 102), Roof = Color3.fromRGB(124, 106, 82)}, -- arena
	{Wall = Color3.fromRGB(142, 126, 150), Floor = Color3.fromRGB(98, 94, 104),  Roof = Color3.fromRGB(80, 70, 88)},   -- lila
	{Wall = Color3.fromRGB(96, 120, 134),  Floor = Color3.fromRGB(86, 94, 100),  Roof = Color3.fromRGB(62, 76, 86)},   -- petroleo
}

-- Repinta una bodega con el estilo n (1..6). Se hace DESPUES de construirla:
-- solo cambia colores de piezas conocidas (paredes, piso, techo, porton), asi
-- que no puede romper la geometria ni los nombres que buscan Main y ClientUI.
function CityGenerator.VarianteVecina(model: Model, n: number): ()
	local V = VARIANTES[((n - 1) % #VARIANTES) + 1]
	local tier = math.clamp(tonumber(model:GetAttribute("Tier")) or 1, 1, #Config.WarehouseTiers)
	local T = Config.WarehouseTiers[tier]
	local pared = T.WallColor
	local piso = T.FloorColor
	local techoViejo = Color3.fromRGB(62, 66, 72)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local nom = d.Name
			if d.Color == pared then
				d.Color = V.Wall
			elseif d.Color == piso then
				d.Color = V.Floor
			elseif (nom == "Roof" or nom == "GateLeft" or nom == "GateRight") and d.Color == techoViejo then
				d.Color = V.Roof
			end
		end
	end
	model:SetAttribute("Vecina", true)
	model:SetAttribute("EstiloVecina", ((n - 1) % #VARIANTES) + 1)
end

-- Lote CLAUSURADO (v42): cinta policial cruzada en la entrada, tablilla de
-- "CLAUSURADA" y los letreros. Devuelve las dos posiciones donde se plantan
-- los oficiales (izquierda y derecha del porton).
function CityGenerator.Clausurar(model: Model): {Vector3}
	local T = Config.WarehouseTiers[math.clamp(tonumber(model:GetAttribute("Tier")) or 1, 1, #Config.WarehouseTiers)]
	local D = T.Size.Z

	-- el porton de la entrada: de ahi salen las medidas de la cinta
	-- (si por lo que sea no esta, se usan los numeros del nivel 1)
	--
	-- OJO (v47): AQUI estaba "la cinta gigante que va desde las bodegas inactivas
	-- hasta mi bodega". Se medía `math.abs(gl.Position.X)`: eso solo da bien si el
	-- modelo esta en el origen, como en las pruebas. En el juego el lote vecino
	-- vive en x = -600, asi que |X| = 600 y la cinta salia de 1200 studs de ancho:
	-- cruzaba TODA la ciudad y caia encima del patio del jugador. Peor: la cinta,
	-- los postes y la tablilla de CLAUSURADA se colocaban en x = 0 (el origen del
	-- mundo), o sea justo frente a la bodega del jugador.
	-- Ahora TODO se mide tomando como centro las HOJAS DEL PORTON (que ya estan en
	-- coordenadas del mundo) y se coloca alrededor de esa X.
	local halfGate, gateX, gateZ = 12, 0, D * 0.5
	local gl = model:FindFirstChild("GateLeft", true)
	local gr = model:FindFirstChild("GateRight", true)
	if gl and gl:IsA("BasePart") and gr and gr:IsA("BasePart") then
		halfGate = math.abs(gr.Position.X - gl.Position.X) * 0.5 + gl.Size.X * 0.5
		gateX = (gl.Position.X + gr.Position.X) * 0.5
		gateZ = (gl.Position.Z + gr.Position.Z) * 0.5
	elseif gl and gl:IsA("BasePart") then
		halfGate = gl.Size.X
		gateX = gl.Position.X + gl.Size.X * 0.5
		gateZ = gl.Position.Z
	elseif model.PrimaryPart then
		gateX = model.PrimaryPart.Position.X
		gateZ = model.PrimaryPart.Position.Z + D * 0.5
	end
	local tapeZ = gateZ + 1.6

	local zone = model:FindFirstChild("Clausura") :: Folder?
	if not zone then
		zone = Instance.new("Folder")
		zone.Name = "Clausura"
		zone.Parent = model
	end

	local function cpart(nom: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material?): Part
		local pp = part({Name = nom, Size = size, Position = pos, Color = color,
			Material = mat or Enum.Material.SmoothPlastic, CanCollide = false})
		pp.Parent = zone
		return pp
	end

	-- postes a los lados del porton + tres franjas de cinta cruzando la entrada
	for _, sx in ipairs({-1, 1}) do
		cpart("CintaPoste", Vector3.new(0.5, 4.4, 0.5),
			Vector3.new(gateX + sx * (halfGate + 0.9), 4.6, tapeZ), Color3.fromRGB(196, 172, 40), Enum.Material.Metal)
	end
	for k = 1, 3 do
		cpart("CintaPolicial", Vector3.new(halfGate * 2 + 2, 0.55, 0.14),
			Vector3.new(gateX, 3.1 + (k - 1) * 1.5, tapeZ), Color3.fromRGB(238, 206, 46))
	end
	-- franjas negras de la cinta (el rayado de cinta de obra)
	for k = 1, 3 do
		local y = 3.1 + (k - 1) * 1.5
		local n = math.floor(halfGate / 2)
		for i = -n, n do
			cpart("CintaRayas", Vector3.new(0.9, 0.57, 0.16),
				Vector3.new(gateX + i * 2, y, tapeZ - 0.02), Color3.fromRGB(26, 26, 30))
		end
	end

	-- tablilla de CLAUSURADA clavada adelante, en el piso de afuera
	local tabla = cpart("TablillaClausurada", Vector3.new(9, 4.6, 0.4),
		Vector3.new(gateX, 6.4, tapeZ + 1.4), Color3.fromRGB(214, 206, 190), Enum.Material.WoodPlanks)
	for _, sx in ipairs({-1, 1}) do
		cpart("TablillaPata", Vector3.new(0.4, 4.2, 0.4), Vector3.new(gateX + sx * 3.7, 2.2, tapeZ + 1.4),
			Color3.fromRGB(110, 84, 58), Enum.Material.Wood)
	end
	textoPlano(tabla, "CLAUSURADA", Color3.fromRGB(226, 62, 54),
		{ pixels = 96, letra = 1.2 })

	-- donde se plantan los DOS oficiales: afuera, a los lados del porton.
	-- OJO: aqui afuera el piso esta en y ~ 0.6 (la rampa baja del anden), no en 2.
	return {
		Vector3.new(gateX - (halfGate + 2.2), 0.6, gateZ + 8),
		Vector3.new(gateX + (halfGate + 2.2), 0.6, gateZ + 8),
	}
end

-- Guardia contratado, plantado junto a la caja.
function CityGenerator.MakeGuard(parent: Instance, pos: Vector3, facing: Vector3?): Model
	local npc = makeBuyerNPC(parent, pos, {Id = "Guard", Name = "Guardia"},
		facing, "guard")
	CollectionService:RemoveTag(npc, "BuyerNPC")
	npc:SetAttribute("BuyerId", nil)
	npc.Name = "HiredGuard"
	return npc
end

function CityGenerator.BuildAgent(): Model
	local A = Config.Agents

	local model = Instance.new("Model")
	model.Name = "CustomsAgent"

	local skin = Color3.fromRGB(198, 156, 120)

	-- HumanoidRootPart
	local hrp = part({
		Name = "HumanoidRootPart",
		Size = Vector3.new(2, 2, 1),
		Position = Vector3.new(0, 3, 0),
		Transparency = 1,
		CanCollide = false,
	})
	hrp.Parent = model
	model.PrimaryPart = hrp

	-- Torso (R6: se llama Torso)
	local torso = part({
		Name = "Torso",
		Size = Vector3.new(2, 2, 1),
		Position = Vector3.new(0, 3, 0),
		Color = A.ShirtColor,
		Material = Enum.Material.Fabric,
	})
	torso.Parent = model

	-- chaleco tactico
	local vest = part({
		Name = "Vest",
		Size = Vector3.new(2.15, 1.5, 1.2),
		Position = Vector3.new(0, 3.1, 0),
		Color = A.VestColor,
		Material = Enum.Material.Fabric,
	})
	vest.Parent = model

	-- letras en la espalda
	local badge = part({
		Name = "Badge",
		Size = Vector3.new(1.4, 0.5, 0.1),
		Position = Vector3.new(0, 3.3, -0.65),
		Color = Color3.fromRGB(235, 225, 120),
		Material = Enum.Material.Neon,
	})
	badge.Parent = model

	-- Head (R6 lo requiere con ese nombre)
	local head = part({
		Name = "Head",
		Size = Vector3.new(1.2, 1.2, 1.2),
		Position = Vector3.new(0, 4.5, 0),
		Color = skin,
	})
	head.Parent = model

	-- gorra
	local cap = part({
		Name = "Cap",
		Size = Vector3.new(1.3, 0.45, 1.3),
		Position = Vector3.new(0, 5.15, 0),
		Color = A.VestColor,
		Material = Enum.Material.Fabric,
	})
	cap.Parent = model

	local visor = part({
		Name = "Visor",
		Size = Vector3.new(1.3, 0.16, 0.6),
		Position = Vector3.new(0, 4.98, 0.62),
		Color = Color3.fromRGB(22, 26, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	visor.Parent = model

	-- lentes oscuros
	local shades = part({
		Name = "Shades",
		Size = Vector3.new(1.05, 0.28, 0.12),
		Position = Vector3.new(0, 4.62, 0.62),
		Color = Color3.fromRGB(16, 16, 20),
		Material = Enum.Material.Glass,
		Reflectance = 0.3,
	})
	shades.Parent = model

	-- extremidades R6
	local limbs = {
		{"Left Arm",  Vector3.new(-1.5, 3, 0), A.ShirtColor},
		{"Right Arm", Vector3.new(1.5, 3, 0),  A.ShirtColor},
		{"Left Leg",  Vector3.new(-0.5, 1, 0), Color3.fromRGB(32, 36, 48)},
		{"Right Leg", Vector3.new(0.5, 1, 0),  Color3.fromRGB(32, 36, 48)},
	}
	for _, d in ipairs(limbs) do
		local l = part({
			Name = d[1],
			Size = Vector3.new(1, 2, 1),
			Position = d[2],
			Color = d[3],
			Material = Enum.Material.Fabric,
		})
		l.Parent = model
	end

	-- Humanoid (esto es lo que permite caminar/pathfinding)
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.MaxHealth = A.Health
	hum.Health = A.Health
	hum.WalkSpeed = A.WalkSpeed
	hum.AutoRotate = true
	hum.Parent = model

	-- Motor6D para que el Humanoid reconozca el rig
	local function joint(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
	end

	joint("RootJoint", hrp, torso, CFrame.new(), CFrame.new())
	joint("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))

	local arms = {
		{"Left Shoulder",  "Left Arm",  -1.5},
		{"Right Shoulder", "Right Arm",  1.5},
	}
	for _, a in ipairs(arms) do
		local limb = model:FindFirstChild(a[2])
		if limb then
			joint(a[1], torso, limb, CFrame.new(a[3], 0.5, 0), CFrame.new(0, 0.5, 0))
		end
	end

	local legs = {
		{"Left Hip",  "Left Leg",  -0.5},
		{"Right Hip", "Right Leg",  0.5},
	}
	for _, lg in ipairs(legs) do
		local limb = model:FindFirstChild(lg[2])
		if limb then
			joint(lg[1], torso, limb, CFrame.new(lg[3], -1, 0), CFrame.new(0, 1, 0))
		end
	end

	-- soldar accesorios (no articulados)
	for _, acc in ipairs({vest, badge, cap, visor, shades}) do
		local wc = Instance.new("WeldConstraint")
		wc.Part0 = (acc == cap or acc == visor or acc == shades) and head or torso
		wc.Part1 = acc
		wc.Parent = acc
	end

	-- luz azul parpadeante para ubicarlos
	local beacon = part({
		Name = "AgentBeacon",
		Size = Vector3.new(0.8, 0.8, 0.8),
		Position = Vector3.new(0, 6, 0),
		Color = Color3.fromRGB(80, 140, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Shape = Enum.PartType.Ball,
	})
	beacon.Parent = model
	local bw = Instance.new("WeldConstraint")
	bw.Part0 = head; bw.Part1 = beacon; bw.Parent = beacon

	local bl = Instance.new("PointLight")
	bl.Color = Color3.fromRGB(80, 140, 255)
	bl.Brightness = 3
	bl.Range = 26
	bl.Parent = beacon

	-- letrero flotante
	makeBillboard(head, "ADUANAS", Color3.fromRGB(140, 190, 255), 2.5)

	return model
end

function CityGenerator.Build(): Folder
	local old = Workspace:FindFirstChild("City")
	if old then old:Destroy() end

	local city = Instance.new("Folder")
	city.Name = "City"
	city.Parent = Workspace

	buildGround(city)

	local blocks = Instance.new("Folder")
	blocks.Name = "Blocks"
	blocks.Parent = city

	for cx = 0, C.GridX - 1 do
		for cz = 0, C.GridZ - 1 do
			-- deja libre la celda de la estacion y la de spawn
			if not (cx == 2 and cz == 0) then
				buildBlock(blocks, cx, cz)
			end
		end
	end

	buildBuyers(city)
	buildPoliceStation(city)

	local templates = Instance.new("Folder")
	templates.Name = "Templates"
	templates.Parent = ReplicatedStorage
	buildWarehouseTemplate(templates)

	-- spawn central
	local sp = Instance.new("SpawnLocation")
	sp.Name = "CitySpawn"
	sp.Anchored = true
	sp.Size = Vector3.new(24, 1, 24)
	sp.Position = CityGenerator.CellToWorld(2, 1) + Vector3.new(0, 3, 0)
	sp.Color = Color3.fromRGB(240, 240, 240)
	sp.Material = Enum.Material.Neon
	sp.Duration = 0
	sp.Parent = city

	-- >>> TESTIGO DEL SERVIDOR (v38) <<<
	-- Letrero flotando ARRIBA DEL SPAWN con la RONDA de los archivos del SERVIDOR.
	-- Para que sirve: el jugador reporto "pegue todo y no cambia nada". Con este
	-- letrero, CUALQUIER captura del juego dice de que ronda son los archivos del
	-- servidor (si no dice la ronda nueva, ese archivo no se pego). Junto con la
	-- placa del cliente se ve CUAL de los dos lados esta viejo.
	do
		local ronda = tostring(Config.Build or "(sin numero)")
		local bb = Instance.new("BillboardGui")
		bb.Name = "TestigoRonda"
		bb.Size = UDim2.new(0, 320, 0, 92)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
		bb.AlwaysOnTop = false          -- respeta la altura (nada de letreros encima de todo)
		bb.MaxDistance = 500
		bb.LightInfluence = 0
		bb.Parent = sp

		local fondo = Instance.new("Frame")
		fondo.Name = "Placa"
		fondo.Size = UDim2.fromScale(1, 1)
		fondo.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
		fondo.BackgroundTransparency = 0.12
		fondo.BorderSizePixel = 0
		fondo.Parent = bb
		do
			local esquina = Instance.new("UICorner")
			esquina.CornerRadius = UDim.new(0, 10)
			esquina.Parent = fondo
			local canto = Instance.new("UIStroke")
			canto.Color = Color3.fromRGB(130, 255, 150)
			canto.Thickness = 3
			canto.Parent = fondo
		end

		local linea1 = Instance.new("TextLabel")
		linea1.Name = "Ronda"
		linea1.BackgroundTransparency = 1
		linea1.Size = UDim2.new(1, -16, 0, 46)
		linea1.Position = UDim2.new(0, 8, 0, 6)
		linea1.Font = Enum.Font.GothamBold
		linea1.TextScaled = true
		linea1.TextColor3 = Color3.fromRGB(140, 255, 160)
		linea1.TextStrokeTransparency = 0.3
		linea1.TextStrokeColor3 = Color3.new(0, 0, 0)
		linea1.Text = "SERVIDOR " .. ronda
		linea1.Parent = fondo

		local linea2 = Instance.new("TextLabel")
		linea2.Name = "QueEs"
		linea2.BackgroundTransparency = 1
		linea2.Size = UDim2.new(1, -16, 0, 30)
		linea2.Position = UDim2.new(0, 8, 0, 54)
		linea2.Font = Enum.Font.Gotham
		linea2.TextScaled = true
		linea2.TextColor3 = Color3.fromRGB(225, 230, 240)
		linea2.TextStrokeTransparency = 0.5
		linea2.TextStrokeColor3 = Color3.new(0, 0, 0)
		linea2.Text = "letrero del archivo CityGenerator"
		linea2.Parent = fondo

		print("[SpiceEmpire] TESTIGO: letrero del servidor (" .. ronda .. ") puesto arriba del spawn.")
	end

	CityGenerator.SetupLighting()

	return city
end

----------------------------------------------------------------------
-- ILUMINACION + CICLO DIA/NOCHE
----------------------------------------------------------------------
function CityGenerator.SetupLighting()
	local Lighting = game:GetService("Lighting")

	-- OJO: Lighting.Technology es SOLO-LECTURA desde scripts.
	-- Se configura a mano en Studio: selecciona Lighting > propiedad Technology > Future
	safeSet(Lighting, "GlobalShadows", true)
	safeSet(Lighting, "EnvironmentDiffuseScale", 0.45)
	safeSet(Lighting, "EnvironmentSpecularScale", 0.35)
	-- v36: el interior salia BLANCO, quemado (captura del usuario). Se bajo la
	-- exposicion, el bloom y las luces de adentro (ver mas abajo).
	safeSet(Lighting, "ExposureCompensation", 0)
	local DN = Config.DayNight
	Lighting.ClockTime = DN.Enabled and DN.StartHour or DN.FixedHour
	safeSet(Lighting, "GeographicLatitude", 20)

	-- limpia efectos viejos (juntando primero: borrar dentro del bucle se salta
	-- elementos y quedaban efectos duplicados encimados)
	do
		local basura = {}
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("PostEffect") or e:IsA("Sky") or e:IsA("Atmosphere") then
				table.insert(basura, e)
			end
		end
		for _, e in ipairs(basura) do e:Destroy() end
	end

	local sky = Instance.new("Sky")
	sky.StarCount = 3000
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 12
	sky.Parent = Lighting

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.32
	atmo.Offset = 0.25
	atmo.Haze = 1.6
	atmo.Glare = 0.2
	atmo.Color = Color3.fromRGB(199, 199, 199)
	atmo.Decay = Color3.fromRGB(106, 112, 125)
	atmo.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	-- v36: era 0.5 / 22 / 1.1. Con tantas luces encendidas de noche (la bodega
	-- sola tiene ~20) todo salia con halo blanco, sobre todo las paredes y el
	-- piso de adentro. Ahora brilla menos y solo lo MUY brillante.
	bloom.Intensity = 0.22
	bloom.Size = 16
	bloom.Threshold = 1.45
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CityGrade"
	-- v36: menos contraste/saturacion = menos "quemado" adentro
	cc.Saturation = 0.04
	cc.Contrast = 0.05
	cc.Brightness = 0
	cc.Parent = Lighting

	local sun = Instance.new("SunRaysEffect")
	sun.Intensity = 0.08
	sun.Spread = 0.6
	sun.Parent = Lighting

	-- Ambiente INTERIOR fijo. 'Ambient' es la luz base que llega a todas
	-- las superficies, incluso dentro de cuartos cerrados: si sube de dia,
	-- la bodega se lava. Dejandolo fijo, adentro siempre se ve igual y el
	-- dia/noche se nota solo afuera (via Brightness y OutdoorAmbient).
	local INTERIOR_AMBIENT = Color3.fromRGB(42, 44, 54)

	-- ===== ENCENDER / APAGAR LUCES SEGUN LA HORA =====
	local lightsOn = nil  -- nil = aun sin aplicar

	local function setCityLights(on: boolean)
		if lightsOn == on then return end
		lightsOn = on

		for _, inst in ipairs(CollectionService:GetTagged(NIGHT_TAG)) do
			if inst:IsA("Light") then
				-- v46: una luz de INTERIOR (con brillo de dia) nunca se apaga:
				-- de dia queda bajita y de noche en su brillo suave.
				local dia = inst:GetAttribute("DayBrightness")
				inst.Enabled = true
				if on then
					inst.Brightness = inst:GetAttribute("NightBrightness") or 2
				else
					inst.Brightness = dia or 0
				end
			elseif inst:IsA("BasePart") then
				local litColor = inst:GetAttribute("LitColor")
				local offColor = inst:GetAttribute("OffColor")
				if on then
					inst.Material = Enum.Material.Neon
					inst.Transparency = 0
					inst.Reflectance = 0
					if litColor then inst.Color = litColor end
				else
					if inst:GetAttribute("IsWindow") then
						inst.Material = Enum.Material.Glass
						inst.Transparency = 0.35
						inst.Reflectance = 0.25
					else
						inst.Material = Enum.Material.SmoothPlastic
					end
					if offColor then inst.Color = offColor end
				end
			end
		end
	end

	CityGenerator.SetCityLights = setCityLights

	-- Ciclo: DayLengthMinutes minutos reales = 24h en el juego
	local step = 24 / (DN.DayLengthMinutes * 60)  -- horas de juego por segundo real

	task.spawn(function()
		while true do
			task.wait(1)
			local t = Lighting.ClockTime
			if DN.Enabled then
				t = (t + step) % 24
				Lighting.ClockTime = t
			end

			-- luces encendidas solo de 18:00 a 6:30
			setCityLights(t >= 18 or t < 6.5)

			-- de noche sube el ambiente para que no quede boca de lobo
			local isNight = t < 6 or t > 18.5
			local isDusk = (t >= 17 and t <= 18.5) or (t >= 5.5 and t <= 7)

			if isNight then
				Lighting.Brightness = 1.2
				Lighting.Ambient = INTERIOR_AMBIENT
				Lighting.OutdoorAmbient = Color3.fromRGB(72, 76, 100)
				Lighting.FogColor = Color3.fromRGB(28, 30, 45)
				atmo.Density = 0.38
				atmo.Color = Color3.fromRGB(120, 130, 170)
				cc.Brightness = 0.04
				cc.TintColor = Color3.fromRGB(205, 215, 255)
			elseif isDusk then
				Lighting.Brightness = 2.0
				Lighting.Ambient = INTERIOR_AMBIENT
				Lighting.OutdoorAmbient = Color3.fromRGB(150, 118, 100)
				Lighting.FogColor = Color3.fromRGB(120, 85, 70)
				atmo.Density = 0.42
				atmo.Color = Color3.fromRGB(235, 175, 130)
				cc.Brightness = 0
				cc.TintColor = Color3.fromRGB(255, 235, 215)
			else
				Lighting.Brightness = 3.0
				Lighting.Ambient = INTERIOR_AMBIENT
				Lighting.OutdoorAmbient = Color3.fromRGB(168, 170, 178)
				Lighting.FogColor = Color3.fromRGB(165, 178, 195)
				atmo.Density = 0.3
				atmo.Color = Color3.fromRGB(199, 205, 215)
				cc.Brightness = 0
				cc.TintColor = Color3.fromRGB(255, 255, 255)
			end
		end
	end)
end

return CityGenerator
