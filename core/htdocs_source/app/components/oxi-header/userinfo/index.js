import Component from '@glimmer/component';
import { service } from '@ember/service';
import { inject as controller } from '@ember/controller';
import { action } from '@ember/object';

/**
 * User info panel in the application header. Displays the logged-in user's name, role,
 * realm and last-login time. When the user has multiple tenants a drop-down is shown
 * to switch the active tenant.
 *
 * Takes no arguments; all data is read from the {@link service/oxi-content} service.
 *
 * @class OxiHeader::UserInfo
 * @extends Component
 */
export default class ApplicationHeaderUserinfo extends Component {
    @service('oxi-content') content;
    @controller('openxpki') openxpki;

    /**
     * Returns a display string for the active tenant, combining label and value when they differ.
     * Returns `null` when no tenant is active or the user has no tenant list.
     * @memberOf OxiHeader::UserInfo
     */
    get currentTenant() {
        if (!this.content.tenant || !this.content.user.tenants) return null;

        let tenant = this.content.user.tenants.find(t => t.value == this.content.tenant);
        if (!tenant === undefined) return null;

        return tenant.label === tenant.value ? tenant.label : `${tenant.label} (${tenant.value})`;
    }

    /**
     * Returns `true` when the user has more than one tenant, used to show the tenant switcher drop-down.
     * @memberOf OxiHeader::UserInfo
     */
    get hasMultipleTenants() {
        if (!this.content.user.tenants) return false;
        return (this.content.user.tenants.length > 1);
    }

    /**
     * Returns the tenant descriptor object matching the currently active tenant,
     * or `[]` when no active tenant is set.
     * @memberOf OxiHeader::UserInfo
     */
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

    /**
     * Switches the active tenant and navigates to the welcome page.
     * No-op when the selected tenant is already active.
     * @memberOf OxiHeader::UserInfo
     */
    @action
    selectTenant(tenant) {
        if (tenant == this.content.tenant) return
        this.content.setTenant(tenant)
        this.content.openPage({ name: 'welcome', target: this.content.TARGET.TOP, force: true })
    }
}
