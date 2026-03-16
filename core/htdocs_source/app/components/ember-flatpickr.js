/**
 * Local re-implementation of ember-flatpickr (https://github.com/RobbieTheWagner/ember-flatpickr).
 * Shipping the source directly avoids the addon's pre-compiled dist referencing
 * @embroider/virtual/modifiers/* paths that the pure-Vite ember() plugin cannot resolve.
 *
 * Lifecycle:
 *   - `setup` modifier runs on insert and re-runs (destroy + reinit) whenever any @arg changes
 *   - `willDestroy()` tears down the flatpickr instance when the component leaves the DOM
 */
import Component from '@glimmer/component';
import { assert } from '@ember/debug';
import { waitForPromise } from '@ember/test-waiters';
import { modifier } from 'ember-modifier';
import flatpickr from 'flatpickr';

function setDisabled(fp, disabled) {
    if (!fp || disabled === undefined) return;
    const { altInput, element } = fp;
    if (altInput && element?.nextSibling) {
        element.nextSibling.disabled = disabled;
    } else {
        element.disabled = disabled;
    }
}

export default class EmberFlatpickr extends Component {
    flatpickrRef = undefined;

    // Defined as a class field so the modifier closure has access to `this.args`.
    // ember-modifier tracks every this.args.* access, so the modifier re-runs
    // automatically when any passed argument changes — replacing all {{did-update}} calls.
    setup = modifier((element) => {
        const { date, onChange, wrap, disabled, onReady, onOpen, onClose, locale, onDestroyed, ...rest } =
            this.args;

        assert(
            '<EmberFlatpickr> requires a `date` to be passed as the value for flatpickr.',
            date !== undefined,
        );
        assert(
            '<EmberFlatpickr> requires an `onChange` action or null for no action.',
            onChange !== undefined,
        );
        assert('<EmberFlatpickr> does not support the wrap option.', wrap !== true);

        const config = Object.fromEntries(
            Object.entries(rest).filter(([, v]) => v !== undefined),
        );

        let destroyed = false;

        const init = async () => {
            if (locale === 'de') {
                await waitForPromise(import('flatpickr/dist/l10n/de.js'));
            }
            if (destroyed) return;

            this.flatpickrRef = flatpickr(element, {
                ...config,
                defaultDate: date,
                onChange,
                onClose: onClose || this._onClose,
                onOpen: onOpen || this._onOpen,
                onReady: onReady || this._onReady,
                ...(locale ? { locale } : {}),
            });

            setDisabled(this.flatpickrRef, disabled);
        };

        waitForPromise(init());

        return () => {
            destroyed = true;
            onDestroyed?.();
            this.flatpickrRef?.destroy();
            this.flatpickrRef = undefined;
        };
    });

    willDestroy() {
        super.willDestroy();
        this.args.onDestroyed?.();
        this.flatpickrRef?.destroy();
        this.flatpickrRef = undefined;
    }

    _onClose() {}
    _onOpen() {}
    _onReady() {}
}
