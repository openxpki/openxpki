import Helper from "@ember/component/helper";

/**
 * Calls the given function and outputs its return value.
 *
 * Example:
 * ```html
 * <div class={{echo this.getCssClassByStatus status}}>
 * ```
 * @module helper/echo
 */
export default class Echo extends Helper {
    /**
     * Invokes `func` with the remaining positional arguments and returns its result.
     * Throws when `func` is `undefined` or `null`.
     * @memberOf module:helper/echo
     */
    compute([func, ...args]) {
        if ((typeof func == 'undefined') || func === null) throw new Error('{{echo}} helper expects a function as first argument')
        return func(...args)
    }
}
