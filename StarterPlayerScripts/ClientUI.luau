--!strict
-- ===== RONDA: v46 =====   <-- Ctrl+F con este texto para saber si este script
--                             es el de la ronda nueva (docs/09-SI-SALE-DOBLE.md)
-- LocalScript -> StarterPlayer.StarterPlayerScripts.ClientUI
-- HUD, telefono con alertas, tiendas y controles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- interfaces propias (el cartel y el avisito): el barrido de arriba nunca las toca
local MIS_GUIS: {[any]: boolean} = {}

-- ===== QUE RONDA ES ESTE ARCHIVO =====
-- Declarado ARRIBA de todo a proposito: lo usan funciones de mas abajo y, si se
-- declara despues, en Lua se lee un global nil (comparacion siempre falsa, sin
-- tronar). Ya paso una vez y lo cazaron tools/globals.py y tools/copias.py.
local MI_VERSION = "v46"
local RONDA_NUM = tonumber(string.match(MI_VERSION, "%d+") or "0") or 0
-- en que ronda aparecio cada remote (para poder decir QUE archivo pegar)
local DESDE = {
	OpenVault = "v18", Shoot = "v21", TerritoryUpdate = "v24",
	IncomingCall = "v28",   -- en la v28 se crea al arranque del servidor
}

----------------------------------------------------------------------
-- ¿HAY OTRA ClientUI CORRIENDO?  (dos copias pegadas)
----------------------------------------------------------------------
-- CASO REAL (v35): el usuario pego la ronda nueva, pero le quedo una ClientUI
-- VIEJA corriendo en otra parte del lugar (o una copia 'ClientUI2'). Dos HUD,
-- dos carteles... y el cartel que veia era el de la copia VIEJA, que decia
-- "esta ronda es v32" mientras su servidor ya era v34. Desde la pantalla es
-- imposible de entender: parecia que el juego estaba roto y no lo estaba.
--
-- Como se evita: cada copia deja un LATIDO con su version en el PlayerGui. Al
-- arrancar, si el latido ajeno es FRESCO y de una version igual o mas nueva,
-- esta copia se apaga sola (y lo dice en la consola). La que gana se queda.
do
	local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 10)
	if pg then
		local LATIDO, QUIEN = "SpiceEmpireLatido", "SpiceEmpireRonda"
		local tAjeno, quienAjeno = pg:GetAttribute(LATIDO), pg:GetAttribute(QUIEN)
		local ahora = os.clock()
		local fresco = (type(tAjeno) == "number") and ((ahora - tAjeno) < 2)
		local numAjeno = tonumber(string.match(tostring(quienAjeno or ""), "%d+") or "0") or 0
		if fresco and numAjeno >= RONDA_NUM then
			warn("[SpiceEmpire] *** HAY OTRA ClientUI CORRIENDO (" .. tostring(quienAjeno) ..
				") *** esta copia (" .. MI_VERSION .. ") se apaga sola para que no salga todo doble.")
			warn("[SpiceEmpire] En el Explorer tiene que quedar UNA sola ClientUI, dentro de" ..
				" StarterPlayer > StarterPlayerScripts. Borra las demas (clic derecho > Delete)." ..
				" El servidor imprime la lista con rutas: busca 'INVENTARIO DE ARCHIVOS'.")
			return
		end
		pg:SetAttribute(LATIDO, ahora)
		pg:SetAttribute(QUIEN, MI_VERSION)
		task.spawn(function()
			while true do
				task.wait(0.5)
				if not pg.Parent then return end
				pg:SetAttribute(LATIDO, os.clock())
			end
		end)
		if fresco then
			warn("[SpiceEmpire] hay otra ClientUI corriendo (" .. tostring(quienAjeno) ..
				") pero es MAS VIEJA que esta (" .. MI_VERSION .. "): se apaga sola la vieja.")
		end
	end
end

----------------------------------------------------------------------
-- RECEPCION DE SCRIPTS Y REMOTES  (con TIMEOUT)
----------------------------------------------------------------------
-- Antes esto era WaitForChild a secas. Si faltaba UNA cosa (un script que
-- no pegaste, o el servidor que trono antes de crear los remotes), el
-- cliente se quedaba esperando PARA SIEMPRE: sin error, sin nada en
-- pantalla, y todo lo que venia despues (el detector de cercania, los
-- botones, los paneles) nunca se ejecutaba. Ese era el "no me deja hacer
-- nada". Ahora espera 10 segundos, AVISA, y sigue.
local AVISOS: {string} = {}

-- cartel rojo de emergencia. Se dibuja a mano porque los helpers de UI
-- todavia no existen en este punto del archivo.
local function cartelDeError(lineas: {string})
	local sg = Instance.new("ScreenGui")
	MIS_GUIS[sg] = true
	sg.Name = "SpiceEmpire_Error"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 999
	sg.Parent = player:WaitForChild("PlayerGui")
	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, 30 + 22 * #lineas)
	box.BackgroundColor3 = Color3.fromRGB(120, 22, 22)
	box.BorderSizePixel = 0
	box.Parent = sg
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -20, 1, -8)
	t.Position = UDim2.new(0, 10, 0, 4)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.TextColor3 = Color3.fromRGB(255, 235, 235)
	t.Text = table.concat(lineas, "\n")
	t.Parent = box
end

local function need(parent: Instance, name: string): any
	local found = parent:WaitForChild(name, 10)
	if found then return found end
	table.insert(AVISOS, parent.Name .. "." .. name)
	warn("[SpiceEmpire] FALTA " .. parent.Name .. "." .. name .. " (revisa docs/01-INSTALACION.md)")
	-- sustituto inerte: asi nada mas truena en cadena y la UI carga igual
	return {
		Name = name,
		OnClientEvent = {Connect = function() return {Disconnect = function() end} end},
		OnServerEvent  = {Connect = function() return {Disconnect = function() end} end},
		Connect = function() return {Disconnect = function() end} end,
		InvokeServer = function() return {ok = false, msg = "Falta un script en el servidor"} end,
		FireServer = function() end,
	}
end

-- 1) GameConfig: sin el no hay juego, asi que aqui si nos detenemos
--    (con un cartel que dice QUE falta, en vez de una pantalla muerta).
local cfgModule = ReplicatedStorage:WaitForChild("GameConfig", 10)
if not cfgModule then
	warn("[SpiceEmpire] FALTA ReplicatedStorage.GameConfig")
	if player:WaitForChild("PlayerGui", 10) then
		cartelDeError({
			"FALTA UN SCRIPT:  ReplicatedStorage > GameConfig",
			"Pega GameConfig.luau como ModuleScript en ReplicatedStorage y vuelve a probar.",
			"(Guia paso a paso: docs/01-INSTALACION.md)",
		})
	end
	return
end
local Config = require(cfgModule)

-- 2) REMOTES (con cambio de carpeta EN CALIENTE)
-- ======================================================================
-- LECCION DE LA v34 (caso real del usuario):
--   El cliente arranca ANTES de que el servidor termine de limpiar. Si en
--   ReplicatedStorage hay una carpeta 'Remotes' VIEJA guardada en el lugar, el
--   cliente se enganchaba a ESA (era la unica que veia), el servidor la borraba
--   un instante despues, y el jugador quedaba con remotes MUERTOS: botones que
--   no hacian nada, sin un solo error en consola. Dificilisimo de diagnosticar.
--
-- ARREGLO: el cliente NO guarda el objeto del remote, guarda un INTERMEDIARIO.
--   - Al arrancar: se engancha a lo que haya (para no tardar ni un segundo).
--   - A los 1.5 s y a los 4.5 s: vuelve a mirar. En cuanto aparece la carpeta
--     del servidor (la que trae el sello 'Build'), el intermediario se muda a
--     esa y RECONECTA solo las señales: los paneles siguen funcionando.
--   - Los que envian (FireServer/InvokeServer) se resuelven en el momento de
--     llamar, asi que tambien van a la carpeta correcta.
local NOMBRES_REMOTE = {
	"StateUpdate", "PhoneAlert", "Toast", "MissionUpdate", "IncomingCall",
	"OpenUpgrades", "OpenVault", "Sfx", "Shoot", "TerritoryUpdate", "Action",
}
local PA: {[string]: any} = {}          -- nombre -> intermediario

local function crearProxy(nombre: string): any
	local real: any = nil
	local conexiones: {{fn: any, conn: any}} = {}
	local proxy: any = {}

	local function conectarTodo()
		for _, c in ipairs(conexiones) do
			c.conn = nil
			if real and real.Parent then
				local sig = real.OnClientEvent or real.OnServerEvent
				if sig then
					local ok, conn = pcall(function() return sig:Connect(c.fn) end)
					if ok then c.conn = conn end
				end
			end
		end
	end

	-- mueve el intermediario a otra carpeta (esta es la parte que arregla el bug)
	function proxy.apuntar(nuevo: any)
		if real == nuevo then return false end
		for _, c in ipairs(conexiones) do
			if c.conn then pcall(function() c.conn:Disconnect() end) end
			c.conn = nil
		end
		real = nuevo
		conectarTodo()
		return true
	end

	return setmetatable(proxy, {
		__index = function(_, k)
			if k == "OnClientEvent" or k == "OnServerEvent" then
				return {
					Connect = function(_, fn)
						local reg = { fn = fn, conn = nil }
						table.insert(conexiones, reg)
						if real and real.Parent then
							local sig = real[k]
							if sig then
								local ok, conn = pcall(function() return sig:Connect(fn) end)
								if ok then reg.conn = conn end
							end
						end
						return {
							Disconnect = function()
								if reg.conn then pcall(function() reg.conn:Disconnect() end) end
								reg.conn = nil
							end,
						}
					end,
				}
			end
			-- FireServer / InvokeServer: se resuelven AL MOMENTO de llamar, asi
			-- que siempre van a la carpeta que este en uso (y si el remote ya no
			-- existe, no truena: se regresa el mismo "no hay" de siempre)
			return function(_, ...)
				-- OJO: '...' NO se puede usar dentro de la clausura de pcall
				-- (truena al compilar). Se copia a una tabla y se desempaqueta.
				local args = { ... }
				local cuantos = select("#", ...)
				local ok, res = pcall(function()
					if real and real.Parent then
						local fn = real[k]
						if type(fn) == "function" then
							return fn(real, table.unpack(args, 1, cuantos))
						end
					end
					return nil
				end)
				if not ok then res = nil end
				if res == nil and k == "InvokeServer" then
					return { ok = false, msg = "el servidor todavia no tiene ese remote" }
				end
				return res
			end
		end,
	})
