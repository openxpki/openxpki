import Helper from "@ember/component/helper";

/*

Convert given value to lowercase.

Example:

    <span>{{lc this.value}}</span>

*/
export default class Lc extends Helper {
    compute([val]) {
        return (new String(val)).toLowerCase();
    }
}
