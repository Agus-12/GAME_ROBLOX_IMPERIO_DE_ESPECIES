local TOOLS = os.getenv("TOOLS") or "."
dofile(TOOLS .. "/mock.lua")
-- señales REALES (del mock): asi una prueba puede disparar un remoto y ver
-- como reacciona la interfaz. Antes esto devolvia un Connect hueco (no guardaba
-- el manejador) y las pruebas del HUD no podian encender nada.
local function newSignal()
  if _G.__newSignal then return _G.__newSignal() end
  local s = {_fns = {}}
  function s:Connect(fn)
    local i = #self._fns + 1
    self._fns[i] = fn
    return {Disconnect = function() self._fns[i] = nil end}
  end
  function s:Fire(...) for _, fn in ipairs(self._fns) do pcall(fn, ...) end end
  return s
end
local vw = tonumber(os.getenv("MOCK_VW") or "1920")
local vh = tonumber(os.getenv("MOCK_VH") or "1080")
local touch = (os.getenv("MOCK_TOUCH") == "1")
local cam = Instance.new("Camera")
cam.ViewportSize = Vector2.new(vw, vh)
cam.GetPropertyChangedSignal = function() return newSignal() end
workspace.CurrentCamera = cam
local uis = game:GetService("UserInputService")
uis.TouchEnabled = touch ; uis.KeyboardEnabled = not touch ; uis.InputBegan = newSignal()
local plr = Instance.new("Player") ; plr.Name="Tester" ; plr.UserId=1
plr.GetMouse = function() return {Hit = nil} end
local bpk = Instance.new("Backpack"); bpk.Name = "Backpack"; bpk.Parent = plr
plr.FindFirstChildOfClass = function(s,c)
  if c == "Backpack" then return bpk end
  return nil end
plr.WaitForChild = function(s,n)
  local c=s:FindFirstChild(n) ; if c then return c end
  local o=Instance.new("Folder") ; o.Name=n ; o.Parent=s ; return o end
local pg = Instance.new("PlayerGui") ; pg.Name="PlayerGui" ; pg.Parent=plr
game:GetService("Players").LocalPlayer = plr
local rs = game:GetService("ReplicatedStorage")
local cfgSrc = dofile(TOOLS .. "/cfgload.lua")
LLAMADAS = LLAMADAS or {}
local NEEDED={"StateUpdate","PhoneAlert","Toast","MissionUpdate","IncomingCall","OpenUpgrades","OpenVault","Sfx","Shoot","TerritoryUpdate","Action"}

-- El juego de verdad: el SERVIDOR borra las carpetas Remotes viejas y crea la
-- suya con el sello "Build" (Config.Build). El simulador tiene que hacer lo
-- mismo, si no las pruebas mienten.
-- Anota a QUE carpeta se engancha el cliente, contando conexiones por carpeta.
-- Tiene que vivir AQUI (no en el guion de prueba): en el escenario de la carrera
-- la carpeta del servidor se crea DESPUES, asi que un instrumento puesto al
-- principio no la veria y la prueba daria un falso "no se engancho".
_G.__CON = {}
local function instrumentar(f)
  local et = tostring(f.Name) .. "#" .. tostring(f:GetAttribute("Build") ~= nil)
  for _, r in ipairs(f:GetChildren()) do
    local sig = r.OnClientEvent
    if sig and sig.Connect then
      local orig = sig.Connect
      sig.Connect = function(self, fn)
        _G.__CON[et] = (_G.__CON[et] or 0) + 1
        local conn = orig(self, fn)
        return { Disconnect = function()
          _G.__CON[et] = (_G.__CON[et] or 0) - 1
          if conn and conn.Disconnect then conn:Disconnect() end
        end }
      end
    end
  end
end

local function crearRemotes(cualSello)
  local f = Instance.new("Folder") ; f.Name="Remotes" ; f.Parent=rs
  for _,n in ipairs(NEEDED) do
    local e=Instance.new(n=="Action" and "RemoteFunction" or "RemoteEvent")
    e.Name=n ; e.OnClientEvent=newSignal()
    if n == "Action" and os.getenv("MOCK_SERVER_MUDO") == "1" then
      -- servidor atorado (por ejemplo esperando a DataStore): la llamada NUNCA
      -- regresa. Es el caso que dejaba la portada en "Cargando la ciudad..."
      e.InvokeServer=function() while true do task.wait(1) end end
    else
      -- v43: ademas de "si funciona", se ANOTA que accion mando el cliente.
      -- Sin esto, las pruebas de la interfaz solo miraban que el boton EXISTIERA:
      -- que el boton mandara la accion correcta no se probaba nunca (el remoto no
      -- existia en el simulador y `act()` moria dentro de su pcall).
      e.InvokeServer=function(_, ...)
        table.insert(LLAMADAS, {rem = e.Name, args = {...}})
        return {ok = true}
      end
    end
    e.Parent=f end
  if cualSello then f:SetAttribute("Build", tostring(cfgSrc.Build or "?")) end
  instrumentar(f)
  return f
