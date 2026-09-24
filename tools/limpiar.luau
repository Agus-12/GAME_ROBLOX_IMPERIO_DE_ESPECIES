-- LIMPIADOR DE COPIAS  (ronda v43)
----------------------------------------------------------------------
-- PARA QUE SIRVE
--   Tu juego avisa "HAY COPIAS PEGADAS EN STUDIO". Esto las borra SOLO,
--   sin que tengas que andar cazando cosas en el Explorer.
--
-- COMO SE USA (2 pasos)
--   1) En Studio, SIN dar Play (en modo edicion), abre la PESTANA 'View' (las de
--      adentro: Home, Model, Avatar, Terrain, Test, View, Plugins) y prende el
--      boton 'Command Bar' (es la barrita que sale abajo, junto al Output).
--      OJO: el menu 'View' de la barra de arriba de la pantalla NO es ese menu.
--   2) Pega TODO este codigo y dale Enter. Listo: te dice que borro.
--
-- QUE HACE
--   1) Borra las copias repetidas de Main, CityGenerator, DataService,
--      GameConfig y ClientUI (deja UNA de cada: la de la ronda nueva).
--   2) Borra TODAS las carpetas Remotes: el juego crea la suya solito al
--      dar Play, asi que dejarlas pegadas solo causa problemas.
--   3) Te dice QUE ARCHIVO hay que volver a pegar (los que son de otra
--      ronda, o los que faltan).
--
-- No toca nada mas (ni el mapa, ni BuildCar, ni tus cosas). Si algo no te
-- gusta, Ctrl+Z lo deshace.
----------------------------------------------------------------------

local RONDA = "v43"          -- esta ronda de archivos (lo revisa tools/remotes.py)

local SALIDA: {string} = {}
local borrados: {string} = {}
local paraPegar: {string} = {}
local faltan: {string} = {}

local function di(s: string)
	table.insert(SALIDA, s)
end

-- 1) servicios (con pcall: si algo no existe en este Studio, no truena)
local function servicio(nombre: string): any
	local ok, s = pcall(function() return game:GetService(nombre) end)
	if ok and s then return s end
	local ok2, s2 = pcall(function() return game:FindFirstChild(nombre) end)
	if ok2 and s2 then return s2 end
	return nil
end

local SPS: any = nil
do
	local sp = servicio("StarterPlayer")
	if sp then
		local ok, s = pcall(function() return sp:FindFirstChild("StarterPlayerScripts") end)
		if ok then SPS = s end
	end
end

-- 2) ¿esta corriendo el juego? Esto hay que correrlo SIN dar Play
do
	local ok, corriendo = pcall(function()
		local rs = game:GetService("RunService")
		return rs and rs:IsRunning()
	end)
	if ok and corriendo then
		print("[LIMPIADOR] OJO: el juego esta CORRIENDO. Lo que borre ahora se deshace cuando")
		print("[LIMPIADOR] pares. Mejor deten el juego (boton Stop), quedate en modo edicion y")
		print("[LIMPIADOR] vuelve a pegar el limpiador.")
	end
end

-- 3) el sello de ronda de un archivo: "RONDA: vNN" en sus primeras lineas
local function selloDe(o: any): string?
	local ok, src = pcall(function() return o.Source end)
	if not ok or type(src) ~= "string" then return nil end
	return string.match(src, "RONDA:%s*(v%d+)")
end

local function numDe(v: string?): number
	if not v then return 0 end
	return tonumber(string.match(v, "%d+") or "0") or 0
end

-- 4) ruta legible de un objeto ("ServerScriptService > Main2")
local function rutaDe(o: any): string
	local partes: {string} = {}
	local actual: any = o
	local saltos = 0
	while actual and saltos < 4 do
		local n = actual.Name
		if not n or n == "Game" then break end
		table.insert(partes, 1, n)
		local ok, p = pcall(function() return actual.Parent end)
		actual = (ok and p) or nil
		saltos += 1
	end
	return table.concat(partes, " > ")
end

-- 5) los 5 archivos del juego: nombre esperado y donde van
local BLANCOS = {
	{ nombre = "Main",           padres = { "ServerScriptService" } },
	{ nombre = "CityGenerator",  padres = { "ServerScriptService" } },
	{ nombre = "DataService",    padres = { "ServerScriptService" } },
	{ nombre = "GameConfig",     padres = { "ReplicatedStorage" } },
	{ nombre = "ClientUI",       padres = { "StarterPlayerScripts", "StarterGui" } },
}

