OXI.SectionViewContainer = OXI.View.extend({
    
    jsClassName:'OXI.SectionViewContainer',
    
    templateName: "sections",
    SectionViewList:[],
    MessageView:null,

    init:function(){
        //Ember.debug('SectionViewContainer init ');
        this._super();
        this.SectionViewList = [];
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
        this.debug({level:level,message:message});
    },

    reset:function(){
        this.set('level','');
        this.set('message', '');
    },
    
    msg_class:function(){
        this.debug('eval msg_class');
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