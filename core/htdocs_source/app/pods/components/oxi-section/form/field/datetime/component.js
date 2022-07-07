import Component from '@glimmer/component';
import { action, computed } from '@ember/object';
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
        }
    }

    @action
    onReady(dates, dateStr, flatpickr) {
        this.flatpickr = flatpickr;
        this.datePicked(dates, dateStr, flatpickr);
    }

    @action
    datePicked(dates, dateStr, flatpickr) {
        let epoch = null
        if (dates[0]) {
            let dt = DateTime.fromJSDate(dates[0])
            dt = dt.setZone(this.timezone, { keepLocalTime: true })
            epoch = dt.toSeconds()
            this.allowClearing = true
        }
        else {
            this.allowClearing = false
        }
        this.args.onChange(epoch)
    }
}
