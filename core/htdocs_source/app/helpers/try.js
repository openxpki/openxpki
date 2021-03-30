import Helper from "@ember/component/helper";

/**
 * Check given values and return the first one that is defined and not null.
 * If all are null return empty string "".
 *
 * Example:
 * ```html
 * <span>{{try this.value this.label "---"}}</span>
 * ```
 * @module helper/try
 */
export default class Try extends Helper {
    compute(candidates) {
        for (let val of candidates) {
            if ((typeof val !== 'undefined') && val !== null) return val;
        }
        return "";
    }
}
