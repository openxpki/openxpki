/**
defines classes for Forms
*/


"use strict";

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
        js_debug('form submit!');
        return false;
    },

    hasRightPane:function(){
        //this.debug('hasRightPane? ');
        return this.SectionView.hasRightPane();
    },

    callServer: function(action,sourceField){
        this.debug('call server with action '+action+', sourceField '+sourceField.fieldname);
        var formValues = this.getFormValues();
        formValues.action = action;
        formValues._sourceField = sourceField.getKey();
        var FormView = this;
        App.showLoader();
        App.callServer(formValues).success(
            function(json){
                FormView.debug('server responded');
                //js_debug(json,2);
                App.hideLoader();

                switch(json._returnType){
                    case 'partial':
                        if(!json.fields){
                            js_debug('Server returned no fields for action "'+action+'", triggered by "'+formValues._sourceField+'"');
                            return;
                        }
                        FormView.updateFields(json.fields);
                        break;
                    case 'full':
                        break;
                    default:
                        //this should not happen!
                        App.applicationAlert('Server returned wrong returnType for action "'+action+'", triggered by "'+formValues._sourceField+'": '+json._returnType);

                        return;
                }

            }
        );
    },

    getFormValues: function(){
        var i;
        var formValues = {};
        for(i=0;i<this.FieldContainerList.length;i++){
            var values = this.FieldContainerList[i].getKeyValueEntries();
            var k;
            for(k in values){
                formValues[k] = values[k];
            }
        }
        return formValues;
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
        var formValues = {};

        if(do_submit){//should the form-values be transmitted to the server?

            formValues = this.getFormValues();
            for(i=0;i<this.FieldContainerList.length;i++){
                var FieldView = this.FieldContainerList[i];
                //this.debug(FieldView.getKey() +': '+FieldView.getValue());
                if(!FieldView.isValid()){
                    submit_ok = false;
                    //this.debug(FieldView.getKey() +' not valid: '+FieldView.getErrorsAsString);
                }
            }
        }
        formValues.target = target;
        //js_debug(formValues);
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
            App.showLoader();
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
            this.addButton({ParentView:this,label:label,action:this.action,do_submit:true,is_default:true});
        }else{
            var i;
            //determine default action:
            for(i=0;i<this.content.buttons.length;i++){
                var def = this.content.buttons[i];
                if(def.do_submit && (!this.default_action || def['default'])){
                    //first submit-button (or the one specially marked as "default") found: mark it as default
                    this.default_action = def.action;
                }
            }

            for(i=0;i<this.content.buttons.length;i++){
                var def = this.content.buttons[i];
                def.ParentView = this;
                def.is_default=(def.action == this.default_action);
                this.addButton(def);
            }
        }
    },

    /*overwritten from base-class: when "page" is given, go to parent-class::_getButton
    otherwise return a FormButton
    */
    _getButton: function(button_def){
        if(button_def.page){
            return this._super(button_def);
        }
        return OXI.FormButton.create(button_def);
    },

    _initFields:function(){
        this.fields = this.content.fields;
        var i;
        var FormView = this;
        for(i=0;i<this.fields.length;i++){
            var field=this.fields[i];
            var ContainerView;
            if(field.clonable){
                //wrap FieldContainer  in ClonableContainer
                ContainerView = OXI.ClonableFieldContainer.create({fieldDef:field,FormView:FormView});
            }else{
                ContainerView = OXI.FormFieldFactory.getComponent(field.type, {fieldDef:field,FormView:FormView});
            }

            this.FieldContainerList.push(this.createChildView(ContainerView));
            var i = this.FieldContainerList.length -1;
            this.fieldContainerMap[field.name] = i;
            //js_debug('added field '+field.name+ ' to field-map with index '+i);
        }
    },

    updateFields: function(fields){
        var i;
        for(i=0;i< fields.length;i++){
            var fieldDef = fields[i];
            if(!fieldDef.name)continue;
            var FieldView = this.getFieldView(fieldDef.name);
            FieldView.updateFormProperties(fieldDef);
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


OXI.ClonableFieldControler =  Ember.Controller.extend({
    actions: {
        addField: function(){
            //js_debug('addField triggered');
            this.view.addField();
        },
        removeField: function(fieldindex){
            //js_debug('removeField ' + fieldindex);
            this.view.removeField(fieldindex);
        }
    },

    _lastItem: '' //avoid trailing commas
});

OXI.ClonableFieldContainer = OXI.View.extend({


    templateName: "form-clonable",
    jsClassName:'OXI.ClonableFieldContainer',

    FormView:null,//set via constructor
    fieldDef:null,//set via constructor
    FieldContainerList: null,
    label:null,
    fieldname:null,

    hasRightPane:function(){
        //this.debug('hasRightPane? ');
        return this.FormView.hasRightPane();
    }.property(),

    getKey:function(){
         return this.fieldname;
    },

    init:function(){

        this._super();
        if(!this.fieldDef){
            App.applicationAlert('ClonableFieldContainer: no fielddef!');
        }
        this.set('label',this.fieldDef.label);
        this.set('fieldname', this.fieldDef.name);
        this.set('FieldContainerList', Ember.ArrayController.create({
            content: Ember.A([])
        }));
        var i;
        //for each given value in value-array one field
        //this.debug('given values' + typeof this.fieldDef.values);
        var values = (typeof this.fieldDef.value == 'object' && this.fieldDef.value.length>0)?this.fieldDef.value : [this.fieldDef.value];
        for(i=0;i<values.length;i++){
            this.addField(values[i]);
        }

        this.set('controller',OXI.ClonableFieldControler.create({view:this}));
    },

    addField: function(value){
        var fieldDef = this.fieldDef;
        fieldDef.value = value;
        var FieldView = OXI.FormFieldFactory.getComponent(this.fieldDef.type,{fieldDef:fieldDef,FormView:this.FormView});
        this.FieldContainerList.pushObject(this.createChildView(FieldView));
        this._updateIndex();
    },

    removeField: function(fieldindex){
        var FieldView = this.FieldContainerList.content[fieldindex];
        if(!FieldView){
            js_debug('no FieldView at index '+fieldindex);
            return
        }

        this.FieldContainerList.removeAt(fieldindex);
        FieldView.destroy();
        this._updateIndex();

    },

    /**
    reindexing all clone fields, set property "isLast":
    */
    _updateIndex: function(){
        var last_index = this.FieldContainerList.content.length -1;
        this.FieldContainerList.forEach(
        function(FieldView, index, enumerable){
            FieldView.set('fieldindex',index);
            var isLast = (index==last_index);
            FieldView.set('isLast',isLast);
        }
        );
    },

    isValid: function(){
        this.resetErrors();
        var isValid = true;
        this.FieldContainerList.forEach(
        function(FieldView, index, enumerable){
            if(! FieldView.isValid()){
                isValid = false;
            }
        }
        );
        return isValid;
    },


    getKeyValueEntries: function(){
        var entries = {};
        this.FieldContainerList.forEach(
            function(FieldView, index, enumerable){
                var k = FieldView.getKey();
                if(!entries[k]){
                    entries[k] = [];
                }
                entries[k].push(FieldView.getValue());
            }
        );
        return entries;
    },

    _lastItem: '' //avoid trailing commas
});

OXI.DynamicKeyView = OXI.View.extend({
    templateName: "form-dynamic-key-selection",
    jsClassName:'OXI.DynamicKeyView',
    options:null,
    SelectView: null,
    init:function(){

        this._super();
        this.SelectView = this.createChildView(OXI.Select.create({options:this.options}));
    },

    getSelectedKey: function(){
        return (this.SelectView.selection)?this.SelectView.selection.value:'';
    },

    _lastItem: '' //avoid trailing commas
});

OXI.FormFieldContainer = OXI.View.extend({
    templateName: "form-field",
    fieldDef:null,//set via constructor
    FormView:null,//set via constructor

    FieldView: null,
    DynamicKeyView: null,
    label:null,
    fieldname:null,
    isRequired:true,
    clonable: false,

    classNames: ['form-group'],
    classNameBindings: ['_hasError:has-error'],

    isValid: function(){
        this.resetErrors();
        if(this.isRequired && this.fieldindex==0){
            if(!this.getValue()){
                this.setError('Please specify a value');
                return false;
            }
        }
        return true;
    },

    updateFormProperties: function(fieldDef){
        var k;
        for(k in fieldDef){
            if(k=='name' || k=='type')continue;
            if(k=='visible'){
                this.toggle(fieldDef[k]);
                continue;
            }
            this.set( k,fieldDef[k]);
            this.FieldView.set(k,fieldDef[k]) ;
        }
    },

    hasRightPane:function(){
        //this.debug('hasRightPane? ');
        return this.FormView.hasRightPane();
    }.property(),

    hasDynamicKeys:function(){
        return (this.DynamicKeyView);
    }.property(),

    //needed for clonalbe fields:
    fieldindex:0,
    isFirst: function(){
        return (this.fieldindex==0);
    }.property('fieldindex'),

    isLast: false,//wird vom ClonableFieldContainer gesetzt

    _toString:function(){
        return this._super()+' '+this.getKey();
    },

    getKey:function(){
         if(this.DynamicKeyView){
            return this.DynamicKeyView.getSelectedKey();
         }
         return this.fieldname;
    },



    init:function(){
        //Ember.debug('OXI.FormFieldContainer :init '+this.fieldDef.label);
        this.isRequired = true;
        this.FieldView = null;
        this.DynamicKeyView = null;

        this._super();
        this.label = this.fieldDef.label;
        this.fieldname = this.fieldDef.name;
        if(this.fieldDef.keys && typeof(this.fieldDef.keys) =='object'){
            this.DynamicKeyView = this.createChildView(OXI.DynamicKeyView.create({options:this.fieldDef.keys}));
        }
        if(typeof(this.fieldDef.visible) != 'undefined'){
            var bVis = (this.fieldDef.visible)?true:false;
            this.toggle(bVis) ;
        }

        if(this.fieldDef.is_optional){//required is default!
            this.isRequired = false;
        }
    },
    setFieldView:function(View){
        this.FieldView = this.createChildView( View );
        if(!this.isVisible){
            //this.FieldView.set( 'isVisible',false);
        }
    },
    destroy: function() {
        //Ember.debug('FormFieldContainer::destroy:'+this.getKey());
        this._super()
    },
    getValue:function(){
        return this.FieldView.value;
    },

    getKeyValueEntries:function(){
       var k = this.getKey();
       var entries = {};
       entries[k] = this.getValue();
       return entries;
    },

    _lastItem: '' //avoid trailing commas
});

OXI.TextFieldContainer = OXI.FormFieldContainer.extend({

    jsClassName:'OXI.TextFieldContainer',
    init:function(){
        //Ember.debug('OXI.TextFieldContainer :init '+this.fieldDef.label);
        this._super();
        this.setFieldView(OXI.TextField.create(this.fieldDef));
    },

    _lastItem: '' //avoid trailing commas
});

OXI.TextFieldCertIdentifierContainer = OXI.FormFieldContainer.extend({

    jsClassName:'OXI.TextFieldCertIdentifierContainer',
    init:function(){
        //Ember.debug('OXI.TextFieldContainer :init '+this.fieldDef.label);
        this._super();
        if (!this.fieldDef.autoComplete) {
        	this.fieldDef.autoComplete = {source: '/cgi-bin/webui.cgi?action=certificate!autocomplete&query=%QUERY', type: 'url' };
        }
        this.setFieldView(OXI.TextField.create(this.fieldDef));
    },

    _lastItem: '' //avoid trailing commas
});

OXI.HiddenFieldContainer = OXI.TextFieldContainer.extend({
    init:function(){
        this._super();
        this.hide();
    },

    _lastItem: '' //avoid trailing commas
});

OXI.DatetimeFieldContainer = OXI.TextFieldContainer.extend({

	init:function(){
		this._super();
		if (typeof this.fieldDef.notime != undefined) {
			this.notime = this.fieldDef.notime;
		}
		if (typeof this.fieldDef.nodate != undefined) {
			this.nodate = this.fieldDef.nodate;
		}

	},
    /**
    re-convert the datepicker format "mm/dd/yyyy" to specified return format
    return format can be specified via field parameter "return_format"
    for valid formats see OpenXPKI::Datetime
    default is "epoch"

    */
    getValue:function(){
        var v = this._super();
        if(!v) return v;

        var return_format = (this.fieldDef.return_format) ? this.fieldDef.return_format : 'epoch';

        switch(return_format){
            case 'terse':
            	return moment(v).format('YYYYMMDDhhmmss');
            case 'printable':
                return moment(v).format('YYYY-MM-DD hh:mm:ss');
            case 'iso8601':
            	return moment(v).format('YYYY-MM-DDThh:mm:ss');
            case 'epoch':
            	return moment(v).format('X');
                return 0;
            default:
                App.applicationAlert('date field '+this.label+': no valid return format specified: '+return_format);
                return 0;
        }

    },

    /**
    convert the stupid textfield to an bootstrap datepicker
    for documentation see http://bootstrap-datepicker.readthedocs.org/en/latest/
    */
    didInsertElement: function(){

        this._super();
        var options = {};
        var DateNotBefore = this._getDateObjectFromTime(this.fieldDef.notbefore);
        if (DateNotBefore) {
            options.minDate = DateNotBefore;
        }

        var DateNotAfter = this._getDateObjectFromTime(this.fieldDef.notafter);
        if (DateNotAfter) {
            options.maxDate = DateNotAfter;
        }

        if (this.nodate) {
        	options.pickDate = false;
        }

        if (this.notime) {
        	options.pickTime = false;
        }

        if (this.fieldDef.value) {
        	options.defaultDate = this._getDateObjectFromTime(this.fieldDef.value);
        }
        console.log(this.fieldDef);
        console.log(options);

        this.$('input').datetimepicker(options);

        // This creates a readable string in the input field
        if (options.defaultDate) {
        	this.$('input').data("DateTimePicker").setDate(options.defaultDate);
        }

    },

    /**
    returns a moment object or undefined
    recognices the string "now", epoch or any string parseable by
    the moment lib (http://momentjs.com/)
    */
    _getDateObjectFromTime: function(time){
        if (!time) return;

        if(time == 'now'){
            return moment();
        }

        // digits only is epoch
        if(time.match(/^\d+$/)) {
        	time = parseInt(time) * 1000;
        }
        // Try to use moment lib to parse the string, will also recognize the epoch
        var D = moment(time);
        if (D.isValid()) {
        	return D;
        }

    },

    _lastItem: '' //avoid trailing commas
});

OXI.DateFieldContainer = OXI.DatetimeFieldContainer.extend({
	init:function(){
		this._super();
		this.notime = true;
	}
});

OXI.TimeFieldContainer = OXI.DatetimeFieldContainer.extend({
	init:function(){
		this._super();
		this.nodate = true;
	}
});

OXI.CheckboxContainer = OXI.FormFieldContainer.extend({
    templateName: "form-checkbox",
    jsClassName:'OXI.CheckboxContainer',
    init:function(){
        //Ember.debug('OXI.CheckboxContainer :init '+this.fieldDef.label);
    	this.fieldDef.type = 'checkbox';
        this._super();
        this.setFieldView(OXI.Checkbox.create(this.fieldDef));
    },
    isValid:function(){
        return true;//checkbox shopuld be always valid
    },

    getValue:function(){
        return (this.FieldView.isChecked())?1:0;
    },

    _lastItem: '' //avoid trailing commas
});

OXI.TextAreaContainer = OXI.FormFieldContainer.extend({

    jsClassName:'OXI.TextAreaContainer',
    init:function(){
        //Ember.debug('OXI.TextFieldContainer :init '+this.fieldDef.label);
        this._super();
        this.setFieldView(OXI.TextArea.create(this.fieldDef));
    },

    _lastItem: '' //avoid trailing commas
});



OXI.PulldownContainer = OXI.FormFieldContainer.extend({

    jsClassName:'OXI.PulldownContainer',



    editable:false,
    optionAjaxSource:null,
    _isComboBox:false,


    triggerSelectionChanged:function(){
        //js_debug('triggerSelectionChanged');
        if(this.fieldDef.actionOnChange){
            this.debug('call actionOnChange '+ this.fieldDef.actionOnChange );
            this.FormView.callServer(this.fieldDef.actionOnChange, this);
        }
    },

    init:function(){
        //Ember.debug('OXI.PulldownContainer :init '+this.fieldDef.label);
        this.set('editable',false);
        this._super();
        if(this.fieldDef.editable){
            this.set('editable',true);
            this.set('_isComboBox',true);
        }

        if(typeof this.fieldDef.options == 'string'){
            this.set('_isComboBox',true);
            this.set('optionAjaxSource',this.fieldDef.options);
            this.fieldDef.options = [];
        }
        this.setFieldView(OXI.Select.create(this.fieldDef));
    },

    /**
    returns the selected value
    */

    getValue:function(){
        if(this._isComboBox){
            var v = this.$('select').combobox('getValue');
            this.debug({combo: this.getKey(), combovalue: v});
            return v;
        }
        return this._getSelected();
    },

    _getSelected:function(){
        return (this.FieldView.selection)?this.FieldView.selection.value:'';
    },

    change: function () {
        //console.log(this.FieldView.name + ' changed to '+this.getValue());
    },

    didInsertElement: function(){

        this._super();
        if(this._isComboBox){
            js_debug(this.getKey()+' is editable');
            var comboOptions = {queryDelay: 300,editable:this.editable};
            if(this.optionAjaxSource){
                comboOptions.ajaxSource = App.serverUrl + '?action='+this.optionAjaxSource;
            }

            this.$('select').addClass('form-control-combo');
            this.$('select').combobox(comboOptions);

        }
    },



    _lastItem: '' //avoid trailing commas

});


OXI.Checkbox = Ember.Checkbox.extend(
{
	label: '',

	init: function(){
		this._super();
	},
    isChecked:function(){
        var checkbox = this.$();
        //we ask the DOM-element itself, not its jquery wrapper
        return checkbox[0].checked;
    },
    _lastItem: '' //avoid trailing commas
}
);



OXI.Select = Ember.Select.extend(
{
    optionLabelPath: 'content.label',
    optionValuePath: 'content.value',

    classNames: ['form-control'] ,
    prompt:null,

    _optionUpdateTrigger: function(){
       this.setOptions(this.options);
    }.observes('this.options'),


    checkSelection:function(){
        var v = (this.selection)?this.selection.value:'-';
        js_debug(this.name +': sel val changed: ' + v);
        this.get('parentView').triggerSelectionChanged();

    }.observes('selection.value'),

    init:function(){
        //Ember.debug('OXI.Select :init ');
        this._super();
        this.setOptions(this.options);
        if( !this.isRequired || (typeof this.prompt != 'undefined' && this.prompt=='' )) {
            this.prompt = ' ';//display white option
        }

        //this.set('controller',OXI.SelectFieldControler.create({view:this}));
    },

    setOptions:function(options){
        options = (typeof options == 'object')?options:[];
        this.set('content', Ember.A(options));
        if(typeof this.prompt == 'undefined' && !this.value && options[0]){
            this.set('selection',   options[0]);
        }
    },

    _lastItem: '' //avoid trailing commas

});

OXI.TextArea = Ember.TextArea.extend(
{
    classNames: ['form-control']
}
);

OXI.TextField = Ember.TextField.extend(
{
    classNames: ['form-control'],
	autoComplete: null,//source, value, url
    toggle:function(bShow){
        this.set('isVisible', bShow);
    },
	didInsertElement: function(){
	if(this.autoComplete){


		var tt_init = {
		};

		var bh_init = {
			datumTokenizer: function(d) { alert(d); return Bloodhound.tokenizers.whitespace(d.val); },
			queryTokenizer: Bloodhound.tokenizers.whitespace,
		};
		if(this.autoComplete.type == 'value' || this.autoComplete.type == 'source') {
			bh_init.local = this.autoComplete.source;
		}
		if(this.autoComplete.type == 'url') {
			bh_init.remote = this.autoComplete.source;
		}

		var mySource = new Bloodhound(bh_init);
		mySource.initialize();

		$('#'+this.elementId).typeahead(tt_init, {
			source: mySource.ttAdapter(),
			templates: { suggestion: function(model) { return '<span>'+model.label+'</span>'; } },
		});

	}
	},
    _lastItem: '' //avoid trailing commas
}
);

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
    },

    _lastItem: '' //avoid trailing commas
});

