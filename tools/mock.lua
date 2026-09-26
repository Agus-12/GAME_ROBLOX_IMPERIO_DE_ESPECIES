-- SENALES DE VERDAD (v40). Antes: Connect devolvia un Disconnect falso y NO habia
-- Fire, o sea que nada conectado a un evento corria NUNCA en el simulador (falso
-- verde: no se podia probar "aparece una carpeta a media partida").
local function newSignal()
  local s = {_fns = {}}
  function s:Connect(fn)
    local i = #self._fns + 1
    self._fns[i] = fn
    return { Disconnect = function() self._fns[i] = nil end,
             disconnect = function() self._fns[i] = nil end }
  end
  function s:ConnectParallel(fn) return self:Connect(fn) end
  function s:Once(fn) return self:Connect(fn) end
  function s:Wait() return nil end
  function s:Fire(...)
    for _, fn in ipairs(self._fns) do pcall(fn, ...) end
  end
  return s
end
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
-- v46: CFrame.Angles() devolvia un CFrame VACIO y la rotacion se perdia, asi que
-- no se podia probar "¿esta la llanta parada o acostada?". Ahora se ANOTA la
-- rotacion (en radianes) en cf.rot y se va sumando al multiplicar CFrames.
local function sumaRot(a, b)
  a = a or {X=0, Y=0, Z=0}
  b = b or {X=0, Y=0, Z=0}
  return {X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z}
end
local CFmt={}
CFmt.__index=function(t,k)
  if k=="Position" then return t.p end
  if k=="ToObjectSpace" then return function(a,b) return mkCF(Vector3.new()) end end
  if k=="Inverse" then return function(a) return mkCF(Vector3.new()) end end
  if k=="LookVector" then return Vector3.new(0,0,1) end
  return nil end
-- v45: multiplicar CFrames ANTES devolvia el mismo CFrame (el simulador no
-- componia nada), asi que colocar una pieza "respecto al mango" no movia nada y
-- posiciones como la boca del cañon no se podian probar. Ahora compone posiciones
-- (la rotacion se ignora: para lo que se prueba aqui alcanza).
CFmt.__mul=function(a,b)
  if type(b)=="table" and b.p then
    local c = mkCF(Vector3.new(a.p.X+b.p.X, a.p.Y+b.p.Y, a.p.Z+b.p.Z))
    c.rot = sumaRot(a.rot, b.rot)
    return c
  end
  if type(b)=="table" and b.X then
    return Vector3.new(a.p.X+b.X, a.p.Y+b.Y, a.p.Z+b.Z)
  end
  return a end
-- v45: sumarle/restarle un Vector3 a un CFrame ANTES devolvia el mismo CFrame
-- (mover una parte "funcionaba" sin mover nada). Ahora si desplaza.
CFmt.__add=function(a,b)
  if type(b)=="table" and b.X then
    return mkCF(Vector3.new(a.p.X+b.X, a.p.Y+b.Y, a.p.Z+b.Z))
  end
  return a end
CFmt.__sub=function(a,b)
  if type(b)=="table" and b.X then
    return mkCF(Vector3.new(a.p.X-b.X, a.p.Y-b.Y, a.p.Z-b.Z))
  end
  return a end
function mkCF(p) return setmetatable({p=p or Vector3.new()},CFmt) end
CFrame={new=function(x,y,z) if type(x)=="table" then return mkCF(x) end return mkCF(Vector3.new(x,y,z)) end,
  lookAt=function(a,b) return mkCF(a) end,
  Angles=function(x,y,z)
    local c = mkCF()
    c.rot = {X = x or 0, Y = y or 0, Z = z or 0}
    return c
  end,
  fromEulerAnglesXYZ=function(x,y,z)
    local c = mkCF()
    c.rot = {X = x or 0, Y = y or 0, Z = z or 0}
    return c
  end,
  fromOrientation=function(x,y,z)
    local c = mkCF()
    c.rot = {X = math.rad(x or 0), Y = math.rad(y or 0), Z = math.rad(z or 0)}
    return c
  end}
