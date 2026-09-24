--!strict
-- LocalScript -> StarterPlayer.StarterPlayerScripts.ClientUI
-- HUD, telefono con alertas, tiendas y controles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RE_State = Remotes:WaitForChild("StateUpdate") :: RemoteEvent
local RE_Phone = Remotes:WaitForChild("PhoneAlert") :: RemoteEvent
local RE_Toast = Remotes:WaitForChild("Toast") :: RemoteEvent
local RE_Mission = Remotes:WaitForChild("MissionUpdate") :: RemoteEvent
local RE_OpenUp  = Remotes:WaitForChild("OpenUpgrades") :: RemoteEvent
local RE_Sfx     = Remotes:WaitForChild("Sfx") :: RemoteEvent
local RF_Action = Remotes:WaitForChild("Action") :: RemoteFunction

local player = Players.LocalPlayer
local State: any = {Cash = 0, Leaves = 0, Blocks = 0, Heat = 0, Plots = 0, PressLevel = 1,
	Employees = {Harvester=0,Presser=0,Guard=0}, Vehicles = {}, Properties = {}, Storage = 200}

local function act(name: string, a: any?, b: any?)
	task.spawn(function()
		pcall(function() RF_Action:InvokeServer(name, a, b) end)
	end)
end

----------------------------------------------------------------------
-- HELPERS UI
----------------------------------------------------------------------
local FONT = Enum.Font.GothamBold
local ACCENT = Color3.fromRGB(240, 180, 70)
local BG = Color3.fromRGB(18, 18, 22)
local BG2 = Color3.fromRGB(28, 28, 34)

local function corner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function stroke(inst: Instance, color: Color3, t: number?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 1
	s.Transparency = 0.4
	s.Parent = inst
end

local function frame(parent: Instance, props: {[string]: any}): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = BG2
	f.BorderSizePixel = 0
	for k, v in pairs(props) do (f :: any)[k] = v end
	f.Parent = parent
	return f
end

local function label(parent: Instance, props: {[string]: any}): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in pairs(props) do (l :: any)[k] = v end
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, props: {[string]: any}?): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = ACCENT
	b.TextColor3 = Color3.fromRGB(20, 20, 20)
	b.Font = FONT
	b.Text = text
	b.TextScaled = false
	b.TextSize = 14
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	if props then for k, v in pairs(props) do (b :: any)[k] = v end end
	b.Parent = parent
	corner(b, 8)
	return b
end

----------------------------------------------------------------------
-- SCREEN GUI
----------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SpiceEmpireUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

----------------------------------------------------------------------
-- ADAPTACION A CELULAR
----------------------------------------------------------------------
-- En celular Roblox pone SU joystick abajo-izquierda y el boton de
-- saltar abajo-derecha. Hay que dejar esas esquinas libres.
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local camera = workspace.CurrentCamera

-- Hace que un panel grande SIEMPRE quepa en la pantalla.
-- En vez de andar cambiando 80 medidas a mano, le metemos un UIScale
-- que se recalcula segun el tamaño real del dispositivo.
local function fitPanel(panel: GuiObject, designW: number, designH: number, center: boolean?)
	local sc = Instance.new("UIScale")
	sc.Parent = panel

	-- El UIScale encoge desde el punto de anclaje. Si el panel estaba
	-- centrado con un offset fijo (tipo -310), al encogerse se descuadra.
	-- Lo anclamos al centro real para que siempre quede en medio.
	if center ~= false then
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
	end

	local function update()
		if not camera then return end
		local vp = camera.ViewportSize
		-- dejamos un margen para que no quede pegado a las orillas
		local maxW = vp.X - 24
		local maxH = vp.Y - (IS_MOBILE and 24 or 90)
		local k = math.min(maxW / designW, maxH / designH, 1)
		sc.Scale = math.max(k, 0.45)
	end

	update()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return sc
end

----------------------------------------------------------------------
-- HUD SUPERIOR
----------------------------------------------------------------------
----------------------------------------------------------------------
-- PANTALLA DE INICIO
----------------------------------------------------------------------
local splash = frame(gui, {
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(0, 0),
	BackgroundColor3 = Color3.fromRGB(8, 8, 12),
	ZIndex = 50,
})

-- degradado de fondo
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 18, 28)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 10, 16)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 16, 10)),
})
grad.Rotation = 135
grad.Parent = splash

local title = label(splash, {
	Size = UDim2.new(1, 0, 0, 84),
	Position = UDim2.new(0, 0, 0.20, 0),
	TextSize = 64,
	Font = Enum.Font.GothamBlack,
	TextColor3 = Color3.fromRGB(245, 196, 92),
	Text = "SPICE EMPIRE",
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 51,
})

local subtitle = label(splash, {
	Size = UDim2.new(1, 0, 0, 30),
	Position = UDim2.new(0, 0, 0.20, 76),
	TextSize = 20,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(180, 180, 200),
	Text = "Cultiva.  Prensa.  Vende.  Sobrevive.",
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 51,
})

-- linea decorativa
local line = frame(splash, {
	Size = UDim2.new(0, 260, 0, 2),
	Position = UDim2.new(0.5, -130, 0.20, 116),
	BackgroundColor3 = Color3.fromRGB(245, 196, 92),
	BackgroundTransparency = 0.4,
	ZIndex = 51,
})

local tips = {
	"Los compradores lejanos pagan mas, pero te queman mas rapido.",
	"Escondete en tu Zona Segura para bajar el Heat.",
	"Contrata Guardias para que no te asalten la bodega.",
	"Presiona M para minimizar el HUD.",
	"Un crew protege tu mercancia de otros jugadores.",
	"Si te agarran, pierdes la mitad de tu carga.",
}

local tipLbl = label(splash, {
	Size = UDim2.new(1, -80, 0, 24),
	Position = UDim2.new(0, 40, 1, -70),
	TextSize = 15,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(150, 150, 170),
	Text = "",
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 51,
})

local playBtn = Instance.new("TextButton")
playBtn.Size = UDim2.new(0, 240, 0, 56)
playBtn.Position = UDim2.new(0.5, -120, 0.5, 10)
playBtn.BackgroundColor3 = Color3.fromRGB(245, 196, 92)
playBtn.TextColor3 = Color3.fromRGB(18, 16, 12)
playBtn.Font = Enum.Font.GothamBold
playBtn.TextSize = 22
playBtn.Text = "ENTRAR AL BARRIO"
playBtn.BorderSizePixel = 0
playBtn.ZIndex = 51
playBtn.Parent = splash
corner(playBtn, 10)

