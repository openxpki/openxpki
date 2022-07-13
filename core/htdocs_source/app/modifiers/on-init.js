import Modifier from 'ember-modifier';

export default class OnInitModifier extends Modifier {
  /*
    modify() is called upon every changed of any of its arguments or tracked
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
