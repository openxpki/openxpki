import Controller from '@ember/controller';
import { tracked } from '@glimmer/tracking';
import { action, computed, set } from '@ember/object';
import { gt } from '@ember/object/computed';
import { inject } from '@ember/service';

export default class OpenXpkiController extends Controller {
    @inject('oxi-config') config;

    // Reserved Ember properties
    // https://api.emberjs.com/ember/release/classes/Controller
    queryParams = [
        "count",
        "limit",
        "startat",
        "force" // supported query parameters, available as this.count etc.
    ];

    // FIXME Remove those three?! (auto-injected by Ember, see queryParams above)
    count = null;
    startat = null;
    limit = null;

    @tracked loading = false;

    @computed("model.status.{level,message}")
    get statusClass() {
        let level = this.get("model.status.level");
        let message = this.get("model.status.message");
        if (!message) { return "hide" }
        if (level === "error") { return "alert-danger" }
        if (level === "success") { return "alert-success" }
        if (level === "warn") { return "alert-warning" }
        return "alert-info";
    }

    @gt("model.tabs.length", 1) showTabs;

    // Wen don't use <ddm.LinkTo> but our own method to navigate to target page.
    // This way we can force Ember to do a transition even if the new page is
    // the same page as before by setting parameter "force" a timestamp.
    @action
    navigateTo(page, event) {
        event.stopPropagation();
        event.preventDefault();
        //this.lookup("route:openxpki").transitionTo("openxpki", button.page);
        this.transitionToRoute('openxpki', page, { queryParams: { force: (new Date()).valueOf() } });
    }

    @action
    activateTab(entry) {
        let tabs = this.get("model.tabs");
        tabs.setEach("active", false);
        set(entry, "active", true);
        return false;
    }

    @action
    closeTab(entry) {
        let tabs = this.get("model.tabs");
        tabs.removeObject(entry);
        if (!tabs.findBy("active", true)) {
            tabs.set("lastObject.active", true);
        }
        return false;
    }

    @action
    reload() {
        return window.location.reload();
    }

    @action
    clearPopupData() {
        return this.set("model.popup", null);
    }
}