local loadingLbl = label(splash, {
	Size = UDim2.new(1, 0, 0, 22),
	Position = UDim2.new(0, 0, 0.5, 80),
	TextSize = 14,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(130, 130, 150),
	Text = "Cargando la ciudad...",
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 51,
})

playBtn.Visible = false

-- rotar tips
task.spawn(function()
	while splash.Parent and splash.Visible do
		tipLbl.Text = "TIP:  " .. tips[math.random(1, #tips)]
		task.wait(3.5)
	end
end)

local function closeSplash()
	for _, obj in ipairs({title, subtitle, tipLbl, loadingLbl}) do
		TweenService:Create(obj, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
	end
	TweenService:Create(playBtn, TweenInfo.new(0.3),
		{BackgroundTransparency = 1, TextTransparency = 1}):Play()
	TweenService:Create(line, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
	TweenService:Create(splash, TweenInfo.new(0.7), {BackgroundTransparency = 1}):Play()
	task.wait(0.75)
	splash.Visible = false
end

playBtn.MouseButton1Click:Connect(function()
	task.spawn(closeSplash)
end)

local hudExpanded = true

local hud = frame(gui, {
	Size = UDim2.new(0, 420, 0, 74),
	Position = UDim2.new(0, 16, 0, 96),  -- debajo de la barra de Roblox
	BackgroundColor3 = BG,
	BackgroundTransparency = 0.12,
})
corner(hud, 12)
stroke(hud, ACCENT)

local cashLbl = label(hud, {
	Size = UDim2.new(1, -100, 0, 28),
	Position = UDim2.new(0, 14, 0, 8),
	TextSize = 22,
	TextColor3 = Color3.fromRGB(120, 230, 150),
	Text = "$0",
})

local invLbl = label(hud, {
	Size = UDim2.new(1, -20, 0, 18),
	Position = UDim2.new(0, 14, 0, 36),
	TextSize = 14,
	TextColor3 = Color3.fromRGB(225, 225, 235),
	Text = "Hojas 0  |  Bloques 0  |  Espacio 0/200",
})

local heatTxt = label(hud, {
	Size = UDim2.new(0, 110, 0, 16),
	Position = UDim2.new(1, -158, 0, 12),
	TextSize = 12,
	TextColor3 = Color3.fromRGB(190, 190, 205),
	Text = "HEAT 0%",
	TextXAlignment = Enum.TextXAlignment.Right,
})

-- barra de heat
local heatBg = frame(hud, {
	Size = UDim2.new(1, -28, 0, 8),
	Position = UDim2.new(0, 14, 0, 58),
	BackgroundColor3 = Color3.fromRGB(50, 50, 58),
})
corner(heatBg, 4)

local heatFill = frame(heatBg, {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(230, 150, 60),
})
corner(heatFill, 4)

----------------------------------------------------------------------
-- HUD COMPACTO (iconos semitransparentes)
----------------------------------------------------------------------
local mini = frame(gui, {
	Size = UDim2.new(0, 250, 0, 62),
	Position = UDim2.new(0, 16, 0, 96),
	BackgroundTransparency = 1,
	Visible = false,
})

local miniCash = label(mini, {
	Size = UDim2.new(1, 0, 0, 26),
	Position = UDim2.new(0, 4, 0, 0),
	TextSize = 22,
	TextColor3 = Color3.fromRGB(120, 230, 150),
	Text = "$0",
	TextStrokeTransparency = 0.25,
})

local miniRow = frame(mini, {
	Size = UDim2.new(1, 0, 0, 28),
	Position = UDim2.new(0, 0, 0, 28),
	BackgroundTransparency = 1,
})
local miniLayout = Instance.new("UIListLayout")
miniLayout.FillDirection = Enum.FillDirection.Horizontal
miniLayout.VerticalAlignment = Enum.VerticalAlignment.Center
miniLayout.Padding = UDim.new(0, 6)
miniLayout.Parent = miniRow

-- chip = icono dibujado + numero, semitransparente
local function chip(iconColor: Color3, shape: string)
	local holder = frame(miniRow, {
		Size = UDim2.new(0, 74, 0, 26),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		BackgroundTransparency = 0.45,
	})
	corner(holder, 13)

	local ic = frame(holder, {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0, 7, 0.5, -7),
		BackgroundColor3 = iconColor,
		BackgroundTransparency = 0.15,
	})
	if shape == "leaf" then
		corner(ic, 7)                       -- redondo = hoja
	elseif shape == "block" then
		corner(ic, 3)                       -- cuadrado = bloque
	else
		corner(ic, 4)                       -- mochila
		local flap = frame(ic, {
			Size = UDim2.new(0.6, 0, 0.3, 0),
			Position = UDim2.new(0.2, 0, -0.18, 0),
			BackgroundColor3 = iconColor,
			BackgroundTransparency = 0.15,
		})
		corner(flap, 3)
	end

	local txt = label(holder, {
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.new(0, 26, 0, 0),
		TextSize = 13,
		TextColor3 = Color3.fromRGB(235, 235, 245),
		TextTransparency = 0.1,
		Text = "0",
	})
	return txt
end

local chipLeaf  = chip(Color3.fromRGB(110, 205, 95),  "leaf")
local chipBlock = chip(Color3.fromRGB(226, 208, 168), "block")
local chipBag   = chip(Color3.fromRGB(150, 175, 220), "bag")

----------------------------------------------------------------------
-- BOTON MINIMIZAR
----------------------------------------------------------------------
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 26, 0, 26)
toggleBtn.Position = UDim2.new(1, -34, 0, 8)
toggleBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 66)
toggleBtn.BackgroundTransparency = 0.2
toggleBtn.TextColor3 = Color3.fromRGB(230, 230, 240)
toggleBtn.Font = FONT
toggleBtn.TextSize = 18
toggleBtn.Text = "-"
toggleBtn.BorderSizePixel = 0
toggleBtn.ZIndex = 5
toggleBtn.Parent = hud
corner(toggleBtn, 13)

local miniToggle = Instance.new("TextButton")
miniToggle.Size = UDim2.new(0, 22, 0, 22)
miniToggle.Position = UDim2.new(0, 150, 0, 2)
miniToggle.BackgroundColor3 = Color3.fromRGB(45, 45, 56)
miniToggle.BackgroundTransparency = 0.45
miniToggle.TextColor3 = Color3.fromRGB(225, 225, 240)
miniToggle.TextTransparency = 0.1
miniToggle.Font = FONT
miniToggle.TextSize = 15
miniToggle.Text = "+"
miniToggle.BorderSizePixel = 0
miniToggle.Parent = mini
corner(miniToggle, 11)

local function setHud(expanded: boolean)
	hudExpanded = expanded
	hud.Visible = expanded
	mini.Visible = not expanded
end

toggleBtn.MouseButton1Click:Connect(function() setHud(false) end)
miniToggle.MouseButton1Click:Connect(function() setHud(true) end)

local wantedLbl = label(gui, {
	Size = UDim2.new(0, 400, 0, 34),
	Position = UDim2.new(0, 16, 0, 176),
	TextSize = 20,
	TextColor3 = Color3.fromRGB(255, 90, 90),
	Text = "",
	TextStrokeTransparency = 0.3,
})

-- reloj del juego
local clockLbl = label(gui, {
	Size = UDim2.new(0, 120, 0, 24),
	Position = UDim2.new(0, 446, 0, 96),
	TextSize = 17,
	TextColor3 = Color3.fromRGB(200, 210, 235),
	Text = "",
	TextStrokeTransparency = 0.4,
})

task.spawn(function()
	local Lighting = game:GetService("Lighting")
	while true do
		local t = Lighting.ClockTime
		local h = math.floor(t)
		local m = math.floor((t - h) * 60)
		local icon = (h >= 6 and h < 19) and "SOL" or "LUNA"
		clockLbl.Text = string.format("%02d:%02d  %s", h, m, icon)
		task.wait(1)
	end
end)

----------------------------------------------------------------------
-- BOTONES DE ACCION (abajo)
----------------------------------------------------------------------
-- En CELULAR: rejilla de 2 columnas pegada al costado DERECHO, a media
-- altura. Ahi no estorba el joystick (abajo-izq) ni el salto (abajo-der).
-- En COMPU: la barra horizontal de siempre, abajo al centro.
local BTN_W = IS_MOBILE and 106 or 100
local BTN_H = IS_MOBILE and 46 or 38   -- en tactil el boton debe ser mas alto

local dock
if IS_MOBILE then
	dock = frame(gui, {
		Size = UDim2.new(0, BTN_W * 2 + 18, 0, BTN_H * 4 + 26),
		Position = UDim2.new(1, -(BTN_W * 2 + 26), 0.5, -(BTN_H * 4 + 26) / 2),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.18,
	})
	corner(dock, 14)
	stroke(dock, ACCENT)

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, BTN_W, 0, BTN_H)
	grid.CellPadding = UDim2.new(0, 6, 0, 6)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.Parent = dock
