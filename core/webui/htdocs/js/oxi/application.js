/**
defines the OXI Application classs
*/



OXI.Route = Ember.Route.extend({

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
            //controller.set('current_action', this.subActionKey);

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


OXI.Application = Ember.Application.extend(
{
    LOG_TRANSITIONS: true,
    //LOG_TRANSITIONS_INTERNAL: true,
    
    rootElement: null,//read from config
    serverUrl:null,//read from config
    cookieName:null,

    user_logged_in: false,
    user:null,
    username:function(){
        if(this.user){
            return this.user.name;
        }else{
            return '';
        }
    }.property('user'),
    userrole:function(){
        if(this.user){
            return this.user.role;
        }else{
            return '';
        }
    }.property('user'),

    //store currentPath (of router) to have a observable property for navigation-highlighting:
    currentPath: '',
    currentRootPath:'',
    SideNavs : {},
    CurrentSideNav : null,
    sideTreeStructure: {},
    
    
    _actualPageRenderCount:0,
    _actualPageKey: null,

    ApplicationController : Ember.Controller.extend({
        updateCurrentPath: function() {
            
            js_debug('ApplicationController:updateCurrentPath '+this.get('currentPath'));
            App.setCurrentPath( this.get('currentPath'));
        }.observes('currentPath'),
        
        
        
    }),

    BadUrlRoute : OXI.Route.extend({
        
        originalTarget:null,
        subActionKey:null,
        
        beforeModel: function(transition) {
            Ember.debug('BadUrlRoute '+location.hash+' check transition');
            this.originalTarget = location.hash.substr(1);
            
            if(!App.user_logged_in){
                App.set('original_target',orig_target);
                js_debug('original_target stored: ' + orig_target);
                this.transitionTo('login');
            }else{
                if(this.originalTarget .indexOf('/') == 0){
                    this.subActionKey  = this.originalTarget .substr(1);   
                }
                
                //this.transitionTo('forward');
            }
        },
        
        setupController: function(controller) {
        },
        
        
        
    }),

    NotfoundRoute: Ember.Route.extend({

        renderTemplate: function(controller, model) {
            var original_target = App.get('original_target');
            if(original_target){
                controller.set('original_target',original_target);
                App.set('original_target','');
            }
            this.render('notfound');
        }
    }),

    Router: Ember.Router.extend({
        
        
        didTransition: function(infos){
            this._super(infos);
            var path = Ember.Router._routePath(infos);
            //this hook is triggered if a link has been clicked on the page
            js_debug('didTransition ' + path); 
            //we check, if the content for the current route(=server page) has been changed (via form actions etc)
            //if so, we reload page infos from server (otherwise, the re-rendered püagecontent (e.e. form-submits, searchresults) will not be changed)
            if(App.get('_actualPageRenderCount')>1){
                 App.reloadPageInfoFromServer();  
            }
            
        }
    }),

    ready: function() {
        Ember.debug('Application ready');
    },

    init:function(){
        this._super();
        this.rootElement = OXI.Config.get('rootElement');
        this.serverUrl = OXI.Config.get('serverUrl');
        this.cookieName = OXI.Config.get('cookieName');
        this._actualPageRenderCount = 0;
    },

    logout:function(){
        this.set('user',null);
        this.set('user_logged_in',false);
    },

    login:function(user){
        this.set('user',user);
        this.set('user_logged_in',true);
    },

    checkSideStructure: function(callback){
        Ember.debug('Application checkSideStructure');
        this.set('CurrentSideNav',null);
        this.set('SideNavs',{});
        this.set('sideTreeStructure',{});
        //this.sideTreeStructure = testStructure;
        var App = this;
        return this.callServer({page:'bootstrap!structure'})
        .done(function(json){
            js_debug('sidestructure retrieved');
            //js_debug( json,2);
            if(json.structure){
                App.set('sideTreeStructure', json.structure);
            }else{
                App.applicationError('call to bootstrap!structure failed!',json);
            }
            if(json.user){
                App.login(json.user);
            }
        });
    },

    applicationError: function(msg,data){
        if(confirm('A bad application error happened: '+msg+'. Do you want to reset your session?')){
            $.removeCookie(this.cookieName);
            this.reloadPage();
        }
        js_debug(data);
    },
    
    applicationAlert: function(msg,data){
        alert(msg);
        js_debug(data);
    },
    
    reloadPageInfoFromServer: function(){
        js_debug('App.reloadPageInfoFromServer');
        this.loadPageInfoFromServer(this._actualPageKey);
    },
    
    loadPageInfoFromServer: function(pageKey){
        var App = this;
        js_debug('App.loadPageInfoFromServer: '+pageKey);
        this.set('_actualPageRenderCount',0);
        this.set('_actualPageKey',pageKey);
        this.callServer({page:pageKey})
            .success(function(json){
                if(pageKey == 'logout'){
                    App.logout();
                    App.reloadPage('login');
                }else{
                    App.renderPage(json);
                }
            });
    },
    
    renderPage: function(json){
        js_debug({'App.renderPage':json},3);
        if(json.status){
            this.MainView.setStatus(json.status);
        }
        if(json.page){
            this.MainView.initSections(json);
            this.set('_actualPageRenderCount',this._actualPageRenderCount +1);
        }
        
        
        
        //this.MainView.get('controller').send('routeContentChanged', true);
        
        if(json.reloadTree){
            var timeout = (json.status)?1000:0;
            window.setTimeout(function(){App.reloadPage(json.goto);},timeout);
            return;   
        }else if(json.goto){
            //goto solo...   
            var timeout = (json.status)?1000:0;
            window.setTimeout(function(){App.goto(json.goto);},timeout);
        }
    },
    
    goto: function(target){
        try{
            target = target.replace(/\./g,'/');
            if(target.indexOf('/')!=0){
                target = '/'+target;
            }
            location.hash=target;
        }catch(e){
        }
    },

    reloadPage: function(goto){
        js_debug('reloadPage!');
        if(goto){
            this.goto(goto);
        }
        js_debug('do reload');
        location.reload();
    },

    callServer: function(params, callback,debug){
        var app = this;
        return jQuery.ajax({
            type: params.action ? "POST" : "GET",
            url: this.serverUrl,
            dataType: "json",
            data:params,
            success: function(json, textStatus){
                if(!json){
                    ajaxErrorAlert(app.serverUrl,textStatus,'no json returned');
                    return;
                }
                if(debug)js_debug(json);

                if(typeof(callback!='undefined') && callback)callback(json);

            },
            error: function(XMLHttpRequest, textStatus){
                //js_debug(XMLHttpRequest);
                ajaxErrorAlert(app.serverUrl,textStatus,XMLHttpRequest.responseText);
            }
        });
    },

    setCurrentPath:function(currentPath){
        js_debug('updateCurrentPath: '+ currentPath );
        this.set('_actualPageRenderCount',0);
        this.set('currentPath',currentPath);
        var currentRootPath = currentPath.split('.')[0];
        if(currentRootPath =='index')currentRootPath='home';
        this.set('currentRootPath',currentRootPath);
        this.set('CurrentSideNav',this.SideNavs[currentRootPath]);
    },

    initRouter: function(){
        var App = this;
        Ember.debug('initRouter');
        this.Router.map(function() {
            Ember.debug('App.Router.map');
            this.route('login');
            this.route('logout');
            this.route('notfound');
            this.route('welcome');
            this.route('forward');
            
            App.set('NavArrayController', Ember.ArrayController.create({
                content: Ember.A([])
            }));
            var i,j;
            for(i=0;i<App.sideTreeStructure.length;i++){
                var ressource = App.sideTreeStructure[i];
                //Ember.debug('add to Top Nav: '+ressource.key);
                if(!ressource.entries || !ressource.entries.length){
                    this.route(ressource.key);
                    App.NavArrayController.pushObject(
                    OXI.NavRessource.create({
                        rootPath : ressource.key,
                        goto:ressource.key,
                        title:     ressource.label,
                        has_entries: false
                    })
                    );

                }else{

                    this.resource(ressource.key,  function() {

                        var subLevelControler = Ember.ArrayController.create({ content: Ember.A([])});
                        for(j=0;j<ressource.entries.length;j++){
                            var route = ressource.entries[j];
                            this.route(route.key);
                            subLevelControler.pushObject(
                            OXI.NavItem.create({
                                title: route.label,
                                goto: ressource.key+'.'+route.key
                            })
                            );
                        }

                        App.NavArrayController.pushObject(
                        OXI.NavRessource.create({
                            rootPath : ressource.key,
                            goto:ressource.key,
                            title:     ressource.label,
                            has_entries: true,
                            entries : subLevelControler
                        })
                        );
                        App.SideNavs[ressource.key] = subLevelControler;
                    });
                }//ende if/else entries
            }//for

            this.route('bad_url', { path: '/*badurl' }); // Catch everything else!

        });//App.Router.map
    },//initRouter

    SideNavItemView : Ember.View.extend({
        tagName: "li"
    }),

    MainNavItemView : Ember.View.extend({
        tagName: "li",
        classNames:['dropdown']
    }),

});