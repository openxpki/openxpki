
var App = OXI.Application.create();

App.ApplicationRoute = Ember.Route.extend({
    setupController: function(controller) {
        // Ember.debug('ApplicationRoute:setupController');
    }
});


App.Route = OXI.Route;

//basic initialisation of router:
App.deferReadiness();
App.checkSideStructure()
.success(
function(){
    App.initRouter();
    App.advanceReadiness();
});