else
	dock = frame(gui, {
		Size = UDim2.new(0, 660, 0, 56),
		Position = UDim2.new(0.5, -330, 1, -76),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.12,
	})
	corner(dock, 12)
	stroke(dock, ACCENT)

	local dockLayout = Instance.new("UIListLayout")
	dockLayout.FillDirection = Enum.FillDirection.Horizontal
	dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dockLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dockLayout.Padding = UDim.new(0, 8)
	dockLayout.Parent = dock
end

-- en celular no tiene caso mostrar "[E]": no hay teclado
local function dockBtn(name: string, key: string, cb: () -> ())
	local text = IS_MOBILE and name or (name .. " [" .. key .. "]")
	local b = button(dock, text, {Size = UDim2.new(0, BTN_W, 0, BTN_H)})
	if IS_MOBILE then b.TextSize = 13 end
	b.MouseButton1Click:Connect(cb)
	return b
end

dockBtn("Cosechar", "E", function() act("harvest") end)
dockBtn("Prensar", "R", function() act("press") end)
dockBtn("Vender", "F", function()
	-- vende en el comprador mas cercano
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local buyers = workspace:FindFirstChild("City") and workspace.City:FindFirstChild("Buyers")
	if not buyers then return end
	local best, bestD = nil, math.huge
	for _, pad in ipairs(buyers:GetChildren()) do
		local d = (pad.Position - hrp.Position).Magnitude
		if d < bestD then best, bestD = pad, d end
	end
	if best then act("sell", best.Name) end
end)

local shopBtn = dockBtn("Tienda", "B", function() end)
local phoneBtn = dockBtn("Telefono", "T", function() end)
dockBtn("Bodega", "H", function() act("teleportHome") end)

----------------------------------------------------------------------
-- PANEL TIENDA
----------------------------------------------------------------------
local shop = frame(gui, {
	Size = UDim2.new(0, 620, 0, 460),
	Position = UDim2.new(0.5, -310, 0.5, -230),
	BackgroundColor3 = BG,
	Visible = false,
})
corner(shop, 14)
stroke(shop, ACCENT, 1.5)

label(shop, {Size = UDim2.new(1, -20, 0, 40), Position = UDim2.new(0, 16, 0, 6),
	TextSize = 22, Text = "MERCADO", TextColor3 = ACCENT})

local closeShop = button(shop, "X", {Size = UDim2.new(0, 32, 0, 32),
	Position = UDim2.new(1, -44, 0, 10), BackgroundColor3 = Color3.fromRGB(200, 70, 70),
	TextColor3 = Color3.new(1,1,1)})
closeShop.MouseButton1Click:Connect(function() shop.Visible = false end)

-- tabs
local tabBar = frame(shop, {Size = UDim2.new(1, -32, 0, 34), Position = UDim2.new(0, 16, 0, 46),
	BackgroundTransparency = 1})
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabBar

local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -32, 1, -100)
content.Position = UDim2.new(0, 16, 0, 88)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 5
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = shop

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 6)
contentLayout.Parent = content

local currentTab = "bodega"
local renderTab: (string) -> ()

local function row(title: string, subtitle: string, btnText: string, cb: () -> (), disabled: boolean?)
	local r = frame(content, {Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = BG2})
	corner(r, 8)

	label(r, {Size = UDim2.new(1, -140, 0, 22), Position = UDim2.new(0, 12, 0, 8),
		TextSize = 16, Text = title})
	label(r, {Size = UDim2.new(1, -140, 0, 18), Position = UDim2.new(0, 12, 0, 30),
		TextSize = 13, Text = subtitle, TextColor3 = Color3.fromRGB(180, 180, 195)})

	local b = button(r, btnText, {Size = UDim2.new(0, 112, 0, 34), Position = UDim2.new(1, -124, 0, 12)})
	if disabled then
		b.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
		b.TextColor3 = Color3.fromRGB(150, 150, 160)
	else
		b.MouseButton1Click:Connect(function()
			cb()
			task.wait(0.15)
			renderTab(currentTab)
		end)
	end
