import { modifier } from 'ember-modifier';
import tippy from 'tippy.js';

export default modifier(function tippyInit(element, [], { placement, delay, popperOptions, onShow }) {
    const trigger = element.parentElement;
    if (!trigger) return;

    const instance = tippy(trigger, {
        content: element,
        placement: placement ?? 'top',
        delay: delay ?? [0, 50],
        popperOptions,
        onShow,
        allowHTML: true,
    });

    return () => instance.destroy();
});
