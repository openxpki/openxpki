OXI.SectionViewContainer = OXI.View.extend({
   // We are setting templateName manually here to the default value
   templateName: "sections",
   SectionViewList:[],
   jsClassName:'OXI.SectionViewContainer',

   init:function(){
      //Ember.debug('SectionViewContainer init ');
      this._super();
      this.SectionViewList = [];
   },
   
   initSections:function(json){
      //js_debug(json,2);
      this.set('SectionViewList',[]);
      this.set('page_label','');
      this.set('page_desc','');
      if(json.page){
         if(json.page.label){
            this.set('page_label', json.page.label);
         }
         if(json.page.desc){
            this.set('page_desc', json.page.desc);
         }
      }
      //die einzelnen sections abbilden
      if(json.main){
         var i;
         var sections = json.main;
         for(i=0;i<sections.length;i++){

            if(!sections[i])next;

            this.addSectionView({sectionData:sections[i],
               section_nr:i+1
            });
         }
      }
   },
   

   addSectionView:function(params){
      //Ember.debug('SectionViewContainer:addSectionView');

      var SectionView = this.createChildView(OXI.SectionView.create(params));

      if(!this.SectionViewList){
         //this.SectionViewList= [];
         this.set('SectionViewList',[]);
      }
      this.SectionViewList.push(SectionView);
   },
   resetSections:function(){
      this.set('SectionViewList',[]);
   },

   destroy: function() {
      //Ember.debug('SectionViewContainer::destroy');
      this._super()
   }

});

OXI.SectionView = OXI.View.extend({
   // We are setting templateName manually here to the default value
   templateName: "section",
   sectionData: null,
   ContentView:null,
   section_nr:null,
   section_type:null,
   jsClassName:'OXI.SectionView',
   destroy: function() {
      //Ember.debug('SectionView::destroy '+this.section_nr);
      this._super()
   },
   init:function(){
      //Ember.debug('App.SectionView Nr '+this.section_nr+':init ');
      this.ContentView = null;
      this._super();
      this.section_type = this.sectionData.type;
      var ContentView;
      switch(this.section_type){
         case 'form':
         ContentView = OXI.FormView.create(
         {action:this.sectionData.action, content:this.sectionData.content}
         );
         break;
         case 'text':
         ContentView = OXI.TextView.create(
         {content:this.sectionData.content}
         );
         break;
         case 'grid':
         ContentView = OXI.GridView.create(
         {action:this.sectionData.action, results:this.sectionData.results}
         );
         break;
         default:
         alert('section '+  this.section_nr+' has unkown type: '+this.section_type);
         return;
      }
      this.ContentView = this.createChildView(ContentView);
   }


});