end

renderTab = function(tab: string)
	currentTab = tab
	for _, c in ipairs(content:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	if tab == "bodega" then
		local cur = State.WarehouseTier or 1
		local T = Config.WarehouseTiers[cur]
		local nextT = Config.WarehouseTiers[cur + 1]

		local info = frame(content, {Size = UDim2.new(1, -8, 0, 68), BackgroundColor3 = BG2})
		corner(info, 8)
		label(info, {Size = UDim2.new(1, -24, 0, 24), Position = UDim2.new(0, 12, 0, 8),
			TextSize = 18, Text = "Nivel " .. cur .. ": " .. T.Name, TextColor3 = ACCENT})
		label(info, {Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, 34),
			TextSize = 13, Text = T.Desc, TextColor3 = Color3.fromRGB(180, 180, 195)})
		label(info, {Size = UDim2.new(1, -24, 0, 16), Position = UDim2.new(0, 12, 0, 50),
			TextSize = 12, Text = string.format("Parcelas %d  |  Almacen +%d", T.Plots, T.StorageBonus),
			TextColor3 = Color3.fromRGB(150, 200, 160)})

		if nextT then
			row(nextT.Name,
				string.format("%s  |  Parcelas %d  |  Almacen +%d", nextT.Desc, nextT.Plots, nextT.StorageBonus),
				"$" .. Config.Abbrev(nextT.Cost),
				function() act("upgradeWarehouse") end)
		else
			row("Nivel maximo alcanzado", "Ya tienes la Mega Procesadora", "MAX", function() end, true)
		end

		row("Bicicleta", "Tu transporte inicial. Gratis siempre.", "Spawnear",
			function() act("spawnBike") end)

	elseif tab == "negocio" then
		local plotCost = Config.CostCurve(Config.Plots.BaseCost, Config.Plots.Growth,
			State.Plots - Config.Plots.StartingPlots)
		row("Parcela de cultivo",
			string.format("Tienes %d/%d - mas hojas por cosecha", State.Plots, Config.Plots.MaxPlots),
			"$" .. Config.Abbrev(plotCost), function() act("buyPlot") end,
			State.Plots >= Config.Plots.MaxPlots)

		local pressCost = Config.CostCurve(Config.Press.BaseCost, Config.Press.Growth, State.PressLevel - 1)
		row("Mejorar prensa",
			string.format("Nivel %d/%d - mas bloques por prensada", State.PressLevel, Config.Press.MaxLevel),
			"$" .. Config.Abbrev(pressCost), function() act("upgradePress") end,
			State.PressLevel >= Config.Press.MaxLevel)

	elseif tab == "empleados" then
		for _, role in ipairs({"Harvester", "Presser", "Guard"}) do
			local info = Config.Employees[role]
			local owned = State.Employees[role] or 0
			local cost = Config.CostCurve(info.BaseCost, info.Growth, owned)
			local desc
			if role == "Guard" then
				desc = string.format("%d/%d - cada uno baja %d%% el riesgo de asalto", owned, info.Max, info.RaidReduction * 100)
			else
				desc = string.format("%d/%d - produce solo cada %ds", owned, info.Max, info.Interval)
			end
			row(info.Name, desc, "$" .. Config.Abbrev(cost),
				function() act("hire", role) end, owned >= info.Max)
		end

	elseif tab == "autos" then
		for _, v in ipairs(Config.Vehicles) do
			local owned = State.Vehicles[v.Id]
			row(v.Name, string.format("Velocidad %d - Capacidad %d", v.Speed, v.Capacity),
				owned and "Spawnear" or ("$" .. Config.Abbrev(v.Cost)),
				function()
					if owned then act("spawnVehicle", v.Id) else act("buyVehicle", v.Id) end
				end)
		end

	elseif tab == "props" then
		for _, p in ipairs(Config.Properties) do
			local owned = State.Properties[p.Id]
			row(p.Name, string.format("Renta $%d/min - Almacen +%d", p.Income, p.Storage),
				owned and "COMPRADA" or ("$" .. Config.Abbrev(p.Cost)),
				function() act("buyProperty", p.Id) end, owned)
		end

	elseif tab == "crew" then
		if State.CrewName then
			row("Tu crew: " .. State.CrewName, "Los miembros no se roban entre si",
				"Salir", function() act("leaveCrew") end)
		else
			local r = frame(content, {Size = UDim2.new(1, -8, 0, 110), BackgroundColor3 = BG2})
			corner(r, 8)
			label(r, {Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 0, 6),
				TextSize = 16, Text = "Crear o unirte a un crew"})

			local box = Instance.new("TextBox")
			box.Size = UDim2.new(1, -150, 0, 32)
			box.Position = UDim2.new(0, 12, 0, 34)
			box.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
			box.TextColor3 = Color3.new(1,1,1)
			box.Font = Enum.Font.Gotham
			box.TextSize = 14
			box.PlaceholderText = "Nombre del crew / del lider"
			box.Text = ""
			box.ClearTextOnFocus = false
			box.BorderSizePixel = 0
			box.Parent = r
			corner(box, 6)

			local bc = button(r, "Crear", {Size = UDim2.new(0, 120, 0, 32), Position = UDim2.new(1, -132, 0, 34)})
			bc.MouseButton1Click:Connect(function()
				act("createCrew", box.Text)
				task.wait(0.2); renderTab("crew")
			end)

			local bj = button(r, "Unirme al jugador", {Size = UDim2.new(0, 160, 0, 30),
				Position = UDim2.new(0, 12, 0, 72), BackgroundColor3 = Color3.fromRGB(90, 150, 220),
				TextColor3 = Color3.new(1,1,1)})
			bj.MouseButton1Click:Connect(function()
				act("joinCrew", box.Text)
				task.wait(0.2); renderTab("crew")
			end)
		end

	elseif tab == "compradores" then
		for _, b in ipairs(Config.Buyers) do
			row(b.Name, string.format("Precio x%.2f - Riesgo x%.1f", b.PriceMult, b.HeatMult),
				"Marcar", function() end, true)
		end
	end
end

for _, t in ipairs({
	{"bodega", "Bodega"}, {"negocio", "Negocio"}, {"empleados", "Empleados"}, {"autos", "Autos"},
	{"props", "Propiedades"}, {"crew", "Crew"}, {"compradores", "Compradores"},
}) do
	local b = button(tabBar, t[2], {Size = UDim2.new(0, 80, 1, 0),
		BackgroundColor3 = BG2, TextColor3 = Color3.fromRGB(220, 220, 230), TextSize = 13})
	b.MouseButton1Click:Connect(function() renderTab(t[1]) end)
