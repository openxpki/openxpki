import Route from '@ember/routing/route';

export default Route.extend({
    redirect: function(/*model, transition*/) {
        return this.transitionTo("openxpki", "welcome");
    }
});