OXI.UploadButton = Ember.View.extend({
	jsClassName:'OXI.PageButton',
	templateName: "page-button",
	tagName: 'button',
	classNames: ['btn'],
	parent: null,

	click: function(){
		this.upload();
	},

	upload: function(){
		var certToSend = $('#' + this.parent.textArea.elementId).val();
		var dataToSend = {'action' : 'upload_cert', 'rawData' : certToSend};
		if(certToSend){
			$.post(App.serverUrl, dataToSend, function(data, status, xhr){
				alert(data.message);
			});
		}else{
			App.applicationAlert('Please chose a File to upload!');
		}
	},
	_lastItem: ''
});

OXI.Upload = Ember.TextField.extend({

	jsClassName:'OXI.Upload',
	classNameBindings:['btn_type'],
	classNames: ['form-control'],
	type: 'file',
	textArea: OXI.TextArea.create(),
	areaVisible: 0,
	uploadButton: null,
	maxSize: 0, //maxSize in byte!
	allowedFiles: null,
	textAreaSize: null,

	init: function(){
		this._super();
	},

	didInsertElement: function(){
		var field = this.$();
		var self = this;
		if(this.textAreaSize){
			var area = this.textArea.$().css({"width" : this.textAreaSize[0].width, "height" : this.textAreaSize[1].height});
		}
		if(this.areaVisible == 0){
			this.textArea.$().css('display', 'none');
		}
		field.textArea = this.textArea;
		field.maxSize = this.maxSize;
		field.allowedFiles = this.allowedFiles;
		field[0].addEventListener('change', function(e){
			var tempExtension = e.target.value.split('.');
			var extension = tempExtension[tempExtension.length-1];
			if(field.allowedFiles && !field.allowedFiles.contains(extension)){
				bootbox.alert("This file extension is not allowed for upload. Allowed extensions are: "+ field.allowedFiles.toString());
				field.val('');
				$('#' + field.textArea.elementId).val('');
				return false;
			}
			var reader = new FileReader();
			reader.textArea = $('#' + field.textArea.elementId);
			if(!field.textArea.elementId){
				reader.textArea = $(document).find('textarea');
				}
			reader.maxSize = field.maxSize;
			reader.readAsDataURL(e.target.files[0]);
			reader.onload = function(e){
				var dataURL = reader.result;
				$('#data').val(dataURL);
				if(reader.maxSize && reader.maxSize >= e.total){
					reader.textArea.val(dataURL);//if maxSize is set and its valid
				}else if(!reader.maxSize){
					reader.textArea.val(dataURL);//if maxSize is not set
				}else{
					bootbox.alert('Your file is too big to upload.');
					field.val('');
					$('#' + field.textArea.elementId).val('');
				}
			};
		});

	},
	_lastItem: ''
});

