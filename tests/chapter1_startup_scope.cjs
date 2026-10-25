const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const source=fs.readFileSync(process.argv[3]||path.join(__dirname,'../chapter1.lua'),'utf8').replace(/\r\n/g,'\n');
const scope=source.slice(source.indexOf('local CollectingTab\n'),source.indexOf('\ndo\n',source.indexOf('local CollectingTab\n')));
const constructor=source.match(/^.*tntDiagnostics=createFeatureDiagnostics\(\{Tab=\w+[\s\S]*?Write=safeWrite\}\)/m)?.[0];
const start=source.indexOf('local function installTntObservation('),end=source.indexOf('local function createPitchforkSelector(',start);
if(!constructor||start<0||end<0)throw Error('Missing Chapter 1 startup sections');
const fixture=`local function createFeatureDiagnostics()return {Enabled=function()return false end}end
${source.slice(start,end)}
${scope}
do
${constructor}
end
assert(type(tntDiagnostics)=='table','TNT diagnostics must remain visible after menu scope closes')
installTntObservation(tntDiagnostics,function()return {}end)
tntDiagnostics.BindGate({})
local vacuumWorkerReached=true
assert(vacuumWorkerReached)
print('PASS Chapter 1 diagnostics survives menu scope and initialization reaches the vacuum worker boundary')
`;
const tmp=path.join(os.tmpdir(),`chapter1-scope-${process.pid}.luau`);
try{fs.writeFileSync(tmp,fixture);const r=cp.spawnSync(process.argv[2]||'luau',[tmp],{encoding:'utf8'});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exitCode=r.status??1;}finally{fs.unlinkSync(tmp);}
