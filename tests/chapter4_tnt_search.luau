-- Test actual indexed selection and ballistics against exhaustive nearest selection.
local now,yields,onYield,attributeCost=0,0,nil,0
local os={clock=function()return now end}
local task={wait=function()now+=1/60;yields+=1;if onYield then onYield()end end}
local _G={}
local vmt={}
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},vmt)end
vmt.__index=function(v,k)
    if k=="Magnitude"then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end
    if k=="Unit"then return v/v.Magnitude end
    if k=="Dot"then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
end
vmt.__add=function(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vmt.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vmt.__div=function(a,b)return vec(a.X/b,a.Y/b,a.Z/b)end
vmt.__mul=function(a,b)return vec(a.X*b,a.Y*b,a.Z*b)end
local Vector3={new=vec,zero=vec(0,0,0),yAxis=vec(0,1,0),zAxis=vec(0,0,1)}
local CFrame={lookAt=function(origin,target,up)return {Position=origin,Target=target,Up=up}end}
local function makeSearch()
-- INSERT_SEARCH
    return haySearch,aimHayTnt
end
local function signal()
    local s={listeners={}}
    function s:Connect(fn)
        local c={fn=fn,on=true};function c:Disconnect()self.on=false end
        table.insert(self.listeners,c);return c
    end
    function s:Fire(...)for _,c in ipairs(self.listeners)do if c.on then c.fn(...)end end end
    return s
end
local function part(x,y,z,id,anchored)
    local p={Name="HayPiece",Position=vec(x,y,z),Anchored=anchored~=false,HayId=id,CanQuery=false,signals={Position=signal(),Anchored=signal()}}
    function p:IsA(name)return name=="BasePart"end
    function p:GetAttribute(name)now+=attributeCost;return name=="HayId"and self.HayId or nil end
    function p:GetPropertyChangedSignal(name)return self.signals[name]end
    function p:move(x,y,z,notify)self.Position=vec(x,y,z);if notify~=false then self.signals.Position:Fire()end end
    function p:anchor(on)self.Anchored=on;self.signals.Anchored:Fire()end
    return p
end
local function folder(items)
    local f={Name="HaystackClient",Parent=true,items={},ChildAdded=signal(),ChildRemoved=signal(),AncestryChanged=signal(),reads=0}
    function f:GetChildren()self.reads+=1;return table.clone(self.items)end
    function f:add(p)p.Parent=self;table.insert(self.items,p);self.ChildAdded:Fire(p)end
    function f:remove(p)
        for i,c in ipairs(self.items)do if c==p then table.remove(self.items,i);break end end
        p.Parent=nil;self.ChildRemoved:Fire(p)
    end
    for _,p in ipairs(items or {})do f:add(p)end
    return f
end
local function valid(f,center)
    return function(p)
        if p.Parent~=f or p:GetAttribute("HayId")==nil then return false end
        local d=p.Position-center;return d.X*d.X+d.Z*d.Z>9
    end
end
local function brute(f,center)
    local best,score=nil,math.huge
    for _,p in ipairs(f.items)do if valid(f,center)(p)then
        local d=p.Position-center;local s=d:Dot(d);if s<score then best,score=p,s end
    end end
    return best
end
local function reset()now=0;yields=0;onYield=nil;attributeCost=0;_G={}end
local passed=0
local function test(name,fn)reset();fn();passed+=1;print("PASS "..name)end
test("spatial nearest agrees with exhaustive search over randomized worlds",function()
    local seed=17
    local function nextInt(n)seed=(seed*16807)%2147483647;return seed%n end
    for _=1,25 do
        local items={};for i=1,160 do items[i]=part(nextInt(600)-300,nextInt(160)-80,nextInt(600)-300,i,nextInt(4)~=0)end
        local f=folder(items);local center=vec(nextInt(80)-40,0,nextInt(80)-40);local index=makeSearch()
        assert(index.Nearest(f,center,function()return true end,valid(f,center))==brute(f,center));index.Stop()
    end
end)
test("equal-distance ties keep folder insertion order across cells",function()
    local first,second=part(-8,0,0,1),part(8,0,0,2);local f=folder({first,second});local index=makeSearch()
    assert(index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))==first)
end)
test("height contributes to exact distance, not just planar distance",function()
    local high,near=part(4,100,0,1),part(8,0,0,2);local f=folder({high,near});local index=makeSearch()
    assert(index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))==near)
end)
test("missing IDs and self-collision radius are excluded; CanQuery false is supported",function()
    local target=part(4,0,0,0);local f=folder({part(2,0,0,1),part(3,0,0,2),part(3.5,0,0,nil),target});local index=makeSearch()
    assert(index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))==target)
end)
test("anchored movement updates bucket membership",function()
    local a,b=part(8,0,0,1),part(50,0,0,2);local f=folder({a,b});local index=makeSearch();index.Snapshot(f)
    b:move(-4,0,0)
    assert(index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))==b)
