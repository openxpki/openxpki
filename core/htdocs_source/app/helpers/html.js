import Helper from "@ember/component/helper"
import { htmlSafe } from '@ember/template'

/**
 * Interpret the given string as HTML code and remove unsafe parts.
 *
 * Example:
 * ```html
 * <span>{{html this.label}}</span>
 * ```
 * @module helper/html
 */
export default class Html extends Helper {
    compute([html]) {
        if (html === null || html === undefined) return ""

        let type = typeof html
        if (type == 'string' || type == 'number' || type == 'boolean') return htmlSafe(html)

        return `[${typeof html}]`
    }
}
