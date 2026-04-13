import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { service } from '@ember/service';
import { fromUnixTime, getUnixTime } from 'date-fns';
import { toZonedTime, fromZonedTime } from 'date-fns-tz';

/**
 * Date/time picker field implementation, backed by {@link EmberFlatpickr}.
 *
 * @param { object } content - Plain field hash (from {@link Field}).
 * @param { string|number } [content.value] - Initial epoch timestamp, or `"now"` for the current time.
 * @param { string } [content.timezone] - IANA timezone name, `"utc"` (default), or `"local"` for the browser timezone.
 * @param { string } [content.placeholder] - Placeholder text for the input.
 * @param { boolean } [content.is_optional] - When falsy the input is marked required.
 * @param { function } onChange - Callback invoked with the selected epoch (number) or `null` when cleared.
 * @param { function } setFocusInfo - Callback to register the flatpickr input element for focus management.
 * @param { string } [error] - Validation error message to display below the input.
 *
 * @class OxiSection::Form::Field::Datetime
 * @extends Component
 */
export default class OxiFieldDatetimeComponent extends Component {
    @service('oxi-locale') oxiLocale;

    @tracked date;
    flatpickr; // reference to the JS object
    timezoneLabel = this.args.content.timezone || "UTC";
    @tracked allowClearing = false

    /**
     * Returns the resolved IANA timezone string. `"utc"` stays as-is; `"local"` is
     * replaced with the browser's timezone via `Intl.DateTimeFormat`.
     * @memberOf OxiSection::Form::Field::Datetime
     */
    get timezone() {
        let tz = this.args.content.timezone || "utc";
        if (tz === "local") tz = Intl.DateTimeFormat().resolvedOptions().timeZone; // Browser's timezone
        return tz;
    }

    constructor() {
        super(...arguments);

        // convert epoch to DateTime object
        let epoch = this.args.content.value;

        if (!epoch) {
            this.date = null;
        }
        else {
            let date = ("now" === epoch) ? new Date() : fromUnixTime(parseInt(epoch));

            // create a Date() object with the same wall-clock numbers as in this.timezone
            this.date = toZonedTime(date, this.timezone);
            this.allowClearing = true;
        }
    }

    /**
     * Called by {@link EmberFlatpickr} once the picker is initialized.
     * Stores the flatpickr instance, normalizes the `"now"` preset to a concrete epoch,
     * and registers the input element for focus management.
     * @memberOf OxiSection::Form::Field::Datetime
     */
    @action
    onReady(dates, dateStr, flatpickr) {
        this.flatpickr = flatpickr;
        // For the "now" preset: normalize to a specific epoch so the form submits
        // a concrete timestamp instead of the literal string "now".
        // For regular presets: field.value is already the correct epoch from the
        // backend — calling datePicked would change it from string to number
        // ("1234" -> 1234), which triggers a tracked re-render, which causes the
        // modifier to re-run, which re-fires onReady, producing an infinite loop.
        if (dates[0] && this.args.content.value === "now") {
            this.datePicked(dates, dateStr, flatpickr);
        }
        this.args.setFocusInfo(flatpickr.element, true);
    }

    /**
     * Clears the stored flatpickr reference when the picker is destroyed (modifier re-run or teardown),
     * preventing stale calls during the gap before the next `onReady`.
     * @memberOf OxiSection::Form::Field::Datetime
     */
    @action
    onFlatpickrDestroyed() {
        // Called by EmberFlatpickr before it destroys the flatpickr instance
        // (modifier re-run or component teardown). Clears the stale reference so
        // that openFlatpickr/clearFlatpickr safely no-op during the gap between
        // destroy and the next onReady.
        this.flatpickr = undefined;
    }

    /**
     * Programmatically opens the flatpickr calendar (triggered by the calendar icon button).
     * @memberOf OxiSection::Form::Field::Datetime
     */
    @action
    openFlatpickr() {
        this.flatpickr?.open();
    }

    /**
     * Clears the current date selection and resets the tracked `date` property to `null`.
     * @memberOf OxiSection::Form::Field::Datetime
     */
    @action
    clearFlatpickr() {
        this.date = null;
        this.flatpickr?.clear();
    }

    /**
     * Called by {@link EmberFlatpickr} when the user selects or clears a date.
     * Converts the selected wall-clock date to a UTC epoch and reports it via `onChange`.
     * Updates `allowClearing` to show/hide the clear button.
     * @memberOf OxiSection::Form::Field::Datetime
     */
    @action
    datePicked(dates, dateStr, flatpickr) {
        let epoch = null
        if (dates[0]) {
            epoch = getUnixTime(fromZonedTime(dates[0], this.timezone))
            // Guard to avoid spurious tracked re-renders when the value is unchanged
            if (!this.allowClearing) this.allowClearing = true
        }
        else {
            if (this.allowClearing) this.allowClearing = false
        }
        this.args.onChange(epoch)
    }
}
