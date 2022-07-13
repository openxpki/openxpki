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
    compute([func, ...args]) {
        if ((typeof func == 'undefined') || func === null) throw new Error('{{echo}} helper expects a function as first argument')
        return func(...args)
    }
}