local U2mt={} ; U2mt.__add=function(a,b) return a end ; U2mt.__sub=function(a,b) return a end
UDim2={new=function() return setmetatable({},U2mt) end,
  fromScale=function() return setmetatable({},U2mt) end,
  fromOffset=function() return setmetatable({},U2mt) end}
UDim={new=function() return {} end} ; TweenInfo={new=function() return {} end}
local Instance_={}
-- ===== CLASES VALIDAS DE ROBLOX (v41) =====
-- CASO REAL: el cliente hacia  Instance.new("AutomaticSize")  y AutomaticSize NO es
-- una clase de Roblox (es una PROPIEDAD). En Studio eso TRUENA a media construccion
-- de la interfaz (se dibujaba la barra ancha y el script moria justo despues: el
-- jugador veia el tablero viejo para siempre). El simulador no lo cazo en varias
-- rondas porque aceptaba cualquier nombre inventado. Ahora se compara contra la
-- lista real (tools/clases-roblox.txt) y TRUENA igual que Roblox.
local CLASES_VALIDAS = nil
do
  local ruta = (os.getenv("TOOLS") or ".") .. "/clases-roblox.txt"
  local f = io.open(ruta, "r")
  if f then
    CLASES_VALIDAS = {}
    for linea in f:lines() do
      if linea ~= "" and string.sub(linea, 1, 1) ~= "#" then CLASES_VALIDAS[linea] = true end
    end
    f:close()
  end
end

