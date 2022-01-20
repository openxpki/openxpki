import Helper from "@ember/component/helper";

/**
 * Check if all given expressions evaluate to true.
 *
 * Example:
 * ```html
 * {{#unless (and @empty @disableIfEmpty)}}
 *   <button ...>
 * {{/unless}}
 * ```
 * @module helper/and
 */
export default class And extends Helper {
    compute(args) {
        return !!args.reduce((ac, val) => ac && !!val); // true if all are true
    }
}