end

shopBtn.MouseButton1Click:Connect(function()
	shop.Visible = not shop.Visible
	if shop.Visible then renderTab(currentTab) end
end)

-- Boton de MEJORAS. Antes solo existia la tecla G, asi que en celular
-- no habia forma de abrir la computadora del escritorio.
dockBtn("Mejoras", "G", function()
	shop.Visible = true
	renderTab("bodega")
end)

-- El servidor avisa cuando te paras en el tapete del escritorio:
-- la computadora abre sola el panel de mejoras.
RE_OpenUp.OnClientEvent:Connect(function()
	if shop.Visible then return end
	shop.Visible = true
	renderTab("bodega")
end)

-- que la tienda quepa siempre, sobre todo en pantallas de celular
fitPanel(shop, 620, 460)

----------------------------------------------------------------------
-- TELEFONO
----------------------------------------------------------------------
local phone = frame(gui, {
	Size = UDim2.new(0, 300, 0, 440),
	-- en compu va pegado a la derecha; en celular se centra (abajo)
	Position = IS_MOBILE and UDim2.fromScale(0.5, 0.5) or UDim2.new(1, -320, 1, -540),
	BackgroundColor3 = Color3.fromRGB(12, 12, 16),
	Visible = false,
})
corner(phone, 20)
stroke(phone, Color3.fromRGB(90, 200, 255), 1.5)
if IS_MOBILE then fitPanel(phone, 300, 440) end

label(phone, {Size = UDim2.new(1, -24, 0, 34), Position = UDim2.new(0, 16, 0, 10),
	TextSize = 18, Text = "MENSAJES", TextColor3 = Color3.fromRGB(120, 210, 255)})

local unread = label(phone, {Size = UDim2.new(0, 60, 0, 20), Position = UDim2.new(1, -76, 0, 18),
	TextSize = 12, Text = "", TextColor3 = Color3.fromRGB(255, 120, 120),
	TextXAlignment = Enum.TextXAlignment.Right})

local feed = Instance.new("ScrollingFrame")
feed.Size = UDim2.new(1, -24, 1, -60)
feed.Position = UDim2.new(0, 12, 0, 48)
feed.BackgroundTransparency = 1
feed.BorderSizePixel = 0
feed.ScrollBarThickness = 4
feed.AutomaticCanvasSize = Enum.AutomaticSize.Y
feed.CanvasSize = UDim2.new(0, 0, 0, 0)
feed.Parent = phone

local feedLayout = Instance.new("UIListLayout")
feedLayout.Padding = UDim.new(0, 6)
feedLayout.Parent = feed

local unreadCount = 0

local KIND_COLORS = {
	info = Color3.fromRGB(120, 180, 255),
	good = Color3.fromRGB(120, 230, 150),
	danger = Color3.fromRGB(255, 100, 100),
	money = Color3.fromRGB(240, 200, 90),
}

local function addMessage(data)
	local c = KIND_COLORS[data.Kind] or KIND_COLORS.info

	local m = frame(feed, {Size = UDim2.new(1, -8, 0, 0), BackgroundColor3 = Color3.fromRGB(26, 26, 32),
		AutomaticSize = Enum.AutomaticSize.Y})
	corner(m, 10)
	stroke(m, c)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = m

	local ml = Instance.new("UIListLayout")
	ml.Padding = UDim.new(0, 2)
	ml.Parent = m

	label(m, {Size = UDim2.new(1, 0, 0, 18), TextSize = 14, Text = data.Title, TextColor3 = c})
	label(m, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 13, Text = data.Body, TextWrapped = true,
		Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(215, 215, 225)})

	m.LayoutOrder = -os.clock()

	if #feed:GetChildren() > 40 then
		local oldest
		for _, ch in ipairs(feed:GetChildren()) do
			if ch:IsA("Frame") and (not oldest or ch.LayoutOrder > oldest.LayoutOrder) then oldest = ch end
		end
		if oldest then oldest:Destroy() end
	end

	if not phone.Visible then
		unreadCount += 1
		unread.Text = unreadCount .. " nuevos"
		phoneBtn.BackgroundColor3 = Color3.fromRGB(255, 110, 110)
	end
end

phoneBtn.MouseButton1Click:Connect(function()
	phone.Visible = not phone.Visible
	if phone.Visible then
		unreadCount = 0
		unread.Text = ""
		phoneBtn.BackgroundColor3 = ACCENT
	end
end)

RE_Phone.OnClientEvent:Connect(addMessage)

----------------------------------------------------------------------
-- TOASTS
----------------------------------------------------------------------
local toastHolder = frame(gui, {
	Size = UDim2.new(0, 340, 0, 200),
	Position = UDim2.new(0.5, -170, 0, 140),
	BackgroundTransparency = 1,
})
local tl = Instance.new("UIListLayout")
tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
tl.Padding = UDim.new(0, 4)
tl.Parent = toastHolder

