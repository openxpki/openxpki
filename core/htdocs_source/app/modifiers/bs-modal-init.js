import Modifier from 'ember-modifier';
import { Modal } from 'bootstrap';

/**
 * Ember modifier that initialises a Bootstrap `Modal` on the target element
 * and controls its visibility reactively.
 *
 * ```html
 * <div {{bs-modal-init @open={{this.isOpen}} onHidden=this.onClose onShown=this.onShown backdropClose={{false}} onReady=this.registerHide}}></div>
 * ```
 *
 * @param { boolean } open - When `true` the modal is shown; `false` hides it.
 * @param { function } [onHidden] - Called when the modal finishes hiding.
 * @param { function } [onShown] - Called when the modal finishes showing.
 * @param { boolean } [backdropClose] - When `false` clicking the backdrop does not close the modal.
 * @param { boolean } [backdrop] - Passed directly to Bootstrap's `backdrop` option. Ignored when `backdropClose` is `false`.
 * @param { function } [onReady] - Called once after init with a `hide()` function so the parent can close the modal programmatically.
 *
 * @class BsModalInitModifier
 * @extends Modifier
 */
export default class BsModalInitModifier extends Modifier {
    _modal = null;

    modify(element, [open], { onHidden, onShown, backdropClose, backdrop, onReady }) {
        if (!this._modal) {
            this._modal = new Modal(element, {
                backdrop: backdropClose === false ? 'static' : (backdrop !== false),
            });
            if (onHidden) element.addEventListener('hidden.bs.modal', (e) => { if (e.target === element) onHidden(e) });
            if (onShown) element.addEventListener('shown.bs.modal', (e) => { if (e.target === element) onShown(e) });
            // Expose the hide() function so the parent component can close the modal programmatically
            onReady?.(() => this._modal.hide());
        }

        if (open) {
            this._modal.show();
        } else {
            this._modal.hide();
        }
    }

    willDestroy() {
        this._modal?.dispose();
        this._modal = null;
    }
}