end)
test("unanchored physics movement is read without Position signals",function()
    local a,b=part(8,0,0,1),part(500,0,0,2,false);local f=folder({a,b});local index=makeSearch();index.Snapshot(f)
    b:move(4,0,0,false)
    assert(index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))==b)
end)
test("anchor transitions preserve live nearest selection",function()
    local a,b=part(8,0,0,1),part(500,0,0,2);local f=folder({a,b});local index=makeSearch();index.Snapshot(f)
    b:anchor(false);b:move(4,0,0,false)
    assert(index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))==b)
    b:anchor(true);b:move(100,0,0)
    assert(index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))==a)
end)
test("late children and removal are reflected without rebuilding folder lists",function()
    local a,b=part(8,0,0,1),part(4,0,0,2);local f=folder({a});local index=makeSearch();index.Snapshot(f);local reads=f.reads
    f:add(b);assert(index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))==b)
    f:remove(b);assert(index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))==a);assert(f.reads==reads)
end)
test("cancellation across a budget yield returns no target",function()
    local items={};for i=1,150 do items[i]=part(4+i/100,0,0,i)end
    local f=folder(items);local index=makeSearch();index.Snapshot(f);local allowed=true;attributeCost=0.0001
    onYield=function()allowed=false end
    local target,stats=index.Nearest(f,vec(0,0,0),function()return allowed end,valid(f,vec(0,0,0)))
    assert(target==nil and stats.Cancelled and stats.Yields>0)
end)
test("removing bucket entries during a yield does not invalidate iteration",function()
    local items={};for i=1,150 do items[i]=part(4+i/100,0,0,i)end
    local f=folder(items);local index=makeSearch();index.Snapshot(f);attributeCost=0.0001
    onYield=function()onYield=nil;for i=80,150 do f:remove(items[i])end end
    local target=index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))
    assert(target and target.Parent==f and yields>0)
end)
test("cold index is identified and a warm search reuses it",function()
    local f=folder({part(8,0,0,1)});local index=makeSearch()
    local _,a=index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))
    local _,b=index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))
    assert(not a.IndexWasReady and b.IndexWasReady and f.reads==1)
end)
test("folder replacement releases old connections and stopped index cannot search",function()
    local a=part(8,0,0,1);local one=folder({a});local two=folder({part(5,0,0,2)});local index=makeSearch();index.Snapshot(one)
    assert(index.Nearest(two,vec(0,0,0),function()return true end,valid(two,vec(0,0,0)))==two.items[1])
    for _,s in pairs(a.signals)do for _,c in ipairs(s.listeners)do assert(not c.on)end end
    index.Stop();assert(index.Nearest(two,vec(0,0,0),function()return true end,valid(two,vec(0,0,0)))==nil)
end)
test("preferred target skips search and ballistic endpoint still reaches hay",function()
    local hay=part(8,0,0,1);local f=folder({hay});local _,aim=makeSearch()
    local world={Gravity=196.2,FindFirstChild=function()return f end};local root={Parent=true,Position=vec(0,0,0)}
    local from,v,target,flight,stats=aim(world,{TNT_MIN_THROW_SPEED=20,TNT_MAX_THROW_SPEED=100,TNT_FUSE_TIME=2.9},root,function()return true end,hay)
    assert(from and target==hay and stats.Mode=="Preferred"and f.reads==0)
    local endpoint=from.Position+v*flight+vec(0,-world.Gravity*flight*flight/2,0)
    assert((endpoint-hay.Position).Magnitude<0.00001)
end)
test("removed preferred target is replaced through spatial selection",function()
    local old,new=part(6,0,0,1),part(8,0,0,2);local f=folder({new});local _,aim=makeSearch()
    local from,_,hay,_,stats=aim({Gravity=196.2,FindFirstChild=function()return f end},
        {TNT_MIN_THROW_SPEED=20,TNT_MAX_THROW_SPEED=100}, {Parent=true,Position=vec(0,0,0)},function()return true end,old)
    assert(from and hay==new and stats.Mode=="SpatialNearest")
end)
test("large pile prunes distant cells while keeping the exhaustive nearest target",function()
    local items={}
    for i=1,20000 do items[i]=part(1024+i%200,i%8,1024+math.floor(i/200),i)end
    for i=1,128 do table.insert(items,part(4+i/100,0,0,20000+i))end
    local f=folder(items);local index=makeSearch();index.Snapshot(f)
    local target,stats=index.Nearest(f,vec(0,0,0),function()return true end,valid(f,vec(0,0,0)))
    assert(target==brute(f,vec(0,0,0))and stats.InspectedParts==128 and stats.VisitedCells==1)
    print(string.format("SEARCH WORKLOAD: %d parts inspected instead of %d; same nearest target",stats.InspectedParts,#items))
end)
print(string.format("%d spatial TNT search tests passed",passed))
