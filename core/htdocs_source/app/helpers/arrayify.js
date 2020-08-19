import Helper from "@ember/component/helper";

/*

Turn a plain value, an object, undefined or null into an array or return a given array.

Example:

    {{#each (arrayify @text) as |txt|}}
        <span> {{txt}} </span>
    {{/each}}

*/
export default class Arrayify extends Helper {
    compute([strOrArray]) {
        if (strOrArray === null) return [null];
        if (Array.isArray(strOrArray)) return strOrArray.slice();
        if (typeof strOrArray === 'undefined') return [];
        return [strOrArray];
    }
}
