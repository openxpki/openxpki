/* flexible factory for new (OXI)-Components */

OXI.ComponentFactory = Ember.Object.extend({
   
   _componentMap : {},//must bve defined in concrete instances!
   
   getComponent: function(type,params){
       var classname = this._componentMap[type];
       if(!classname){
            App.applicationAlert('OXI.ComponentFactory: no classname defined for type '+type);
            return;
       }
       if(!OXI[classname]){
           App.applicationAlert('OXI.ComponentFactory: container-class '+classname+' for type '+type+' not defined in OXI namespace');
           return;  
       }
       return OXI[classname].create(params);
   },
   
   registerComponent: function(type,classname, method){
       this._componentMap[type] = classname;
       OXI[classname] = method;
   }
    
});

OXI.FormFieldFactory = OXI.ComponentFactory.create({
   
   _componentMap : {
        text :      'TextFieldContainer',
        password:   'TextFieldContainer',
        textarea:   'TextAreaContainer',
        select :    'PulldownContainer',
        checkbox:   'CheckboxContainer' 
    }
   
});

OXI.SectionViewFactory = OXI.ComponentFactory.create({
   
   _componentMap : {
        form :      'FormView',
        text:       'TextView',
        keyvalue:   'KeyValueView',
        grid :      'GridView'
    }
   
});
