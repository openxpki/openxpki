import Component from '@glimmer/component';
import { tracked  } from '@glimmer/tracking';
import { action, set } from '@ember/object';
import { getOwner } from '@ember/application';

export default class OxiFieldCertIdentifierComponent extends Component {
    /*
     * Note: the search input field is two-fold:
     * If a cert identifier is entered manually, it's value equals the
     * value that is submitted.
     * If an entry from the drop-down list is chosen, then it shows
     * the certificate subject but not the true form value to be submitted.
     */
    @tracked value = null;
    @tracked isDropdownOpen = false;
    @tracked searchResults = [];
    searchIndex = 0;
    searchPrevious = null;
    searchTimer = null;

    constructor() {
        super(...arguments);
        // do not turn "search" into a @computed property as we want the search field
        // to show the cert subject in case of a selection from the auto-suggest dropdown
        this.value = this.args.content.value;
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
    onFocus() {
        if (this.searchResults.length) { this.isDropdownOpen = true }
    }

    @action
    onBlur() {
        this.isDropdownOpen = false;
    }

    @action
    onMouseDown(evt) {
        if (evt.target.tagName === "INPUT") { return }
        evt.stopPropagation(); evt.preventDefault();
    }

    @action
    onInput(evt) {
        this.value = evt.target.value;
        // don't process same value as before
        if (this.value === this.searchPrevious) { return }
        this.searchPrevious = this.value;
        // cancel old search query timer on new input
        if (this.searchTimer) clearTimeout(this.searchTimer); // after check this.value === this.searchPrevious !
        // don't search short values
        if (this.value.length < 3) { this.isDropdownOpen = false; return }

        // report changes to parent component
        this.args.onChange(this.value);

        // start search query after 300ms without input
        this.searchTimer = setTimeout(() => {
            let searchIndex = ++this.searchIndex;
            getOwner(this).lookup("route:openxpki").sendAjaxQuiet({
                action: "certificate!autocomplete",
                query: this.value
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
        }, 300);
    }

    @action
    selectResult(res) {
        this.args.onChange(res.value);
        this.value = res.label;
        this.searchPrevious = this.value;
        this.isDropdownOpen = false;
        this.searchResults = [];
    }
}
