// Run: node tests/chapter4_tnt_search.cjs /path/to/luau
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const source=fs.readFileSync(path.join(__dirname,'../chapter4.lua'),'utf8');
const a=source.indexOf('local haySearch = (function()'),b=source.indexOf('local selectPitchforkHay,',a);
if(a<0||b<a)throw Error('Hay index/aim source not found');
const fixture=fs.readFileSync(path.join(__dirname,'chapter4_tnt_search.luau'),'utf8').replace('-- INSERT_SEARCH',source.slice(a,b));
const tmp=path.join(os.tmpdir(),`beyy-tnt-search-${process.pid}.luau`);
try{fs.writeFileSync(tmp,fixture);const r=cp.spawnSync(process.argv[2]||'luau',[tmp],{encoding:'utf8'});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');if(r.error)throw r.error;process.exitCode=r.status??1;}finally{fs.unlinkSync(tmp);}
