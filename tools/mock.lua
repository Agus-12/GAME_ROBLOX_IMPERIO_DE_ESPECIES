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
  o.Destroy=function() end
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
  o.FireClient=function() end
  local proxy
  proxy=setmetatable({},{
    __isinstance=true,
    __index=function(_,k) return o[k] end,
    __newindex=function(_,k,v)
      if k=="Parent" and v~=nil then
        local ch=rawget(v,"_children") or (getmetatable(v) and v._children)
        if ch then table.insert(ch,proxy) end
      end
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
task={spawn=function() end, wait=function() end, delay=function() end, defer=function() end}
function wait() end
warn=function(...) print("WARN:",...) end
math.clamp=function(v,lo,hi) if v<lo then return lo elseif v>hi then return hi end return v end
math.round=function(v) return math.floor(v+0.5) end
