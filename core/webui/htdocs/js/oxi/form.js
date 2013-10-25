/**
defines classes for Forms
*/

OXI.FormView = OXI.ContentBaseView.extend({

    templateName: "form-view",
    jsClassName:'OXI.FormView',

    
    default_action:null,
    default_submit_label: 'send',
    
    action:null,
    _actionIsTriggered : false,

    fields:[],

    FieldContainerList:[],
    
    submit: function (event){

        return false;
    },
    
    

    submitAction: function(action, do_submit,target) {
        // will be invoked whenever the user triggers
        // the browser's `submit` method or a button is clicked explicitly
        
        if(this._actionIsTriggered){
            js_debug('action already triggered ...return.');   
            return;
        }
        this.set('_actionIsTriggered',true);
        
        this.debug('Form submit with action '+action + ', target '+target);
        if(!action){
            App.applicationError('Form or Button without action!');
            return;
        }
        if(!target)target='self';
        this.resetErrors();
        var i;
        var submit_ok = true;
        var formValues = {target:target};
        if(do_submit){//should the form-values be transmitted to the server?
            for(i=0;i<this.FieldContainerList.length;i++){
                var FieldView = this.FieldContainerList[i];
                //this.debug(FieldView.fieldname +': '+FieldView.getValue());

                if(!FieldView.isValid()){
                    submit_ok = false;
                    //this.debug(FieldView.fieldname +' not valid: '+FieldView.getErrorsAsString);
                }else{
                    formValues[FieldView.fieldname] = FieldView.getValue();
                }
            }
        }
        if(submit_ok){
            this.debug('submit ok');
            formValues.action = action;
            var FormView = this;
            if(action=='login'){
                var original_target = App.get('original_target');
                js_debug('original_target:'+original_target);
                if(original_target){
                    formValues.original_target= original_target;
                    App.set('original_target','');
                }
            }
            //App.showLoader();
            App.callServer(formValues).success(
            function(json){
                FormView.debug('server responded');
                FormView.set('_actionIsTriggered',false);
                //js_debug(json,2);
                App.hideLoader();
                App.renderPage(json,target,FormView);
                
                if(json.error){
                    var field;
                    for(field in json.error){
                        var FieldView = FormView.getFieldView(field);
                        FieldView.setError(json.error[field]);
                    }
                }
            }
            );
        }else{
            this.debug('submit nok');
            this.set('_actionIsTriggered',false);
        }


    },


    init:function(){
        //this.debug('init!');
        this._super();
        this.FieldContainerList = [];
        this.fieldContainerMap = {};
        this.fields = [];
        this.default_action = null;
        
        this.set('_actionIsTriggered',false);

        if( !this.content.fields){
            App.applicationError('Form, init failed: no content definition!');
            return;
        }

        this._initFields();
    },
    
    //method overwritten from ContentBaseView
    _initButtons:function(){
        this.debug('init buttons!');
        if(!this.content.buttons){
            //default/fallback: no list with buttons is given: lets create ONE Submit-Button with Submit-Labekl and Action
            var label = (this.content.submit_label)?this.content.submit_label:this.default_submit_label;
            if(!this.action){//action must be set via create()!
                App.applicationError('Form created without action!');
                return;
            }
            //the one-and-only button is obviously the default action:
            this.default_action = this.action;
            this.addButton(OXI.FormButton.create({ParentView:this,label:label,action:this.action,do_submit:true,is_default:true}));
        }else{
            var i;
            //determine default action:
            for(i=0;i<this.content.buttons.length;i++){
                var def = this.content.buttons[i];
                if(def.do_submit && (!this.default_action ||def.default)){
                    //first submit-button (or the one specially marked as "default") found: mark it as default
                    this.default_action = def.action;
                }
            }

            for(i=0;i<this.content.buttons.length;i++){
                var def = this.content.buttons[i];
                def.ParentView = this;
                def.is_default=(def.action == this.default_action);
                this.addButton(OXI.FormButton.create(def));
            }
        }
    },

    _initFields:function(){
        this.fields = this.content.fields;
        var i;
        for(i=0;i<this.fields.length;i++){
            var field=this.fields[i];
            var ContainerView;
            switch(field.type){              
                case 'hidden':
                case 'text':
                case 'password':
                ContainerView = OXI.TextFieldContainer.create({fieldDef:field});
                break;

                case 'textarea':
                ContainerView = OXI.TextAreaContainer.create({fieldDef:field});
                break;
                case 'select':
                ContainerView = OXI.PulldownContainer.create({fieldDef:field});
                break;
                case 'checkbox':
                ContainerView = OXI.CheckboxContainer.create({fieldDef:field});
                break;
                default:
                alert('field '+field.name+': type not supported: '+field.type);

            }
            this.FieldContainerList.push(this.createChildView(ContainerView));
            var i = this.FieldContainerList.length -1;
            this.fieldContainerMap[field.name] = i;
            //js_debug('added field '+field.name+ ' to field-map with index '+i);
        }
    },

    getFieldView:function(field){
        var i =  this.fieldContainerMap[field];
        if(i=='undefined'){
            App.applicationError('getFieldView: field not registered as View '+field);
            return;
        }
        return this.FieldContainerList[i];
    }


});