function Instance_.new(cls,parent)
  if CLASES_VALIDAS and not CLASES_VALIDAS[cls] then
    error('Instance.new("' .. tostring(cls) .. '"): eso NO es una clase de Roblox' ..
      ' (en Studio truena aqui mismo; mira tools/clases.py)', 2)
  end
  local o={ClassName=cls,Name=cls,_children={},_attrs={}}
  -- PROPIEDADES CON VALOR POR DEFECTO (como Roblox)
  -- El mock no las ponia y quedaban en nil. Eso rompia codigo real: por ejemplo
  -- "c.LayoutOrder >= 2" en el HUD del cliente tronaba con "attempt to compare
  -- number with nil" — un error que en Roblox NUNCA pasa (ahi LayoutOrder nace
  -- en 0). Aqui se imita a Roblox para que las pruebas sean de verdad.
  o.LayoutOrder = 0
  -- v45: en Roblox TODA parte nace con CFrame y Size. El mock los dejaba en nil,
  -- asi que armar el arma (que coloca cada pieza tomando como base el CFrame del
  -- mango) tronaba aqui y no se podia probar. Se imita a Roblox.
  do
    local BASEPART = {Part=true, MeshPart=true, WedgePart=true, CornerWedgePart=true,
      TrussPart=true, SpawnLocation=true, Seat=true, VehicleSeat=true,
      UnionOperation=true, PartOperation=true}
    if BASEPART[cls] then
      o.CFrame = mkCF(Vector3.new(0, 0, 0))
      o.Size = Vector3.new(1, 1, 1)
      o.Position = Vector3.new(0, 0, 0)
    end
  end
  o.Visible = true
  o.Enabled = true
  o.Text = ""
  o.ZIndex = 1
  o.Transparency = 0
  o.RichText = false
  o.TextTransparency = 0
  o.BackgroundTransparency = 0
  o.GetChildren=function(s) return s._children end
  -- OJO: GetDescendants en Roblox baja TODOS los niveles. Aqui devolvia solo los
  -- hijos directos: el simulador decia "GetDescendants" y los scripts que
  -- recorrian a fondo (limpieza de empleados, inventario, conteo de luces) se
  -- probaban solo UN nivel. Un falso verde mas. Ahora baja de verdad.
  o.GetDescendants=function(s)
    local todo={}
    local function baja(n)
      for _,c in ipairs(n:GetChildren()) do
        table.insert(todo,c)
        baja(c)
      end
    end
    baja(s)
    return todo
  end
  -- v47: el segundo argumento de FindFirstChild (buscar en DESCENDIENTES) se
  -- ignoraba. Eso escondia medio mundo: `model:FindFirstChild("GateLeft", true)`
  -- devolvia nil porque la hoja del porton vive dentro de una carpeta, asi que el
  -- codigo caia en su camino de respaldo y las pruebas medían OTRA COSA (la cinta
  -- gigante se veia "bien" porque nunca se ejecutaba la rama del porton).
  -- OJO con el nombre: en Roblox es `FindFirstChild(name, recursive)`.
  o.FindFirstChild=function(s,n,recursivo)
    for _,c in ipairs(s._children) do if c.Name==n then return c end end
    if recursivo then
      for _,c in ipairs(s._children) do
        local ok, hallado = pcall(function() return c:FindFirstChild(n, true) end)
        if ok and hallado then return hallado end
      end
    end
  end
  o.FindFirstChildWhichIsA=function(s) return s._children[1] end
  o.FindFirstChildOfClass=function(s,c) for _,x in ipairs(s._children) do if x.ClassName==c then return x end end end
  -- IsA en Roblox contempla la HERENCIA (un Frame es un GuiObject). El mock
  -- comparaba solo el nombre exacto, asi que "c:IsA(\"GuiObject\")" daba FALSO
  -- para todo: el codigo que muestra/oculta filas del HUD se probaba... sin
  -- probarse (falso verde que escondio que la columna del HUD nunca se veia).
  local GUI_OBJ = {Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,
    ImageButton=true,ScrollingFrame=true,ViewportFrame=true,TextBox=true,
    CanvasGroup=true}
  local GUI_BASE = {ScreenGui=true,SurfaceGui=true,BillboardGui=true}
  o.IsA=function(s,t)
    if t == s.ClassName or t == "Instance" then return true end
    if t == "GuiObject" then return GUI_OBJ[s.ClassName] == true end
    if t == "GuiBase2d" or t == "LayerCollector" or t == "GuiBase" then
      return GUI_OBJ[s.ClassName] == true or GUI_BASE[s.ClassName] == true
    end
    if t == "BasePart" then return s.ClassName == "Part" end
    if t == "Light" then return s.ClassName == "PointLight" or s.ClassName == "SpotLight" end
    if t == "LuaSourceContainer" then
      local c = s.ClassName
      return c == "Script" or c == "LocalScript" or c == "ModuleScript"
    end
    return false
  end
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
  -- v47: PivotTo SOLO guardaba el CFrame en el modelo; las PIEZAS no se movian.
  -- Eso escondia todo lo que depende de donde queda un modelo: una bodega vecina
  -- "colocada" en su lote seguia midiendo en el origen, asi que la cinta gigante
  -- (que se coloca mal justo por ignorar el lote) pasaba como si estuviera bien.
  -- Ahora PivotTo MUEVE de verdad todas las piezas (respeta la rotacion en Y).
  o.GetPivot=function(s)
    if not s._cf then
      local pp = s.PrimaryPart
      s._cf = (pp and pp.CFrame) or mkCF()
    end
    return s._cf
  end
  o.PivotTo=function(s,cf)
    local antes = s:GetPivot()
    local d = cf.p - antes.p
    local girar = (cf.rot and cf.rot.Y) or 0
    s._cf = cf
    local function mueve(inst)
      local hijos = inst:GetChildren()
      for _, c in ipairs(hijos) do
        local esParte = false
        for _, n in ipairs({"Part","MeshPart","WedgePart","TrussPart","Seat","VehicleSeat",
                            "SpawnLocation","UnionOperation","PartOperation"}) do
          if c.ClassName == n then esParte = true break end
        end
        if esParte then
          local rel = c.Position - antes.p
          local nx, nz = rel.X, rel.Z
          if girar ~= 0 then
            local ca, sa = math.cos(girar), math.sin(girar)
            nx, nz = rel.X * ca - rel.Z * sa, rel.X * sa + rel.Z * ca
          end
          c.Position = Vector3.new(cf.p.X + nx, cf.p.Y + rel.Y, cf.p.Z + nz)
          local r = c.CFrame.rot or {X = 0, Y = 0, Z = 0}
          c.CFrame.rot = {X = r.X, Y = r.Y + girar, Z = r.Z}
        end
        mueve(c)
      end
    end
    mueve(s)
  end
  o.Clone=function(s) return Instance_.new(s.ClassName) end
  o.WaitForChild=function(s,n) return s:FindFirstChild(n) end
  o.GetPropertyChangedSignal=function() return newSignal() end
  o.LoadAnimation=function() return {Play=function() end,Looped=false,Priority=0} end
  o.MoveTo=function() end ; o.Play=function() end ; o.Stop=function() end
  -- asientos: en Roblox  seat:Sit(humanoid)  sienta al personaje. Sin esto, las
  -- pruebas no podian comprobar que "Sacar y conducir" te deja manejando.
  o.Sit=function(s, hum) if hum then s.Occupant = hum end return true end
  o.SitOccupant=function(s) return s.Occupant end
  o.MoveToFinished=newSignal() ; o.Died=newSignal()
  o.AncestryChanged=newSignal() ; o.Completed=newSignal()
  o.MouseButton1Click=newSignal() ; o.OnClientEvent=newSignal() ; o.Touched=newSignal()
  o.OnServerEvent=newSignal() ; o.Activated=newSignal() ; o.Equipped=newSignal()
  o.ChildAdded=newSignal() ; o.CharacterAdded=newSignal()
  -- ProximityPrompt: en Roblox trae Triggered/PromptShown/PromptHidden. El
  -- simulador no los tenia y por eso los botones (bici, "Sacar y conducir",
  -- portones) TRONABAN en las pruebas y esas partes quedaban sin revisar.
  o.Triggered=newSignal() ; o.PromptShown=newSignal() ; o.PromptHidden=newSignal()
  -- GuiObject: se usan para "toca la pantalla para entrar" y hover
  o.InputBegan=newSignal() ; o.InputEnded=newSignal() ; o.InputChanged=newSignal()
  o.MouseEnter=newSignal() ; o.MouseLeave=newSignal() ; o.SelectionGained=newSignal()
  o.Activated=newSignal() ; o.ChildRemoved=newSignal() ; o.Changed=newSignal()
  o.AttributeChanged=newSignal()
  -- los RemoteEvent/RemoteFunction del simulador no traian FireAllClients: los
  -- push del servidor tronaban dentro de un task.spawn y el error se veia solo
  -- como "!! error en un task.spawn", sin decir de donde salia. Y ademas, para
  -- poder probar LA PANTALLA, disparar un remoto tiene que llegar al manejador
  -- del cliente (OnClientEvent) igual que en el juego.
  o.FireClient=function(s, ...) local sig = s.OnClientEvent ; if sig and sig.Fire then sig:Fire(...) end end
  o.FireAllClients=function(s, ...) local sig = s.OnClientEvent ; if sig and sig.Fire then sig:Fire(...) end end
  o.Fire=function(s, ...) local sig = s.OnServerEvent ; if sig and sig.Fire then sig:Fire(...) end end
  o.InvokeClient=function(s, ...) local f = s.OnClientInvoke ; if type(f) == "function" then return f(...) end end
  o.InvokeServer=function(s, ...) local f = s.OnServerInvoke ; if type(f) == "function" then return f(...) end end
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
          -- Roblox dispara ChildAdded al poner Parent (el mock no lo hacia)
          pcall(function()
            local sig = v.ChildAdded
            if sig and sig.Fire then sig:Fire(proxy) end
          end)
        end
      end
      -- POSICION y CFRAME van JUNTOS (como en Roblox: son la misma cosa).
      -- El mock no lo hacia: las piezas creadas con Position no tenian CFrame,
      -- asi que codigo real que guarda "piece.CFrame" (el porton del garaje,
      -- que lo necesita para enrollarse) se veia como si no guardara nada.
      -- Eso apagaba la prueba del garaje sin que nadie se diera cuenta.
      if k == "Position" and type(v) == "table" and v.X then
        o[k] = v
        o.CFrame = mkCF(v)
      elseif k == "CFrame" and type(v) == "table" and v.Position then
        o[k] = v
        o.Position = v.Position
        o.Rotation = v.Rotation
        if v.rot then o.rot = v.rot end
      else
        o[k]=v
      end
      if k ~= "_parentChildren" and __ON_SET then pcall(__ON_SET, o, k, v) end
    end})
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
    -- v46: las ETIQUETAS eran de mentiras (AddTag no guardaba NADA y GetTagged
    -- devolvia vacio). Con eso, el sistema de luces de noche (lo que se enciende
    -- y se apaga segun la hora) se veia "perfecto" en las pruebas SIN encender ni
    -- apagar nada: la clase de bug que el simulador debe cazar, no tapar.
    -- Ahora las etiquetas se guardan de verdad.
    local TAGS = {}
    _G.__TAGS = TAGS
    s.AddTag = function(_, inst, tag)
      if type(inst) == "table" and type(tag) == "string" then
        TAGS[tag] = TAGS[tag] or {}
        TAGS[tag][inst] = true
      end
    end
    s.RemoveTag = function(_, inst, tag)
      if TAGS[tag] then TAGS[tag][inst] = nil end
    end
    s.HasTag = function(_, inst, tag)
      return TAGS[tag] ~= nil and TAGS[tag][inst] == true
    end
    s.GetTagged = function(_, tag)
      local out = {}
      for inst in pairs(TAGS[tag] or {}) do table.insert(out, inst) end
      return out
    end
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
    -- StarterPlayer trae DOS carpetas adentro en Roblox (StarterPlayerScripts y
    -- StarterCharacterScripts). El mock no las tenia, asi que los chequeos del
    -- servidor sobre la ClientUI (v38) nunca encontraban nada al probarlos.
    if n == "StarterPlayer" then
      local sps = Instance_.new("StarterPlayerScripts") ; sps.Parent = s
      local scs = Instance_.new("StarterCharacterScripts") ; scs.Parent = s
    end
    s.GetDataStore=function() return {GetAsync=function() return nil end,SetAsync=function() end} end
    s.Create=function() return {Play=function() end,Completed=newSignal()} end
    s.CreatePath=function() return {ComputeAsync=function() end,Status=nil,GetWaypoints=function() return {} end} end
    s.Raycast=function() return nil end
    services[n]=s
  end
  return services[n] end
