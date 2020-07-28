import Helper from "@ember/component/helper";

/*

Turn a plain value into an array or return a given array.

Example:

    <option value="{{i.value}}" selected={{eq i.label "butter"}}>
        {{i.label}}
    </option>

*/
export default class Arrayify extends Helper {
    compute([strOrArray]) {
        if (typeof strOrArray === 'string') return [strOrArray];
        if (typeof strOrArray === 'number') return [strOrArray];
        if (typeof strOrArray === 'undefined') return [];
        if (strOrArray === null) return [null];
        if (Array.isArray(strOrArray)) return strOrArray.slice();
        throw new Error(`Arrayify: Unsupported argument type '${typeof strOrArray}'`);
    }
}
