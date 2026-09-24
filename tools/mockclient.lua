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
plr.WaitForChild = function(s,n)
  local c=s:FindFirstChild(n) ; if c then return c end
  local o=Instance.new("Folder") ; o.Name=n ; o.Parent=s ; return o end
local pg = Instance.new("PlayerGui") ; pg.Name="PlayerGui" ; pg.Parent=plr
game:GetService("Players").LocalPlayer = plr
local rs = game:GetService("ReplicatedStorage")
local remotes = Instance.new("Folder") ; remotes.Name="Remotes" ; remotes.Parent=rs
local NEEDED={"StateUpdate","PhoneAlert","Toast","MissionUpdate","IncomingCall","OpenUpgrades","OpenVault","Sfx","Action"}
for _,n in ipairs(NEEDED) do
  local e=Instance.new(n=="Action" and "RemoteFunction" or "RemoteEvent")
  e.Name=n ; e.OnClientEvent=newSignal() ; e.InvokeServer=function() return {ok=true} end
  e.Parent=remotes end
local cfgSrc = dofile(TOOLS .. "/cfgload.lua")
rs.WaitForChild=function(s,n)
  if n=="Remotes" then return remotes end
  if n=="GameConfig" then return "__CFG__" end
  return s:FindFirstChild(n) end
require=function(x) if x=="__CFG__" then return cfgSrc end return {} end
