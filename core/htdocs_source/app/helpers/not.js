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
        return !a;
    }
}
