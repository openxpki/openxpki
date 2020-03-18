import Component from '@ember/component';

const OxifieldCertIdentifierComponent = Component.extend({
    search: Em.computed(function() {
        return this.get("content.value");
    }),
    focusOut: function(evt) {
        return this.$().find(".drowdown").removeClass("open");
    },
    focusIn: function(evt) {
        if (this.get("searchResults.length")) {
            return this.$().find(".drowdown").addClass("open");
        }
    },
    searchResults: Em.computed(function() {
        return [];
    }),
    selectNeighbor: function(diff) {
        let results = this.get("searchResults");
        if (!results.length) {
            return;
        }
        let a = results.findBy("active", true);
        Em.set(a, "active", false);
        let index = (results.indexOf(a) + diff + results.length) % results.length;
        a = results[index];
        return Em.set(a, "active", true);
    },
    keyboardNavigation: Em.on("keyDown", function(e) {
        if (e.keyCode === 13) {
            let results = this.get("searchResults");
            let a = results.findBy("active", true);
            if (a) {
                this.send("selectResult", a);
            }
            e.stopPropagation();
            return e.preventDefault();
        } else if (e.keyCode === 9) {
            return this.set("seatchResults", []);
        } else if (e.keyCode === 38) {
            this.selectNeighbor(-1);
            e.stopPropagation();
            return e.preventDefault();
        } else if (e.keyCode === 40) {
            this.selectNeighbor(1);
            e.stopPropagation();
            return e.preventDefault();
        }
    }),
    mouseDown: function(evt) {
        if (evt.target.tagName === "INPUT") {
            return;
        }
        evt.stopPropagation();
        return evt.preventDefault();
    },
    searchIndex: 0,
    searchChanged: Em.observer("search", function() {
        let search = this.get("search");
        if (search === this.get("searchPrevious")) {
            return;
        }
        if (search.length < 3) {
            this.$().find(".drowdown").removeClass("open");
            return;
        }
        this.set("searchPrevious", search);
        this.set("content.value", search);
        let searchIndex = this.incrementProperty("searchIndex");
        return this.container.lookup("route:openxpki").sendAjax({
            data: {
                action: "certificate!autocomplete",
                query: search
            }
        }).then((doc) => {
            if (searchIndex !== this.get("searchIndex")) {
                return;
            }
            if (doc.error) {
                doc = [];
            }
            this.set("searchResults", doc);
            let ref;
            if ((ref = doc[0]) != null) {
                ref.active = true;
            }
            return this.$().find(".drowdown").addClass("open");
        });
    }),
    actions: {
        selectResult: function(res) {
            this.set("content.value", res.value);
            this.set("searchPrevious", res.label);
            this.set("search", res.label);
            this.$().find(".drowdown").removeClass("open");
            return this.set("searchResults", []);
        }
    }
});

export default OxifieldCertIdentifierComponent;