end

for _, n in ipairs(NOMBRES_REMOTE) do PA[n] = crearProxy(n) end

local PROBLEMAS: {string} = {}
local copiasLeves = false              -- hay carpetas Remotes de mas, pero la buena sirve
local carpetaUsada: any = nil          -- la carpeta a la que apuntan los intermediarios

local function carpetasRemotes(): {any}
	local lista = {}
	for _, c in ipairs(ReplicatedStorage:GetChildren()) do
		-- por PREFIJO: Roblox renombra solos los repetidos a "Remotes2"
		if string.sub(c.Name, 1, 7) == "Remotes" then table.insert(lista, c) end
	end
	return lista
end

-- cual es la buena: la que el servidor marco con el sello "Build" (esa la acaba
-- de crear ESTE arranque). Las que no lo traen son carpetas viejas del lugar.
local function puntajeDe(c: any): number
	if c:GetAttribute("Build") ~= nil then return 3 end
	if c.Name == "Remotes" then return 2 end
	return 1
end

local function eligeCarpeta(todas: {any}): any
	if #todas == 0 then return nil end
	local copia = {}
	for i, c in ipairs(todas) do copia[i] = c end
	table.sort(copia, function(a, b)
		local pa, pb = puntajeDe(a), puntajeDe(b)
		if pa ~= pb then return pa > pb end
		return #a:GetChildren() > #b:GetChildren()
	end)
	return copia[1]
end

-- (re)apunta los intermediarios a esta carpeta y devuelve los que faltan
local function apuntarRemotes(carpeta: any): {string}
	local faltan: {string} = {}
	for _, n in ipairs(NOMBRES_REMOTE) do
		local obj = nil
		if carpeta then
			local ok, f = pcall(function() return carpeta:FindFirstChild(n) end)
			obj = ok and f or nil
		end
		PA[n].apuntar(obj)
		if not obj then table.insert(faltan, n) end
	end
	carpetaUsada = carpeta
	return faltan
end

local function elegirYApuntar(): {string}
	return apuntarRemotes(eligeCarpeta(carpetasRemotes()))
end
-- El cliente se engancha YA a lo que haya (no espera al servidor). Si todavia
-- esta agarrando una carpeta vieja, a los 1.5 s se muda solo a la buena: ver
-- veredicto(), mas abajo.
elegirYApuntar()

local RE_State = PA.StateUpdate
local RE_Phone = PA.PhoneAlert
local RE_Toast = PA.Toast
local RE_Mission = PA.MissionUpdate
local RE_OpenUp  = PA.OpenUpgrades
local RE_Sfx     = PA.Sfx
local RE_OpenVault = PA.OpenVault
local RE_Shoot   = PA.Shoot
local RE_Terr    = PA.TerritoryUpdate
local RF_Action  = PA.Action

-- ===== ¿LOS ARCHIVOS QUE PEGASTE SON DE ESTA RONDA? =====
-- Esto nace de un caso real: el cliente ya era de la ronda nueva pero el
-- Main.luau del servidor seguia siendo de 8 rondas atras. El unico sintoma
-- era "faltan 2 remotes", sin decir cual de los 5 archivos pegar ni por que.
-- Ahora el servidor estampa su version en la carpeta Remotes, GameConfig trae
-- la suya, y aqui se comparan las tres cosas.
local lineas: {string} = {}
local viejo = false
local yaAviso = false

-- avisito azul chiquito (abajo de la pantalla, 14 s): para cuando hay carpetas
-- de mas pero el juego SI funciona. Antes esto era un cartel rojo gigante.
local function avisoChiquito(texto: string)
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return end
	local sg = Instance.new("ScreenGui")
	MIS_GUIS[sg] = true
	sg.Name = "SpiceEmpire_Avisito"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 90            -- por debajo del cartel rojo (999)
	sg.Parent = pg
	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, -24, 0, 46)
	box.Position = UDim2.new(0, 12, 1, -58)
	box.BackgroundColor3 = Color3.fromRGB(28, 60, 96)
	box.BackgroundTransparency = 0.15
	box.BorderSizePixel = 0
	box.Parent = sg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = box
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -16, 1, -8)
	t.Position = UDim2.new(0, 8, 0, 4)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.Gotham
	t.TextSize = 13
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.TextColor3 = Color3.fromRGB(225, 240, 255)
	t.Text = texto
	t.Parent = box
	task.delay(14, function()
		if box and box.Parent then box:Destroy() end
	end)
end

-- cartel rojo del final (se dibuja con cartelDeError, que esta mas arriba)
local function dibujarCartel()
	local hayCopias = #PROBLEMAS > 0
	local titulo
	if hayCopias and not viejo and #lineas > 0 and #PROBLEMAS == #lineas then
		titulo = "HAY CARPETAS 'Remotes' DE MAS EN STUDIO"
	elseif viejo then
		titulo = "ARCHIVOS VIEJOS EN STUDIO  --  esta ronda es " .. MI_VERSION
	elseif hayCopias then
		titulo = "HAY CARPETAS 'Remotes' DE MAS EN STUDIO"
	else
		titulo = "FALTAN REMOTES EN EL SERVIDOR"
	end
	local box = { titulo }
	for _, l in ipairs(lineas) do table.insert(box, l) end
	if hayCopias then
		table.insert(box, "Arreglo facil (2 min): en Studio abre la pestana View (arriba),")
		table.insert(box, "boton Command Bar, pega el LIMPIADOR de la ronda " .. MI_VERSION)
		table.insert(box, "y Enter: el borra las copias solo y dice que archivo volver a pegar.")
		table.insert(box, "A mano: en el Explorer, clic derecho en la carpeta > Delete.")
		table.insert(box, "Tiene que quedar UNA sola carpeta Remotes (o ninguna: el juego la")
		table.insert(box, "crea sola al dar Play). Guia: docs/09-SI-SALE-DOBLE.md")
	else
		table.insert(box, "Pega los 5 archivos de la ronda COMPLETOS (Ctrl+A y Ctrl+V) y vuelve a dar Play.")
		table.insert(box, "Si ya los pegaste: revisa que no haya archivos REPETIDOS (docs/09-SI-SALE-DOBLE.md)")
	end
	pcall(cartelDeError, box)
end

