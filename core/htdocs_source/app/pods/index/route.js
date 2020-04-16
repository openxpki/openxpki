import Route from '@ember/routing/route';

export default class IndexRoute extends Route {
    redirect(/*model, transition*/) {
        return this.transitionTo("openxpki", "welcome");
    }
}
