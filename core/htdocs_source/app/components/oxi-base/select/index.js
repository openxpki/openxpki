import Component from '@glimmer/component'
import { action } from '@ember/object'
import { debug } from '@ember/debug'
import { service } from '@ember/service'
import { tracked } from '@glimmer/tracking'
import Choices from 'choices.js'

/**
 * Shows a drop-down list of options.
 *
 * ```html
 * <OxiBase::Select
 *   @list={{data.keys}}
 *   @selected={{data.name}}
 *   @onChange={{myFunc}}
 *   @onInsert={{otherFunc}}
 *   @inline={{true}}
 *   @placeholder="Please choose"
 *   @showClearButton={{true}}
 * />
 * ```
 *
 * @param { array } list - List of option hashes, each with `value` and `label` keys:
 * ```javascript
 * [
 *     { value: 1, label: "Major" },
 *     { value: 2, label: "Tom" },
 * ]
 * ```
 * @param { string } selected - Currently selected value.
 * @param { function } onChange - Called when a selection is made, with `(value, label)` of the
 *   selected item. Also called initially to report the first item's value.
 * @param { function } [onInsert] - Called after the Choices.js element is inserted into the DOM.
 * @param { function } [setFocusInfo] - Callback to register the Choices.js outer element for focus management.
 * @param { boolean } [inline] - Render the select inline (no `form-control` wrapper).
 * @param { string } [placeholder] - Placeholder text shown when nothing is selected.
 * @param { boolean } [showClearButton] - Show a clear button once a value is selected.
 * @class OxiBase::Select
 */
export default class OxiSelectComponent extends Component {
    @service('intl') intl

    #choicesObj = null
    @tracked allowClearing = false

    /**
     * Returns the CSS class(es) for the underlying `<select>` element.
     * Inline mode omits the `form-control` wrapper.
     * @memberOf OxiBase::Select
     */
    get cssClasses() {
        return (this.args.inline
            ? 'oxi-inline-select'
            : 'form-select text-truncate'
        )
    }

    /**
     * Returns the placeholder string, converting an empty `""` to `"…"` so
     * Choices.js recognises it. Returns `null` when no placeholder is configured.
     * @memberOf OxiBase::Select
     */
    get placeholder() {
        let label = this.args.placeholder ?? null
        // convert empty to non-empty string so Choice.js will recognize placeholder
        // (but respect null/undefined = no placeholder)
        if (label === '') label = '…'
        return label
    }

    /**
     * Redirects browser focus to the Choices.js outer container element.
     * @memberOf OxiBase::Select
     */
    @action
    focussed(element) {
        // "redirect" focus to the dynamically created Choices.js object
        if (this.#choicesObj) this.#choicesObj.containerOuter.element.focus()
    }

    /**
     * Initialises the Choices.js widget on insert and fires `@onChange` once to
     * report the initial selection.
     * @memberOf OxiBase::Select
     */
    @action
    startup(element) {
        this.#choicesObj = new Choices(element, {
            choices: this.args.list.map(choice => new Object({ ...choice, selected: choice.value == this.args.selected })),
            classNames: {
                containerOuter: ['choices', this.args.inline ? 'oxi-inline-select' : 'form-control'],
                containerInner: [],
                itemSelectable: ['choices__item--selectable', this.args.inline ? 'dummy-noop' : 'text-truncate'],
                activeState: ['is-active', 'shadow'],
            },
            searchPlaceholderValue: this.intl.t('component.oxibase_select.search'),
            noChoicesText: this.intl.t('component.oxibase_select.no_choices'),
            noResultsText: this.intl.t('component.oxibase_select.no_results'),
            searchEnabled: true,
            searchResultLimit: 10,
            searchFields: [ 'label', 'value' ],
            shouldSort: false,
            itemSelectText: '',
            placeholder: !!(this.args.placeholder ?? null),
            fuseOptions: {
                threshold: 0.2, // default threshold of 0.6 shows too many unrelated results
            },
            callbackOnInit: function () {
                this.dropdown.element.addEventListener(
                    'keydown', (event) => {
                        // prevent form submit
                        if (event.keyCode === 13) event.stopPropagation()
                    },
                    false,
                )
            },
        })
        if (this.args.onInsert) this.args.onInsert(element)
        if (this.args.setFocusInfo) this.args.setFocusInfo(this.#choicesObj.containerOuter.element, true)
        this.notifyOnChange()
    }

    /**
     * Reads the currently selected item from Choices.js and calls `@onChange`
     * with its value and label. Also enables the clear button when `@showClearButton` is set.
     * @memberOf OxiBase::Select
     */
    @action
    notifyOnChange() {
        let item = this.#choicesObj.getValue()
        if (typeof item === 'undefined' || item === null) return

        if (this.args.showClearButton) this.allowClearing = true

        debug(`oxi-select: notifyOnChange (value="${item.element.value}", label="${item.element.label}")`)
        if (typeof this.args.onChange !== "function") {
            /* eslint-disable-next-line no-console */
            console.error("<OxiBase::Select>: Wrong type parameter type for @onChange. Expected: function, given: " + (typeof this.args.onChange))
            return
        }
        this.args.onChange(item.element.value, item.element.label)
    }

    /**
     * Clears the current selection and calls `@onChange(null, null)`.
     * @memberOf OxiBase::Select
     */
    @action
    clear() {
        this.allowClearing = false
        this.#choicesObj.removeActiveItems()
        this.args.onChange(null, null)
    }
}
