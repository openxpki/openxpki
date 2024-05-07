import Component from '@glimmer/component'
import { service } from '@ember/service'
import { set as emSet } from '@ember/object'
import { guidFor } from '@ember/object/internals'

/**
 * Draws a list of key/value pairs.
 *
 * @param { hash } def - section definition
 * ```javascript
 * {
 *     ... // TODO
 * }
 * ```
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
