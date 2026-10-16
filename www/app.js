(function(){
  'use strict';
  const categories=new Map();
  function filterGrid(gridId){
    const grid=document.getElementById(gridId); if(!grid)return;
    const selected=categories.get(gridId)||[];
    const search=document.querySelector('[data-search-target="'+CSS.escape(gridId)+'"] input');
    const query=(search?.value||'').trim().toLocaleLowerCase();
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
    if(!window.Shiny){setTimeout(install,50);return;}
    Shiny.addCustomMessageHandler('moduleFocus',function(){requestAnimationFrame(()=>{const main=document.querySelector('.section-intro');if(main)main.scrollIntoView({behavior:'smooth',block:'start'});});});
    Shiny.addCustomMessageHandler('interestCategories',function(data){categories.set(data.id,data.selected||[]);requestAnimationFrame(()=>filterGrid(data.id));});
    Shiny.addCustomMessageHandler('heightLanguage',function(data){
      const root=document.getElementById(data.id);if(!root)return;
      root.classList.toggle('lang-cs',data.language==='cs');
      const labels=data.language==='cs'?['Silně nesouhlasím','Nesouhlasím','Souhlasím','Silně souhlasím']:['Strongly disagree','Disagree','Agree','Strongly agree'];
      root.querySelectorAll('.height-question').forEach(question=>question.querySelectorAll('.radio-inline span').forEach((label,i)=>label.textContent=labels[i]));
    });
    if(window.jQuery)jQuery(document).on('shiny:value',function(){requestAnimationFrame(()=>{categories.forEach((_,id)=>filterGrid(id));});});
  }
  install();
})();
