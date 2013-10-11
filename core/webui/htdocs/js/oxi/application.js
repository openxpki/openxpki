/**
defines the OXI Application classs
*/

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



    ApplicationController : Ember.Controller.extend({
        updateCurrentPath: function() {
            
            //js_debug('ApplicationController:updateCurrentPath '+this.get('currentPath'));
            App.setCurrentPath( this.get('currentPath'));
        }.observes('currentPath')
    }),

    BadUrlRoute: Ember.Route.extend({
        beforeModel: function(transition) {
            Ember.debug('BadUrlRoute '+location.hash+' check transition');

            App.set('original_target',location.hash.substr(1));
            if(!App.user_logged_in){
                this.transitionTo('login');
            }else{
                this.transitionTo('notfound');
            }
        }
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



    ready: function() {
        Ember.debug('Application ready');
    },

    init:function(){
        this._super();
        this.rootElement = OXI.Config.get('rootElement');
        this.serverUrl = OXI.Config.get('serverUrl');
        this.cookieName = OXI.Config.get('cookieName');
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
        return this.callServer({action:'bootstrap!structure'})
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

    reloadPage: function(goto){
        js_debug('reloadPage!');
        if(!goto) goto='/';
        try{
            if(goto.indexOf('/')!=0){
                goto = '/'+goto;
            }
            location.hash=goto;
        }catch(e){

        }
        js_debug('do reload');
        location.reload();
    },

    callServer: function(params, callback,debug){
        var app = this;
        return jQuery.ajax({
            type: "POST",
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
            App.set('NavArrayController', Ember.ArrayController.create({
                content: Ember.A([])
            }));
            var i,j;
            for(i=0;i<App.sideTreeStructure.length;i++){
                var ressource = App.sideTreeStructure[i];
                Ember.debug('add to Top Nav: '+ressource.key);
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