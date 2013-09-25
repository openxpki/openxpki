var route_structure = {
   home :{
      label: 'Home',
      entries: {
          my_tasks:{label : "My tasks"},
          my_workflows:{label : "My workflows"},  
          my_certificates:{label : "My certificates"} , 
          key_status:{label : "Key status"}  
      }
   },
   
   request:{
      label: 'Request',
      entries: {
          request_cert:{label : "Request new certificate"},
          request_renewal:{label : "Request renewal"},  
          request_revocation:{label : "Request revocation"} , 
          issue_clr:{label : "Issue CLR"}  
      }
   },
   info:{
      label: 'Information',
      entries: {
          ca_cetrificates:{label : "CA certificates"},
          revocation_lists:{label : "Revocation lists"},  
          pollicy_docs:{label : "Pollicy documents"} , 
      }
   },
   search:{
      label: 'Search',
      entries: {
          search_cetrificates:{label : "Certificates"},
          search_workflows:{label : "Workflows"},  
      }
   },

};

//defining the app
App = Ember.Application.create(
   {
     LOG_TRANSITIONS: true,
     rootElement: '#application',
     //store currentPath (of router) to have a observable property for navigation-highlighting:
     currentPath: '',
     currentRootPath:'',

    ApplicationController : Ember.Controller.extend({
        updateCurrentPath: function() {
            App.setCurrentPath( this.get('currentPath'));
        }.observes('currentPath')
    }),
    
    NavArrayController : Ember.ArrayController.create({
               content: Ember.A([])
            }
    ),
    
    SideNavs : {},
    
    CurrentSideNav : null,
    
    
    
    setCurrentPath:function(currentPath){
       js_debug('updateCurrentPath: '+ currentPath );
       this.set('currentPath',currentPath);
       var currentRootPath = currentPath.split('.')[0];
       if(currentRootPath =='index')currentRootPath='home';
       this.set('currentRootPath',currentRootPath);
       this.set('CurrentSideNav',this.SideNavs[currentRootPath]);
    },
    
    getCurrentSideNav:function(){
        return (this.CurrentSideNav) ?this.CurrentSideNav:this.SideNavs['home'];
    }
      
   }
);

App.Route = Ember.Route.extend({
  
  mainActionKey:null,
  subActionKey:null,
  
  setupController: function(controller) {
    // Set the IndexController's `title`
    controller.set('title', 'def title');
    //debugger;
    js_debug('path: '+ this.routeName);
    if(this.routeName.indexOf('.')>0){
         var temp = this.routeName.split('.');
         this.mainActionKey = temp[0];
         this.subActionKey = temp[1];  
    }
  },
  renderTemplate: function(controller, model) {
      js_debug('renderTemplate');
      if(this.subActionKey){
         controller.set('current_action', this.subActionKey);
         this.render('simple-content');
      }
   }
});

//Navigation-Stuff



// NavItem has two settable properties and 
// an programmatic active state depending on the router
App.NavItem = Ember.Object.extend({
     title: '',
     goto: null,    // this is the name of the state we want to go to!
     entries:null,
     active: function(){
             //js_debug({currPath:App.currentPath,goto:this.get("goto")});
             if (App.currentPath == this.get("goto")){//App.Router.router.isActive(this.get("goto"))
               return true;
             }else{
               return false;
             }
           }.property('App.currentPath')//react to changes of current path
     }    
)

App.NavRessource = Ember.Object.extend({
        title: '',
        rootPath: null,   
        active: function(){
                //js_debug({currPath:App.currentPath,goto:this.get("goto")});
                if (App.currentRootPath == this.get("rootPath")){
                  return true;
                }else{
                  return false;
                }
              }.property('App.currentRootPath'),//react to changes of root path
        getPath:function(){
         return this.rootPath;
       }.property()   
           
     }
       
)

/* the actual NavElement which gets the class="active" if the 
 property "active" is true, plus a on-click binding to
 make the Router transition to this state
 */
App.SideNavItemView = Ember.View.extend({
    tagName: "li"
   }
)

App.MainNavItemView = Ember.View.extend({
       tagName: "li",
       classNames:['dropdown'] 
    }
)


App.Router.map(function() {
  //js_debug('App.Router.map');
  
  this.route('logout');  
  
  var main_key, second_key, routes,route;
  for(main_key in route_structure){
      var ressource = route_structure[main_key];
      routes = ressource.entries;
      this.resource(main_key,  function() {
          var subLevelControler = Ember.ArrayController.create({ content: Ember.A([])});
          for(route in routes){
               this.route(route);  
               subLevelControler.pushObject(
                  App.NavItem.create({
                     title: routes[route].label,  
                     'goto': main_key+'.'+route
                   })
               );
          }
          App.NavArrayController.pushObject(
               App.NavRessource.create({
                        rootPath : main_key,
                        title:     ressource.label,
                        entries : subLevelControler
                     })
               );
          App.SideNavs[main_key] = subLevelControler;
        });
  }
});




App.ApplicationRoute = Ember.Route.extend({
  
  route_structure: route_structure,
  
  setupController: function(controller) {
      Ember.debug('ApplicationRoute:setupController');
    
  }
});




