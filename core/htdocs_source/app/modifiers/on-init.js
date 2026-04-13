import Modifier from 'ember-modifier';

/**
 * Ember modifier that calls a registration function exactly once when the
 * element is first inserted into the DOM.
 *
 * ```html
 * <div {{on-init this.registerElement "extra-param"}}></div>
 * ```
 *
 * @param { function } registerFunction - Called with `(element, ...params)` on first insert.
 * @param { any } [...params] - Additional positional arguments forwarded to `registerFunction`.
 *
 * @class OnInitModifier
 * @extends Modifier
 */
export default class OnInitModifier extends Modifier {
  /*
    modify() is called upon every change of any of its arguments or tracked
    values it accesses. So we have to manually prevent the repeated
    execution of its code that would lead to endless re-rendering.
  */
  ran_once = false

  modify(element, [registerFunction, ...params]) {
    if (this.ran_once) return
    this.ran_once = true

    if (typeof registerFunction !== 'function') throw new Error("{{on-init}}: First argument needs to be an Ember action, DOM element: " + element.outerHTML.replace(/[\s\n]+/g, " "));

    registerFunction(element, ...params);
  }
}