-- 6) junta TODOS los objetos del lugar (una sola pasada)
local todos: {any} = {}
do
	local ok, lista = pcall(function() return game:GetDescendants() end)
	if ok and lista then
		for _, d in ipairs(lista) do table.insert(todos, d) end
	end
	-- y los servicios donde se pueden esconder (un Script dentro de Workspace
	-- TAMBIEN corre, por eso se revisa todo esto)
	for _, n in ipairs({ "ServerScriptService", "ReplicatedStorage", "StarterGui",
		"ReplicatedFirst", "ServerStorage", "Workspace" }) do
		local s = servicio(n)
		if s then
			table.insert(todos, s)
			local ok2, hijos = pcall(function() return s:GetChildren() end)
			if ok2 and hijos then
				for _, d in ipairs(hijos) do table.insert(todos, d) end
			end
		end
	end
	if SPS then
		table.insert(todos, SPS)
		local ok3, hijos = pcall(function() return SPS:GetChildren() end)
		if ok3 and hijos then
			for _, d in ipairs(hijos) do table.insert(todos, d) end
		end
	end
end

local function esScript(o: any): boolean
	local ok, cls = pcall(function() return o.ClassName end)
	if not ok then return false end
	return cls == "Script" or cls == "LocalScript" or cls == "ModuleScript"
end

local function esCarpeta(o: any): boolean
	local ok, cls = pcall(function() return o.ClassName end)
	return ok and cls == "Folder"
end

print("===== LIMPIADOR DE COPIAS (" .. RONDA .. ") =====")

-- 7) archivo por archivo
for _, b in ipairs(BLANCOS) do
	local copias: {any} = {}
	for _, o in ipairs(todos) do
		if esScript(o) and o.Name and (o.Name == b.nombre
			or string.match(o.Name, "^" .. b.nombre .. "%d+$")) then
			table.insert(copias, o)
		end
	end

	if #copias == 0 then
		table.insert(faltan, b.nombre)
		di(b.nombre .. ": NO lo encontre -> falta pegarlo")
	else
		-- cual se queda: el que tenga el sello mas nuevo; en empate, el nombre
		-- exacto; si tambien empata, el primero de la lista
		local mejor = 1
		local mejorNum = -1
		local mejorExacto = false
		for i, c in ipairs(copias) do
			local n = numDe(selloDe(c))
			local exacto = (c.Name == b.nombre)
			if n > mejorNum or (n == mejorNum and exacto and not mejorExacto) then
				mejor = i
				mejorNum = n
				mejorExacto = exacto
			end
		end
		local queda = copias[mejor]
		local selloQueda = selloDe(queda)

		for i, c in ipairs(copias) do
			if i ~= mejor then
				table.insert(borrados, "'" .. c.Name .. "' (" .. rutaDe(c) .. ")")
				pcall(function() c:Destroy() end)
			end
		end

		local donde = rutaDe(queda)
		if #copias == 1 then
			di(b.nombre .. ": 1 sola copia (" .. donde .. ")")
		else
			di(b.nombre .. ": habia " .. #copias .. " -> borre " .. (#copias - 1) ..
				", quedo '" .. queda.Name .. "' (" .. donde .. ")")
		end
		if selloQueda ~= RONDA then
			table.insert(paraPegar, b.nombre .. " (el que tienes dice " ..
				(selloQueda or "NADA: es de una ronda vieja, sin sello") .. ")")
		end
	end
end

-- 8) carpetas Remotes: TODAS fuera (el juego crea la suya al dar Play)
local remotesBorradas = 0
do
	local basura: {any} = {}
	for _, o in ipairs(todos) do
		if esCarpeta(o) and o.Name and string.match(o.Name, "^Remotes%d*$") then
			table.insert(basura, o)
		end
	end
	for _, o in ipairs(basura) do
		local cuantos = 0
		local ok, hijos = pcall(function() return o:GetChildren() end)
		if ok and hijos then cuantos = #hijos end
		table.insert(borrados, "'" .. o.Name .. "' (" .. rutaDe(o) .. ", " .. cuantos .. " remotes)")
		pcall(function() o:Destroy() end)
		remotesBorradas += 1
	end
end
if remotesBorradas > 0 then
	di("carpetas Remotes: borre " .. remotesBorradas .. " (el juego crea la buena al dar Play)")
else
	di("carpetas Remotes: no habia ninguna pegada (bien)")
end

-- 9) resumen
print("----- que borre -----")
if #borrados == 0 then
	print("  (nada: ya estaba limpio)")
else
	for _, t in ipairs(borrados) do print("  borrado: " .. t) end
end

print("----- resultado -----")
for _, t in ipairs(SALIDA) do print("  " .. t) end

if #paraPegar > 0 then
	print("----- PARA PEGAR DE NUEVO (son de otra ronda) -----")
	for _, t in ipairs(paraPegar) do print("  " .. t) end
	print("  Abre el HTML de la ronda " .. RONDA .. " y pega esos archivos COMPLETOS.")
end
if #faltan > 0 then
	print("----- FALTAN (no los encontre pegados) -----")
	for _, t in ipairs(faltan) do print("  " .. t) end
end

if #borrados > 0 or #paraPegar > 0 or #faltan > 0 then
	print("===== LISTO: ahora dale Play =====")
else
	print("===== LISTO: no habia nada que arreglar =====")
end
