import Component from '@glimmer/component';
import { tracked  } from '@glimmer/tracking';
import { action, computed, set } from '@ember/object';
import { getOwner } from '@ember/application';

export default class OxifieldCertIdentifierComponent extends Component {
    /*
     * Note: the search input field is two-fold:
     * If a cert identifier is entered manually, it's value equals the
     * value that is submitted.
     * If an entry from the drop-down list is chosen, then it shows
     * the certificate subject but not the true form value to be submitted.
     */
    @tracked search = null;
    @tracked isDropdownOpen = false;
    @tracked searchResults = [];
    searchIndex = 0;
    searchPrevious = null;

    constructor() {
        super(...arguments);
        // do not turn "search" into a @computed property as we want the search field
        // to show the cert subject in case of a selection from the auto-suggest dropdown
        this.search = this.args.content.value;
    }

    selectNeighbor(diff) {
        let results = this.searchResults;
        if (!results.length) { return }
        let a = results.findBy("active", true);
        set(a, "active", false);
        let index = (results.indexOf(a) + diff + results.length) % results.length;
        a = results[index];
        return set(a, "active", true);
    }

    @action
    onKeydown(evt) {
        if (evt.keyCode === 13) {
            let results = this.searchResults;
            let a = results.findBy("active", true);
            if (a) {
                this.selectResult(a);
            }
            evt.stopPropagation(); evt.preventDefault();
        }
        else if (evt.keyCode === 38) {
            this.selectNeighbor(-1);
            evt.stopPropagation(); evt.preventDefault();
        }
        else if (evt.keyCode === 40) {
            this.selectNeighbor(1);
            evt.stopPropagation(); evt.preventDefault();
        }
    }

    @action
    onFocus(evt) {
        if (this.searchResults.length) { this.isDropdownOpen = true }
    }

    @action
    onBlur(evt) {
        this.isDropdownOpen = false;
    }

    @action
    onMouseDown(evt) {
        if (evt.target.tagName === "INPUT") { return }
        evt.stopPropagation(); evt.preventDefault();
    }

    @action
    onInput(evt) {
        console.log(evt.target);
        this.search = evt.target.value;

        if (this.search === this.searchPrevious) { return }
        if (this.search.length < 3) { this.isDropdownOpen = false; return }
        this.searchPrevious = this.search;

        this.args.onChange(this.search);

        let searchIndex = ++this.searchIndex;
        return getOwner(this).lookup("route:openxpki").sendAjax({
            action: "certificate!autocomplete",
            query: this.search
        }).then((doc) => {
            // only show results of most recent search
            if (searchIndex !== this.searchIndex) { return }
            if (doc.error) { doc = [] }
            this.searchResults = doc;
            if (doc[0] != null) {
                doc[0].active = true;
            }
            this.isDropdownOpen = true;
        });
    }

    @action
    selectResult(res) {
        this.args.onChange(res.value);
        this.search = res.label;
        this.searchPrevious = this.search;
        this.isDropdownOpen = false;
        this.searchResults = [];
    }
}
