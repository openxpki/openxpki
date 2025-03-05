import Component from '@glimmer/component'
import { action } from "@ember/object"
import { debug } from '@ember/debug'
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
    #choicesObj = null

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
        if (label === "") label = '…'
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
            classNames: {
                containerOuter: ['choices', this.args.inline ? 'oxi-inline-select' : 'form-control'],
                containerInner: [],
                list: ['choices__list', this.args.inline ? 'dummy-noop' : 'text-truncate'],
                activeState: ['is-active', 'shadow'],
            },
            noChoicesText: 'No choices to choose from',
            searchEnabled: true,
            searchResultLimit: 10,
            searchFields: [ 'label' ],
            shouldSort: false,
            itemSelectText: '',
            placeholder: !!(this.args.placeholder ?? null),
            placeholderValue: '',
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
        this.notifyOnChange(element.selectedIndex)
    }

    @action
    listChanged(event) {
        this.notifyOnChange(event.target.selectedIndex)
    }

    notifyOnChange(index) {
        if (index === -1) { return } // there might be no options on page initialization, before field is hidden by a "partial" request
        let item = this.args.list[index];
        debug(`oxi-select: notifyOnChange (value="${item.value}", label="${item.label}")`)
        if (typeof this.args.onChange !== "function") {
            /* eslint-disable-next-line no-console */
            console.error("<OxiBase::Select>: Wrong type parameter type for @onChange. Expected: function, given: " + (typeof this.args.onChange))
            return
        }
        this.args.onChange(item.value, item.label)
    }
}
