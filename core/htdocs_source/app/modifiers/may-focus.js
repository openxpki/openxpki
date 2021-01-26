import { modifier } from 'ember-modifier';

export default modifier((element, [emberObject, mayFocus]) => {
    // note: we don't use an Ember loading substate here as this would
    // lead to a disruptive UX on every page (route) switch
    if (!emberObject) throw new Error("{{may-focus}}: no Ember component passed (maybe there is no corresponding component.js or controller.js to the template that called this modifier?), DOM element: " + element.outerHTML.replace(/[\s\n]+/g, " "));
    if (!emberObject.args.setFocusInfo) throw new Error("{{may-focus}}: Ember component did not get passed a setFocusInfo() method from it's parent, DOM element: " + element.outerHTML.replace(/[\s\n]+/g, " "));
    emberObject.args.setFocusInfo(mayFocus, element);
});
