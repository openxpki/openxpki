import Controller from '@ember/controller';
import { computed, observer } from '@ember/object';
import { set as emSet } from '@ember/object';

export default Controller.extend({
    // Reserved Ember properties
    // https://api.emberjs.com/ember/release/classes/Controller
    queryParams: [
        "count",
        "limit",
        "startat",
        "force" // supported query parameters, available as this.count etc.
    ],

    // FIXME Remove those three?! (auto-injected by Ember, see queryParams above)
    count: null,
    startat: null,
    limit: null,
    manageActive: observer("model.{navEntries,page}", function() {
        let page = this.get("model.page");
        for (const entry of this.get("model.navEntries")) {
            emSet(entry, "active", entry.key === page);
            if (entry.entries) {
                entry.entries.setEach("active", false);
                let subEntry = entry.entries.findBy("key", page);
                if (subEntry) {
                    emSet(subEntry, "active", true);
                    emSet(entry, "active", true);
                }
            }
        }
        return null;
    }),
    statusClass: computed("model.status.{level,message}", function() {
        let level = this.get("model.status.level");
        let message = this.get("model.status.message");
        if (!message) { return "hide" }
        if (level === "error") { return "alert-danger" }
        if (level === "success") { return "alert-success" }
        if (level === "warn") { return "alert-warning" }
        return "alert-info";
    }),
    showTabs: computed.gt("model.tabs.length", 1),
    actions: {
        activateTab: function(entry) {
            let tabs = this.get("model.tabs");
            tabs.setEach("active", false);
            emSet(entry, "active", true);
            return false;
        },
        closeTab: function(entry) {
            let tabs = this.get("model.tabs");
            tabs.removeObject(entry);
            if (!tabs.findBy("active", true)) {
                tabs.set("lastObject.active", true);
            }
            return false;
        },
        reload: function() {
            return window.location.reload();
        },
        clearPopupData: function() {
            return this.set("model.modal", null);
        }
    }
});