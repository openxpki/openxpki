`import Em from "vendor/ember"`

Controller = Em.Controller.extend
    baseUrl: "#{window.location.protocol}//#{window.location.host}"
    url: Em.computed "baseUrl", ->
        "#{@get "baseUrl"}/cgi-bin/webui.fcgi"

`export default Controller`
