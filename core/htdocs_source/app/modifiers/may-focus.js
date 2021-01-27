import Modifier from 'ember-modifier';

export default class MayFocusModifier extends Modifier {
  /*
   * Lifecycle hooks
   */
  didInstall() {
    let [emberObject, mayFocus] = this.args.positional;
    if (!emberObject) throw new Error("{{may-focus}}: no Ember component passed (maybe there is no corresponding component.js or controller.js to the template that called this modifier?), DOM element: " + this.element.outerHTML.replace(/[\s\n]+/g, " "));
    if (!emberObject.args.setFocusInfo) throw new Error("{{may-focus}}: Ember component did not get passed a setFocusInfo() method from it's parent, DOM element: " + this.element.outerHTML.replace(/[\s\n]+/g, " "));
    emberObject.args.setFocusInfo(mayFocus, this.element);
  }
}
