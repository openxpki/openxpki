/**
defines classes for Forms
*/

OXI.FormView = OXI.View.extend({

    templateName: "form-view",
    jsClassName:'OXI.FormView',

    //content prop: must be set via create() , info comes fropm server
    content:null,

    submit_label: null,
    form_title :null,
    form_text:null,
    action:null,

    fields:[],

    FieldContainerList:[],
    ButtonList:[],//additional (submit-)buttons

    submit: function(event) {
        // will be invoked whenever the user triggers
        // the browser's `submit` method
        //this.debug('Form submit!');
        if(!this.action){
            App.applicationError('Form without action!');
            return;
        }
        this.resetErrors();
        var i;
        var submit_ok = true;
        var formValues = {};
        for(i=0;i<this.FieldContainerList.length;i++){
            var FieldView = this.FieldContainerList[i];
            //this.debug(FieldView.fieldname +': '+FieldView.getValue());

            if(!FieldView.isValid()){
                submit_ok = false;
                this.debug(FieldView.fieldname +' not valid: '+FieldView.getErrorsAsString);
            }else{
                formValues[FieldView.fieldname] = FieldView.getValue();
            }
        }

        if(submit_ok){
            this.debug('submit ok');
            formValues.action = this.action;
            var FormView = this;
            if(this.action=='login'){
                var original_target = App.get('original_target');
                js_debug('original_target:'+original_target);
                if(original_target){
                    formValues.original_target= original_target;
                    App.set('original_target','');
                }
            }
            App.callServer(formValues).success(
            function(json){
                FormView.debug('server responded');
                js_debug(json,2);

                //status-messages page-level:
                if(json.status){
                    App.MainView.setStatus(json.status);
                }

                if(json.reloadTree){
                    var timeout = (json.status)?100:0;
                    window.setTimeout(function(){App.reloadPage();},timeout);
                    return;
                }


                //error-message form-level
                //TODO: needed?
                if(json.form_error){
                    FormView.setError(json.form_error);
                }

                if(json.field_errors){
                    var field;
                    for(field in json.field_errors){
                        var FieldView = FormView.getFieldView(field);
                        FieldView.setError(json.field_errors[field]);
                    }
                }

                if(json.page){
                    App.get('MainView').initSections(json);
                }
            }
            );
        }else{
            this.debug('submit nok');
        }

        return false;
    },


    init:function(){
        //Ember.debug('OXI.FormView :init ');
        this._super();
        this.FieldContainerList = [];
        this.ButtonList = [];
        
        this.fieldContainerMap = {};
        this.fields = [];

        this.form_title=null;
        this.form_text=null;
        this.submit_label='send';
        if(!this.action){//action must be set via create()!
            App.applicationError('Form created without action!');
            return;
        }
        if(!this.content || !this.content.fields){
            App.applicationError('Form, init failed: no content definition!');
            return;
        }

        if (this.content.title){
            this.form_title = this.content.title;
        }
        if (this.content.title){
            this.form_text = this.content.text;
        }
        if (this.content.submit_label){
            this.submit_label = this.content.submit_label;
        }
        this._initFields();
        this._initButtons();
    },
    
    _initButtons:function(){
        if(!this.content.buttons)return;
        var i;
        for(i=0;i<this.content.buttons.length;i++){
            this.ButtonList.push(this.createChildView(OXI.FormButton.create(this.content.buttons[i]))); 
        }
        
    },
    
    _initFields:function(){
        this.fields = this.content.fields;
        var i;
        for(i=0;i<this.fields.length;i++){
            var field=this.fields[i];
            var ContainerView;
            switch(field.type){
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

OXI.FormButton = OXI.View.extend({
    
    jsClassName:'OXI.FormButton',
    templateName: "form-button",
    
    subaction:null,//set via constructor (from json)
    do_submit:false,//set via constructor (from json)
    label:null,//set via constructor (from json)
    
    init:function(){
        this._super();
        if(!this.label){
            App.applicationError('FormButton withot label!');
            return;   
        }
        if(!this.subaction){
            App.applicationError('FormButton withot subaction!');
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
        Ember.debug('FormFieldContainer::destroy:'+this.fieldname);
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
        Ember.debug('OXI.CheckboxContainer :init '+this.fieldDef.label);
        this._super();
        this.setFieldView(OXI.Checkbox.create(this.fieldDef));
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
        return this.FieldView.selection.key;
    }
});


OXI.Checkbox = Ember.Checkbox.extend(
{}
);

OXI.Select = Ember.Select.extend(
{
    optionLabelPath: 'content.label',
    optionValuePath: 'content.key',
    classNames: ['form-control'] ,
    init:function(){
        //Ember.debug('OXI.Select :init ');
        this._super();
        this.content = Ember.A(this.options);
    }

});

OXI.TextArea = Ember.TextArea.extend(
{}
);

OXI.TextField = Ember.TextField.extend(
{
    classNames: ['form-control']
}
);