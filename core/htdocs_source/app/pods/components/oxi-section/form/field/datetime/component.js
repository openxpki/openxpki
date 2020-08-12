import Component from '@glimmer/component';
import { action, computed } from '@ember/object';
import { inject as service } from '@ember/service';
import moment from "moment-timezone";

export default class OxiFieldDatetimeComponent extends Component {
    @service('oxi-locale') oxiLocale;

    format = "DD.MM.YYYY HH:mm";
    value;

    constructor() {
        super(...arguments);

        let val = this.args.content.value;
        if ("now" === val) val = (new Date()).valueOf() / 1000;
        let tz = this.args.content.timezone;
        this.value = val
            ? this.resolveTimezone(
                () => moment.unix(val).utc(),
                () => moment.unix(val).local(),
                v => moment.unix(val).tz(v),
                tz
            )
            : null; // will be used as a flag to set the current time when the widget opens
    }

    resolveTimezone(ifEmpty, ifLocal, otherwise, param) {
        let tz = this.args.content.timezone;
        let result = tz
            ? (tz === "local" ? ifLocal : otherwise)
            : ifEmpty;
        return result(param);
    }

    @computed("args.content.timezone")
    get timezone() {
        return this.resolveTimezone(
            () => "UTC",
            () => "local",
            () => this.args.content.timezone,
        );
    }

    @action
    datePicked(dateObj) {
        // the dateObj will have the correct timezone set (as we gave it to BsDatetimepicker)
        let datetime = dateObj ? Math.floor(dateObj / 1000) : "";
        this.args.onChange(datetime);
    }

    @action
    datepickerReady(obj) {
        // code taken from https://github.com/btecu/ember-cli-bootstrap-datetimepicker/blob/1b4c7d3ac930338e71211f23d8c1d0da8ae795b7/addon/components/bs-datetimepicker.js#L73
        let jqElement = $(obj).data('DateTimePicker');
        let d = jqElement.date() && jqElement.date().toDate() || null;
        this.datePicked(d);
    }
}
