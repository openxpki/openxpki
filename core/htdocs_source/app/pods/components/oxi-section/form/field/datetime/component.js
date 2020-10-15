import Component from '@glimmer/component';
import { action, computed } from '@ember/object';
import { inject as service } from '@ember/service';
import moment from "moment-timezone";

export default class OxiFieldDatetimeComponent extends Component {
    @service('oxi-locale') oxiLocale;

    format = "DD.MM.YYYY HH:mm"; // do not add "ZZ" as this results in the date being converted to local timezone (why?)
    value;
    jqElement;

    constructor() {
        super(...arguments);

        let epoch = this.args.content.value;
        if ("now" === epoch) epoch = (new Date()).valueOf() / 1000;

        if (epoch) {
            this.value = this.createMomentWithTZ(epoch * 1000);
        }
        else {
            this.value = null; // will be used as a flag to set the current time when the widget opens
        }
    }

    @computed("args.content.timezone")
    get timezoneLabel() {
        let tz = this.args.content.timezone;
        // default to UTC
        if (!tz) return "UTC";
        // "local" or other timezone
        return tz;
    }

    @action
    datePicked(dateObj) {
        /* NOTE!
           1. We cannot reliably calculate an epoch from the JavaScript Date()
              object passed by DateTimePicker via dateObj. It does not contain
              a timezone and DateTimePicker sometimes sets it to wrong dates
              and timezone offsets.
           2. this.jqElement.toValue() also queries moment.js' internal Date()
              object and thus returns the same wrong epoch.

           So we query the plain date values via moment.toObject() instead
           and get the epoch via an intermediate moment.js object.
         */
        // helper function to provide leading zeros
        let nn = (num) => (new String(num)).length < 2 ? '0'+num : num;

        // plain date values --> date string + tz --> moment.js object --> epoch
        let dt = this.jqElement.date().toObject(); // date() return moment.js object
        let dateStr = `${dt.years}-${nn(dt.months + 1)}-${nn(dt.date)} ${nn(dt.hours)}:${nn(dt.minutes)}:${nn(dt.seconds)}`;
        let date = this.createMomentWithTZ(dateStr);

        this.args.onChange(date.valueOf() / 1000);
    }

    @action
    datepickerReady(obj) {
        // code taken from https://github.com/btecu/ember-cli-bootstrap-datetimepicker/blob/1b4c7d3ac930338e71211f23d8c1d0da8ae795b7/addon/components/bs-datetimepicker.js#L73
        this.jqElement = $(obj).data('DateTimePicker');

        if (!this.jqElement.date()) {
            this.args.onChange("");
            return;
        }

        this.datePicked(this.jqElement.date().toDate());
    }

    createMomentWithTZ(value) {
        let tz = this.args.content.timezone;
        // default to UTC
        if (!tz) return moment.utc(value);
        // special treatment of "local"
        if (tz === "local") return moment(value).local();
        // other timezone
        return moment.tz(value, this.args.content.timezone);
    }
}
