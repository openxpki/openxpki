import Helper from "@ember/component/helper";

/*

Test two values for equality.

Example:

    <option value="{{i.value}}" selected={{eq i.label "butter"}}>
        {{i.label}}
    </option>

*/
export default class Eq extends Helper {
    compute([a, b]) {
        return a == b;
    }
}
