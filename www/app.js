(function(){
  'use strict';
  const categories=new Map();
  let startupTimer=null;
  let startupStarted=false;
  let startupObserver=null;
  let eventsBound=false;
  let installAttempts=0;
  function syncStartup(){
    const screen=document.getElementById('screen');
    const loading=document.getElementById('soulmatch-loading');
    if(!screen || !loading || screen.children.length===0)return;
    loading.hidden=true;
    if(startupTimer!==null){clearTimeout(startupTimer);startupTimer=null;}
    if(startupObserver){startupObserver.disconnect();startupObserver=null;}
  }
  function startStartup(){
    if(startupStarted)return;
    startupStarted=true;
    const screen=document.getElementById('screen');
    const retry=document.getElementById('soulmatch-startup-retry');
    if(retry)retry.addEventListener('click',function(){window.location.reload();});
    if(screen && typeof MutationObserver==='function'){
      startupObserver=new MutationObserver(syncStartup);
      startupObserver.observe(screen,{childList:true});
    }
    startupTimer=setTimeout(function(){
      syncStartup();
      const loading=document.getElementById('soulmatch-loading');
      if(!loading || loading.hidden)return;
      const label=document.getElementById('soulmatch-startup-label');
      const help=document.getElementById('soulmatch-startup-help');
      if(label)label.textContent='Still waiting for the app to start.';
      if(help)help.textContent='Try reloading. If this continues, check the R console or hosting logs for a startup error.';
      if(retry)retry.hidden=false;
    },15000);
    syncStartup();
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',startStartup,{once:true});
  else startStartup();
  function filterGrid(gridId){
    const grid=document.getElementById(gridId); if(!grid)return;
    const selected=categories.get(gridId)||[];
    const search=document.querySelector('[data-search-target="'+CSS.escape(gridId)+'"] input');
    const query=((search && search.value)||'').trim().toLocaleLowerCase();
    grid.querySelectorAll('.interest-category').forEach(section=>{
      let visible=0;
      section.querySelectorAll('.checkbox').forEach(chip=>{
        const matches=!query||chip.textContent.toLocaleLowerCase().includes(query);
        chip.style.display=matches?'':'none';if(matches)visible++;
      });
      section.hidden=!selected.includes(section.dataset.categoryId)||(query.length>0&&visible===0);
      if(query.length>0&&visible>0)section.open=true;
    });
  }
  document.addEventListener('click',function(event){
    const button=event.target.closest('[data-world-chat]');
    if(button && window.Shiny)Shiny.setInputValue('world_chat',button.dataset.worldChat,{priority:'event'});
  });
  document.addEventListener('input',function(event){
    const search=event.target.closest('.interest-search');if(search)filterGrid(search.dataset.searchTarget);
  });
  function install(){
    // Bind lifecycle hints independently of custom-handler readiness. Actual
    // screen content and the CSS sibling rule are the source of readiness.
    if(window.jQuery && !eventsBound){
      eventsBound=true;
      window.jQuery(document).on('shiny:connected shiny:sessioninitialized shiny:value',function(){
        requestAnimationFrame(function(){syncStartup();categories.forEach(function(_,id){filterGrid(id);});});
      });
    }
    syncStartup();
    if(!window.Shiny || typeof window.Shiny.addCustomMessageHandler!=='function'){
      if(installAttempts++<600)setTimeout(install,50);
      return;
    }
    Shiny.addCustomMessageHandler('moduleFocus',function(){requestAnimationFrame(()=>{const main=document.querySelector('.section-intro');if(main)main.scrollIntoView({behavior:'smooth',block:'start'});});});
    Shiny.addCustomMessageHandler('interestCategories',function(data){categories.set(data.id,data.selected||[]);requestAnimationFrame(()=>filterGrid(data.id));});
    Shiny.addCustomMessageHandler('heightLanguage',function(data){
      const root=document.getElementById(data.id);if(!root)return;
      root.classList.toggle('lang-cs',data.language==='cs');
      const labels=data.language==='cs'?['Silně nesouhlasím','Nesouhlasím','Souhlasím','Silně souhlasím']:['Strongly disagree','Disagree','Agree','Strongly agree'];
      root.querySelectorAll('.height-question').forEach(question=>question.querySelectorAll('.radio-inline span').forEach((label,i)=>label.textContent=labels[i]));
    });

  }
  install();
})();
