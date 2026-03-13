import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';

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
