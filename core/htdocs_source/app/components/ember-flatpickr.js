/**
 * Local re-implementation of ember-flatpickr (https://github.com/RobbieTheWagner/ember-flatpickr).
 * Shipping the source directly avoids the addon's pre-compiled dist referencing
 * `@embroider/virtual/modifiers/*` paths that the pure-Vite `ember()` plugin cannot resolve.
 *
 * Lifecycle:
 *   - `setup` modifier runs on insert and re-runs (destroy + reinit) whenever any `@arg` changes
 *   - `willDestroy()` tears down the flatpickr instance when the component leaves the DOM
 *
 * ```html
 * <EmberFlatpickr
 *     @date={{this.date}}
 *     @onChange={{this.datePicked}}
 *     @onReady={{this.onReady}}
 *     @enableTime={{true}}
 * />
 * ```
 *
 * @param { Date|null } date - Initial date value passed to flatpickr as `defaultDate`.
 * @param { function } onChange - Required. flatpickr `onChange` callback: `(dates, dateStr, instance)`.
 * @param { boolean } [enableTime] - Show time picker in addition to date.
 * @param { string } [dateFormat] - flatpickr date format string.
 * @param { string } [locale] - Locale code (currently `'de'` loads the German flatpickr locale).
 * @param { boolean } [allowInput] - Allow direct text input in addition to the picker.
 * @param { string } [placeholder] - Placeholder text for the input element.
 * @param { boolean } [disabled] - Disables the input.
 * @param { function } [onReady] - flatpickr `onReady` callback: `(dates, dateStr, instance)`.
 * @param { function } [onOpen] - flatpickr `onOpen` callback.
 * @param { function } [onClose] - flatpickr `onClose` callback.
 * @param { function } [onDestroyed] - Called just before the flatpickr instance is destroyed.
 *
 * @class EmberFlatpickr
 * @extends Component
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

    /**
     * Tears down the flatpickr instance when the component leaves the DOM.
     * Calls `@onDestroyed` if provided.
     * @memberOf EmberFlatpickr
     */
    willDestroy() {
        super.willDestroy();
        this.args.onDestroyed?.();
        this.flatpickrRef?.destroy();
        this.flatpickrRef = undefined;
    }

    /**
     * No-op default for the flatpickr `onClose` event.
     * @memberOf EmberFlatpickr
     */
    _onClose() {}
    /**
     * No-op default for the flatpickr `onOpen` event.
     * @memberOf EmberFlatpickr
     */
    _onOpen() {}
    /**
     * No-op default for the flatpickr `onReady` event.
     * @memberOf EmberFlatpickr
     */
    _onReady() {}
}
