
"use strict";


OXI.TabListControler = Ember.Controller.extend({
   actions: {
            addTab: function(){
              js_debug('add tab triggered - section controler level');
              this.view.addTab('Test new');
            }
          },
          
   _lastItem: '' //avoid trailing commas    
});

OXI.TabControler = Ember.Controller.extend({
   actions: {
            closeTab: function(){
              js_debug('close tab triggered - controler level');
              this.view.closeTab();
            }
          }, 
   _lastItem: '' //avoid trailing commas       
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
    
    _markAsActive:false,
    
    getTabHref:function(){
        return '#'+this.get('elementId');
    }.property(),
    
    getMainViewContainer:function(){
        return this.ParentView.getMainViewContainer();  
    },
    
    init:function(){
        this._super();
        if(!this.label){
            this.label = '';
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
        this.set('ContentView', this.createChildView(
                                    OXI.SectionViewContainer.create({displayType:'tab',parentContainer:this})
                                   ));
        this.set('_domReady',false);
    },
    closeTab:function(){
        //js_debug('will close myself...');
        this.ParentView.closeTab(this.tabindex)
    },
    
    setActive: function(){
        if(this._domReady){
            this._markAsActive = false;
            this.ParentView.showTab(this.tabindex); //this.get('elementId')
        }else{
            //js_debug('mark as active ...delayed!');
            this._markAsActive = true;
        }
    },
    didInsertElement: function(){
         this._super();
        if(this._markAsActive){
            var Tab = this;
            //for some (unknown) reasons the immediate call to setActive fails here...although the DOM is ready... 
            setTimeout(function(){Tab.setActive();},100);
        }
    },
    
    _lastItem: '' //avoid trailing commas
});

OXI.SectionViewContainer = OXI.View.extend({
    
    jsClassName:'OXI.SectionViewContainer',
    
    templateName: "sections",
    SectionViewList:[],
    MessageView:null,
    RightPaneView:null,
    Tabs: null,
    _hasTabs:false,
    _debugTabs:false,
    label:null,
    shortlabel:null,
    description:null,
    displayType:'main',
    parentContainer:null,
    
    //computed properties:
     hasNoTabs: function(){
       return (!this._hasTabs);
    }.property('_hasTabs'),
    
    
    labelTabMain: function(){
       var label = (this.shortlabel)?this.shortlabel:this.label;
       if(this._debugTabs){
           label += ' #'+ this.get('elementId');
       }
       if(!label)label = 'Main page';
       return label;
    }.property('label','shortlabel'),
    
    getMainTabHref:function(){
        return '#' + this.getMainTabId();
    }.property(),
    
    getMainTabId:function(){
        return this.get('elementId') +'-main-tab';

    },
    
    mainTabId:function(){
        return this.getMainTabId();
    }.property(),
    
    hasRightPane:false,
    
    //methods:
    getMainViewContainer: function(){
        if(this.displayType=='tab'){
            return this.parentContainer.getMainViewContainer();
        }
        return this;  
        
    },
    
    addTab: function(label){
        //js_debug('add tab called,  label '+label);  
        var TabView = OXI.TabView.create({label:label,ParentView:this,tabindex:this.Tabs.content.length});
        this.Tabs.pushObject(this.createChildView(TabView));
        this.set('_hasTabs',true);
        
        return TabView;
    },
    
    showTab: function(tab_index){
        //js_debug('show tab '+tab_index);
        if(!this._domReady)return;
        tab_index++;//we must increnent the index, because the first (bootstrap-)tab "main" is not in our TabList
        this.$('.nav-tabs  li:eq('+tab_index+') a').tab('show'); 
    },
    
    
    closeTab:function(tabindex){
        //js_debug('will close tab #' + tabindex);
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
    
    closeTabs:function(){
        this.Tabs.forEach(
            function(Tab, index, enumerable){
                Tab.destroy();
            }
        );
        this.initTabs();
        this.showTab(-1);//main tab
    },
    
    initTabs:function(){
        this.set('Tabs', Ember.ArrayController.create({
                content: Ember.A([])
            }));
        this.set('_hasTabs',false);
    },

    init:function(){
        this.debug('SectionViewContainer init '+this.displayType);
        this._super();
        this.SectionViewList = [];
        this.initTabs();
        this.set('controller',OXI.TabListControler.create({view:this}));
        if(this.displayType != 'right'){
            this.RightPaneView = this.createChildView(OXI.RightPaneView.create());
            this.MessageView = this.createChildView(OXI.MessageView.create());
        }else{
            this.RightPaneView = this.createChildView(OXI.EmptyView.create()); 
            this.MessageView = this.createChildView(OXI.EmptyView.create()); 
        }
            
        
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
        this.debug('start initSections');
        this.set('SectionViewList',[]);
        this.set('label','');
        this.set('shortlabel','');
        this.set('description','');
        this.set('hasRightPane',false);
        if(json.page){
            if(this.displayType == 'main'){//no label/description in tabs
                if(json.page.label){
                    //this.debug('set label '+ json.page.label);
                    this.set('label', json.page.label);
                }
                if(json.page.description){
                    this.set('description', json.page.description);
                }
                this.setStatus(json.status);
            }
            if(json.page.shortlabel){
                this.set('shortlabel', json.page.shortlabel);
            }
        }

        //die einzelnen sections abbilden
        if(json.main){
            var i;
            var sections = json.main;
            for(i=0;i<sections.length;i++){

                if(!sections[i])next;

                this.addSectionView({
                    sectionData:sections[i],
                    section_nr:i+1
                });
            }
        }
        
        //right pane:
        if(json.right && json.right.length > 0){
            this.set('hasRightPane',true);
            this.RightPaneView.initSections(json.right);
        }
        this.debug('initSections finished');
    },


    addSectionView:function(params){
        //js_debug('SectionViewContainer:addSectionView');
        //js_debug(params);
        params.SectionContainer = this;
        var SectionView = this.createChildView(OXI.SectionView.create(params));
        js_debug('section '+params.section_nr+' created');
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
    
    SectionContainer:null,//set via Constructor, points to parent
    
    hasButtons: function(){
        if(this.ContentView.jsClassName == 'OXI.FormView'){
            return false;    
        }
        return this.ContentView.getButtonCount();
    }.property(),
    
    
    destroy: function() {
        //Ember.debug('SectionView::destroy '+this.section_nr);
        this._super()
    },
    init:function(){
        //Ember.debug('App.SectionView Nr '+this.section_nr+':init ');
        this.ContentView = null;
        
        this._super();
        this.section_type = this.sectionData.type;
        var params = {SectionView:this, content:this.sectionData.content};
        if(this.sectionData.action){
            params.action =  this.sectionData.action;  
        }
        
        this.ContentView = this.createChildView(
                                OXI.SectionViewFactory.getComponent(this.section_type,params)
                            );
    }
    

});

OXI.RightPaneView = OXI.View.extend({
    jsClassName:'OXI.ModalView',
    templateName: "right-pane",
    classNames: ['panel panel-default right-pane'],//http://getbootstrap.com/components/#panels
    ContentView:null,
    
    
    init:function(){
        this._super();
        this.set('ContentView', this.createChildView(
                                    OXI.SectionViewContainer.create({displayType:'right',templateName:'sections-right'})
                                   ));
        
    },
    
    initSections: function(sections){
        this.debug('init Sections');
        this.ContentView.initSections({main : sections});
    },
    
    _lastItem: '' //avoid trailing commas
});

OXI.EmptyView = OXI.View.extend({
    jsClassName:'OXI.EmptyView',
    
    _lastItem: '' //avoid trailing commas
});

OXI.MessageView = OXI.View.extend({
    
    jsClassName:'OXI.MessageView',
    classNames: ['oxi-message'],
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
    }.property('level','message'),
    
    didInsertElement: function(){
        this._super();
        /*
        var elemId = this.get('elementId');
        $(window).scroll(function(){            
            $('#'+elemId)
                .stop()
                .animate({"marginTop": ($(window).scrollTop() )}, "slow" );         
        });
        */   
    },
    
    _lastItem: '' //avoid trailing commas
});