RE_Toast.OnClientEvent:Connect(function(text: string, kind: string)
	local color = kind == "bad" and Color3.fromRGB(255, 110, 110) or Color3.fromRGB(150, 240, 170)
	local t = label(toastHolder, {
		Size = UDim2.new(1, 0, 0, 24), TextSize = 15, Text = text,
		TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
	})
	task.delay(2.2, function()
		TweenService:Create(t, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		task.wait(0.55)
		t:Destroy()
	end)
end)

----------------------------------------------------------------------
-- SYNC DE ESTADO
----------------------------------------------------------------------
RE_State.OnClientEvent:Connect(function(data)
	State = data
	local cashTxt = "$" .. Config.Abbrev(data.Cash)
	cashLbl.Text = cashTxt
	miniCash.Text = cashTxt

	local used = data.Leaves + data.Blocks * 3
	invLbl.Text = string.format("Hojas %d  |  Bloques %d  |  Espacio %d/%d",
		data.Leaves, data.Blocks, used, data.Storage)

	chipLeaf.Text = Config.Abbrev(data.Leaves)
	chipBlock.Text = Config.Abbrev(data.Blocks)
	chipBag.Text = string.format("%d/%d", used, data.Storage)

	local ratio = data.Heat / Config.Heat.Max
	heatTxt.Text = string.format("HEAT %d%%", math.floor(ratio * 100))
	TweenService:Create(heatFill, TweenInfo.new(0.3), {Size = UDim2.new(ratio, 0, 1, 0)}):Play()
	heatFill.BackgroundColor3 = ratio > 0.7 and Color3.fromRGB(255, 70, 70)
		or ratio > 0.4 and Color3.fromRGB(255, 160, 60)
		or Color3.fromRGB(120, 200, 120)

	wantedLbl.Text = data.Wanted and "BUSCADO - ADUANAS EN TU CONTRA" or ""

	if shop.Visible then renderTab(currentTab) end
end)

----------------------------------------------------------------------
-- TECLAS
----------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local k = input.KeyCode
	if k == Enum.KeyCode.E then act("harvest")
	elseif k == Enum.KeyCode.G then
		-- la computadora del escritorio: abre la pestaña de Bodega
		shop.Visible = true
		renderTab("bodega")
	elseif k == Enum.KeyCode.R then act("press")
	elseif k == Enum.KeyCode.H then act("teleportHome")
	elseif k == Enum.KeyCode.B then
		shop.Visible = not shop.Visible
		if shop.Visible then renderTab(currentTab) end
	elseif k == Enum.KeyCode.M then
		setHud(not hudExpanded)
	elseif k == Enum.KeyCode.T then
		phone.Visible = not phone.Visible
		if phone.Visible then unreadCount = 0; unread.Text = ""; phoneBtn.BackgroundColor3 = ACCENT end
	elseif k == Enum.KeyCode.F then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local buyers = workspace:FindFirstChild("City") and workspace.City:FindFirstChild("Buyers")
		if not buyers then return end
		local best, bestD = nil, math.huge
		for _, pad in ipairs(buyers:GetChildren()) do
			local d = (pad.Position - hrp.Position).Magnitude
			if d < bestD then best, bestD = pad, d end
		end
		if best then act("sell", best.Name) end
	end
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- PANEL DE ENCARGO ACTIVO
----------------------------------------------------------------------
local missionPanel = frame(gui, {
	Size = UDim2.new(0, 300, 0, 86),
	-- en celular el costado derecho lo ocupan los botones, asi que
	-- el encargo se va arriba al centro
	Position = IS_MOBILE and UDim2.new(0.5, -150, 0, 92) or UDim2.new(1, -320, 0, 250),
	BackgroundColor3 = Color3.fromRGB(14, 14, 20),
	BackgroundTransparency = 0.15,
	Visible = false,
})
corner(missionPanel, 10)
stroke(missionPanel, Color3.fromRGB(240, 200, 90), 1.5)

local mTitle = label(missionPanel, {
	Size = UDim2.new(1, -54, 0, 20),
	Position = UDim2.new(0, 12, 0, 8),
	TextSize = 15,
	TextColor3 = Color3.fromRGB(250, 205, 100),
	Text = "",
})

local mText = label(missionPanel, {
	Size = UDim2.new(1, -20, 0, 32),
	Position = UDim2.new(0, 12, 0, 28),
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(215, 215, 228),
	Text = "",
	TextWrapped = true,
})

local mTimer = label(missionPanel, {
	Size = UDim2.new(1, -20, 0, 18),
	Position = UDim2.new(0, 12, 1, -24),
	TextSize = 14,
	TextColor3 = Color3.fromRGB(255, 140, 120),
	Text = "",
})

-- boton de minimizar el encargo
local mMin = Instance.new("TextButton")
mMin.Name = "MinBtn"
mMin.Size = UDim2.new(0, 28, 0, 22)
mMin.Position = UDim2.new(1, -36, 0, 7)
mMin.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
mMin.BorderSizePixel = 0
mMin.Font = Enum.Font.GothamBold
mMin.TextSize = 16
mMin.TextColor3 = Color3.fromRGB(240, 210, 130)
mMin.Text = "-"
mMin.AutoButtonColor = true
mMin.Parent = missionPanel
corner(mMin, 6)

local missionMin = false
local function setMissionMin(minimized: boolean)
	missionMin = minimized
	mText.Visible = not minimized
	if minimized then
		missionPanel.Size = UDim2.new(0, 300, 0, 34)
		mTimer.Position = UDim2.new(0, 12, 0, 8)
		mTimer.Visible = false
		mMin.Text = "+"
		mTitle.TextSize = 14
	else
		missionPanel.Size = UDim2.new(0, 300, 0, 86)
		mTimer.Position = UDim2.new(0, 12, 1, -24)
		mTimer.Visible = true
		mMin.Text = "-"
		mTitle.TextSize = 15
	end
end

mMin.MouseButton1Click:Connect(function()
	setMissionMin(not missionMin)
end)

local currentMission = nil

RE_Mission.OnClientEvent:Connect(function(m)
	currentMission = m
	if not m then
		missionPanel.Visible = false
		return
	end
	missionPanel.Visible = true
	mTitle.Text = m.Title
	mText.Text = m.Text
end)

-- cuenta regresiva
task.spawn(function()
	while true do
		if currentMission and currentMission.EndsAt then
			local left = currentMission.EndsAt - os.time()
			if left < 0 then left = 0 end
			local mm = math.floor(left / 60)
			local ss = left % 60
			mTimer.Text = string.format("%02d:%02d  |  Pago $%s", mm, ss,
				Config.Abbrev(currentMission.Reward or 0))
			mTimer.TextColor3 = left < 30 and Color3.fromRGB(255, 90, 90)
				or Color3.fromRGB(255, 190, 120)
		end
		task.wait(1)
	end
end)

----------------------------------------------------------------------
-- LLAMADA ENTRANTE (encargo: aceptas o rechazas)
----------------------------------------------------------------------
local RE_Call = Remotes:WaitForChild("IncomingCall") :: RemoteEvent

-- El celular entra deslizandose por la DERECHA, timbra y vibra.
local CALL_W, CALL_H = 290, 330
-- En COMPU: orilla derecha, arriba de la barra de botones.
-- En CELULAR: orilla IZQUIERDA, porque la derecha ya la ocupan los
-- botones de accion. Entra deslizandose desde ese mismo lado.
local CALL_SHOWN, CALL_HIDDEN
if IS_MOBILE then
	CALL_SHOWN  = UDim2.new(0, 14, 0.5, -(CALL_H / 2) - 20)
	CALL_HIDDEN = UDim2.new(0, -(CALL_W + 30), 0.5, -(CALL_H / 2) - 20)
else
	CALL_SHOWN  = UDim2.new(1, -(CALL_W + 16), 1, -(CALL_H + 96))
	CALL_HIDDEN = UDim2.new(1, 18, 1, -(CALL_H + 96))
end

local callGui = frame(gui, {
	Size = UDim2.new(0, CALL_W, 0, CALL_H),
	Position = CALL_HIDDEN,
	BackgroundColor3 = Color3.fromRGB(10, 10, 16),
	Visible = false,
	ZIndex = 50,
})
corner(callGui, 20)
stroke(callGui, Color3.fromRGB(70, 180, 110), 2)

-- sombra suave detras, para que no se vea pegado en el aire
local callShadow = frame(gui, {
	Size = UDim2.new(0, CALL_W + 12, 0, CALL_H + 12),
	Position = CALL_HIDDEN,
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.55,
	Visible = false,
	ZIndex = 49,
})
corner(callShadow, 24)

-- ===== SONIDO DE TIMBRE =====
-- Usamos un sonido que ya trae Roblox, asi no tienes que subir nada.
local ringSound = Instance.new("Sound")
ringSound.Name = "Ringtone"
ringSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
ringSound.Volume = 0.55
ringSound.Parent = callGui

local vibeSound = Instance.new("Sound")
vibeSound.Name = "Vibrate"
vibeSound.SoundId = "rbxasset://sounds/switch.wav"
vibeSound.Volume = 0.25
vibeSound.Parent = callGui

-- barra superior tipo telefono
local callTop = frame(callGui, {
	Size = UDim2.new(1, 0, 0, 108),
	BackgroundColor3 = Color3.fromRGB(18, 22, 30),
	ZIndex = 51,
})
corner(callTop, 22)

local callStatus = label(callTop, {
	Size = UDim2.new(1, -20, 0, 16),
	Position = UDim2.new(0, 10, 0, 12),
	TextSize = 11,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(150, 220, 170),
	Text = "LLAMADA ENTRANTE",
	ZIndex = 52,
})

local callName = label(callTop, {
	Size = UDim2.new(1, -20, 0, 30),
	Position = UDim2.new(0, 10, 0, 32),
	TextSize = 23,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Text = "DESCONOCIDO",
	ZIndex = 52,
})

local callNum = label(callTop, {
	Size = UDim2.new(1, -20, 0, 16),
	Position = UDim2.new(0, 10, 0, 66),
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(130, 140, 155),
	Text = "numero oculto",
	ZIndex = 52,
})

local callLine = label(callGui, {
	Size = UDim2.new(1, -28, 0, 80),
	Position = UDim2.new(0, 14, 0, 118),
	TextSize = 13,
	Font = Enum.Font.GothamMedium,
	TextColor3 = Color3.fromRGB(226, 226, 236),
	Text = "",
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 51,
})

local callDeal = label(callGui, {
	Size = UDim2.new(1, -28, 0, 58),
	Position = UDim2.new(0, 14, 0, 200),
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(250, 205, 100),
	Text = "",
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 51,
})

local callTimer = label(callGui, {
	Size = UDim2.new(1, -28, 0, 14),
	Position = UDim2.new(0, 14, 0, 258),
	TextSize = 11,
	Font = Enum.Font.Gotham,
	TextColor3 = Color3.fromRGB(150, 150, 165),
	Text = "",
	ZIndex = 51,
})

local function callBtn(text: string, color: Color3, xOff: number)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 128, 0, IS_MOBILE and 54 or 46)
	b.Position = UDim2.new(0, xOff, 1, -60)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Text = text
	b.AutoButtonColor = true
	b.ZIndex = 52
	b.Parent = callGui
	corner(b, 23)
	return b