-- ===== VEREDICTO =====
-- Se corre a los 1.5 s y a los 4.5 s (nunca al instante: el cliente arranca
-- ANTES de que el servidor termine de limpiar, y juzgar tan temprano era justo
-- el bug: avisaba "hay 2 Main pegados" nada mas porque todavia no se borraba la
-- carpeta vieja del lugar).
local function veredicto(momento: string)
	local definitivo = (momento == "final")
	local todas = carpetasRemotes()
	local carpeta = eligeCarpeta(todas)
	local antes = carpetaUsada
	local faltanAqui = apuntarRemotes(carpeta)
	local servidor = carpeta and carpeta:GetAttribute("Build") or nil
	local esDelServidor = (servidor ~= nil)

	if carpeta ~= antes and carpeta then
		print("[SpiceEmpire] remotes enganchados a la carpeta '" .. carpeta.Name .. "'" ..
			(esDelServidor and (" (sello " .. tostring(servidor) .. ")") or " (SIN sello del servidor)"))
	end

	-- ¿todavia no aparece la carpeta del servidor? No se juzga hasta el final.
	if not esDelServidor and not definitivo then return end

	-- armar el diagnostico
	lineas = {}
	viejo = false
	if not esDelServidor then
		viejo = true
		local dice = servidor and ("'" .. tostring(servidor) .. "'")
			or "NADA (no hay sello: el Main del servidor es viejo)"
		table.insert(lineas, " - el Main.luau del servidor dice " .. dice ..
			"; esta ronda es " .. MI_VERSION)
	elseif servidor ~= MI_VERSION then
		viejo = true
		local numServidor = tonumber(string.match(tostring(servidor), "%d+") or "0") or 0
		if numServidor > RONDA_NUM then
			-- ESTE es el caso del usuario: el servidor esta al dia y el que se
			-- queda atras es ESTA ClientUI (hay una copia vieja corriendo).
			table.insert(lineas, "*** ESTA ClientUI ES LA VIEJA: el servidor ya es " ..
				tostring(servidor) .. " y esta copia dice " .. MI_VERSION .. " ***")
			table.insert(lineas, "Hay MAS DE UNA ClientUI pegada. Deja UNA sola, en")
			table.insert(lineas, "StarterPlayer > StarterPlayerScripts, y borra las demas.")
		else
			table.insert(lineas, " - el Main.luau del servidor dice '" .. tostring(servidor) ..
				"'; esta ronda es " .. MI_VERSION)
		end
	end
	if Config.Build ~= MI_VERSION then
		viejo = true
		table.insert(lineas, " - GameConfig dice '" .. tostring(Config.Build) ..
			"'; esta ronda es " .. MI_VERSION)
	end

	local faltan = faltanAqui
	if #faltan > 0 then
		local bonito = {}
		for i, n in ipairs(faltan) do
			if i <= 4 then
				local d = DESDE[n]
				table.insert(bonito, n .. (d and ("  (existe desde " .. d .. ")") or ""))
			end
		end
		table.insert(lineas, " - el servidor no tiene estos remotes: " .. table.concat(bonito, " , "))
	end

	-- carpetas de mas
	PROBLEMAS = {}
	copiasLeves = false
	if #todas > 1 then
		local detalles = {}
		for _, c in ipairs(todas) do
			local et = c:GetAttribute("Build")
			table.insert(detalles, "'" .. c.Name .. "' (" ..
				(et and ("sello " .. tostring(et)) or "SIN sello = vieja") .. ", " ..
				#c:GetChildren() .. " remotes)")
		end
		table.insert(PROBLEMAS, #todas .. " carpetas Remotes en ReplicatedStorage: " ..
			table.concat(detalles, " + "))
		table.insert(PROBLEMAS, "el juego esta usando '" .. tostring(carpeta and carpeta.Name or "?") ..
			"'; se puede borrar la que NO tiene sello del servidor")
		if esDelServidor and #faltan == 0 then copiasLeves = true end
	end
	for _, p in ipairs(PROBLEMAS) do table.insert(lineas, " - " .. p) end

	local hayQueArreglar = viejo or #faltan > 0 or (#PROBLEMAS > 0 and not copiasLeves)

	if hayQueArreglar and not yaAviso then
		yaAviso = true
		pcall(dibujarCartel)
	elseif copiasLeves and definitivo and not yaAviso then
		-- Hay carpetas de mas pero TODO funciona: avisito, no cartel rojo.
		-- v40: mensaje corto y con el ARREGLO exacto (antes era un rollo largo que
		-- no decia que hacer). Ademas el aviso se QUITA SOLO si el problema se
		-- resuelve (el servidor borra la carpeta vieja al instante): el usuario veia
		-- el aviso aunque ya estuviera todo bien, y parecia que seguia roto.
		yaAviso = true
		pcall(avisoChiquito, "Puedes jugar normal: el servidor ya borro la carpeta 'Remotes'" ..
			" vieja (la creo una version ANTERIOR del juego que sigue corriendo). Para que no" ..
			" vuelva: deja UN solo 'Main' en ServerScriptService (el que diga RONDA: " ..
			MI_VERSION .. ") y corre el LIMPIADOR de la pestana 0. Ruta exacta de lo que" ..
			" sobra: mira el Output.")
		task.delay(4, function()
			if #carpetasRemotes() <= 1 then
				local pg = player:FindFirstChild("PlayerGui")
				local a = pg and pg:FindFirstChild("SpiceEmpire_Avisito")
				if a then
					pcall(function() a:Destroy() end)
					print("[SpiceEmpire] el aviso de carpetas de mas se quito solo: ya hay 1 Remotes.")
				end
			end
		end)
	elseif definitivo and #PROBLEMAS > 0 then
		warn("[SpiceEmpire] siguen habiendo " .. #PROBLEMAS .. " carpetas Remotes de mas, pero" ..
			" el juego esta funcionando con la buena. Borra las que no tienen sello (docs/09)")
	end
end

veredicto("1.5s")
task.delay(1.5, function() veredicto("1.5s") end)
task.delay(4.5, function() veredicto("final") end)

local State: any = {Cash = 0, Leaves = 0, Blocks = 0, Heat = 0, Plots = 0, PressLevel = 1,
	Employees = {Harvester=0,Presser=0,Guard=0}, Vehicles = {}, Properties = {}, Storage = 200}

-- se define mas abajo, junto al panel de la caja fuerte
local Territories: {any} = {}
local refreshVault: () -> () = function() end

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
-- ¿HAY UNA INTERFAZ DEL JUEGO YA PUESTA EN LA PANTALLA?
----------------------------------------------------------------------
-- >>> ESTE BLOQUE ERA LA CAUSA DEL "no cambio nada" (v37) <<<
-- Antes decia: si ya hay algo llamado "SpiceEmpireUI" en PlayerGui, es que hay
-- DOS ClientUI pegados -> esta copia se APAGABA (con cartel rojo y 'return').
--
-- El problema: esa interfaz puede ser BASURA GUARDADA en el lugar (una copia
-- vieja que quedo en StarterGui y Roblox mete en PlayerGui al arrancar). En ese
-- caso la copia nueva se apagaba TODAS las veces y el jugador se quedaba con la
-- interfaz vieja PARA SIEMPRE: "le pegue los archivos y no cambio nada".
--
-- Ahora: la copia que gana se decide por RONDA (con el latido de arriba, que
-- solo apaga a la MAS VIEJA). Si al llegar aqui todavia hay una interfaz, es
-- basura guardada del lugar: se BORRA y seguimos dibujando la nueva.
local playerGui = player:WaitForChild("PlayerGui", 10)
if playerGui then
	local basura = {}
	-- por nombre (copia del juego) o por CONTENIDO (el tablero viejo se reconoce
	-- por sus textos: "Hojas", "HEAT", "Espacio"), aunque se llame de otra forma
	local okD, todos = pcall(function() return playerGui:GetDescendants() end)
	for _, g in ipairs((okD and todos) or playerGui:GetChildren()) do
		local ok, cls = pcall(function() return g.ClassName end)
		if ok and cls == "ScreenGui" and g.Name ~= "SpiceEmpire_Error"
			and g.Name ~= "SpiceEmpire_Avisito" and g.Name ~= "AvisoRonda" then
			local porNombre = string.sub(g.Name or "", 1, 11) == "SpiceEmpire"
			local porTexto = false
			if not porNombre then
				local okk, desc = pcall(function() return g:GetDescendants() end)
				if okk and desc then
					for _, d in ipairs(desc) do
						local ok2, txt = pcall(function() return d.Text end)
						if ok2 and type(txt) == "string" and #txt > 0
							and (string.find(txt, "Hojas", 1, true)
								or string.find(txt, "HEAT", 1, true)
								or string.find(txt, "Espacio", 1, true)) then
							porTexto = true
							break
						end
					end
				end
			end
			if porNombre or porTexto then table.insert(basura, g) end
		end
	end
	if #basura > 0 then
		for _, g in ipairs(basura) do pcall(function() g:Destroy() end) end
		-- se guarda la cuenta en un ATRIBUTO (no en una variable nueva: este archivo
		-- anda en 183 de 200 locales permitidos) para que la placa testigo lo diga
		pcall(function() player:SetAttribute("TablerosBorrados", #basura) end)
		warn("[SpiceEmpire] encontre " .. #basura .. " interfaz(es) VIEJAS guardadas en el" ..
			" lugar (por eso seguia saliendo el tablero anterior) y las borre para dibujar la" ..
			" de esta ronda. Si el juego avisa otra vez: borra el 'ScreenGui' que sobra en" ..
			" StarterGui y la ClientUI que sobre en el Explorer (docs/09-SI-SALE-DOBLE.md).")
	end
end

----------------------------------------------------------------------
-- TESTIGO DE RONDA (v38): la prueba de que ESTE archivo es el que corre
----------------------------------------------------------------------
-- El usuario reporto: "estoy copiando todo tal cual y sigue igual". Desde una
-- captura no habia como saber si el codigo que dibuja es el nuevo o una copia
-- vieja. Ahora, apenas arranca, sale una PLACA verde arriba de la pantalla:
--
--    "RONDA v38  (arrancando...)"  -> el archivo SI esta corriendo
--    "RONDA v38  OK"               -> corrio TODO (interfaz completa)
--    ninguna placa                 -> esta ClientUI no es la que corre
--                                     (o no es LocalScript / esta Disabled)
--
-- y a los 14 segundos se encoge a un letrerito chiquito que se queda para
-- siempre (asi cualquier captura futura dice de que ronda es lo que se ve).
--
-- El ScreenGui se llama "AvisoRonda" a proposito (sin la palabra SpiceEmpire):
-- asi NINGUN barrido de copias viejas lo puede borrar.
do
	local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 10)
	if pg then
		local sg = Instance.new("ScreenGui")
		MIS_GUIS[sg] = true
		sg.Name = "AvisoRonda"
		sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.DisplayOrder = 120          -- arriba de la interfaz (50), debajo del cartel (999)
		sg.Parent = pg

		local placa = Instance.new("Frame")
		placa.Name = "Placa"
		placa.Size = UDim2.new(0, 430, 0, 106)
		placa.Position = UDim2.new(0.5, -215, 0, 44)
		placa.BackgroundColor3 = Color3.fromRGB(10, 16, 12)
		placa.BackgroundTransparency = 0.08
		placa.BorderSizePixel = 0
		placa.Parent = sg
		do
			local esquina = Instance.new("UICorner")
			esquina.CornerRadius = UDim.new(0, 12)
			esquina.Parent = placa
			local canto = Instance.new("UIStroke")
			canto.Color = Color3.fromRGB(120, 255, 150)
			canto.Thickness = 3
			canto.Parent = placa
			local titulo = Instance.new("TextLabel")
			titulo.Name = "Titulo"
			titulo.BackgroundTransparency = 1
			titulo.Size = UDim2.new(1, -20, 0, 54)
			titulo.Position = UDim2.new(0, 10, 0, 8)
			titulo.Font = Enum.Font.GothamBold
			titulo.TextScaled = true
			titulo.TextColor3 = Color3.fromRGB(140, 255, 160)
			titulo.TextStrokeTransparency = 0.35
			titulo.TextStrokeColor3 = Color3.new(0, 0, 0)
			titulo.Text = "RONDA " .. MI_VERSION .. "  (arrancando...)"
			titulo.Parent = placa
			local pie = Instance.new("TextLabel")
			pie.Name = "Pie"
			pie.BackgroundTransparency = 1
			pie.Size = UDim2.new(1, -20, 0, 32)
			pie.Position = UDim2.new(0, 10, 0, 68)
			pie.Font = Enum.Font.Gotham
			pie.TextScaled = true
			pie.TextColor3 = Color3.fromRGB(230, 235, 245)
			pie.TextStrokeTransparency = 0.5
			pie.TextStrokeColor3 = Color3.new(0, 0, 0)
			pie.Text = "si no dice " .. MI_VERSION .. ", lo que ves NO es de esta ronda"
			-- si la limpieza de arriba ya borro tableros viejos, se dice AQUI (en
			-- pantalla) y no solo en el Output
			local borrados = tonumber(player:GetAttribute("TablerosBorrados") or 0) or 0
			if borrados > 0 then
				pie.Text = "borre " .. borrados .. " tablero(s) viejo(s) que estaban pegados"
				pie.TextColor3 = Color3.fromRGB(255, 200, 120)
			end
			pie.Parent = placa
		end

		-- el letrerito chiquito que se queda para siempre (arriba al centro)
		local chico = Instance.new("TextLabel")
		chico.Name = "RondaChica"
		chico.BackgroundColor3 = Color3.fromRGB(10, 16, 12)
		chico.BackgroundTransparency = 0.35
		chico.Size = UDim2.new(0, 78, 0, 22)
		chico.Position = UDim2.new(0.5, -39, 0, 152)
		chico.Font = Enum.Font.GothamBold
		chico.TextSize = 14
		chico.TextColor3 = Color3.fromRGB(150, 255, 170)
		chico.Text = MI_VERSION
		chico.Visible = false
		chico.Parent = sg
		do
			local esquina2 = Instance.new("UICorner")
			esquina2.CornerRadius = UDim.new(0, 8)
			esquina2.Parent = chico
		end

		task.delay(14, function()
			pcall(function() placa.Visible = false end)
			pcall(function() chico.Visible = true end)
		end)
		print("[SpiceEmpire] TESTIGO: placa 'RONDA " .. MI_VERSION .. "' dibujada en la pantalla.")
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "SpiceEmpireUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
-- v38: dibuja POR ENCIMA de cualquier interfaz que haya quedado pegada en el
-- lugar (una viuda con DisplayOrder mas alto tapaba la nueva y parecia que
-- "no cambio nada"). El cartel rojo (999) sigue arriba de todo.
gui.DisplayOrder = 50
gui.Parent = playerGui or player:WaitForChild("PlayerGui")

----------------------------------------------------------------------
-- BARRIDO DE INTERFACES VIEJAS  (v36)
----------------------------------------------------------------------
-- CASO REAL: el usuario veia el "dashboard anterior" (la barra ancha vieja)
-- aunque su ClientUI ya era la nueva. Causa: quedaba OTRA copia de ClientUI
-- corriendo (vieja) y ESA dibujaba SU interfaz encima. Las dos se ven, y una
-- es de hace varias rondas.
--
-- Solucion: al arrancar, esta copia borra las interfaces del juego que NO son
-- suyas (las de las otras copias), asi se ve UNA sola. Se repite un par de
-- veces porque la copia vieja puede arrancar un instante despues.
-- OJO (v37): el barrido comparaba el nombre EXACTO ("SpiceEmpireUI") y por eso
-- NO borraba la copia vieja cuando Roblox la renombraba solo: "SpiceEmpireUI2".
-- Ahora se compara por PREFIJO: cualquier interfaz del juego menos las mias.
do
	local MIA = gui

	-- >>> v39: AHORA POR CONTENIDO, NO SOLO POR NOMBRE <<<
	-- El usuario reporto que seguia viendo el tablero VIEJO con la placa nueva en
	-- pantalla (o sea: la ClientUI nueva SI corria y el tablero viejo seguia ahi).
	-- La limpieza anterior solo reconocia nombres que empiezan con "SpiceEmpire":
	-- si la copia vieja se llamaba distinto (o la renombro el usuario), no la
	-- tocaba. Este tablero se reconoce por lo que DICE: "Hojas", "HEAT", "Espacio".
	local function tienePintaDeTablero(g: any): boolean
		local ok, desc = pcall(function() return g:GetDescendants() end)
		if not ok or not desc then return false end
		for _, d in ipairs(desc) do
			local ok2, txt = pcall(function() return d.Text end)
			if ok2 and type(txt) == "string" and #txt > 0 then
				if string.find(txt, "Hojas", 1, true)
					or string.find(txt, "HEAT", 1, true)
					or string.find(txt, "Espacio", 1, true) then
					return true
				end
			end
		end
		return false
	end

	local function esInterfazDelJuego(g: any): boolean
		if g == MIA or MIS_GUIS[g] then return false end
		local ok, cls = pcall(function() return g.ClassName end)
		if not ok or cls ~= "ScreenGui" then return false end
		local n = g.Name or ""
		-- por nombre (cualquier copia del juego) o por contenido (el tablero viejo,
		-- aunque se llame de cualquier manera)
		return string.sub(n, 1, 11) == "SpiceEmpire" or tienePintaDeTablero(g)
	end

	local function barrerInterfacesViejas(): number
		local pg = player:FindFirstChild("PlayerGui")
		if not pg then return 0 end
		local basura = {}
		-- GetDescendants y no GetChildren: la basura puede estar dentro de una
		-- carpeta dentro del PlayerGui
		local ok, todos = pcall(function() return pg:GetDescendants() end)
		if not ok or not todos then return 0 end
		for _, g in ipairs(todos) do
			if esInterfazDelJuego(g) then table.insert(basura, g) end
		end
		for _, g in ipairs(basura) do pcall(function() g:Destroy() end) end
		if #basura > 0 then
			print("[SpiceEmpire] limpie " .. #basura .. " interfaz(es) vieja(s) que estaban en la" ..
				" pantalla (tablero de otra copia del juego; la nueva ya se dibujo). Docs: docs/09.")
			-- y se avisa EN PANTALLA, en la placa: asi el usuario ve que SI se limpio
			pcall(function()
				local antes = tonumber(player:GetAttribute("TablerosBorrados") or 0) or 0
				player:SetAttribute("TablerosBorrados", antes + #basura)
				local aviso = pg:FindFirstChild("AvisoRonda")
				local placa = aviso and aviso:FindFirstChild("Placa")
				local pie = placa and placa:FindFirstChild("Pie")
				if pie then
					pie.Text = "borre " .. (antes + #basura) .. " tablero(s) viejo(s) que quedaron pegados"
					pie.TextColor3 = Color3.fromRGB(255, 200, 120)
				end
			end)
		end
		return #basura
	end

	-- se revisa al arrancar y varias veces mas; y ADEMAS, si en cualquier momento
	-- aparece una interfaz de otra copia, se borra al instante
	barrerInterfacesViejas()
	do
		local pg = player:FindFirstChild("PlayerGui")
		if pg then
			pg.ChildAdded:Connect(function()
				task.defer(function()
					if barrerInterfacesViejas() > 0 then
						warn("[SpiceEmpire] aparecio una interfaz de OTRA copia del juego y la" ..
							" borre. Borra la ClientUI que sobra en el Explorer (docs/09).")
					end
				end)
			end)
		end
	end
	for _, espera in ipairs({0.7, 1.5, 3, 6, 10}) do
		task.delay(espera, barrerInterfacesViejas)
	end
end

----------------------------------------------------------------------
-- ADAPTACION A CELULAR
----------------------------------------------------------------------
-- En celular Roblox pone SU joystick abajo-izquierda y el boton de
-- saltar abajo-derecha. Hay que dejar esas esquinas libres.
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- v42: se avisa al SERVIDOR si este jugador anda en celular. Lo usan las cosas
-- que en celular se comportan distinto: la bici (sin letrero de tecla E: te
-- acercas y te subes) y los botones de los vehiculos.
pcall(function() player:SetAttribute("Tactil", IS_MOBILE) end)

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

-- ======================================================================
-- CUANDO SE ABRE EL BOTON "ENTRAR AL BARRIO"
-- ======================================================================
-- VIVE AQUI ARRIBA A PROPOSITO. Estaba al final del archivo, y eso era una
-- trampa: si CUALQUIER cosa de mas abajo truena (un panel, el HUD), el script
-- se detiene y la portada se queda en "Cargando la ciudad..." PARA SIEMPRE.
-- Poniendolo arriba, el boton sale pase lo que pase con el resto.
--
-- Y ya no espera al SERVIDOR: antes pedia "sync" y solo abria cuando le
-- contestaban, con respaldo de 30 x 0.4 s = 12 segundos. Si el servidor se
-- quedaba esperando a DataStore, el InvokeServer se colgaba para siempre y el
-- jugador no entraba NUNCA (`Main.sync` ya se arreglo: nunca deja de responder).
--
-- Como abre: con datos LOCALES que el cliente ve solo
--   1) ya hay ciudad y ya tienes personaje -> al instante
--   2) si no, revisa cada 0.1 s (30 veces = tope de 3 s, contado por
--      revoluciones: un tope con os.clock() no se puede medir en pruebas)
--   3) tocar la pantalla tambien entra
local introAbierta = false
local closeSplashFn = nil                  -- se define mas abajo (closeSplash)

local function queFalta(): string
	local city = workspace:FindFirstChild("City")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not city and not hrp then return "esperando la ciudad y tu personaje" end
	if not city then return "esperando la ciudad (revisa la consola: Output)" end
	if not hrp then return "esperando a tu personaje" end
	return "listo"
end

local function abrirPortada(motivo: string?)
	if introAbierta then return end
	introAbierta = true
	loadingLbl.Text = "Toca la pantalla o el boton para entrar"
	playBtn.Visible = true
	print("[SpiceEmpire] portada abierta (" .. tostring(motivo) .. ")")
end

-- aviso visible: si el server no contesta o algo falta, que se VEA, no que se
-- quede el jugador adivinando
local function avisoPortada(txt: string)
	if not introAbierta then loadingLbl.Text = txt end
	warn("[SpiceEmpire] portada: " .. txt)
end

local function listoParaJugar(): boolean
	local city = workspace:FindFirstChild("City")
	if not city then return false end
	local char = player.Character
	if not (char and char:FindFirstChild("HumanoidRootPart")) then return false end
	return true
end

if listoParaJugar() then
	abrirPortada("todo listo de una")      -- el servidor arranco antes que el cliente
end

task.spawn(function()
	for _ = 1, 30 do
		if listoParaJugar() then
			abrirPortada("ya se podia jugar a los " .. tostring(_ / 10) .. " s")
			return
		end
		task.wait(0.1)
	end
	-- tope: se abre de todos modos, y el texto dice que esta faltando
	local falta = queFalta()
	loadingLbl.Text = "Toca la pantalla o el boton para entrar"
	abrirPortada("tope de 3 s, faltaba: " .. falta)
	if falta ~= "listo" then
		avisoPortada("falta: " .. falta .. " (puedes entrar igual)")
	end
end)

-- mientras tanto: si a los 1.5 s todavia no abre, que el texto diga QUE falta
task.spawn(function()
	for _ = 1, 30 do
		if introAbierta then return end
		task.wait(0.1)
	end
	if not introAbierta then
		loadingLbl.Text = "Cargando...  (" .. queFalta() .. ")"
	end
end)

-- tocar la pantalla tambien entra (en celular es lo natural)
splash.InputBegan:Connect(function(input)
	if not introAbierta or not splash.Visible then return end
	if input.UserInputType ~= Enum.UserInputType.Touch
		and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local fn = closeSplashFn
	if fn then task.spawn(fn) end
end)

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

closeSplashFn = closeSplash

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
-- ======================================================================
-- HUD: COLUMNA VERTICAL DEL LADO IZQUIERDO
-- ======================================================================
-- El usuario lo pidio asi: la barra de arriba era DEMASIADO LARGA (medía
-- casi 600 px: media pantalla de un celular). Ahora todo va en una columna
-- pegada al borde izquierdo, de arriba hacia abajo, con el ancho de un dedo.
-- Ademas asi el centro de la pantalla queda libre para ver el juego.
local COL_W = IS_MOBILE and 112 or 124
local COL_X = IS_MOBILE and 6 or 12
local COL_Y = IS_MOBILE and 56 or 92      -- debajo del boton de Roblox

local mini = frame(gui, {
	Size = UDim2.new(0, COL_W, 0, 10),     -- la altura la pone el layout solo
	Position = UDim2.new(0, COL_X, 0, COL_Y),
	BackgroundColor3 = Color3.fromRGB(10, 10, 14),
	BackgroundTransparency = 0.35,
	Visible = false,
})
corner(mini, 12)

local colPad = Instance.new("UIPadding")
colPad.PaddingTop = UDim.new(0, 6)
colPad.PaddingBottom = UDim.new(0, 6)
colPad.PaddingLeft = UDim.new(0, 5)
colPad.PaddingRight = UDim.new(0, 5)
colPad.Parent = mini

local colList = Instance.new("UIListLayout")
colList.FillDirection = Enum.FillDirection.Vertical
colList.HorizontalAlignment = Enum.HorizontalAlignment.Center
colList.SortOrder = Enum.SortOrder.LayoutOrder
colList.Padding = UDim.new(0, 3)
colList.Parent = mini

-- el alto de la columna se calcula sola para que nunca se corte una fila ni se
-- encime con los botones de abajo.
-- >>> ESTE ERA EL BUG QUE ROMPIA TODA LA INTERFAZ (v41) <<<
-- Antes decia:  local colSize = Instance.new("AutomaticSize")
-- y "AutomaticSize" NO ES UNA CLASE de Roblox (es una PROPIEDAD). En Studio eso
-- truena ahi mismo: la barra ancha ya estaba dibujada y el script moria ANTES de
-- llegar al setHud(true) que la esconde -> el jugador veia la barra vieja para
-- siempre ("pegue todo y sigue igual"). El simulador no lo cazo porque aceptaba
-- cualquier clase inventada; ya no (tools/clases.py + mock estricto).
mini.AutomaticSize = Enum.AutomaticSize.Y

-- efectivo, arriba de todo y bien visible
local miniCash = label(mini, {
	Size = UDim2.new(1, 0, 0, IS_MOBILE and 24 or 26),
	LayoutOrder = 1,
	TextSize = IS_MOBILE and 19 or 21,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(120, 230, 150),
	Text = "$0",
	TextStrokeTransparency = 0.25,
	TextXAlignment = Enum.TextXAlignment.Center,
})

-- Fila = icono + numero. Se usan emojis porque se ven igual en todos los
-- dispositivos y no hay que subir imagenes a Roblox.
local function row(icon: string, tint: Color3, order: number, wide: boolean?)
	local holder = frame(mini, {
		Size = UDim2.new(1, 0, 0, IS_MOBILE and 24 or 28),
		LayoutOrder = order,
		BackgroundColor3 = Color3.fromRGB(22, 22, 28),
		BackgroundTransparency = 0.25,
	})
	corner(holder, 9)
	if wide then holder.Size = UDim2.new(1, 0, 0, IS_MOBILE and 44 or 50) end

	label(holder, {
		Size = UDim2.new(0, 22, 1, 0),
		Position = UDim2.new(0, 5, 0, 0),
		TextSize = 14,
		Text = icon,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local txt = label(holder, {
		Size = UDim2.new(1, -32, 1, -4),
		Position = UDim2.new(0, 29, 0, 2),
		TextSize = IS_MOBILE and 12 or 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = tint,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Text = "0",
	})
	return txt
end

-- v42: la columna quedo ORDENADA y clara (el usuario reporto que se veia
-- "recorrida" y que no sabia para que era la sirenita 🚨):
--   $        = tu efectivo
--   🌿 18    = hojas que TRAES encima
--   🧱 23    = bloques que traes encima
--   🎒 41/80 = tu mochila (espacio usado / capacidad)
--   🔒 ....  = lo GUARDADO en la caja fuerte (una linea por producto)
-- La sirenita 🚨 ya NO va aqui: el nivel de busqueda ahora son ESTRELLAS
-- debajo del reloj (arriba a la derecha), como pidio el usuario.
local chipLeaf  = row("🌿", Color3.fromRGB(150, 235, 140), 2)
local chipBlock = row("🧱", Color3.fromRGB(238, 216, 160), 3)
local chipBag   = row("🎒", Color3.fromRGB(170, 195, 235), 4)
local chipVault = row("🔒", Color3.fromRGB(130, 245, 190), 5, true)

-- ===== ESTRELLAS DE BUSQUEDA (v42) =====
-- 5 estrellas debajo del reloj: se van encendiendo con el nivel de busqueda y
-- se apagan solas cuando la zona segura te baja el heat (lo hace el servidor).
local estrellas: {TextLabel} = {}
do
	local marco = Instance.new("Frame")
	marco.Name = "EstrellasBusqueda"
	marco.BackgroundTransparency = 1
	marco.Size = UDim2.new(0, 5 * 20, 0, 22)
	marco.Position = UDim2.new(1, IS_MOBILE and -108 or -120, 0, IS_MOBILE and 30 or 36)
	marco.Parent = gui
	local fila = Instance.new("UIListLayout")
	fila.FillDirection = Enum.FillDirection.Horizontal
	fila.SortOrder = Enum.SortOrder.LayoutOrder
	fila.Parent = marco
	local titulo2 = Instance.new("TextLabel")
	titulo2.Name = "Rotulo"
	titulo2.BackgroundTransparency = 1
	titulo2.Size = UDim2.new(1, 0, 0, 12)
	titulo2.Position = UDim2.new(0, -62, 0, 5)
	titulo2.Font = Enum.Font.GothamBold
	titulo2.TextSize = 11
	titulo2.TextColor3 = Color3.fromRGB(190, 190, 205)
	titulo2.TextXAlignment = Enum.TextXAlignment.Right
	titulo2.Text = "BUSCA"
	titulo2.Parent = marco
	for i = 1, 5 do
		local e = Instance.new("TextLabel")
		e.Name = "Estrella" .. i
		e.BackgroundTransparency = 1
		e.Size = UDim2.new(0, 20, 1, 0)
		e.LayoutOrder = i
		e.Font = Enum.Font.GothamBold
		e.TextSize = 18
		e.Text = "★"
		e.TextColor3 = Color3.fromRGB(64, 64, 76)   -- apagada
		e.TextStrokeTransparency = 0.5
		e.TextStrokeColor3 = Color3.new(0, 0, 0)
		e.Parent = marco
		estrellas[i] = e
	end
end

-- aviso de BUSCADO (antes era un texto larguisimo arriba; ahora es una
-- etiqueta pegada a la columna para que no tape la pantalla)
local wantedLbl = label(mini, {
	Size = UDim2.new(1, 0, 0, 0),      -- crece solo cuando estas BUSCADO
	LayoutOrder = 7,
	TextSize = IS_MOBILE and 11 or 12,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 90, 90),
	Text = "",
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0.4,
})

-- reloj del juego: arriba a la derecha, como el reloj de un celular
local clockLbl = label(gui, {
	Size = UDim2.new(0, 110, 0, 22),
	Position = UDim2.new(1, IS_MOBILE and -112 or -124, 0, IS_MOBILE and 8 or 12),
	TextSize = IS_MOBILE and 14 or 16,
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(200, 210, 235),
	-- v37: junto al reloj va la RONDA de la interfaz que estas viendo. Sirve
	-- para lo que paso: desde la pantalla no habia forma de saber si el que
	-- dibujaba era el codigo nuevo o una copia vieja.
	Text = MI_VERSION,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextStrokeTransparency = 0.4,
})

task.spawn(function()
	local Lighting = game:GetService("Lighting")
	while true do
		local t = Lighting.ClockTime
		local h = math.floor(t)
		local m = math.floor((t - h) * 60)
		local icon = (h >= 6 and h < 19) and "SOL" or "LUNA"
		clockLbl.Text = string.format("%02d:%02d  %s  %s", h, m, icon, MI_VERSION)
		task.wait(1)
	end
end)

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
miniToggle.Position = UDim2.new(1, -26, 0, 4)
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

-- Las FILAS de la columna (icono + numero) se pueden esconder con la tecla
-- M o con el botoncito, para cuando quieras la pantalla limpia. El efectivo
-- se queda siempre visible, y la barra ancha vieja ya NO se muestra nunca
-- (era justo lo que el usuario pidio quitar: media pantalla de celular).
local function setHud(expanded: boolean)
	hudExpanded = expanded
	hud.Visible = false               -- la barra ancha vieja queda retirada
	-- >>> ESTE RENGLON FALTABA (v37) <<<
	-- 'mini' se creo con Visible = false y NADIE lo ponia en true: la columna
	-- quedaba invisible. La barra ancha se escondia bien... y en su lugar no
	-- aparecia NADA. Por eso el usuario seguia viendo "el tablero anterior":
	-- el que se veia era el de OTRA copia vieja, porque la nueva no dibujaba nada.
	mini.Visible = true
	for _, c in ipairs(mini:GetChildren()) do
		if c:IsA("GuiObject") and c.LayoutOrder >= 2 and c ~= miniToggle then
			c.Visible = expanded
		end
	end
	miniToggle.Text = expanded and "-" or "+"
	miniToggle.Visible = true
end

toggleBtn.MouseButton1Click:Connect(function() setHud(false) end)
miniToggle.MouseButton1Click:Connect(function() setHud(not hudExpanded) end)

setHud(true)
toggleBtn.Visible = false

----------------------------------------------------------------------
-- BOTONES DE ACCION (abajo)
----------------------------------------------------------------------
-- En CELULAR: rejilla de 2 columnas pegada al costado DERECHO, a media
-- altura. Ahi no estorba el joystick (abajo-izq) ni el salto (abajo-der).
-- En COMPU: la barra horizontal de siempre, abajo al centro.
-- EN TACTIL: botones de 112x52 (el minimo comodo para un dedo es ~48 px;
-- abajo de eso se fallan los toques) y la rejilla pegada al costado derecho,
-- donde no estorban ni el joystick ni el boton de saltar.
local BTN_W = IS_MOBILE and 78 or 100
local BTN_H = IS_MOBILE and 62 or 38

local dock
if IS_MOBILE then
	-- v43: el usuario dijo "el dashboard de abajo no funciona en celular". El
	-- cuadro estaba a media altura del costado derecho, pero con botones de puro
	-- texto chiquito (14) y de 112x52 pegados con 6 de separacion: se veian
	-- apretados y no se entendian. Ahora son ICONOS grandes (78x62) en 2 columnas
	-- x 3 renglones, con el nombre chiquito abajo de cada icono.
	dock = frame(gui, {
		Size = UDim2.new(0, BTN_W * 2 + 20, 0, BTN_H * 3 + 24),
		Position = UDim2.new(1, -(BTN_W * 2 + 30), 0.42, -(BTN_H * 3 + 24) / 2),
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.2,
	})
	corner(dock, 14)
	stroke(dock, ACCENT)

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, BTN_W, 0, BTN_H)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
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

-- Botones del dock. Ahora son CONTEXTUALES: los que tienen un "ctx" solo
-- aparecen cuando estas junto a la maquina que les toca. Antes estaban
-- los ocho siempre encendidos y tapaban media pantalla.
local ctxButtons: {[string]: {GuiObject}} = {}

local function dockBtn(name: string, key: string, cb: () -> (), ctx: string?, icon: string?)
	local text = IS_MOBILE and name or (name .. " [" .. key .. "]")
	local b = button(dock, text, {Size = UDim2.new(0, BTN_W, 0, BTN_H)})
	if IS_MOBILE then
		-- icono grande arriba y el nombre chiquito abajo
		b.TextSize = 11
		b.TextYAlignment = Enum.TextYAlignment.Bottom
		b.Text = (icon or "") .. "\n" .. name
		b.LineHeight = 1.05
	end
	-- v43: Active y no-Selectable. Sin esto, un toque puede caer en el marco del
	-- cuadro en vez del boton (y en celular el tap se pierde); y con Selectable un
	-- control/mando selecciona el boton sin querer.
	b.Active = true
	b.Selectable = false
	b.MouseButton1Click:Connect(cb)
	if ctx then
		b.Visible = false
		ctxButtons[ctx] = ctxButtons[ctx] or {}
		table.insert(ctxButtons[ctx], b)
	end
	return b
end

-- prende/apaga los botones de un contexto
local function setCtx(ctx: string, on: boolean)
	for _, b in ipairs(ctxButtons[ctx] or {}) do b.Visible = on end
end

dockBtn("Cosechar", "E", function() act("harvest") end, "harvest", "🌿")
dockBtn("Prensar", "R", function() act("press") end, "press", "⚙️")
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
end, "sell", "💰")

