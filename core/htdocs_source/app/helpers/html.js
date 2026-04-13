import Helper from "@ember/component/helper"
import { htmlSafe } from '@ember/template'

/**
 * Interpret the given string as HTML code - DOES NOT remove unsafe parts (script).
 *
 * Example:
 * ```html
 * <span>{{html this.label}}</span>
 * ```
 * @module helper/html
 */
export default class Html extends Helper {
    /**
     * Wraps `html` in an Ember `htmlSafe` string. Returns `""` for null/undefined; returns `[type]` for non-scalar values.
     * @memberOf module:helper/html
     */
    compute([html]) {
        if (html === null || html === undefined) return ""

        let type = typeof html
        if (type == 'string' || type == 'number' || type == 'boolean') return htmlSafe(html)

        return `[${typeof html}]`
    }
}
