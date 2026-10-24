// Run: node tests/chapter4_tnt.cjs /path/to/luau
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const source=fs.readFileSync(path.join(__dirname,'../chapter4.lua'),'utf8');
function section(start,end){const a=source.indexOf(start),b=source.indexOf(end,a);if(a<0||b<a)throw Error('Missing source section '+start);return source.slice(a,b);}
let fixture=fs.readFileSync(path.join(__dirname,'chapter4_tnt.luau'),'utf8');
fixture=fixture.replace('-- INSERT_GATE',section('local function createTntRetryGate(', 'local function createHayTntStep('))
    .replace('-- INSERT_STEP',section('local function createHayTntStep(', 'local function createPumpkinWeakpointResolver('))
    .replace('-- INSERT_RECORDER',section('local function createFeatureDiagnostics(', 'local function createPitchforkSelector('));
const tmp=path.join(os.tmpdir(),`beyy-tnt-${process.pid}.luau`);
try{fs.writeFileSync(tmp,fixture);const r=cp.spawnSync(process.argv[2]||'luau',[tmp],{encoding:'utf8'});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');if(r.error)throw r.error;process.exitCode=r.status??1;}finally{fs.unlinkSync(tmp);}
