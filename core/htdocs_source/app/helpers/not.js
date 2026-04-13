import Helper from "@ember/component/helper";

/**
 * Negates the given value.
 *
 * Example:
 * ```html
 * <button disabled={{not this.showButton}}>
 * ```
 * @module helper/not
 */
export default class Not extends Helper {
    /**
     * Negates `a`. Treats `null` as falsy, empty arrays/objects as falsy, everything else via `!a`.
     * @memberOf module:helper/not
     */
    compute([a]) {
        if (a === null) return true
        if (Array.isArray(a)) return a.length == 0
        if (typeof a === 'object') return Object.keys(a).length == 0
        return !a
    }
}
