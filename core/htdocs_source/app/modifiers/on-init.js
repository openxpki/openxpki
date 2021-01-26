import { modifier } from 'ember-modifier';
import { debug } from '@ember/debug';

export default modifier((element, [registerFunction]) => {
    if (typeof registerFunction !== 'function') throw new Error("{{on-init}}: First argument needs to be an Ember action, DOM element: " + element.outerHTML.replace(/[\s\n]+/g, " "));
    //debug(`{{on-init}}: ${element.outerHTML.replace(/[\s\n]+/g, " ")}`);
    registerFunction(element);
});