OXI.FormButton = OXI.PageButton.extend({

    jsClassName:'OXI.FormButton',
    
    classNameBindings:['btn_type'],
    attributeBindings: ['type'],
    type:function(){
        if(this.is_default){
            return 'submit';
        }else{
            return 'button';
        }
    }.property(),
    btn_type:function(){
        if(this.is_default){
            return 'btn-primary';
        }else if(this.do_submit){
            return 'btn-info';
        }else{
            return 'btn-default';
        }
    }.property(),

    action:null,//set via constructor (from json)
    do_submit:false,//set via constructor (from json)
    is_default:false,//set via constructor
    

    click: function(evt) {
        js_debug("Button with action "+this.action+" was clicked");
        this.ParentView.submitAction(this.action,this.do_submit,this.target);
    },

    init:function(){
        this._super();
        
        if(!this.action){
            App.applicationAlert('FormButton withot action!');
            return;
        }
    }

});

OXI.FormFieldContainer = OXI.View.extend({
    FieldView: null,
    label:null,
    fieldname:null,
    fieldDef:null,
    isRequired:true,

    isValid:function(){
        this.resetErrors();
        if(this.isRequired){
            if(!this.getValue()){
                this.setError('Please specify a value');
                return false;
            }
        }
        return true;
    },

    _toString:function(){
        return this._super()+' '+this.fieldname;
    },

    init:function(){
        //Ember.debug('OXI.FormFieldContainer :init '+this.fieldDef.label);
        this.isRequired = true;
        this.FieldView = null;

        this._super();
        this.label = this.fieldDef.label;
        this.fieldname = this.fieldDef.name;
        if(this.fieldDef.is_optional){//required is default!
            this.isRequired = false;
        }
    },
    setFieldView:function(View){
        this.FieldView = this.createChildView( View );
    },
    destroy: function() {
        //Ember.debug('FormFieldContainer::destroy:'+this.fieldname);
        this._super()
    },
    getValue:function(){
        return this.FieldView.value;
    }
});

OXI.TextFieldContainer = OXI.FormFieldContainer.extend({
    templateName: "form-textfield",
    jsClassName:'OXI.TextFieldContainer',
    init:function(){
        //Ember.debug('OXI.TextFieldContainer :init '+this.fieldDef.label);
        this._super();
        this.setFieldView(OXI.TextField.create(this.fieldDef));
    }

});

OXI.CheckboxContainer = OXI.FormFieldContainer.extend({
    templateName: "form-checkbox",
    jsClassName:'OXI.CheckboxContainer',
    init:function(){
        //Ember.debug('OXI.CheckboxContainer :init '+this.fieldDef.label);
        this._super();
        this.setFieldView(OXI.Checkbox.create(this.fieldDef));
    },
    isValid:function(){
        return true;//checkbox shopuld be always valid
    },
    
    getValue:function(){
        return (this.FieldView.isChecked())?1:0;
    }
});

OXI.TextAreaContainer = OXI.FormFieldContainer.extend({
    templateName: "form-textarea",
    jsClassName:'OXI.TextAreaContainer',
    init:function(){
        //Ember.debug('OXI.TextFieldContainer :init '+this.fieldDef.label);
        this._super();
        this.setFieldView(OXI.TextArea.create(this.fieldDef));
    }

});

OXI.PulldownContainer = OXI.FormFieldContainer.extend({
    templateName: "form-textfield",
    jsClassName:'OXI.PulldownContainer',

    init:function(){
        //Ember.debug('OXI.PulldownContainer :init '+this.fieldDef.label);
        this._super();
        this.setFieldView(OXI.Select.create(this.fieldDef));
    },
    getValue:function(){
        return this.FieldView.selection.value;
    }
});


OXI.Checkbox = Ember.Checkbox.extend(
{
    isChecked:function(){
        var checkbox = this.$();
        //we ask the DOM-element itself, not its jquery wrapper
        return checkbox[0].checked;   
    }    
}
);

OXI.Select = Ember.Select.extend(
{
    optionLabelPath: 'content.label',
    optionValuePath: 'content.value',
    classNames: ['form-control'] ,
    init:function(){
        //Ember.debug('OXI.Select :init ');
        this._super();
        this.content = Ember.A(this.options);
    }

});

OXI.TextArea = Ember.TextArea.extend(
{
    classNames: ['form-control']
}
);

OXI.TextField = Ember.TextField.extend(
{
    classNames: ['form-control']
}
);