local shopBtn = dockBtn("Tienda", "B", function() end, nil, "🛒")
local phoneBtn = dockBtn("Telefono", "T", function() end, nil, "📱")
dockBtn("Bodega", "H", function() act("teleportHome") end, nil, "🏠")
-- v42: boton para traer tu auto donde estas (lo pidio el usuario para celular:
-- "un icono de un auto para spawnear el auto donde estes")
dockBtn("Auto", "Y", function() act("summonCar") end, nil, "🚗")

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
	-- OJO: hay que borrar TODO lo que se dibujo antes, no solo los Frame.
	-- Cuando esto solo borraba Frames, los TextLabel sueltos (los titulos
	-- de MOCHILAS, por ejemplo) se quedaban pegados y se iban apilando en
	-- todas las pestanas. Eso era el "mercado roto".
	do
		local basura = {}
		for _, c in ipairs(content:GetChildren()) do
			if c:IsA("GuiObject") then table.insert(basura, c) end
		end
		for _, c in ipairs(basura) do c:Destroy() end
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
		-- T.StorageBonus ya no existe (se quito en la v22). Leerlo daba nil y
		-- string.format reventaba -> la pestana Bodega se quedaba en blanco
		-- justo cuando abrias la computadora. Los topes reales de la caja
		-- son VaultLeaves (hojas) y VaultBlocks (bloques).
		label(info, {Size = UDim2.new(1, -24, 0, 16), Position = UDim2.new(0, 12, 0, 50),
			TextSize = 12, Text = string.format("Parcelas %d  |  Caja %d hojas / %d bloques",
				T.Plots, T.VaultLeaves, T.VaultBlocks),
			TextColor3 = Color3.fromRGB(150, 200, 160)})

		if nextT then
			row(nextT.Name,
				string.format("%s  |  Parcelas %d  |  Caja %d hojas / %d bloques",
					nextT.Desc, nextT.Plots, nextT.VaultLeaves, nextT.VaultBlocks),
				"$" .. Config.Abbrev(nextT.Cost),
				function() act("upgradeWarehouse") end)
		else
			row("Nivel maximo alcanzado", "Ya tienes la Mega Procesadora", "MAX", function() end, true)
		end

		row("Bicicleta", "Tu transporte inicial. Gratis siempre.", "Spawnear",
			function() act("spawnBike") end)

		-- MOCHILAS: suben cuanto puedes sacar de la caja fuerte de un viaje
		local curCap = State.CarryCap or Config.Carry.BaseCapacity
		label(content, {Size = UDim2.new(1, -8, 0, 22), TextSize = 14,
			Text = "MOCHILAS  -  actual: " .. (State.BackpackName or "Bolsillos")
				.. " (" .. curCap .. ")",
			TextColor3 = Color3.fromRGB(150, 200, 160)})
		for _, b in ipairs(Config.Carry.Backpacks) do
			local owned = (State.Backpack == b.Id)
			local tooSmall = (b.Capacity <= curCap)
			row(b.Name,
				string.format("Cargas hasta %d de una vez", b.Capacity),
				owned and "EN USO" or (tooSmall and "-" or ("$" .. Config.Abbrev(b.Cost))),
				function() act("buyBackpack", b.Id) end,
				owned or tooSmall)
		end

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
		-- los cosechadores van uno por mesa, asi que su tope es tus mesas
		local mesas = (Config.WarehouseTiers[State.WarehouseTier or 1] or {}).Plots or 0
		label(content, {Size = UDim2.new(1, -8, 0, 22), TextSize = 13, TextWrapped = true,
			Text = "Tus empleados trabajan solos, y siguen produciendo aunque cierres el juego.",
			TextColor3 = Color3.fromRGB(150, 200, 160)})

		for _, role in ipairs({"Harvester", "Presser", "Guard"}) do
			local info = Config.Employees[role]
			local owned = State.Employees[role] or 0
			local cost = Config.CostCurve(info.BaseCost, info.Growth, owned)
			local desc, maxed
			if role == "Guard" then
				desc = string.format("%d/%d - cada uno baja %d%% el riesgo de asalto",
					owned, info.Max, info.RaidReduction * 100)
				maxed = owned >= info.Max
			elseif role == "Harvester" then
				desc = string.format("%d/%d mesas - uno por mesa, corta lo maduro cada %ds",
					owned, mesas, info.Interval)
				maxed = owned >= mesas
			else
				desc = string.format("%d/%d - prensa solo cada %ds", owned, info.Max, info.Interval)
				maxed = owned >= info.Max
			end
			row(info.Name, desc, maxed and "MAX" or ("$" .. Config.Abbrev(cost)),
				function() act("hire", role) end, maxed)
		end

	elseif tab == "plazas" then
		label(content, {Size = UDim2.new(1, -8, 0, 40), TextSize = 13, TextWrapped = true,
			Text = "Parate dentro de una zona y aguanta para tomarla. Si hay gente de otro "
				.. "crew adentro, la plaza queda EN DISPUTA y nadie avanza.",
			TextColor3 = Color3.fromRGB(150, 200, 160)})

		for _, t in ipairs(Territories) do
			local mine = (t.CrewName and State.CrewName and t.CrewName == State.CrewName)
			local estado
			if t.Contested then
				estado = "EN DISPUTA"
			elseif t.CrewName then
				estado = mine and ("TUYA - " .. t.CrewName) or t.CrewName
			else
				estado = "Sin dueño"
			end
			row(t.Name,
				string.format("%s%s", estado,
					(t.Progress or 0) > 0 and ("   ·   capturando " .. t.Progress .. "%") or ""),
				mine and "+20%" or "-", function() end, true)
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
	{"plazas", "Plazas"},
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
end, "computer")

