OXI.TabListControler = Ember.Controller.extend({
   actions: {
            addTab: function(){
              js_debug('add tab triggered - section controler level');
              this.view.addTab('Test new');
            }
          }, 
});

OXI.TabControler = Ember.Controller.extend({
   actions: {
            closeTab: function(){
              js_debug('close tab triggered - controler level');
              this.view.closeTab();
            }
          }, 
});

OXI.TabView = OXI.View.extend({
    jsClassName:'OXI.TabView',
    templateName: "tab-pane",
    classNames: ['tab-pane'],
    //this is the View for the Tab-Content (another instance of SectionViewContainer)
    ContentView: null,
    
    //set via constructor
    label:null,
    tabindex:null,
    ParentView:null, //
    _domReady:false,
    _markAsActive:false,
    
    getTabHref:function(){
        return '#'+this.get('elementId');
    }.property(),
    
    isLast:function(){
        return (this.tabindex == this.ParentView.lastTabIndex());
    }.property(),
    
    init:function(){
        this._super();
        if(!this.label){
            App.applicationAlert('Tab withot label!');
            return;
        }
        if(!this.ParentView){
            App.applicationAlert('Tab withot ParentView!');
            return;
        }
        if(typeof this.tabindex == 'undefined'){
            App.applicationAlert('Tab with no valid index!');
            return;
        }
        this.set('controller',OXI.TabControler.create({view:this}));
        this.set('ContentView', this.createChildView(OXI.SectionViewContainer.create()));
        this.set('_domReady',false);
    },
    closeTab:function(){
        js_debug('will close myself...');
        this.ParentView.closeTab(this.tabindex)
    },
    
    setActive: function(){
        if(this._domReady){
            this._markAsActive = false;
            this.ParentView.showTab(this.tabindex); //this.get('elementId')
        }else{
            js_debug('mark as active ...delayed!');
            this._markAsActive = true;
        }
    },
    didInsertElement: function(){
        this.debug('DOM is ready!'+this.get('elementId')); 
        this.set('_domReady',true);
        if(this._markAsActive){
            var Tab = this;
            //for some (unknown) reasons the immediate call to setActive fails here...although the DOM is ready... 
            setTimeout(function(){Tab.setActive();},100);
        }
    }
    
});

OXI.SectionViewContainer = OXI.View.extend({
    
    jsClassName:'OXI.SectionViewContainer',
    
    templateName: "sections",
    SectionViewList:[],
    MessageView:null,
    Tabs: null,
    _hasTabs:false,
    _debugTabs:false,
    label:null,
    shortlabel:null,
    description:null,
    
    //computed properties:
     hasNoTabs: function(){
       return (!this._hasTabs);
    }.property('_hasTabs'),
    
    lastTabIndex: function(){
        return this.Tabs.content.length-1;
    },
    
    labelTabMain: function(){
       var label = (this.shortlabel)?this.shortlabel:this.label;
       if(this._debugTabs){
           label += ' #'+ this.get('elementId');
       }
       return label;
    }.property('label','shortlabel'),
    
    //methods:
    addTab: function(label){
        js_debug('add tab called,  label '+label);  
        var TabView = OXI.TabView.create({label:label,ParentView:this,tabindex:this.Tabs.content.length});
        this.Tabs.pushObject(this.createChildView(TabView));
        this.set('_hasTabs',true);
        
        return TabView;
    },
    
    showTab: function(tab_index){
        js_debug('show tab '+tab_index);
        tab_index++;//we must increnent the index, because the first (bootstrap-)tab "main" is not in our TabList
        var selector = '.nav-tabs  li:eq('+tab_index+') a';
        js_debug(selector);
        js_debug(this.$(selector).html());
        
        this.$(selector).tab('show'); 
    },
    
    
    closeTab:function(tabindex){
        js_debug('will close tab #' + tabindex);
        var Tab = this.Tabs.content[tabindex];
        if(!Tab){
            js_debug('no tab at index '+tabindex);
            return
        }
        
        this.Tabs.removeAt(tabindex);
        Tab.destroy();
        //reindexing all tabs:
        this.Tabs.forEach(
            function(Tab, index, enumerable){
                Tab.set('tabindex',index);   
            }
        );
        this.showTab(tabindex-1);
    },

    init:function(){
        //Ember.debug('SectionViewContainer init ');
        this._super();
        this.SectionViewList = [];
        this.Tabs = Ember.ArrayController.create({
                content: Ember.A([])
            });
        this.set('controller',OXI.TabListControler.create({view:this}));
        this.MessageView = this.createChildView(OXI.MessageView.create());
    },

    setStatus:function(status){
        if(status && status.message){
            var level = (status.level)?status.level:'info';
            this.MessageView.setMessage(status.message,level);
        }else{
            this.MessageView.reset();
        }
    },
    
    

    initSections:function(json){
        //js_debug(json,2);
        this.set('SectionViewList',[]);
        this.set('label','');
        this.set('shortlabel','');
        this.set('desc','');
        if(json.page){
            if(json.page.label){
                this.set('label', json.page.label);
            }
            if(json.page.shortlabel){
                this.set('shortlabel', json.page.shortlabel);
            }
            if(json.page.description){
                this.set('description', json.page.description);
            }
        }

        
        this.setStatus(json.status);
       
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
    
    jsClassName:'OXI.SectionView',
    
    templateName: "section",
    sectionData: null,
    ContentView:null,
    section_nr:null,
    section_type:null,
    
    
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
            case 'keyvalue':
            ContentView = OXI.KeyValueView.create(
            {content:this.sectionData.content}
            );
            break;
            case 'grid':
            ContentView = OXI.GridView.create(
            {action:this.sectionData.action, content:this.sectionData.content}
            );
            break;
            default:
            alert('section '+  this.section_nr+' has unkown type: '+this.section_type);
            return;
        }
        this.ContentView = this.createChildView(ContentView);
    }


});

OXI.MessageView = OXI.View.extend({
    
    jsClassName:'OXI.MessageView',
    
    message:null,
    templateName: "page-message",
    level:null,

    setMessage:function(message,level){
        this.set('level',level);
        this.set('message',message);
        //this.debug({level:level,message:message});
    },

    reset:function(){
        this.set('level','');
        this.set('message', '');
    },
    
    msg_class:function(){
        //this.debug('eval msg_class');
        if(!this.message){
            return 'hide';
        }
        switch(this.level){
            case 'error':
            return 'alert-danger';
            case 'success':
            return 'alert-success';
            case 'info':
            return 'alert-info';
            case 'warn':
            return 'alert-warning';
            default:
            return '';

        }
    }.property('level','message')




});