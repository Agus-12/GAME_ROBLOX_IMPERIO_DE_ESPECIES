local function newSignal() return {Connect=function() return {Disconnect=function() end} end} end
Enum=setmetatable({},{__index=function(t,k)
  local e=setmetatable({},{__index=function(_,k2) return {Name=k2,Value=0} end})
  rawset(t,k,e); return e end})
local function C3(r,g,b) return {R=r,G=g,B=b} end
Color3={fromRGB=C3,new=C3}
ColorSequence={new=function() return {} end} ; ColorSequenceKeypoint={new=function() return {} end}
PhysicalProperties={new=function() return {} end}
local V3mt={}
V3mt.__index=function(t,k)
  if k=="Magnitude" then return math.sqrt(t.X^2+t.Y^2+t.Z^2) end
  if k=="Unit" then local m=math.sqrt(t.X^2+t.Y^2+t.Z^2); if m==0 then m=1 end
    return Vector3.new(t.X/m,t.Y/m,t.Z/m) end
  if k=="Lerp" then return function(a,b,al)
    return Vector3.new(a.X+(b.X-a.X)*al,a.Y+(b.Y-a.Y)*al,a.Z+(b.Z-a.Z)*al) end end
  return nil end
V3mt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V3mt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V3mt.__mul=function(a,b) if type(b)=="number" then return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
  return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z) end