end

local acceptBtn = callBtn("CONTESTAR", Color3.fromRGB(45, 170, 85), 14)
local rejectBtn = callBtn("COLGAR", Color3.fromRGB(190, 55, 55), 158)

local activeCall = nil
local ringTask = nil

local function closeCall(instant: boolean?)
	activeCall = nil
	pcall(function() ringSound:Stop() end)
	if instant then
		callGui.Visible = false
		callShadow.Visible = false
		callGui.Position = CALL_HIDDEN
		return
	end
	-- se desliza de regreso hacia afuera
	local ti = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local out = TweenService:Create(callGui, ti, {Position = CALL_HIDDEN})
	TweenService:Create(callShadow, ti, {Position = CALL_HIDDEN}):Play()
	out:Play()
	out.Completed:Connect(function()
		if not activeCall then
			callGui.Visible = false
			callShadow.Visible = false
		end
	end)
end

RE_Call.OnClientEvent:Connect(function(c)
	if not c then
		closeCall()
		return
	end
	activeCall = c
	activeCall.Until = os.clock() + (c.Seconds or 20)

	callName.Text = c.Caller or "DESCONOCIDO"
	callLine.Text = '"' .. (c.Line or "") .. '"'
	callDeal.Text = string.format(
		"%s\n%d %s para %s\nPaga: $%s",
		c.Title or "", c.Amount or 0,
		(c.Item == "Blocks") and "bloques" or "hojas",
		c.BuyerName or "?", Config.Abbrev(c.Reward or 0))

	-- ENTRADA: se desliza suave desde la derecha
	callGui.Position = CALL_HIDDEN
	callShadow.Position = CALL_HIDDEN
	callGui.Visible = true
	callShadow.Visible = true
	local ti = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(callGui, ti, {Position = CALL_SHOWN}):Play()
	TweenService:Create(callShadow, ti,
		{Position = CALL_SHOWN - UDim2.new(0, 6, 0, 6)}):Play()

	-- TIMBRE + VIBRACION mientras nadie contesta
	local myCall = activeCall
	task.spawn(function()
		task.wait(0.45)
		while activeCall == myCall and callGui.Visible do
			pcall(function() ringSound:Play() end)
			pcall(function() vibeSound:Play() end)

			-- sacudida corta, como vibrador
			for k = 1, 6 do
				if activeCall ~= myCall then break end
				local dx = (k % 2 == 0) and 4 or -4
				local dy = (k % 3 == 0) and 2 or -1
				callGui.Position = CALL_SHOWN + UDim2.new(0, dx, 0, dy)
				callShadow.Position = CALL_SHOWN + UDim2.new(0, dx - 6, 0, dy - 6)
				task.wait(0.045)
			end
			if activeCall == myCall then
				callGui.Position = CALL_SHOWN
				callShadow.Position = CALL_SHOWN - UDim2.new(0, 6, 0, 6)
			end
			task.wait(1.15)
		end
	end)
end)

acceptBtn.MouseButton1Click:Connect(function()
	closeCall()
	act("answerCall", true)
end)

