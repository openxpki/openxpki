import Controller from '@ember/controller';

export default Controller.extend({
    baseUrl: `${window.location.protocol}//${window.location.host}`,
    url: Em.computed("baseUrl", function() {
        return `${this.get("baseUrl")}/cgi-bin/webui.fcgi`;
    })
});