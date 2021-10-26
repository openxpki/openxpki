import Component from '@glimmer/component';
import { inject } from '@ember/service';
import { action } from '@ember/object';

export default class ApplicationHeaderUserinfo extends Component {
    @inject('oxi-content') content;

    get currentTenant() {
        if (!this.content.tenant || !this.content.user.tenants) return;

        let tenant = this.content.user.tenants.find(t => t.value == this.content.tenant);
        if (!tenant === undefined) return;

        return tenant.label === tenant.value ? tenant.label : `${tenant.label} (${tenant.value})`;
    }

    get hasMultipleTenants() {
        if (!this.content.user.tenants) return false;
        return (this.content.user.tenants.length > 1);
    }

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

    @action
    setTenant(tenant) {
        this.content.setTenant(tenant.value);
    }
}
