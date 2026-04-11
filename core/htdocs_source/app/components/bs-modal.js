import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';

/**
 * Bootstrap modal dialog wrapper.
 *
 * ```html
 * <BsModal @open={{this.isOpen}} @size="lg" @onHidden={{this.onClose}} as |m|>
 *     <m.header @closeButton={{true}}>Title</m.header>
 *     <m.body>Content</m.body>
 *     <m.footer><BsButton @onClick={{m.close}}>Close</BsButton></m.footer>
 * </BsModal>
 * ```
 *
 * @param { boolean } open - Controls modal visibility.
 * @param { string } [size] - Space-separated size modifiers: `'sm'`, `'lg'`, `'xl'`,
 *   `'fullscreen'`, or any custom class. Mapped to `modal-<size>` CSS classes.
 * @param { boolean } [scrollable] - Adds `modal-dialog-scrollable` for a scrollable body.
 * @param { boolean } [fade] - Adds the `fade` CSS class for a Bootstrap fade transition.
 * @param { boolean } [closeButton] - Passed to `bs-modal/header` to show a close (X) button.
 * @param { boolean } [backdropClose] - Whether clicking the backdrop closes the modal.
 * @param { string } [backdrop] - Bootstrap backdrop option (`'static'` to prevent backdrop close).
 * @param { function } [onHidden] - Callback invoked after the modal has been hidden.
 * @param { function } [onShown] - Callback invoked after the modal has been shown.
 *
 * @class BsModal
 * @extends Component
 */
export default class BsModal extends Component {
    @tracked _close = null;

    @action
    registerClose(fn) {
        this._close = fn;
    }

    @action
    close() {
        this._close?.();
    }

    get dialogClass() {
        const parts = ['modal-dialog'];
        if (this.args.size) {
            for (const s of this.args.size.split(' ')) {
                if (['sm', 'lg', 'xl', 'fullscreen'].includes(s)) {
                    parts.push('modal-' + s);
                } else {
                    parts.push(s); // pass through (e.g. "modal-fullscreen-md-down")
                }
            }
        }
        if (this.args.scrollable) parts.push('modal-dialog-scrollable');
        return parts.join(' ');
    }
}
