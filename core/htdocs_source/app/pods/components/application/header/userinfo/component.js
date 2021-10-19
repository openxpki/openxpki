import Component from '@glimmer/component';
import { inject as injectCtrl } from '@ember/controller';

export default class ApplicationHeaderUserinfo extends Component {
    @injectCtrl openxpki; // injects OpenxpkiController
    get tenants() {
        if (!this.openxpki.model.tenant) return;
        let tenant = this.openxpki.model.user.tenant;
        for (let ii = 0; ii < tenant.length; ii++) {
            if (tenant[ii].value == this.openxpki.model.tenant) {
                return tenant[ii];
            }
        }
        return;
    }
}