V3mt.__unm=function(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
Vector3={new=function(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V3mt) end}
Vector3.zero=Vector3.new(0,0,0)
Vector2={new=function(x,y) return {X=x or 0,Y=y or 0} end}
local CFmt={}
CFmt.__index=function(t,k)
  if k=="Position" then return t.p end
  if k=="ToObjectSpace" then return function(a,b) return mkCF(Vector3.new()) end end
  if k=="Inverse" then return function(a) return mkCF(Vector3.new()) end end
  if k=="LookVector" then return Vector3.new(0,0,1) end
  return nil end
CFmt.__mul=function(a,b) return a end
CFmt.__add=function(a,b) return a end ; CFmt.__sub=function(a,b) return a end
function mkCF(p) return setmetatable({p=p or Vector3.new()},CFmt) end
CFrame={new=function(x,y,z) if type(x)=="table" then return mkCF(x) end return mkCF(Vector3.new(x,y,z)) end,
  lookAt=function(a,b) return mkCF(a) end, Angles=function() return mkCF() end}
local U2mt={} ; U2mt.__add=function(a,b) return a end ; U2mt.__sub=function(a,b) return a end
UDim2={new=function() return setmetatable({},U2mt) end,
  fromScale=function() return setmetatable({},U2mt) end,
  fromOffset=function() return setmetatable({},U2mt) end}
UDim={new=function() return {} end} ; TweenInfo={new=function() return {} end}
local Instance_={}
function Instance_.new(cls,parent)
  local o={ClassName=cls,Name=cls,_children={},_attrs={}}
  o.GetChildren=function(s) return s._children end
  o.GetDescendants=function(s) return s._children end
  o.FindFirstChild=function(s,n) for _,c in ipairs(s._children) do if c.Name==n then return c end end end
  o.FindFirstChildWhichIsA=function(s) return s._children[1] end
  o.FindFirstChildOfClass=function(s,c) for _,x in ipairs(s._children) do if x.ClassName==c then return x end end end
  o.IsA=function(s,t) return s.ClassName==t end
  -- Destroy de verdad: antes era una funcion vacia, asi que el simulador
  -- nunca podia detectar si el juego limpiaba o no lo que ya no sirve
  -- (justo el bug de "todo sale doble"). Ahora desparenta como Roblox.
  o.Destroy=function(s)
    local pc = s._parentChildren
    if pc then
      for i = #pc, 1, -1 do if pc[i] == s then table.remove(pc, i) end end
    end
    s._parentChildren = nil
    o.Parent = nil
  end
  o.SetAttribute=function(s,k,v) s._attrs[k]=v end
  o.GetAttribute=function(s,k) return s._attrs[k] end
  o.PivotTo=function(s,cf) s._cf=cf end
  o.GetPivot=function(s) return s._cf or mkCF() end
  o.Clone=function(s) return Instance_.new(s.ClassName) end
  o.WaitForChild=function(s,n) return s:FindFirstChild(n) end
  o.GetPropertyChangedSignal=function() return newSignal() end
  o.LoadAnimation=function() return {Play=function() end,Looped=false,Priority=0} end
  o.MoveTo=function() end ; o.Play=function() end ; o.Stop=function() end
  o.MoveToFinished=newSignal() ; o.Died=newSignal()
  o.AncestryChanged=newSignal() ; o.Completed=newSignal()
  o.MouseButton1Click=newSignal() ; o.OnClientEvent=newSignal() ; o.Touched=newSignal()
  o.OnServerEvent=newSignal() ; o.Activated=newSignal() ; o.Equipped=newSignal()
  o.ChildAdded=newSignal() ; o.CharacterAdded=newSignal()
  -- GuiObject: se usan para "toca la pantalla para entrar" y hover
  o.InputBegan=newSignal() ; o.InputEnded=newSignal() ; o.InputChanged=newSignal()
  o.MouseEnter=newSignal() ; o.MouseLeave=newSignal() ; o.SelectionGained=newSignal()
  o.Activated=newSignal() ; o.ChildRemoved=newSignal() ; o.Changed=newSignal()
  o.AttributeChanged=newSignal()
  o.FireClient=function() end
  local proxy
  proxy=setmetatable({},{
    __isinstance=true,
    __index=function(_,k) return o[k] end,
    __newindex=function(_,k,v)
      if k=="Parent" and v~=nil then
        local ch=rawget(v,"_children") or (getmetatable(v) and v._children)
        if ch then
          table.insert(ch,proxy)
          o._parentChildren = ch      -- para que Destroy pueda desparentar
        end
      end
      if k ~= "_parentChildren" and __ON_SET then pcall(__ON_SET, o, k, v) end
      o[k]=v end})
  if parent then proxy.Parent=parent end
  return proxy
end
Instance=Instance_
-- typeof() de Roblox: distingue una Instance de una tabla normal. Lo usa
-- ClientUI para saber si Remotes es de verdad una carpeta o un sustituto.
function typeof(v)
  if type(v)=="table" then
    local mt=getmetatable(v)
    if mt and mt.__isinstance then return "Instance" end
  end
  return type(v)
end
local services={}
local function svc(n)
  if not services[n] then
    local s=Instance_.new(n)
    s.GetTagged=function() return {} end
    s.AddTag=function() end; s.RemoveTag=function() end; s.HasTag=function() return false end
    s.GetPlayers=function() return {} end
    s.PlayerAdded=newSignal(); s.PlayerRemoving=newSignal(); s.Heartbeat=newSignal()
    s.IsStudio=function() return true end
    -- Lighting: los scripts leen/escriben ClockTime, Brightness, etc.
    if n == "Lighting" then
      s.ClockTime = 14 ; s.Brightness = 2 ; s.GlobalShadows = true
      s.Ambient = Color3.fromRGB(42,44,54)
      s.OutdoorAmbient = Color3.fromRGB(70,70,80)
      s.FogColor = Color3.fromRGB(120,120,130) ; s.FogEnd = 4000
      s.EnvironmentDiffuseScale = 0 ; s.EnvironmentSpecularScale = 0
      s.ExposureCompensation = 0 ; s.GeographicLatitude = 20
      s.ClockTimeChanged = newSignal()
    end
    s.GetDataStore=function() return {GetAsync=function() return nil end,SetAsync=function() end} end
    s.Create=function() return {Play=function() end,Completed=newSignal()} end
    s.CreatePath=function() return {ComputeAsync=function() end,Status=nil,GetWaypoints=function() return {} end} end
    s.Raycast=function() return nil end
    services[n]=s
  end
  return services[n] end
game={GetService=function(_,n) return svc(n) end, BindToClose=function() end}
workspace=svc("Workspace")
RaycastParams={new=function() return {} end}
Random={new=function(seed) local r={}; math.randomseed(seed or 1)
  r.NextNumber=function(_,a,b) if not a then return math.random() end return a+math.random()*(b-a) end
  r.NextInteger=function(_,a,b) return math.random(a,b) end
  return r end}
--------------------------------------------------------------------
-- PLANIFICADOR con RELOJ VIRTUAL
--------------------------------------------------------------------
-- Antes: task.spawn no hacia nada y task.wait no esperaba NADA. Eso hacia
-- que el simulador mintiera: el bucle de la portada ("Cargando la ciudad...")
-- recorria sus 30 intentos al instante, asi que un bug REAL de 12 segundos
-- atrapado en la portada se veia perfecto en las pruebas. Justo lo que le
-- paso al usuario.
--
-- Ahora: task.spawn crea corrutinas de verdad, task.wait suspende la corrutina
-- y 'avanza' el tiempo virtual. __SCHED.advance(segundos) corre todo lo que
-- toque. Asi se puede MEDIR cuanto tarda algo en pantalla (tools/intro.py).
local SCHED = {threads = {}, vtime = 0}
SCHED.__index = SCHED

local function addThread(fn, ...)
	if type(fn) ~= "function" then return end
	local co = coroutine.create(fn)
	table.insert(SCHED.threads, {co = co, wake = SCHED.vtime, args = {...}})
	return co
end

task = task or {}
task.spawn = function(fn, ...) return addThread(fn, ...) end
task.defer = function(fn, ...) return addThread(fn, ...) end
task.delay = function(t, fn, ...)
	-- OJO: '...' no se ve dentro de la funcion de abajo (no es vararg), hay que
	-- copiarlo a una tabla antes
	local extras = {...}
	return addThread(function()
		task.wait(t or 0)
		if type(fn) == "function" then fn(table.unpack(extras)) end
	end)
end
task.wait = function(t)
	if coroutine.isyieldable() then
		coroutine.yield(SCHED.vtime + (t or 0))
	end
	return t or 0
end

-- corre los hilos pendientes hasta 'hasta' segundos virtuales
function SCHED.advance(hasta)
	hasta = hasta or (SCHED.vtime + 1)
	local guard = 0
	while true do
		local listo = nil
		for _, t in ipairs(SCHED.threads) do
			if not t.dead and t.wake <= hasta and (listo == nil or t.wake < listo.wake) then
				listo = t
			end
		end
		if not listo then break end
		SCHED.vtime = math.max(SCHED.vtime, listo.wake)
		local ok, err = coroutine.resume(listo.co, table.unpack(listo.args or {}))
		listo.args = nil
		if not ok then
			print("!! error en un task.spawn: " .. tostring(err))
			listo.dead = true
		elseif coroutine.status(listo.co) == "dead" then
			listo.dead = true
		else
			-- se volvio a dormir: regresa el instante en que despierta
			local wake = err
			listo.wake = (type(wake) == "number") and wake or (SCHED.vtime + 0.1)
		end
		guard = guard + 1
		if guard > 200000 then
			print("!! el planificador se quedo dando vueltas (posible bucle sin task.wait)")
			break
		end
	end
	SCHED.vtime = math.max(SCHED.vtime, hasta)
	return SCHED.vtime
end

task.__sched = SCHED
function wait() end
warn=function(...) print("WARN:",...) end
math.clamp=function(v,lo,hi) if v<lo then return lo elseif v>hi then return hi end return v end
math.round=function(v) return math.floor(v+0.5) end