game={GetService=function(_,n) return svc(n) end, BindToClose=function() end}
-- game:GetDescendants() en Roblox recorre TODO el lugar (DataModel). El
-- simulador no lo tenia y por eso el INVENTARIO DE ARCHIVOS de la v35 salia
-- vacio al probarlo (falso verde). Aqui se recorre cada servicio registrado.
game.GetDescendants=function()
  local todo={}
  for _,s in pairs(services) do
    table.insert(todo,s)
    for _,c in ipairs(s:GetChildren()) do
      table.insert(todo,c)
      local ok,hijos=pcall(function() return c:GetDescendants() end)
      if ok and hijos then
        for _,h in ipairs(hijos) do table.insert(todo,h) end
      end
    end
  end
  return todo
end
game.GetChildren=function()
  local todo={}
  for n,s in pairs(services) do table.insert(todo, s) end
  return todo
end
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
-- señales de verdad disponibles para mockclient y para las pruebas: las señales
-- falsas (Connect que no guarda nada y sin Fire) escondian bugs (leccion v40).
_G.__newSignal = newSignal

-- OJO (v42): os.clock() tambien va con el reloj VIRTUAL. Los scripts usan
-- os.clock() para los enfriamientos ("no repitas el aviso antes de 14 s") y
-- con el reloj de verdad (tiempo de CPU) esas esperas NUNCA pasaban en las
-- pruebas: el oficial se quedaba con el primer aviso para siempre y la prueba
-- no alcanzaba a ver el segundo. En Roblox os.clock() es el tiempo desde que
-- arranco el servidor; aqui es el tiempo de la simulacion.
os.clock = function() return SCHED.vtime end
function wait() end
warn=function(...) print("WARN:",...) end
math.clamp=function(v,lo,hi) if v<lo then return lo elseif v>hi then return hi end return v end
math.round=function(v) return math.floor(v+0.5) end
