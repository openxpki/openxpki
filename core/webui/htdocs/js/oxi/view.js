/**
Base Class for all Views in OXI namespace
*/

OXI.View = Ember.View.extend({
    jsClassName:'OXI.View: you must define jsClassName in your subclass!',

    _toString:function(){
        return this.jsClassName + ' '+ this.toString();
    },

    setError:function(msg){
        this.errors.push(msg);
        this.set('_hasError',true);
    },

    getErrorsAsString:function(){
        return this.errors.join(' - ');
    }.property('_hasError'),

    hasError:function(){
        this.debug('has error?' + this._hasError );
        return (this.errors.length>null);
    }.property('_hasError'),

    resetErrors:function(){
        this.set('errors',[]);
        this.set('_hasError',false);
    },

    init:function(){
        //js_debug(this.jsClassName+':init' + this.toString());
        this.resetErrors();

        this._super();
    },


    destroy:function(){
        //js_debug(this.jsClassName+':destroy' + this.toString());
        this._super();
    },

    debug:function(data){
        js_debug({jsClassName:this._toString(),data:data},3);
    }
});

OXI.ContentBaseView = OXI.View.extend(
{
    //content prop: must be set via create() , info comes fropm server
    content:null,
    label:null,
    description:null,
    ButtonList:[],
    
    
    getButtonCount:function(){
        return this.ButtonList.length;
    },

    init:function(){
        //this.debug('init!');
        this.ButtonList = [];
        this.label=null;
        this.description=null;
        this._super();
        if(!this.content ){
            App.applicationError('ContentBaseView, init failed: no content definition!');
            return;
        }
        if (this.content.label){
            this.label = this.content.label;
        }
        if (this.content.description){
            this.description = this.content.description;
        }
        this._initButtons();
    },

    addButton: function(ButtonView){
        this.ButtonList.push(this.createChildView(ButtonView));
    },
    
    _initButtons:function(){
        //this.debug('init buttons!');
        if(!this.content.buttons)return;
        var i;
        for(i=0;i<this.content.buttons.length;i++){
            var def = this.content.buttons[i];
            def.ParentView = this;
            this.ButtonList.push(this.createChildView(OXI.PageButton.create(def)));
        }
        
    },

});

OXI.PageButton = OXI.View.extend({

    jsClassName:'OXI.PageButton',
    templateName: "page-button",
    tagName: 'button',
    classNames: ['btn', 'btn-default'],
    label:null,//set via constructor 
    target:null,//set via constructor 
    action:null,//set via constructor 
    ParentView:null,//set via constructor 
    page:null,

    click: function(evt) {
        js_debug("Button "+this.label+" was clicked");
        App.handleAction({action:this.action,page:this.page,label:this.label,target:this.target});
    },

    init:function(){
        this._super();
        if(!this.ParentView){
              App.applicationAlert('Button without ParentView!');
            return;  
        }
        
        if(!this.label){
            App.applicationAlert('Button without label!');
            return;
        }
        if(!this.action && !this.page){
            App.applicationAlert('Button without action and page!');
            return;
        }
    }

});