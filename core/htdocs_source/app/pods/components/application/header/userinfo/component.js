import Component from '@glimmer/component';
import { service } from '@ember/service';
import { inject as controller } from '@ember/controller';
import { action } from '@ember/object';

export default class ApplicationHeaderUserinfo extends Component {
    @service('oxi-content') content;
    @controller('openxpki') openxpki;

    get currentTenant() {
        if (!this.content.tenant || !this.content.user.tenants) return null;

        let tenant = this.content.user.tenants.find(t => t.value == this.content.tenant);
        if (!tenant === undefined) return null;

        return tenant.label === tenant.value ? tenant.label : `${tenant.label} (${tenant.value})`;
    }

    get hasMultipleTenants() {
        if (!this.content.user.tenants) return false;
        return (this.content.user.tenants.length > 1);
    }

    get tenants() {
        if (!this.content.tenant) return [];
        let tenants = this.content.user.tenants;
        for (let ii = 0; ii < tenants.length; ii++) {
            if (tenants[ii].value == this.content.tenant) {
                return tenants[ii];
            }
        }
        return [];
    }

    @action
    setTenant(tenant) {
        if (tenant.value == this.content.tenant) return;
        this.content.setTenant(tenant.value);
        this.openxpki.navigateTo('welcome');
    }
}
