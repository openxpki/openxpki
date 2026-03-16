import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { service } from '@ember/service';
import { DateTime, SystemZone } from 'luxon';

export default class OxiFieldDatetimeComponent extends Component {
    @service('oxi-locale') oxiLocale;

    date;
    flatpickr; // reference to the JS object
    timezoneLabel = this.args.content.timezone || "UTC";
    @tracked allowClearing = false

    get timezone() {
        let tz = this.args.content.timezone || "utc";
        if (tz === "local") tz = new SystemZone().name; // Browser's timezone
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
            let dt = ("now" === epoch) ? DateTime.now() : DateTime.fromSeconds(parseInt(epoch));
            dt = dt.setZone(this.timezone);

            // create a Date() object with the same numbers but in local timezone
            this.date = dt.setZone(new SystemZone(), { keepLocalTime: true }).toJSDate();
            this.allowClearing = true;
        }
    }

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

    @action
    onFlatpickrDestroyed() {
        // Called by EmberFlatpickr before it destroys the flatpickr instance
        // (modifier re-run or component teardown). Clears the stale reference so
        // that openFlatpickr/clearFlatpickr safely no-op during the gap between
        // destroy and the next onReady.
        this.flatpickr = undefined;
    }

    @action
    openFlatpickr() {
        this.flatpickr?.open();
    }

    @action
    clearFlatpickr() {
        this.flatpickr?.clear();
    }

    @action
    datePicked(dates, dateStr, flatpickr) {
        let epoch = null
        if (dates[0]) {
            let dt = DateTime.fromJSDate(dates[0])
            dt = dt.setZone(this.timezone, { keepLocalTime: true })
            epoch = dt.toSeconds()
            // Guard to avoid spurious tracked re-renders when the value is unchanged
            if (!this.allowClearing) this.allowClearing = true
        }
        else {
            if (this.allowClearing) this.allowClearing = false
        }
        this.args.onChange(epoch)
    }
}
