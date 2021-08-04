import Helper from "@ember/component/helper";

/**
 * Test if at least one of the given expressions evaluates to true.
 *
 * Example:
 * ```html
 * {{#if (or @notEmpty @forceShow)}}
 *   <button ...>
 * {{/if}}
 * ```
 * @module helper/or
 */
export default class Or extends Helper {
    compute(...args) {
        return args.reduce((ac, val) => ac || !!val); // true if all are true
    }
}
