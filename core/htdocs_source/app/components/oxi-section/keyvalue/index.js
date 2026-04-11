import Component from '@glimmer/component'
import { service } from '@ember/service'
import { set as emSet } from '@ember/object'
import { guidFor } from '@ember/object/internals'

/**
 * Render a list of key/value pairs.
 *
 * ```html
 * <OxiSection::KeyValue @def={{this.def}} />
 * ```
 *
 * @param { object } def - Section definition:
 *   - `label` { string } - Section heading. Default: `""`
 *   - `description` { string } - Subheading shown below the label. Default: `""`
 *   - `data` { array } - List of items to display. Each entry is an object with:
 *     - `label` { string } - Row label shown in the left column. Omit to hide the label column entirely.
 *     - `value` { string } - The value to display, passed to {@link OxiBase::Formatted}.
 *     - `format` { string } - Format identifier for {@link OxiBase::Formatted} (e.g. `'raw'`, `'link'`, `'datetime'`).
 *       Items with `format: 'raw'` and an empty value are hidden.
 *     - `preamble` { string } - Optional italicised text rendered above the value.
 *     - `className` { string } - Optional extra CSS class added to the row element.
 *     - `refresh` { object } - Optional auto-refresh config:
 *       - `uri` { string } - Required. Action URI called to fetch an updated value.
 *       - `timeout` { number } - Required. Milliseconds between refresh calls.
 *     - `format: 'head'` - Special marker: renders the `value` as a full-width section divider
 *       instead of a normal key/value row.
 *   - `buttons` { array } - Optional list of button definitions rendered below the items
 *     via {@link OxiBase::ButtonContainer}.
 *
 * @param { object } meta - Rendering metadata:
 *   - `isInfoBox` { boolean } - Adjusts column widths and label CSS for infobox context.
 *   - `isCompact` { boolean } - When true, renders all items inline (suitable for use
*       inside a compact container such as an infobox tile) instead of the default grid layout.
 *
 * @class OxiSection::KeyValue
 * @extends Component
 */
export default class OxiSectionKeyvalueComponent extends Component {
    @service('oxi-content') content

    items = []

    #id = guidFor(this)

    get hasLabels() {
        return this.items.filter(i => typeof i.label !== 'undefined' && i.label !== 0 && i.label !== null).length > 0
    }

    constructor() {
        super(...arguments);

        let items = this.args.def.data ? [ ...this.args.def.data ] : []
        let idx = 0
        for (const i of items) {
            i._id = idx++
            if (i.format === 'head') { i.isHead = 1 }
            if (i.refresh) { this.startRefresh(i) }
        }
        // hide items where value (after formatting) is empty
        // (this could only happen with format 'raw' and empty values)
        this.items = items.filter(item => item.format !== 'raw' || item.value !== '')
    }

    startRefresh(item) {
        let timeout = item.refresh.timeout
        let uri = item.refresh.uri
        if (! timeout) throw new Error("Key 'timeout' is missing in 'refresh' property.")
        if (! uri) throw new Error("Key 'uri' is missing in 'refresh' property.")

        // refresh function
        let refreshRequest = () => {
            emSet(item, '_refreshing', true)
            this.content.requestUpdate({
                action: uri,
            })
            .then((doc) => {
                if (! doc.value) return
                emSet(item, "value", doc.value)
                // item.value = doc.value
                if (!this.isDestroying && !this.isDestroyed) {
                    this.content.addTimer(this, `${this.#id}/${item._id}`, refreshRequest, timeout)
                }
            })
            .finally(() => {
                emSet(item, '_refreshing', false)
            })
        }

        // cancel old search query timer on new input
        this.content.cancelTimer(`${this.#id}/${item._id}`)
        // immediately run first refresh
        refreshRequest()
    }
}
