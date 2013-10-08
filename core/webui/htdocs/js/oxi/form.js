/**
defines classes for Forms
*/

OXI.FormView = OXI.View.extend({
   // We are setting templateName manually here to the default value
   templateName: "form-view",
   jsClassName:'OXI.FormView',

   //content prop: must be set via create() , info comes fropm server
   content:null,

   submit_label: null,
   form_title :null,
   action:null,

   fields:[],

   FieldContainerList:[],   

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
                if(!json.status){
                    App.applicationError('Server returned no status!');
                    return;  
                }
                if(!json.status.level){
                    App.applicationError('Server returned no status-level!');
                    return;  
                }
                switch(json.status.level){
                    case 'error':
                        var msg = (json.status.message)?json.status.message:'Unkown server error.';
                        FormView.setError(msg);
                        if(json.field_errors){
                            var field;
                            for(field in json.field_errors){
                                var FieldView = FormView.getFieldView(field);
                                FieldView.setError(json.field_errors[field]);
                            }
                        }
                        break;
                    case 'success': 
                    
                        if(json.reloadTree){
                            js_debug('reload tree!');
                            try{
                               if(json.goto){
                                 if(json.goto.indexOf('/')!=0){
                                    json.goto = '/'+json.goto;
                                 }
                                 location.hash=json.goto;
                              }else{
                                 location.hash='/';
                              }
                           }catch(e){
                              
                           }
                           js_debug('do reload');
                            location.reload();
                            
                        }else{
                           if(json.page){
                               App.get('MainView').initSections(json);
                           }  
                        }
                    
                        
                        break;
                    default:
                        App.applicationError('Server responded with status-level '+json.status.level+', which is not impkemeted yet.');
                        return;  
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
      this.fieldContainerMap = {};
      this.fields = [];
      
      this.form_title=null;
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
      if (this.content.submit_label){
         this.submit_label = this.content.submit_label;
      }
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
	    return this.FieldView.selection.value;
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