local function signal()
    local listeners={}
    return {Connect=function(_,fn)
        local c={Connected=true};function c:Disconnect()self.Connected=false end
        listeners[#listeners+1]={Fn=fn,Connection=c};return c
    end,Fire=function(_,object)for _,l in ipairs(listeners)do if l.Connection.Connected then l.Fn(object)end end end}
end
local function object(class,values)
    local o=values or {};o.ClassName=class;o.Children={};o.DescendantAdded=signal()
    function o:IsA(kind)return self.ClassName==kind or kind=='BasePart'and self.ClassName=='MeshPart' or kind=='PostEffect'and self.ClassName=='BloomEffect' end
    function o:FindFirstChildOfClass(kind)for _,child in ipairs(self.Children)do if child:IsA(kind)then return child end end end
    function o:IsDescendantOf(parent)local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false end
    function o:GetDescendants()local t={};local function scan(p)for _,c in ipairs(p.Children)do t[#t+1]=c;scan(c)end end;scan(self);return t end
    function o:Add(child)child.Parent=self;self.Children[#self.Children+1]=child;self.DescendantAdded:Fire(child);return child end
    return o
end
local world=object('Workspace');local lighting=object('Lighting',{GlobalShadows=true})
local terrain=world:Add(object('Terrain',{WaterWaveSize=1,WaterWaveSpeed=2,WaterReflectance=0.5,WaterTransparency=0.2}))
local part=world:Add(object('MeshPart',{Material='Wood',Reflectance=0.5,CastShadow=true,RenderFidelity='Precise',TextureID='texture'}))
local decal=world:Add(object('Decal',{Transparency=0.25}))
local effect=lighting:Add(object('BloomEffect',{Enabled=true}))
local character=world:Add(object('Model'));character:Add(object('Humanoid'))
local body=character:Add(object('BasePart',{Material='Wood',Reflectance=0.2,CastShadow=true}))
local ui=world:Add(object('ImageLabel',{Image='ui',Visible=true}))
local quality={SavedQualityLevel='Automatic'}
local players={GetPlayers=function()return {{Character=character}}end}
local game={GetService=function(_,name)return ({Workspace=world,Lighting=lighting,Players=players})[name]end}
local function UserSettings()return {GetService=function()return quality end}end
local Enum={Material={Plastic='Plastic'},RenderFidelity={Performance='Performance'},SavedQualitySetting={QualityLevel1='Low'}}
local jobs={};local task={spawn=function(fn)jobs[#jobs+1]=fn end,defer=function(fn)jobs[#jobs+1]=fn end,wait=function()end}
local function drain()while #jobs>0 do table.remove(jobs,1)()end end
local _G={};local callback;local tab={Toggle=function(_,options)callback=options.Callback;return options end}
-- INSERT_HELPER
local registry={};installMinimalGraphics(tab,registry)
assert(registry.MinimalGraphics.Value==false)
assert(part.Material=='Wood'and lighting.GlobalShadows)
callback(true);drain()
assert(part.Material=='Plastic'and part.TextureID==''and not part.CastShadow)
assert(decal.Transparency==1 and not effect.Enabled and quality.SavedQualityLevel=='Low')
assert(body.Material=='Wood'and body.CastShadow and ui.Image=='ui'and ui.Visible)
local streamed=world:Add(object('ParticleEmitter',{Enabled=true}));drain();assert(not streamed.Enabled)
callback(false);assert(part.Material=='Wood'and part.TextureID=='texture'and part.CastShadow)
assert(decal.Transparency==0.25 and effect.Enabled and streamed.Enabled and quality.SavedQualityLevel=='Automatic')
assert(terrain.WaterWaveSize==1 and terrain.WaterTransparency==0.2 and lighting.GlobalShadows)
callback(true);callback(false);drain();assert(part.Material=='Wood')
callback(true);drain();_G.__BEYY_HUB_CLEANUP();assert(part.Material=='Wood'and lighting.GlobalShadows)
local late=world:Add(object('ParticleEmitter',{Enabled=true}));drain();assert(late.Enabled)
callback(true);drain();assert(part.Material=='Wood')
print('PASS default off, graphics reduction, characters/UI preserved, streamed effects, restoration, cancellation and unload cleanup')