----------------------------------------------------------------------
-- PANEL DE LA CAJA FUERTE
----------------------------------------------------------------------
-- Aqui decides que te llevas y cuanto. Lo que dejes adentro esta a salvo
-- de la Unidad de Aduanas.
local VAULT_W, VAULT_H = 460, 330
local vault = frame(gui, {
	Size = UDim2.fromOffset(VAULT_W, VAULT_H),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = BG,
	Visible = false,
})
corner(vault, 12)
stroke(vault, Color3.fromRGB(80, 220, 160), 2)
fitPanel(vault, VAULT_W, VAULT_H)

label(vault, {Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 14, 0, 10),
	TextSize = 20, Text = "CAJA FUERTE", TextColor3 = Color3.fromRGB(130, 255, 190)})

local vaultClose = button(vault, "X", {
	Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -40, 0, 10),
	BackgroundColor3 = Color3.fromRGB(70, 40, 45)})
corner(vaultClose, 8)
vaultClose.MouseButton1Click:Connect(function() vault.Visible = false end)

local vaultInfo = label(vault, {Size = UDim2.new(1, -28, 0, 20), Position = UDim2.new(0, 14, 0, 40),
	TextSize = 13, Text = "", TextColor3 = Color3.fromRGB(175, 180, 195)})

-- cuanto mover por operacion
local vaultAmount = 25
local amtBtns = {}
local amtRow = frame(vault, {Size = UDim2.new(1, -28, 0, 30), Position = UDim2.new(0, 14, 0, 64),
	BackgroundTransparency = 1})
