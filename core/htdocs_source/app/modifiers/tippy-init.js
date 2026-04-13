import { modifier } from 'ember-modifier';
import tippy from 'tippy.js';

/**
 * Ember modifier that attaches a Tippy.js tooltip to the element's parent.
 * The modified element is used as the tooltip content (HTML is allowed).
 * Returns a cleanup function that destroys the Tippy instance on teardown.
 *
 * ```html
 * <span {{tippy-init placement="bottom" delay=(array 200 100)}}>Tooltip text</span>
 * ```
 *
 * @param { string } [placement] - Tippy placement string (e.g. `"top"`, `"bottom-start"`). Default: `"top"`.
 * @param { array } [delay] - Show/hide delay as `[show, hide]` ms. Default: `[0, 50]`.
 * @param { object } [popperOptions] - Extra options forwarded to Popper.js.
 * @param { function } [onShow] - Called before the tooltip is shown; return `false` to cancel.
 */
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
