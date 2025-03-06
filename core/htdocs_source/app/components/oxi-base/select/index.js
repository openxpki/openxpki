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
 * @param { array } list - List of hashes defining the options.
 * Each hash is expected to have these keys:
 * ```javascript
 * [
 *     { value: 1, label: "Major" },
 *     { value: 2, label: "Tom" },
 * ]
 * ```
 * @param { string } selected - currently selected value
 * @param { callback } onChange - called if a selection was made.
 * It gets passed two arguments: *value* and *label* of the selected item.
 * The callback is also called initially to set the value of the first list item.
 * @class OxiBase::Select
 */
export default class OxiSelectComponent extends Component {
    @service('intl') intl

    #choicesObj = null
    @tracked allowClearing = false

    get cssClasses() {
        return (this.args.inline
            ? 'oxi-inline-select'
            : 'form-select text-truncate'
        )
    }

    get placeholder() {
        let label = this.args.placeholder ?? null
        // convert empty to non-empty string so Choice.js will recognize placeholder
        // (but respect null/undefined = no placeholder)
        if (label === '') label = '…'
        return label
    }

    @action
    focussed(element) {
        // "redirect" focus to the dynamically created Choices.js object
        if (this.#choicesObj) this.#choicesObj.containerOuter.element.focus()
    }

    // initially trigger the onChange event to handle the case
    // when the calling code has no "current selection" defined.
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
        this.notifyOnChange()
    }

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

    @action
    clear() {
        this.allowClearing = false
        this.#choicesObj.removeActiveItems()
        this.args.onChange(null, null)
    }
}
