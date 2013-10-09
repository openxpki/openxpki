
var App = OXI.Application.create();

App.ApplicationRoute = Ember.Route.extend({

<<<<<<< HEAD
   setupController: function(controller) {
      // Ember.debug('ApplicationRoute:setupController');

   }
=======
    setupController: function(controller) {
        // Ember.debug('ApplicationRoute:setupController');

    }
>>>>>>> dsiebeck/feature/webui
});



App.Route = Ember.Route.extend({

<<<<<<< HEAD
   mainActionKey:null,
   subActionKey:null,

   setupController: function(controller) {

      //Ember.debug('App.Route:setupController');

      js_debug('route name: '+ this.routeName);
      //js_debug(this.router.router.targetHandlerInfos,2);
      var routes = this.router.router.targetHandlerInfos;
      var i;
      var final_route = routes[routes.length-1].name;
      js_debug('final route '+final_route);
      if(final_route == this.routeName){
         if(this.routeName.indexOf('.')>0){
            var temp = this.routeName.split('.');
            this.mainActionKey = temp[0];
            this.subActionKey = temp[1];
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
         if(pageKey == 'logout' && !App.user_logged_in){
            pageKey = 'home';
         }
         
         if(pageKey == 'logout'){
            App.callServer({action:pageKey})
            .success(function(json){
               if(json.status.level =='success'){
                  App.logout();
                  
                  location.reload();
                  
               }else{
                  App.applicationError('Server responded with status-level '+json.status.level+' - '+  json.status.message);
               }
               
               
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
   
   
=======
    mainActionKey:null,
    subActionKey:null,

    setupController: function(controller) {

        //Ember.debug('App.Route:setupController');

        js_debug('route name: '+ this.routeName);
        //js_debug(this.router.router.targetHandlerInfos,2);
        var routes = this.router.router.targetHandlerInfos;
        var i;
        var final_route = routes[routes.length-1].name;
        js_debug('final route '+final_route);
        if(final_route == this.routeName){
            if(this.routeName.indexOf('.')>0){
                var temp = this.routeName.split('.');
                this.mainActionKey = temp[0];
                this.subActionKey = temp[1];
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


>>>>>>> dsiebeck/feature/webui


});




//basic initialisation of router:
App.deferReadiness();
App.checkSideStructure()
.success(
function(){
<<<<<<< HEAD
   App.initRouter();
   App.advanceReadiness();
=======
    App.initRouter();
    App.advanceReadiness();
>>>>>>> dsiebeck/feature/webui
});









