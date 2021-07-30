import Route from '@ember/routing/route';
import { inject } from '@ember/service';

export default class IndexRoute extends Route {
    @inject router;

    redirect(/*model, transition*/) {
        return this.router.transitionTo("openxpki", "welcome");
    }
}
