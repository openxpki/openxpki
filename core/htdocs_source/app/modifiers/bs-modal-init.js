import Modifier from 'ember-modifier';
import { Modal } from 'bootstrap';

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
