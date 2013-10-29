
var App = OXI.Application.create();

App.ApplicationRoute = Ember.Route.extend({
    setupController: function(controller) {
        // Ember.debug('ApplicationRoute:setupController');
    }
});

/* //demonstration of dynamically added new Form-Classes
OXI.FormFieldFactory.registerComponent('select','MySpecialSelect',OXI.FormFieldContainer.extend({
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
                                    }));
*/


App.Route = OXI.Route;

//basic initialisation of router:
App.deferReadiness();
App.checkSideStructure()
.success(
function(){
    App.initRouter();
    App.advanceReadiness();
});









