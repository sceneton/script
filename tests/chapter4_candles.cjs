// Run: node tests/chapter4_candles.cjs /path/to/luau
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(root,'chapter4.lua'),'utf8');
const controller=source.slice(source.indexOf('local function createCandleAutomation(options)'),source.indexOf('local function createVacuumUpgradePriority'));
const gate=source.slice(source.indexOf('    local candleCutscenePassLogged=false'),source.indexOf('    local function needlePriority()'));
if(!controller||!gate)throw Error('Chapter 4 controller or gate missing');
const fixture=fs.readFileSync(path.join(__dirname,'chapter4_candles.luau'),'utf8').replace('-- INSERT_CONTROLLER',controller).replace('-- INSERT_GATE',gate);
const tmp=path.join(os.tmpdir(),`beyy-candles-${process.pid}.luau`);
try {fs.writeFileSync(tmp,fixture);const r=cp.spawnSync(process.argv[2]||'luau',[tmp],{encoding:'utf8'});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');if(r.error)throw r.error;process.exitCode=r.status??1;}finally{fs.unlinkSync(tmp);}
