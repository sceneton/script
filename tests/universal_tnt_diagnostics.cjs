const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),os=require('node:os');
const root=process.argv[3]||path.join(__dirname,'..');
for(const chapter of ['chapter1','chapter2','chapter3','lobby']){
 const source=fs.readFileSync(path.join(root,chapter+'.lua'),'utf8');
 const a=source.indexOf('local function installTntObservation('),b=source.indexOf('local function createPitchforkSelector(',a);
 if(a<0||b<a)throw Error(chapter+' missing observation adapter');
 const fixture=`local now=0
local os={clock=function()return now end}
${source.slice(a,b)}
local events,on={},true
local d={Enabled=function()return on end,Status=function()end}
function d.Record(kind,data)if on then events[#events+1]={Kind=kind,Data=data}end end
local reason='Cutscene';local readyAt=5
installTntObservation(d,function()return {BlockReason=reason}end)
d.BindGate({DiagnosticSnapshot=function()return {PredictedReadyAt=readyAt}end})
assert(not d.Probe().CooldownBlocks.Current)
now=5;assert(d.Probe().CooldownBlocks.Current.BlockedAfterCooldownSeconds==0)
now=10;assert(d.Probe().CooldownBlocks.Current.BlockedAfterCooldownSeconds==5)
assert(events[#events].Kind=='CooldownBlockOngoing')
reason='Needle';local s=d.Probe();assert(s.CooldownBlocks.LastCompleted.BlockedAfterCooldownSeconds==5)
now=40;s=d.Probe();assert(s.CooldownBlocks.Current.BlockedAfterCooldownSeconds==30)
reason=nil;s=d.Probe();assert(not s.CooldownBlocks.Current and s.CooldownBlocks.LastCompleted.EndReason=='Block cleared')
reason='Cutscene';d.Probe();readyAt=50;s=d.Probe();assert(not s.CooldownBlocks.Current and s.CooldownBlocks.LastCompleted.EndReason=='Cooldown prediction moved')
now=50;d.Probe();on=false;s=d.Probe();assert(not s.CooldownBlocks.Current)
local a,b,c=d.MeasureAim('Search',function()return 'from',nil,'hay' end)
assert(a=='from' and b==nil and c=='hay')
on=true;local ok=pcall(d.MeasureAim,'Search',function()error('search failed')end)
assert(not ok and events[#events].Kind=='WorkerError')
print('PASS ${chapter}: block durations, transitions, prediction changes, disabled capture, aim return values and errors')
`;
 const tmp=path.join(os.tmpdir(),`tnt-universal-${process.pid}.luau`);
 try{fs.writeFileSync(tmp,fixture);const r=cp.spawnSync(process.argv[2]||'luau',[tmp],{encoding:'utf8'});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');if(r.status!==0)process.exit(r.status||1);}finally{fs.unlinkSync(tmp);}
}