rejectBtn.MouseButton1Click:Connect(function()
	closeCall()
	act("answerCall", false)
end)

-- cuenta regresiva de la llamada
task.spawn(function()
	while true do
		task.wait(0.5)
		if activeCall and activeCall.Until then
			local left = math.max(0, math.floor(activeCall.Until - os.clock()))
			callTimer.Text = string.format("Cuelga solo en %ds", left)
			if left <= 0 then closeCall() end
		end
	end
end)

----------------------------------------------------------------------
-- DIALOGO CON NPCs COMPRADORES
----------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")

local dialog = frame(gui, {
	Size = UDim2.new(0, 520, 0, 92),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = IS_MOBILE and UDim2.new(0.5, 0, 1, -110) or UDim2.new(0.5, 0, 1, -98),
	BackgroundColor3 = Color3.fromRGB(12, 12, 16),
	BackgroundTransparency = 0.08,
	Visible = false,
})
corner(dialog, 12)
stroke(dialog, Color3.fromRGB(240, 200, 120), 1.5)

local dlgName = label(dialog, {
	Size = UDim2.new(1, -24, 0, 20),
	Position = UDim2.new(0, 14, 0, 8),
	TextSize = 15,
	TextColor3 = Color3.fromRGB(255, 205, 120),
	Text = "",
})

local dlgText = label(dialog, {
	Size = UDim2.new(1, -24, 0, 26),
	Position = UDim2.new(0, 14, 0, 30),
	TextSize = 17,
	TextColor3 = Color3.fromRGB(238, 238, 246),
	Font = Enum.Font.Gotham,
	Text = "",
	TextWrapped = true,
})

local dlgHint = label(dialog, {
	Size = UDim2.new(1, -24, 0, 18),
	Position = UDim2.new(0, 14, 1, -26),
	TextSize = 13,
	TextColor3 = Color3.fromRGB(150, 220, 160),
	Text = "",
})

-- efecto maquina de escribir
local typeToken = 0
local function typeOut(txt: string)
	typeToken += 1
	local myToken = typeToken
	dlgText.Text = ""
	for i = 1, #txt do
		if typeToken ~= myToken then return end
		dlgText.Text = string.sub(txt, 1, i)
		task.wait(0.018)
	end
end

local function pick(list)
	return list[math.random(1, #list)]
end

local currentNPC = nil
local lastLine = ""

local function showDialog(npcName: string, line: string, hint: string)
	dialog.Visible = true
	dlgName.Text = npcName
	dlgHint.Text = hint
	if line ~= lastLine then
		lastLine = line
		task.spawn(typeOut, line)
	end
end

local function hideDialog()
	dialog.Visible = false
	currentNPC = nil
	lastLine = ""
end

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then hideDialog() return end

	-- vigilante de tu bodega
	for _, npc in ipairs(CollectionService:GetTagged("LookoutNPC")) do
		local prim = npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
		if prim and (prim.Position - hrp.Position).Magnitude < Config.Dialogue.Radius then
			if npc ~= currentNPC then
				currentNPC = npc
				showDialog("El Vigilante", pick(Config.Dialogue.Lookout), "")
			end
			return
		end
	end

	-- NPC mas cercano
	local best, bestD = nil, Config.Dialogue.Radius
	for _, npc in ipairs(CollectionService:GetTagged("BuyerNPC")) do
		local prim = npc.PrimaryPart or npc:FindFirstChildWhichIsA("BasePart")
		if prim then
			local d = (prim.Position - hrp.Position).Magnitude
			if d < bestD then best, bestD = npc, d end
		end
	end

	if not best then hideDialog() return end

	local npcName = best:GetAttribute("BuyerName") or "Comprador"
	local hasGoods = (State.Leaves or 0) > 0 or (State.Blocks or 0) > 0
	local isHot = State.Wanted

	if best ~= currentNPC then
		currentNPC = best
		local line
		if isHot then
			line = pick(Config.Dialogue.Hot)
		elseif hasGoods then
			line = pick(Config.Dialogue.Greet)
		else
			line = pick(Config.Dialogue.Empty)
		end
		showDialog(npcName, line, hasGoods and not isHot and "Presiona F para vender" or "")
	else
		dlgHint.Text = (hasGoods and not isHot) and "Presiona F para vender" or ""
	end
end)

-- respuesta del NPC despues de vender
RE_Toast.OnClientEvent:Connect(function(text: string, kind: string)
	if kind == "good" and string.find(text, "Vendiste") and currentNPC then
		lastLine = ""
		showDialog(currentNPC:GetAttribute("BuyerName") or "Comprador",
			pick(Config.Dialogue.Sold), "")
	end
end)

-- pide el estado al servidor hasta que llegue (arregla el $0 en Studio)
task.spawn(function()
	for i = 1, 30 do
		pcall(function() RF_Action:InvokeServer("sync") end)
		task.wait(0.4)
		if State and State.Cash and State.Cash > 0 then
			loadingLbl.Text = "Listo"
			playBtn.Visible = true
			break
		end
	end
	-- por si acaso, siempre deja entrar
	loadingLbl.Text = ""
	playBtn.Visible = true
end)

-- la portada SOLO se cierra con el boton (antes se cerraba sola a los 12s)

print("[SpiceEmpire] UI cargada.")

----------------------------------------------------------------------
-- EFECTOS DE SONIDO
----------------------------------------------------------------------
-- El servidor manda el nombre del efecto y aqui lo tocamos. Los IDs,
-- el volumen y el tono se configuran en GameConfig.Sounds.
do
	local SND = Config.Sounds
	if SND and SND.Enabled then
		local bank = Instance.new("Folder")
		bank.Name = "SfxBank"
		bank.Parent = gui

		-- se crean una sola vez y se reusan, en vez de crear y destruir
		local cache = {}
		for key, def in pairs(SND) do
			if type(def) == "table" and def.Id then
				local snd = Instance.new("Sound")
				snd.Name = key
				snd.SoundId = def.Id
				snd.Volume = def.Volume or 0.5
				snd.PlaybackSpeed = def.Pitch or 1
				snd.Parent = bank
				cache[key] = snd
			end
		end

		RE_Sfx.OnClientEvent:Connect(function(key: string)
			local snd = cache[key]
			if snd then
				-- un pelin de variacion para que no suene robotico
				local base = (SND[key] and SND[key].Pitch) or 1
				snd.PlaybackSpeed = base * (0.96 + math.random() * 0.08)
				snd:Play()
			end
		end)
	end
end
