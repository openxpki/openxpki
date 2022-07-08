import Modifier from 'ember-modifier';

export default class MayFocusModifier extends Modifier {
  /*
    modify() is called upon every changed of any of its arguments or tracked
    values it accesses. So we have to manually prevent the repeated
    execution of its code that would lead to endless re-rendering.
  */
  ran_once = false

  modify(element, [emberObject, mayFocus]) {
    if (this.ran_once) return
    this.ran_once = true

    if (!emberObject) throw new Error("{{may-focus}}: no Ember component passed (maybe there is no corresponding component.js or controller.js to the template that called this modifier?), DOM element: " + element.outerHTML.replace(/[\s\n]+/g, " "));
    if (!emberObject.args.setFocusInfo) throw new Error("{{may-focus}}: Ember component did not get passed a setFocusInfo() method from it's parent, DOM element: " + element.outerHTML.replace(/[\s\n]+/g, " "));

    emberObject.args.setFocusInfo(mayFocus, element);
  }
}
