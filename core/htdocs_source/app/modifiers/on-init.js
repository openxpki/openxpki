import Modifier from 'ember-modifier';
import { debug } from '@ember/debug';

export default class OnInitModifier extends Modifier {
  /*
   * Lifecycle hooks
   */
  didInstall() {
    let [registerFunction] = this.args.positional;
    if (typeof registerFunction !== 'function') throw new Error("{{on-init}}: First argument needs to be an Ember action, DOM element: " + this.element.outerHTML.replace(/[\s\n]+/g, " "));
    //debug(`{{on-init}}: ${element.outerHTML.replace(/[\s\n]+/g, " ")}`);
    registerFunction(this.element);
  }
}
