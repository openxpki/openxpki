/* Use the following template to add new format helpers.
 *
 * The example adds a helper called upper that make the value all caps.

window.Em.Application.initializer({
    name: "oxi-localconfig",
    initialize: function(container, application) {
        var formatHelper = application.OxivalueFormatComponent;

        formatHelper.reopen({
            addHelpers: function() {
                this.set("types.upper", function(v) {
                    return v.toUpperCase();
                });
            }.on("init")
        });
    }
});

 */



/* Use the following template to change config options.
 *
 * The example replaces the default server url by a relative one  
 * this is the recommended setting when using url path based realms 

window.Em.Application.initializer({
    name: "oxi-localconfig",
    initialize: function(container, application) {
        var cc = application.ConfigController;
        cc.reopen({
            url: "cgi-bin/webui.fcgi"
        });
    }
});

 */

