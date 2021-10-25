import Component from '@glimmer/component';
import { inject } from '@ember/service';

export default class ApplicationHeaderUserinfo extends Component {
    @inject('oxi-content') content;
    get tenants() {
        if (!this.content.tenant) return;
        let tenants = this.content.user.tenants;
        for (let ii = 0; ii < tenants.length; ii++) {
            if (tenants[ii].value == this.content.tenant) {
                return tenants[ii];
            }
        }
        return;
    }
}