for i, opt in ipairs({10, 25, 100, -1}) do
	local txt = (opt == -1) and "TODO" or tostring(opt)
	local b = button(amtRow, txt, {
		Size = UDim2.new(0.25, -6, 1, 0),
		Position = UDim2.new(0.25 * (i - 1), 3, 0, 0),
		BackgroundColor3 = BG2, TextSize = 14})
	corner(b, 6)
	amtBtns[opt] = b
	b.MouseButton1Click:Connect(function()
		vaultAmount = opt
		for o, bb in pairs(amtBtns) do
			bb.BackgroundColor3 = (o == opt) and Color3.fromRGB(45, 110, 80) or BG2
		end
	end)
end
amtBtns[25].BackgroundColor3 = Color3.fromRGB(45, 110, 80)

-- una fila por producto
local function vaultRow(y, title, kind, colr)
	local row = frame(vault, {Size = UDim2.new(1, -28, 0, 82), Position = UDim2.new(0, 14, 0, y),
		BackgroundColor3 = BG2})
	corner(row, 8)
	local t = label(row, {Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 12, 0, 8),
		TextSize = 16, Text = title, TextColor3 = colr})
	local d = label(row, {Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 12, 0, 28),
		TextSize = 13, Text = "", TextColor3 = Color3.fromRGB(170, 175, 190)})

	local outBtn = button(row, "SACAR", {
		Size = UDim2.new(0.44, -8, 0, 26), Position = UDim2.new(0, 12, 0, 50),
		BackgroundColor3 = Color3.fromRGB(45, 110, 80), TextSize = 14})
	corner(outBtn, 6)
	local inBtn = button(row, "GUARDAR", {
		Size = UDim2.new(0.44, -8, 0, 26), Position = UDim2.new(0.5, 4, 0, 50),
		BackgroundColor3 = Color3.fromRGB(60, 70, 90), TextSize = 14})
	corner(inBtn, 6)

	outBtn.MouseButton1Click:Connect(function()
		local n = vaultAmount
		if n == -1 then n = 999999 end
		act("withdraw", kind, n)
	end)
	inBtn.MouseButton1Click:Connect(function()
		local n = vaultAmount
		if n == -1 then n = 999999 end
		act("deposit", kind, n)
	end)
	return d
