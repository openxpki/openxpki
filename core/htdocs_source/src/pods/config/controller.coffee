`import Em from "vendor/ember"`

Controller = Em.Controller.extend
    baseUrl: "#{window.location.protocol}//#{window.location.host}"
    url: (->
        "#{@get "baseUrl"}/cgi-bin/webui.fcgi"
    ).property "baseUrl"

`export default Controller`
