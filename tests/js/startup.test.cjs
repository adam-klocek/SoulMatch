// Logic regression tests only: these do not launch or substitute for a browser.
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../../www/app.js'),'utf8');
function app({ready='complete',shiny=true,observer=true,mounted=true,populated=false}={}){
  let now=0,nextId=0,reloads=0;
  const timers=new Map(),events=new Map(),jqEvents=new Map(),observers=[];
  const nodes=new Map();
  function node(id){return {id,children:[],hidden:false,textContent:'',listeners:new Map(),addEventListener(event,fn){this.listeners.set(event,fn);}};}
  function mount(){for(const id of ['screen','soulmatch-loading','soulmatch-startup-label','soulmatch-startup-help','soulmatch-startup-retry'])nodes.set(id,node(id));nodes.get('soulmatch-startup-retry').hidden=true;if(populated)nodes.get('screen').children=[{}];}
  if(mounted)mount();
  const document={readyState:ready,getElementById:id=>nodes.get(id)||null,addEventListener(event,fn){if(!events.has(event))events.set(event,[]);events.get(event).push(fn);}};
  const context={document,Map,CSS:{escape:x=>x},requestAnimationFrame:fn=>fn(),setTimeout(fn,delay){const id=++nextId;timers.set(id,{at:now+delay,fn});return id;},clearTimeout:id=>timers.delete(id)};
  context.window={location:{reload(){reloads++;}},jQuery(){return {on(names,fn){for(const name of names.split(' '))jqEvents.set(name,fn);return this;}};}};
  const handlers=new Map();
  function enableShiny(apiReady=true){const api=apiReady?{addCustomMessageHandler(name,fn){handlers.set(name,fn);}}:{};context.window.Shiny=api;context.Shiny=api;}
  if(shiny)enableShiny();
  if(observer)context.MutationObserver=class{constructor(callback){this.callback=callback;this.active=true;observers.push(this);}observe(){}disconnect(){this.active=false;}};
  vm.runInNewContext(source,context,{filename:'app.js'});
  function advance(ms){const target=now+ms;for(;;){const due=[...timers.entries()].filter(([,t])=>t.at<=target).sort((a,b)=>a[1].at-b[1].at)[0];if(!due)break;now=due[1].at;timers.delete(due[0]);due[1].fn();}now=target;}
  function content(){nodes.get('screen').children=[{}];for(const o of observers)if(o.active)o.callback();}
  return {nodes,handlers,events,jqEvents,advance,content,mount,enableShiny,get reloads(){return reloads;},fire(event){for(const fn of events.get(event)||[])fn();},context};
}
test('content dismisses startup even when connected event was already missed',()=>{
  const a=app();a.content();assert.equal(a.nodes.get('soulmatch-loading').hidden,true);assert.equal(a.handlers.size,3);a.advance(16000);assert.equal(a.nodes.get('soulmatch-startup-retry').hidden,true);
});
test('a connected socket alone does not pretend that the app interface is ready',()=>{
  const a=app();a.jqEvents.get('shiny:connected')();assert.equal(a.nodes.get('soulmatch-loading').hidden,false);a.content();assert.equal(a.nodes.get('soulmatch-loading').hidden,true);
});
test('already-rendered content hides loading immediately for late scripts',()=>{
  const a=app({populated:true});assert.equal(a.nodes.get('soulmatch-loading').hidden,true);
});
test('head script waits for DOM without losing later screen content',()=>{
  const a=app({ready:'loading',mounted:false});a.mount();a.fire('DOMContentLoaded');a.content();assert.equal(a.nodes.get('soulmatch-loading').hidden,true);
});
test('an unavailable Shiny client produces an actionable timeout and working retry',()=>{
  const a=app({shiny:false});a.advance(15000);assert.match(a.nodes.get('soulmatch-startup-label').textContent,/Still waiting/);assert.match(a.nodes.get('soulmatch-startup-help').textContent,/R console/);assert.equal(a.nodes.get('soulmatch-startup-retry').hidden,false);a.nodes.get('soulmatch-startup-retry').listeners.get('click')();assert.equal(a.reloads,1);
});
test('a partially initialized Shiny object cannot crash handler installation',()=>{
  const a=app({shiny:false});a.enableShiny(false);a.advance(50);assert.equal(a.handlers.size,0);a.enableShiny(true);a.advance(50);assert.equal(a.handlers.size,3);a.content();assert.equal(a.nodes.get('soulmatch-loading').hidden,true);
});
test('slow content still dismisses the status after the timeout message',()=>{
  const a=app();a.advance(15000);assert.equal(a.nodes.get('soulmatch-startup-retry').hidden,false);a.content();assert.equal(a.nodes.get('soulmatch-loading').hidden,true);
});
test('lifecycle hints work without MutationObserver',()=>{
  const a=app({observer:false});a.content();a.jqEvents.get('shiny:value')();assert.equal(a.nodes.get('soulmatch-loading').hidden,true);
});
test('content fallback works with neither Shiny nor lifecycle events',()=>{
  const a=app({shiny:false});a.content();assert.equal(a.nodes.get('soulmatch-loading').hidden,true);
});
test('CSS prevents loader coverage and also hides it independently of JavaScript',()=>{
  const css=fs.readFileSync(path.join(__dirname,'../../www/app.css'),'utf8');
  const rule=css.match(/\.spark-loading\{([^}]+)\}/)[1];
  assert.match(rule,/position:relative/);assert.doesNotMatch(rule,/position:fixed|inset:0|z-index/);
  assert.match(css,/#screen:not\(:empty\)\+\.spark-loading\{display:none!important\}/);
  const ui=fs.readFileSync(path.join(__dirname,'../../R/ui.R'),'utf8');
  assert.ok(ui.indexOf('uiOutput("screen")')<ui.indexOf('id="soulmatch-loading"'));
  assert.match(ui,/JavaScript is required to run SoulMatch/);
});
