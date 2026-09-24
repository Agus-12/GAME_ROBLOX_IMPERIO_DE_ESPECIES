local TOOLS = os.getenv("TOOLS") or "."
dofile(TOOLS .. "/mock.lua")
local function newSignal() return {Connect=function() return {Disconnect=function() end} end} end
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
local remotes = Instance.new("Folder") ; remotes.Name="Remotes" ; remotes.Parent=rs
local NEEDED={"StateUpdate","PhoneAlert","Toast","MissionUpdate","IncomingCall","OpenUpgrades","OpenVault","Sfx","Shoot","TerritoryUpdate","Action"}
for _,n in ipairs(NEEDED) do
  local e=Instance.new(n=="Action" and "RemoteFunction" or "RemoteEvent")
  e.Name=n ; e.OnClientEvent=newSignal()
  if n == "Action" and os.getenv("MOCK_SERVER_MUDO") == "1" then
    -- servidor atorado (por ejemplo esperando a DataStore): la llamada NUNCA
    -- regresa. Es el caso que dejaba la portada en "Cargando la ciudad..."
    e.InvokeServer=function() while true do task.wait(1) end end
  else
    e.InvokeServer=function() return {ok=true} end
  end
  e.Parent=remotes end
local cfgSrc = dofile(TOOLS .. "/cfgload.lua")
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
