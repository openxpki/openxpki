import Helper from "@ember/component/helper";

/**
 * Turn a plain value, an object, undefined or null into an array or return a given array.
 *
 * Example:
 * ```html
 * {{#each (arrayify @text) as |txt|}}
 *     <span> {{txt}} </span>
 * {{/each}}
 * ```
 * @module helper/arrayify
 */
export default class Arrayify extends Helper {
    compute([strOrArray]) {
        if (strOrArray === null) return [null];
        if (Array.isArray(strOrArray)) return strOrArray.slice();
        if (typeof strOrArray === 'undefined') return [];
        return [strOrArray];
    }
}
