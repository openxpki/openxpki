/* flexible factory for new (OXI)-Components */

"use strict";

OXI.ComponentFactory = Ember.Object.extend({

    _componentMap : {},//must bve defined in concrete instances!

    getComponent: function(type,params){
        if(!type){
            App.applicationAlert('OXI.ComponentFactory:getComponent called without type!');
            return;   
        }
        var classname = this._componentMap[type];
        if(!classname){
            App.applicationAlert('OXI.ComponentFactory: no classname defined for type '+type);
            return;
        }
        if(!OXI[classname]){
            App.applicationAlert('OXI.ComponentFactory: container-class '+classname+' for type '+type+' not defined in OXI namespace');
            return;
        }
        if(!params){
            params = {};
        }
        return OXI[classname].create(params);
    },

    registerComponent: function(type,classname, method,overwrite){
        //security: don't overwrite existing components by hazard
        if(!overwrite && OXI[classname]){
            App.applicationAlert('OXI.ComponentFactory: Component OXI.'+classname+' is already defined - use param "overwrite" if you really want to replace it.');
            return;
        }
        this._componentMap[type] = classname;
        OXI[classname] = method;
    }

});

OXI.FormFieldFactory = OXI.ComponentFactory.create({

    _componentMap : {
        text :      'TextFieldContainer',
        hidden :    'HiddenFieldContainer',
        password:   'TextFieldContainer',
        textarea:   'TextAreaContainer',
        select :    'PulldownContainer',
        checkbox:   'CheckboxContainer',
    	date :      'DateFieldContainer',
    	bool :      'CheckboxContainer' 	
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


