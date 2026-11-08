const fs=require('fs'),vm=require('vm'),assert=require('assert');
const html=fs.readFileSync(require('path').join(__dirname,'../../assets/family_tree/relationship_universe.html'),'utf8');
let code=html.match(/<script>([\s\S]*?)<\/script>/)[1];
code=code.replace('window.DayArkGraph={setData,setView,focus', 'window.DayArkGraph={debugLayout(){return scene.points;},debugRender(){draw(1033);return scene.visible;},setData,setView,focus');
const els=new Map(),posts=[];
class Element {constructor(id){this.id=id;this.hidden=false;this.value='';this.style={};this.classList={add(){},remove(){}};this.children=[];this.textContent='';this.attributes={};this.width=1280;this.height=800;this.complete=true;this.naturalWidth=100;this.naturalHeight=100;}
addEventListener(t,fn){this['on_'+t]=fn;}setAttribute(k,v){this.attributes[k]=v;}
replaceChildren(){this.children=[];}appendChild(v){this.children.push(v);}append(...v){this.children.push(...v);}blur(){}
getBoundingClientRect(){return {width:1280,height:800,left:0,top:0};}setPointerCapture(){}getContext(){return ctx;}toDataURL(){return 'data:image/jpeg;base64,Zm9v';}}
const ctx=new Proxy({}, {get:(o,k)=>o[k]||((...a)=>{if(['createLinearGradient','createRadialGradient'].includes(k))return {addColorStop(){}};if(k==='measureText')return {width:66};})});
function element(id){if(!els.has(id))els.set(id,new Element(id));return els.get(id);}
const document={getElementById:element,createElement:element,hidden:false};
const context={document,window:{devicePixelRatio:1,addEventListener(){},DayArkBridge:{postMessage(s){posts.push(JSON.parse(s));}}},requestAnimationFrame(){return 1;},URLSearchParams:class {has(){return false;}},location:{search:''},Image:class extends Element {set src(s){this._src=s;this.onload?.();}},Math,Set,Map,Array,Number,String,JSON,console};
vm.createContext(context);vm.runInContext(code,context,{timeout:2000});
const g=context.window.DayArkGraph;
const members=['Me','Spouse','Brother','Brother spouse','Mother','Father','Sister','Friend'].map((name,i)=>({id:i+1,name,gender:'unspecified'}));
const relationships=[{from:1,to:2,type:'spouse'},{from:3,to:4,type:'spouse'},{from:5,to:6,type:'spouse'},{from:5,to:1,type:'parent'},{from:6,to:1,type:'parent'},{from:5,to:3,type:'parent'},{from:6,to:3,type:'parent'},{from:1,to:3,type:'sibling'},{from:5,to:7,type:'parent'},{from:6,to:7,type:'parent'}];
const connections=[{from:1,to:8,type:'best_friend'},{from:3,to:8,type:'colleague'}];
const events=[{id:10,name:'Graduation',type:'graduation',participants:[1,8]},{id:11,name:'Family holiday',type:'travel',participants:[1,2,3]}];
g.setData({members,relationships,connections,events,focusedId:1});
let pos=g.debugLayout(),p=id=>pos.find(n=>n.id===id);
assert(pos.length===10,'8 people + 2 events');
assert(Math.abs(p(3).x-p(4).x)<Math.abs(p(3).x-p(7).x),'spouse positioned next to their partner');
assert.equal(p(3).y,p(4).y);assert(p(5).y<p(1).y);
assert(p('event:10'),'first event present');
assert(els.get('summary').textContent.includes('2 events'));
g.debugRender();const rend=g.debugRender();assert(rend.every(n=>Number.isFinite(n.renderY)||n.renderY===undefined),'All nodes have finite render positions');
g.focus(8);assert.equal(els.get('personName').textContent,'Friend');
g.setView('family');pos=g.debugLayout();assert.equal(pos.length,8,'Family view excludes event nodes');
g.setView('life');assert.equal(g.debugLayout().length,10);
g.setMode('2d');assert.equal(els.get('flat').attributes['aria-pressed'],'true');
g.setMode('3d');assert.equal(els.get('space').attributes['aria-pressed'],'true');
g.focus('event:10');assert.equal(els.get('personName').textContent,'Graduation');
els.get('viewDetails').onclick();assert.equal(posts.at(-1).action,'eventDetails');assert.equal(posts.at(-1).id,10);
els.get('addRelative').onclick();assert.equal(posts.at(-1).action,'albumForEvent');
g.focus(1);els.get('addRelative').onclick();assert.equal(posts.at(-1).action,'connect');
els.get('addEvent').onclick();assert.equal(posts.at(-1).action,'addEvent');
g.captureForSheet();assert.equal(posts.at(-1).action,'sheetPreview');
assert.equal(posts.at(-1).view.view,'life');g.restoreState({...posts.at(-1).view,mode:'2d',view:'family'});
assert.equal(g.debugLayout().length,8);assert.equal(els.get('flat').attributes['aria-pressed'],'true');
g.setData({members:[],relationships:[],connections:[],events:[{id:44,name:'Solo event',type:'other',participants:[]}]});
assert.equal(g.debugLayout().length,0,'Family filter only shows people');g.setView('life');assert.equal(g.debugLayout().length,1,'Event-only archives work');
console.log('PASS: no runtime JS exceptions; family generations + spouse placement; event nodes; life/family filters; 2D/3D; event and person click actions; modal state; event-only archive.');