end

local remotes
if os.getenv("MOCK_REMOTES_TARDE") == "1" then
  -- CASO REAL DEL USUARIO (v34): en el lugar quedo guardada una carpeta Remotes
  -- VIEJA (sin sello, con menos remotes) y el servidor todavia NO crea la suya.
  -- Antes: el cliente se enganchaba a la vieja y el servidor la borraba 0.6 s
  -- despues -> remotes MUERTOS (botones que no hacian nada, sin error).
  local vieja = Instance.new("Folder") ; vieja.Name="Remotes" ; vieja.Parent=rs
  vieja:SetAttribute("Build", nil)
  for _,n in ipairs({"StateUpdate","PhoneAlert","Toast","MissionUpdate","IncomingCall"}) do
    local e=Instance.new("RemoteEvent") ; e.Name=n ; e.OnClientEvent=newSignal() ; e.Parent=vieja
  end
  instrumentar(vieja)
  task.delay(0.6, function()
    vieja:Destroy()                 -- el servidor limpia la vieja...
    remotes = crearRemotes(true)    -- ...y crea la suya con sello
    print("[mock] el servidor ya creo su carpeta Remotes (sello " .. tostring(cfgSrc.Build) .. ")")
  end)
else
  remotes = crearRemotes(true)
end
rs.WaitForChild=function(s,n)
  if n=="Remotes" then return remotes end
  if n=="GameConfig" then return "__CFG__" end
  return s:FindFirstChild(n) end
require=function(x) if x=="__CFG__" then return cfgSrc end return {} end

-- ===== LO QUE MIDE tools/intro.py =====
-- 1) reloj virtual: cuando se abre el boton "ENTRAR AL BARRIO"
__ON_SET = function(o, k, v)
  if k == "Visible" and v == true and o.Text
     and string.find(tostring(o.Text), "ENTRAR") and not __INTRO_AT then
    __INTRO_AT = task.__sched.vtime
  end
end

-- 2) escenarios: MOCK_CITY=1 pone la ciudad, MOCK_CHAR=1 pone tu personaje
if os.getenv("MOCK_CITY") == "1" then
  local city = Instance.new("Folder") ; city.Name = "City" ; city.Parent = workspace
end
-- el personaje puede aparecer DESPUES (como en el juego real): util para
-- comprobar que la portada espera al personaje y no se queda colgada
local function ponPersonaje()
  if plr.Character then return end
  local char = Instance.new("Model") ; char.Name = "Tester"
  local hrp = Instance.new("Part") ; hrp.Name = "HumanoidRootPart"
  hrp.Position = Vector3.new(0, 3, 0) ; hrp.Parent = char
  char.Parent = workspace
  plr.Character = char
  plr.FindFirstChild = function(self, n)
    if n == "Character" then return char end
    if n == "PlayerGui" then return pg end
    for _, c in ipairs(self:GetChildren()) do
      if c.Name == n then return c end
    end
  end
end

local delay = tonumber(os.getenv("MOCK_CHAR_DELAY") or "0")
if delay > 0 then
  task.spawn(function() task.wait(delay) ; ponPersonaje() end)
elseif os.getenv("MOCK_CHAR") == "1" then
  ponPersonaje()
end
if false then
  local char = Instance.new("Model") ; char.Name = "Tester"
  local hrp = Instance.new("Part") ; hrp.Name = "HumanoidRootPart"
  hrp.Position = Vector3.new(0, 3, 0) ; hrp.Parent = char
  char.Parent = workspace
  plr.Character = char
  plr.FindFirstChild = function(self, n)
    if n == "Character" then return char end
    if n == "PlayerGui" then return pg end
    for _, c in ipairs(self:GetChildren()) do
      if c.Name == n then return c end
    end
  end
end