end

local vaultLeafTxt = vaultRow(100, "HOJAS", "leaves", Color3.fromRGB(150, 240, 150))
local vaultBlockTxt = vaultRow(190, "BLOQUES", "blocks", Color3.fromRGB(240, 220, 150))

label(vault, {Size = UDim2.new(1, -28, 0, 32), Position = UDim2.new(0, 14, 0, 284),
	TextSize = 12, TextWrapped = true,
	Text = "Lo que dejes en la caja esta a salvo. Aduanas solo te quita lo que traigas encima.",
	TextColor3 = Color3.fromRGB(140, 200, 165)})

refreshVault = function()
	if not vault.Visible or not State then return end
	local cl, cb = State.CarryLeaves or 0, State.CarryBlocks or 0
	local used = (State.Leaves or 0) + (State.Blocks or 0)
	vaultInfo.Text = string.format("Caja %d/%d          Cargas %d/%d  (%s)",
		used, State.Storage or 0, cl + cb, State.CarryCap or 0,
		State.BackpackName or "Bolsillos")
	vaultLeafTxt.Text = string.format("En la caja: %d      Traes: %d", State.Leaves or 0, cl)
	vaultBlockTxt.Text = string.format("En la caja: %d      Traes: %d", State.Blocks or 0, cb)
end

RE_OpenVault.OnClientEvent:Connect(function()
	if vault.Visible then return end
	vault.Visible = true
	refreshVault()
end)

-- boton del dock (va aqui y no arriba porque necesita que 'vault' ya exista)
dockBtn("Caja", "C", function()
	vault.Visible = not vault.Visible
	if vault.Visible then refreshVault() end
end, "vault", "🔐")

dockBtn("Garaje", "V", function()
	shop.Visible = true
	renderTab("autos")
end, "garage", "🅿️")

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

	-- El HUD muestra dos cosas distintas: lo GUARDADO en la caja fuerte y
	-- lo que traes CARGANDO (que es lo unico que te puede quitar Aduanas).
	-- Un bloque ocupa 3 de espacio, igual que en el servidor.
	local used = data.Leaves + data.Blocks * 3
	local cl, cb = data.CarryLeaves or 0, data.CarryBlocks or 0
	local carrying = cl + cb
	local lleno = (used >= data.Storage) and "  <<< LLENA" or ""
	invLbl.Text = string.format(
		"CAJA FUERTE  %d hojas / %d bloques  (%d/%d)%s        LLEVAS ENCIMA  %d/%d",
		data.Leaves, data.Blocks, used, data.Storage, lleno, carrying, data.CarryCap or 0)

	refreshVault()

	-- lo que TRAES ENCIMA (lo unico que te puede quitar Aduanas)
	chipLeaf.Text = Config.Abbrev(cl)
	chipBlock.Text = Config.Abbrev(cb)

	chipBag.Text = string.format("%d/%d", carrying, data.CarryCap or 0)
	chipBag.TextColor3 = (carrying >= (data.CarryCap or 0))
		and Color3.fromRGB(255, 130, 130) or Color3.fromRGB(170, 195, 235)

	-- lo GUARDADO en la caja fuerte: una linea por producto (antes iba todo
	-- apretado en un renglon y se veia "recorrido")
	chipVault.Text = string.format("🌿 %d/%d\n🧱 %d/%d",
		data.Leaves, data.VaultLeafCap or 0, data.Blocks, data.VaultBlockCap or 0)

	local ratio = data.Heat / Config.Heat.Max
	heatTxt.Text = string.format("HEAT %d%%", math.floor(ratio * 100))

	-- estrellas de busqueda: 0 a 5 segun el heat
	local nivel = math.clamp(math.floor(ratio * 5 + 0.5), 0, 5)
	for i = 1, 5 do
		local e = estrellas[i]
		if e then
			e.TextColor3 = (i <= nivel)
				and (nivel >= 4 and Color3.fromRGB(255, 110, 90) or Color3.fromRGB(255, 205, 70))
				or Color3.fromRGB(64, 64, 76)
		end
	end
	TweenService:Create(heatFill, TweenInfo.new(0.3), {Size = UDim2.new(ratio, 0, 1, 0)}):Play()
	heatFill.BackgroundColor3 = ratio > 0.7 and Color3.fromRGB(255, 70, 70)
		or ratio > 0.4 and Color3.fromRGB(255, 160, 60)
		or Color3.fromRGB(120, 200, 120)

	wantedLbl.Text = data.Wanted and "BUSCADO - ADUANAS EN TU CONTRA" or ""
	-- colapsado cuando no estas buscado: la columna no come pantalla de gusto
	wantedLbl.Size = UDim2.new(1, 0, 0, data.Wanted and (IS_MOBILE and 28 or 30) or 0)

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
	elseif k == Enum.KeyCode.V then
		shop.Visible = true
		renderTab("autos")
	elseif k == Enum.KeyCode.C then
		vault.Visible = not vault.Visible
		if vault.Visible then refreshVault() end
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
local RE_Call = PA.IncomingCall      -- por el intermediario, no directo

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

-- Efecto maquina de escribir + vocecita.
-- El blip suena cada 2 letras con el tono movido al azar: da ese
-- "guiri guiri guiri" de los juegos viejos, sin decir nada de verdad.
local talkSound: Sound? = nil
do
	local def = Config.Sounds and Config.Sounds.Talk
	if def and Config.Sounds.Enabled then
		local sd = Instance.new("Sound")
		sd.Name = "NPCTalk"
		sd.SoundId = def.Id
		sd.Volume = def.Volume or 0.3
		sd.Parent = gui
		talkSound = sd
	end
end

local typeToken = 0
local function typeOut(txt: string)
	typeToken += 1
	local myToken = typeToken
	dlgText.Text = ""
	for i = 1, #txt do
		if typeToken ~= myToken then return end
		dlgText.Text = string.sub(txt, 1, i)

		-- no sonar en los espacios ni en cada letra: queda ametrallado
		local ch = string.sub(txt, i, i)
		if talkSound and ch ~= " " and i % 2 == 0 then
			talkSound.PlaybackSpeed = 0.82 + math.random() * 0.5
			talkSound:Play()
		end

		task.wait(0.028)
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

