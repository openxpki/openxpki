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
    compute([a]) {
        if (Array.isArray(a)) return a.length == 0
        if (typeof a === 'object') return Object.keys(a).length == 0
        return !a
    }
}
