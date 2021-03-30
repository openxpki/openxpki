import Helper from "@ember/component/helper";

/**
 * Test two values for equality.
 *
 * Example:
 * ```html
 * <option value="{{i.value}}" selected={{eq i.label "butter"}}>
 *     {{i.label}}
 * </option>
 * ```
 * @module helper/eq
 */
export default class Eq extends Helper {
    compute([a, b]) {
        return a == b;
    }
}
