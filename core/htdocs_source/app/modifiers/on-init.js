import Modifier from 'ember-modifier';
import { debug } from '@ember/debug';

export default class OnInitModifier extends Modifier {
  modify(element, [registerFunction, ...params]) {
    if (typeof registerFunction !== 'function') throw new Error("{{on-init}}: First argument needs to be an Ember action, DOM element: " + element.outerHTML.replace(/[\s\n]+/g, " "));
    //debug(`{{on-init}}: ${element.outerHTML.replace(/[\s\n]+/g, " ")}`, ...params);
    registerFunction(element, ...params);
  }
}
