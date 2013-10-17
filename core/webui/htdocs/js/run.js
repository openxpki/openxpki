
var App = OXI.Application.create();

App.ApplicationRoute = Ember.Route.extend({
    setupController: function(controller) {
        // Ember.debug('ApplicationRoute:setupController');
    }
});


App.Route = Ember.Route.extend({

    mainActionKey:null,
    subActionKey:null,
    
    
    activate:function(){
        js_debug('App.Route activate') ;
    },
    setupController: function(controller) {
        //js_debug('App.Route.setupController: route name: '+ this.routeName);
        //js_debug(this.router.router.targetHandlerInfos,2);
        var routes = this.router.router.targetHandlerInfos;
        var i;
        var final_route = routes[routes.length-1].name;

        if(final_route == this.routeName){
            //js_debug('final route reached:'+final_route);
            
            if(final_route == 'forward'){
                this.subActionKey = App.get('original_target');
                js_debug('forward to original target: '+this.subActionKey);
                App.set('original_target','');
            }else{
            
                var p = this.routeName.indexOf('.');
                if(p>0){
    
                    this.mainActionKey = this.routeName.substr(0,p);
                    this.subActionKey = this.routeName.substr(p+1);
                }else{
                    this.subActionKey =  this.routeName;
                }
            }
        }
    },

    renderTemplate: function(controller, model) {
        

        if(this.subActionKey){
            js_debug('App.Route.renderTemplate for '+this.subActionKey);
            controller.set('current_action', this.subActionKey);

            var Route = this;
            var pageKey = (this.subActionKey=='index')? this.mainActionKey:this.subActionKey;
            if(!pageKey || pageKey == 'index' ){//this is the case when called without hashtagin URI
                pageKey ='home';
            }
            App.set('MainView',OXI.SectionViewContainer.create());
            this.render('main-content',{outlet:'main-content'});
            App.loadPageInfoFromServer(pageKey);
        }
    }

});




//basic initialisation of router:
App.deferReadiness();
App.checkSideStructure()
.success(
function(){
    App.initRouter();
    App.advanceReadiness();
});