----------------------------------------------------------------------
-- DISPARO
----------------------------------------------------------------------
-- El servidor crea la Tool y hace el raycast; aqui solo avisamos hacia
-- donde estas apuntando. En celular se dispara hacia donde mira la camara.
do
	local W = Config.Weapon
	if W then
		local mouse = player:GetMouse()

		local function aimDirection(): Vector3?
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then return nil end
			local from = hrp.Position + Vector3.new(0, 1, 0)

			local target
			if IS_MOBILE then
				-- en tactil no hay mouse: se apunta con la camara
				target = camera.CFrame.Position + camera.CFrame.LookVector * W.Range
			else
				target = mouse.Hit and mouse.Hit.Position
			end
			if not target then return nil end

			local d = target - from
			if d.Magnitude < 0.01 then return nil end
			return d.Unit
		end

		local function hookTool(tool: Instance)
			if not tool:IsA("Tool") or tool.Name ~= W.Name then return end
			tool.Activated:Connect(function()
				local d = aimDirection()
				if d then RE_Shoot:FireServer(d) end
			end)
		end

		local function watch(container: Instance)
			for _, c in ipairs(container:GetChildren()) do hookTool(c) end
			container.ChildAdded:Connect(hookTool)
		end

		local bp = player:FindFirstChildOfClass("Backpack")
		if bp then watch(bp) end
		player.ChildAdded:Connect(function(c)
			if c:IsA("Backpack") then watch(c) end
		end)
		if player.Character then watch(player.Character) end
		player.CharacterAdded:Connect(function(char)
			task.wait(0.4)
			watch(char)
			local nbp = player:FindFirstChildOfClass("Backpack")
			if nbp then watch(nbp) end
		end)
	end
end

----------------------------------------------------------------------
-- CERCANIA A LAS MAQUINAS DE TU BODEGA
----------------------------------------------------------------------
-- Los botones de Cosechar / Prensar / Mejoras / Caja solo salen cuando
-- estas junto a la maquina que les toca, y los menus se cierran solos al
-- alejarte. Antes el dock traia los ocho botones encendidos siempre.
do
	local function sound(key: string)
		local def = Config.Sounds and Config.Sounds[key]
		if not (def and Config.Sounds.Enabled) then return end
		local sd = Instance.new("Sound")
		sd.SoundId = def.Id
		sd.Volume = def.Volume or 0.4
		sd.PlaybackSpeed = def.Pitch or 1
		sd.Parent = gui
		sd:Play()
		task.delay(3, function() sd:Destroy() end)
	end

	-- Los radios salen TODOS de GameConfig: el servidor valida con los
	-- mismos numeros. Antes el cliente usaba 16 para la prensa y el server
	-- 14, asi que entre 14 y 16 studs el boton salia pero te rebotaba con
	-- "estas muy lejos". Si hay que ajustar, se ajusta en UN solo lugar.
	local I = Config.Interact
	local R_PRESS = Config.Press.UseRadius
	local R_COMPUTER = I.Computer
	local R_VAULT = Config.Carry.VaultRadius
	local R_TABLE = Config.Growth.HarvestRadius
	local R_BUYER = I.Buyer
	-- R_GARAGE ya no se usa: el detector de la cochera ahora mide contra la CAJA
	-- del piso (v46). Se deja el numero en GameConfig por si hay que volver.
	local R_GARAGE = I.Garage

	local function myWarehouse(): Model?
		local w = workspace:FindFirstChild("Warehouse_" .. player.UserId)
		return (w and w:IsA("Model")) and w or nil
	end

	local near = {}          -- estado anterior, para detectar el cruce

	local function update()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			for _, c in ipairs({"harvest", "press", "computer", "vault", "sell", "garage"}) do
				setCtx(c, false)
				-- OJO: 'near' tambien se resetea. Si no, y te matan PARADO junto
				-- a la computadora o a la caja fuerte, al revivir 'near' queda
				-- en true y el detector de cruce nunca vuelve a disparar: el
				-- panel NO se abre aunque camines hasta pegado a la maquina.
				-- (Solo se reabria si te alejabas y volvias a acercarte.)
				near[c] = false
			end
			shop.Visible = false
			vault.Visible = false
			return
		end
		local pos = hrp.Position
		local wh = myWarehouse()

		local function dist(name: string): number
			if not wh then return math.huge end
			local part = wh:FindFirstChild(name, true)
			if not (part and part:IsA("BasePart")) then return math.huge end
			return (part.Position - pos).Magnitude
		end

		-- ¿hay alguna mesa cerca?
		local tableNear = false
		if wh then
			local plots = wh:FindFirstChild("Plots")
			if plots then
				for _, d in ipairs(plots:GetChildren()) do
					if d:IsA("BasePart") and string.sub(d.Name, 1, 4) == "Plot" then
						if (d.Position - pos).Magnitude <= R_TABLE then
							tableNear = true
							break
						end
					end
				end
			end
		end

		-- ¿estas ADENTRO de la cochera? (v46)
		-- Antes era dist("GarageFloor") <= R_GARAGE: la distancia al CENTRO del
		-- piso del garaje. Como ese piso mide 26x24 studs, el circulo del radio
		-- se salia por la puerta hasta la calle: ibas caminando frente al porton
		-- y se te abria el mercado solo (reporte del usuario: "cuando me acerco a
		-- la cochera de repente se me abre el mercado").
		-- Ahora se mide contra la CAJA del piso: cuenta solo si de verdad estas
		-- adentro del taller (o pisando el umbral del porton, 2 studs de gracia).
		local enCochera = false
		if wh then
			local piso = wh:FindFirstChild("GarageFloor", true)
			if piso and piso:IsA("BasePart") then
				local d = piso.Position - pos
				local dx = math.max(math.abs(d.X) - piso.Size.X * 0.5, 0)
				local dz = math.max(math.abs(d.Z) - piso.Size.Z * 0.5, 0)
				enCochera = math.sqrt(dx * dx + dz * dz) <= 2
			end
		end

		-- ¿hay un comprador cerca?
		local buyerNear = false
		local city = workspace:FindFirstChild("City")
		local buyers = city and city:FindFirstChild("Buyers")
		if buyers then
			for _, pad in ipairs(buyers:GetChildren()) do
				if pad:IsA("BasePart") and (pad.Position - pos).Magnitude <= R_BUYER then
					buyerNear = true
					break
				end
			end
		end

		local st = {
			harvest  = tableNear,
			press    = dist("PressBase") <= R_PRESS,
			computer = dist("UpgradeScreen") <= R_COMPUTER,
			vault    = dist("VaultBody") <= R_VAULT,
			sell     = buyerNear,
			garage   = enCochera,
		}

		for k, v in pairs(st) do
			setCtx(k, v)

			if v ~= near[k] then
				near[k] = v
				-- al ENTRAR a la computadora o a la caja: sonido + abrir
				if k == "computer" then
					if v then
						sound("Computer")
						shop.Visible = true
						renderTab("bodega")
					else
						shop.Visible = false
					end
				elseif k == "vault" then
					if v then
						sound("VaultOpen")
						vault.Visible = true
						refreshVault()
					else
						vault.Visible = false
					end
				elseif k == "garage" then
					-- v43: el usuario pidio que al acercarse a la bodega se abra el
					-- menu solo, igual que la computadora, con la pestana de AUTOS
					-- (es lo que vas a querer ahi: sacar o guardar un vehiculo).
					-- v46: SOLO se abre si estas ADENTRO del taller. Antes el radio
					-- llegaba a la calle y se abria pasando frente al porton.
					-- Al salir NO se cierra: te quedarias sin poder moverte de la
					-- lista mientras estas adentro.
					if v and not shop.Visible then
						sound("Gate")
						shop.Visible = true
						renderTab("autos")
					end
				end
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.3)
			pcall(update)
		end
	end)
end

----------------------------------------------------------------------
-- TERRITORIOS
----------------------------------------------------------------------
-- Barra que sale cuando estas tomando una plaza, y el estado que usa la
-- pestaña "Plazas" de la tienda.
local capBar = frame(gui, {
	Size = UDim2.fromOffset(320, 46),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 96),
	BackgroundColor3 = BG,
	Visible = false,
})
corner(capBar, 10)
stroke(capBar, Color3.fromRGB(240, 190, 70))
fitPanel(capBar, 320, 46, false)

local capLbl = label(capBar, {
	Size = UDim2.new(1, -16, 0, 18), Position = UDim2.new(0, 8, 0, 5),
	TextSize = 14, Text = "", TextColor3 = Color3.fromRGB(240, 210, 140),
})
local capTrack = frame(capBar, {
	Size = UDim2.new(1, -16, 0, 10), Position = UDim2.new(0, 8, 0, 26),
	BackgroundColor3 = Color3.fromRGB(40, 40, 50),
})
corner(capTrack, 5)
local capFill = frame(capTrack, {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(240, 190, 70),
})
corner(capFill, 5)

RE_Terr.OnClientEvent:Connect(function(list)
	Territories = list or {}
	if shop.Visible and currentTab == "plazas" then renderTab("plazas") end

	-- ¿hay alguna en progreso o en disputa?
	local show = nil
	for _, t in ipairs(Territories) do
		if t.Contested then show = t break end
		if (t.Progress or 0) > 0 then show = t end
	end

	if show then
		capBar.Visible = true
		if show.Contested then
			capLbl.Text = show.Name .. "  ·  EN DISPUTA"
			capFill.BackgroundColor3 = Color3.fromRGB(255, 110, 110)
		else
			capLbl.Text = show.Name .. "  ·  tomando " .. (show.Progress or 0) .. "%"
			capFill.BackgroundColor3 = Color3.fromRGB(240, 190, 70)
		end
		TweenService:Create(capFill, TweenInfo.new(0.3),
			{Size = UDim2.new((show.Progress or 0) / 100, 0, 1, 0)}):Play()
	else
		capBar.Visible = false
	end
end)

----------------------------------------------------------------------
-- TESTIGO DE RONDA (v38): avisar que corrio TODO
----------------------------------------------------------------------
-- Si llegamos hasta aqui, la interfaz entera se construyo. Se cambia el texto
-- de la placa ("arrancando..." -> "OK") buscandola por nombre: asi no se gasta
-- ni una variable local mas (este archivo anda justo de locales, ver docs/03).
do
	local pg = player:FindFirstChild("PlayerGui")
	local sg = pg and pg:FindFirstChild("AvisoRonda")
	local placa = sg and sg:FindFirstChild("Placa")
	local titulo = placa and placa:FindFirstChild("Titulo")
	if titulo then
		titulo.Text = "RONDA " .. MI_VERSION .. "  OK"
	end
	print("[SpiceEmpire] TESTIGO: interfaz completa de la " .. MI_VERSION .. " dibujada.")
end
