//Navigation-Stuff
// NavItem has two settable properties and
// an programmatic active state depending on the router
OXI.NavItem = Ember.Object.extend({
    title: '',
    goto: null,    // this is the name of the state we want to go to!
    entries:null,
    active: function(){
        //js_debug({currPath:App.currentPath,goto:this.get("goto")});
        if (App.currentPath == this.get("goto")){
            return true;
        }else{
            return false;
        }
    }.property('App.currentPath')//react to changes of current path
}
)

OXI.NavRessource = Ember.Object.extend({
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
OXI.SideNavItemView = Ember.View.extend({
    tagName: "li"
}
)

OXI.MainNavItemView = Ember.View.extend({
    tagName: "li",
    classNames:['dropdown']
}
)
