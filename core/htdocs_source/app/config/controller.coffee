import Controller from '@ember/controller'

export default Controller.extend
    baseUrl: "#{window.location.protocol}//#{window.location.host}"
    url: Em.computed "baseUrl", ->
        "#{@get "baseUrl"}/cgi-bin/webui.fcgi"
