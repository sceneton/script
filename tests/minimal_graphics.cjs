const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=process.argv[3]||path.join(__dirname,'..');
let helper;
for(const name of ['chapter1','chapter2','chapter3','chapter4','lobby']){
 const s=fs.readFileSync(path.join(root,name+'.lua'),'utf8').replace(/\r\n/g,'\n');
 const a=s.indexOf('local function installMinimalGraphics('),b=s.indexOf('local function installUniversalWinsRecorder(',a);
 if(a<0||b<0)throw Error('Missing helper in '+name);
 const current=s.slice(a,b);
 if(helper&&helper!==current)throw Error('Divergent helper in '+name);
 helper=current;
 if(!s.includes('installMinimalGraphics('+(name==='chapter1'?'MainTab':'overviewTab')+', Registry)'))throw Error('Missing Overview wiring in '+name);
}
const fixture=fs.readFileSync(path.join(__dirname,'minimal_graphics.luau'),'utf8').replace('-- INSERT_HELPER',()=>helper);
const tmp=path.join(os.tmpdir(),`beyy-graphics-${process.pid}.luau`);
try{fs.writeFileSync(tmp,fixture);const r=cp.spawnSync(process.argv[2]||'luau',[tmp],{encoding:'utf8'});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exitCode=r.status??1;}finally{fs.unlinkSync(tmp);}