OXI.UploadContainer = OXI.FormFieldContainer.extend({
    templateName: "upload-view",
    jsClassName:'OXI.UploadContainer',
	uploadField: '',
	textArea: null,
    init:function(){
        this._super();
		this.uploadField = OXI.Upload.create(this.fieldDef);
		this.uploadField.set('type', 'file');//naming issue in componentFactory
		this.uploadField.set('name', 'file');
		this.textArea = this.uploadField.textArea;
		this.textAreaId = this.uploadField.textArea.elementId;
		this.setFieldView(this.uploadField);
    },
    getValue: function(){
    	return $('#' + this.textAreaId).val();
    },
    isValid: function(){
		if($('#'+this.textAreaId).val() != '' && $('#'+this.textAreaId).val() != null){
			return true;
		}else{
			return false;
		}
	},
    _lastItem: '' //avoid trailing commas
});

OXI.RadioContainer = OXI.FormFieldContainer.extend({
	templateName: "radio-view",
	jsClassName: 'OXI.RadioContainer',
	options: null,
	multi: false,
	checkBoxList: null, //should never be set by constructor

	init:function(){
		this._super();
		this.options = this.fieldDef.options;
		if(this.fieldDef.multi){
			this.multi = this.fieldDef.multi;
			this.checkBoxList = new Array(this.options.length);
			for(var i = 0; i < this.options.length; i++){
				/*this.checkBoxList[i] = OXI.Checkbox.create();
				this.checkBoxList[i].set('value', this.options[i].value);
				this.checkBoxList[i].set('label', this.options[i].label);*/
				this.checkBoxList[i] = this.createChildView(OXI.Checkbox.create().set('value', this.options[i].value).set('label', this.options[i].label));
				//var FieldView = OXI.FormFieldFactory.getComponent('checkbox',{fieldDef:[{label : this.options[i].label} , {value: this.options[i].value}],FormView:this.FormView});
				//this.checkBoxList[i] = FieldView;
			}
		}else{
			this.checkBoxList = new Array(this.options.length);
			for(var i = 0; i < this.options.length; i++){
				this.checkBoxList[i] = this.options[i].value;
			}
		}
	},
	getValue: function(){
		if(this.multi){
			var values = [];
			for(var i = 0; i <this.checkBoxList.length; i++){
				if (this.checkBoxList[i].isChecked()) {
					values.push(this.checkBoxList[i].value);
				}
			}
			return values;

			/*var values = [];
	        this.checkBoxList.forEach(
	        function(FieldView){
	            values.push(FieldView.getValue());
	        }
	        );
	        return values;*/
			}
		else{
			var checkBoxList = this.checkBoxList;
			var ret = '';
			var i = -1;
			$("input[type = 'radio']").each(function(){
				i++;
				if($(this).get(0).checked){
					ret = checkBoxList[i];
				}
			});
			return ret;
		}
	},
	isValid: function(){
		var ret = false;
		for(var i = 0; i < this.checkBoxList.length; i++){
			if(this.checkBoxList[i].isChecked()){
				ret = true;
			}
		}
		return ret;
	},
	_lastItem: ''

});

