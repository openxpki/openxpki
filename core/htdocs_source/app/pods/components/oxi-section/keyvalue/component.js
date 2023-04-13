import Component from '@glimmer/component'
import { service } from '@ember/service'
import { set as emSet } from '@ember/object'

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

    refreshTimers = new Map()

    get items() {
        let items = this.args.def.data ? [ ...this.args.def.data ] : []
        let idx = 0
        for (const i of items) {
            i._id = idx++
            if (i.format === 'head') { i.isHead = 1 }
            if (i.refresh) { this.startRefresh(i) }
        }
        // hide items where value (after formatting) is empty
        // (this could only happen with format 'raw' and empty values)
        return items.filter(item => item.format !== 'raw' || item.value !== '')
    }

    get hasLabels() {
        return this.items.filter(i => typeof i.label !== 'undefined' && i.label !== 0 && i.label !== null).length > 0
    }

    // lifecycle hook of @glimmer/component
    willDestroy() {
        super.willDestroy(...arguments)
        // Remove all refresh timers to prevent that an OpenXPKI page refresh
        // (!= browser reload) leads to multiple parallel request timers.
        // Or that the requests continue if another OpenXPKI page is opened.
        for (const timer of this.refreshTimers.values()) clearTimeout(timer)
    }

    startRefresh(item) {
        let timeout = item.refresh.timeout
        let uri = item.refresh.uri
        if (! timeout) throw new Error("Key 'timeout' is missing in 'refresh' property.")
        if (! uri) throw new Error("Key 'uri' is missing in 'refresh' property.")

        // refresh function
        let refreshRequest = () => {
            emSet(item, '_refreshing', true)
            this.content.updateRequestQuiet({
                action: uri,
            })
            .then((doc) => {
                if (! doc.value) return
                emSet(item, "value", doc.value)
                // item.value = doc.value
                if (!this.isDestroying && !this.isDestroyed) {
                    this.refreshTimers.set(item._id, setTimeout(refreshRequest, timeout * 1000))
                }
            })
            .finally(() => {
                emSet(item, '_refreshing', false)
            })
        }

        // cancel old search query timer on new input
        let oldTimer = this.refreshTimers.get(item._id)
        if (oldTimer) clearTimeout(oldTimer)
        // set refresh timer
        this.refreshTimers.set(item._id, setTimeout(refreshRequest, timeout * 1000))
    }
}
