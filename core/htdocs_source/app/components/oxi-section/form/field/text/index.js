import Component from '@glimmer/component';
import { tracked  } from '@glimmer/tracking';
import { action, set as emSet } from '@ember/object';
import { scheduleOnce } from '@ember/runloop';
import { service } from '@ember/service';
import { guidFor } from '@ember/object/internals'

export default class OxiFieldTextComponent extends Component {
    @service('intl') intl;
    @service('oxi-content') content;

    /*
     * Note: the search input field is two-fold:
     * If a cert identifier is entered manually, it's value equals the
     * value that is submitted.
     * If an entry from the drop-down list is chosen, then it shows
     * the certificate subject but not the true form value to be submitted.
     */
    @tracked value = null;
    @tracked label = null;

    // autocomplete related:
    @tracked isDropdownOpen = false;
    @tracked searchResults = [];
    searchIndex = 0;
    searchPrevious = null;
    acFieldRefParams = new Map(); // mapping: (source field name) => (parameter name for autocomplete query)
    acOtherFieldsReferenced = false

    #id = guidFor(this)

    constructor() {
        super(...arguments);

        let content = this.args.content;
        this.value = content.value;

        if (content.autocomplete_query) {
            if (content.autocomplete_query?.action === undefined) {
                throw new Error(`oxi-section/form/field/text: parameter "autocomplete_query.action" missing`);
            }
            let params = content.autocomplete_query?.params;
            if (params) {
                if (Object.prototype.toString.call(params) != '[object Object]')
                    throw new Error(`oxi-section/form/field/text: parameter "autocomplete_query.params" must be a hash`);

                for (const [param_name, ref_field] of Object.entries(params)) {
                    // param_name - parameter name for autocomplete query
                    // ref_field - name of another form field whose value to use
                    this.acFieldRefParams.set(ref_field, param_name);
                }

                let fieldName = content.name
                let otherFields = Array.from(this.acFieldRefParams.keys()).filter(f => f !== fieldName)
                this.acOtherFieldsReferenced = otherFields.size > 0;
            }
        }
    }

    get isAutoComplete() {
        return !!this.args.content.autocomplete_query;
    }

    @action
    onInput(evt) {
        let inputField = event.target
        this.setValue(inputField.value) // do NOT clean up manually typed text ("the 's-Gravenhage bug")
    }

    // Own "paste" implementation to allow for text cleanup
    @action
    onPaste(event) {
        let paste = (event.clipboardData || window.clipboardData).getData('text');
        let pasteCleaned = this.cleanup(paste, { trimTrailingStuff: true });
        let inputField = event.target;
        let oldVal = this.value || "";

        let newCursorPos = inputField.selectionStart + pasteCleaned.length;

        // put cursor into right position after Ember rendered all updates
        scheduleOnce('afterRender', this, this.setCursorPos, inputField, newCursorPos);

        let value =
            oldVal.slice(0, inputField.selectionStart) +
            pasteCleaned +
            oldVal.slice(inputField.selectionEnd);

        this.setValue(value);
        event.preventDefault();
    }

    setCursorPos(inputField, pos) {
        inputField.focus()
        inputField.setSelectionRange(pos, pos);
    }

    setValue(value) {
        this.value = value
        let skipValidityChecks = this.isAutoComplete
        this.args.onChange(value, skipValidityChecks) // report changes to parent component

        // fetch autocomplete list (but don't process same input value twice)
        if (this.isAutoComplete && value !== this.searchPrevious) {
            this.autocompleteQuery(value)
        }
    }

    // Strips newlines + leading (and if chosen trailing) whitespaces and quotation marks
    cleanup(text, args = { trimTrailingStuff: false }) {
        let result = text.replace(/\r?\n/gm, '').replace(/^["'„\s]*/, '');
        if (args.trimTrailingStuff) {
            result = result.replace(/["'“\s]*$/, '');
        }
        return result;
    }


    /*
     **************************************************************************
     * Autocomplete related methods below...
     **************************************************************************
     */


    autocompleteQuery(value) {
        this.searchPrevious = value;

        this.searchResults = []; // make sure changed input (e.g. under 3 characters) will not show old result list again
        this.label = '';

        // cancel old search query timer on new input
        this.content.cancelTimer(this.#id)

        // don't search short values
        if ((value||"").length < 3) { this.isDropdownOpen = false; return }

        // start search query after 300ms without input
        this.content.addTimer(this, this.#id, function() {
            let searchIndex = ++this.searchIndex;

            // resolve referenced fields and their values
            let ref = this.args.encodeFields(this.acFieldRefParams.keys(), this.acFieldRefParams); // returns an Object

            this.content.requestUpdate({
                action: this.args.content.autocomplete_query.action,
                [this.args.content.name] : value, // [] denotes a dynamic key name
                ...ref,
            }).then((doc) => {
                // only show results of most recent search (if parallel requests were sent)
                if (searchIndex !== this.searchIndex) { return }

                if (doc.error) {
                    this.args.onError(doc.error);
                    return;
                }

                this.searchResults = doc;
                if (doc[0] != null) {
                    doc[0].active = true;
                }
                this.isDropdownOpen = true;
            });
        }, 0.3);
    }

    @action
    onKeydown(evt) {
        if (this.isDropdownOpen == false) return;

        // Enter - select active value
        if (evt.keyCode === 13) {
            let results = this.searchResults;
            let a = results.find(i => i.active == true)
            if (a) {
                this.selectResult(a);
            }
            evt.stopPropagation(); evt.preventDefault();
        }
        // Escape
        else if (evt.keyCode === 27) {
            this.isDropdownOpen = false;
            evt.stopPropagation(); evt.preventDefault();
        }
        // Arrow up
        else if (evt.keyCode === 38) {
            this.selectNeighbor(-1);
            evt.stopPropagation(); evt.preventDefault();
        }
        // Arrow down
        else if (evt.keyCode === 40) {
            this.selectNeighbor(1);
            evt.stopPropagation(); evt.preventDefault();
        }
    }

    selectNeighbor(diff) {
        let results = this.searchResults;
        if (!results.length) { return }
        let a = results.find(i => i.active == true)
        emSet(a, "active", false);
        let index = (results.indexOf(a) + diff + results.length) % results.length;
        a = results[index];
        return emSet(a, "active", true);
    }

    @action
    onFocus() {
        if (this.isAutoComplete) {
            // If we also send other form field(s) then better refresh the
            // autocomplete results as the other field(s) might have changed.
            if (this.acOtherFieldsReferenced > 0) {
                // We don't use the current value (maybe chosen from the autocomplete
                // result list) but the same value as used for the previous query.
                this.autocompleteQuery(this.searchPrevious)
            }
            // Otherwise just show result list again
            else {
                if (this.searchResults.length) this.isDropdownOpen = true
            }
        }
    }

    @action
    onBlur() {
        this.isDropdownOpen = false
        this.content.cancelTimer(this.#id)
    }

    @action
    onMouseDown(evt) {
        if (evt.target.tagName === "INPUT") { return }
        // prevent focus loss on input field after autocomplete list entry was clicked
        evt.stopPropagation(); evt.preventDefault();
    }

    @action
    selectResult(res) {
        this.value = res.value;
        this.label = res.label;
        this.args.onChange(this.value);
        this.isDropdownOpen = false;
    }
}