//main validator class
OXI.Validator = Ember.Object.extend({
	inputField: null,

	getInput: function(){
		return $('#'+this.inputField.elementId).val();
	},
	setInput: function(input){
		$('#'+this.inputField.elementId).val(input);
	},
	validate: function(data){
		//override in subclass
	},

	_lastItem: ''
});

OXI.EmailValidator = OXI.Validator.extend({

	validate: function(data){
		var mail = this.getInput();
		var match = mail.match(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}\b/);
		return match ? true : false;
	},

	_lastItem: ''
});

//popover helper class
OXI.Popover = Ember.Object.extend({
	popoverField: null,
	options: null,
	register: function(){
		var field = $('#'+this.popoverField.elementId);
		field.options = this.options;
		var trigger =  field.options['trigger'] ? field.options['trigger'] : 'manual';
		field.popover({
			placement: function(){
				return field.options['placement'] ? field.options['placement'] : 'top';
			},
			html: 'true',
			content: function(){
				return field.options['content'] ? field.options['content'] : '<div><p>No content defiend<p></div>';
			},
			trigger: trigger// return field.options['content'] ? field.options['content'] : 'hover' provokes an intern bug in bootstrap!
		});
	},
	show: function(){//can only be called after register was called
		$('#'+this.popoverField.elementId).popover('show');
	},
	hide: function(){//can only be called after register was called
		$('#'+this.popoverField.elementId).popover('hide');
	},
	_lastItem: ''
});

OXI.MetaEmailField = OXI.TextField.extend({
	validator: null,
	popover: null,
	didInsertElement: function(){
		this.validator = OXI.EmailValidator.create({'inputField' : this});
		var options = new Object();
		options['trigger'] = 'manual';
		options['placement'] = 'top';
		this.popover = OXI.Popover.create({'popoverField' : this, 'options' : options});
		this.popover.register();
		var field = this.$();
		field.validator = this.validator;
		field.popover = this.popover;
		field.focusout(function(){
			if(!field.validator.validate()){
				field.popover.show();
			}
		field.focusin(function(){
			field.popover.hide();
		});
		});
	},
	_lastItem: ''
});

OXI.MetaEmailContainer = OXI.FormFieldContainer.extend({
	templateName: "meta_email-view",
	jsClassName: 'OXI.MetaEmailContainer',
	init: function(){
		this._super();
		this.setFieldView(OXI.MetaEmailField.create(this.fieldDef));
	},
	_lastItem: ''
});
