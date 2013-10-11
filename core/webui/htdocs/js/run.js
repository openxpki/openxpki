
var App = OXI.Application.create();

App.ApplicationRoute = Ember.Route.extend({

    setupController: function(controller) {
        // Ember.debug('ApplicationRoute:setupController');

    }
});



App.Route = Ember.Route.extend({

    mainActionKey:null,
    subActionKey:null,

    setupController: function(controller) {

        //Ember.debug('App.Route:setupController');

        js_debug('route name: '+ this.routeName);
        //js_debug(this.router.router.targetHandlerInfos,2);
        var routes = this.router.router.targetHandlerInfos;
        var i;
        var final_route = routes[routes.length-1].name;
        
        if(final_route == this.routeName){
            js_debug('final route reached:'+final_route);
            var p = this.routeName.indexOf('.');
            if(p>0){
                
                this.mainActionKey = this.routeName.substr(0,p);
                this.subActionKey = this.routeName.substr(p+1);
            }else{
                this.subActionKey =  this.routeName;
            }
        }
    },

    renderTemplate: function(controller, model) {
        //js_debug('renderTemplate');

        if(this.subActionKey){
            controller.set('current_action', this.subActionKey);

            var Route = this;
            var pageKey = (this.subActionKey=='index')? this.mainActionKey:this.subActionKey;
            if(!pageKey || pageKey == 'index' ){//this is the case when called without hashtagin URI
                pageKey ='home';
            }
            

            if(pageKey == 'logout'){
                App.callServer({action:pageKey})
                .success(function(json){
                    App.logout();
                    App.reloadPage();
                });
            }else{
                App.callServer({page:pageKey})
                .success(function(json){
                    Ember.debug('got page infos from server');
                    Route.applyJsonToPage(json);
                });
            }
        }
    },

    applyJsonToPage:function(json){

        App.set('MainView',OXI.SectionViewContainer.create());

        App.MainView.initSections(json);
        this.render('main-content',{outlet:'main-content'});
        
        //js_debug('available routes: '+Ember.keys(App.Router.router.recognizer.names));
    },




});




//basic initialisation of router:
App.deferReadiness();
App.checkSideStructure()
.success(
function(){
    App.initRouter();
    App.advanceReadiness();
});









