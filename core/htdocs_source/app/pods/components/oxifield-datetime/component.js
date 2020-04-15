import Component from '@glimmer/component';
import { action, computed } from '@ember/object';
import moment from "moment-timezone";

export default class OxifieldDatetimeComponent extends Component {
    format = "DD.MM.YYYY HH:mm";
    value;

    constructor() {
        super(...arguments);
        let val = this.args.content.value;
        let tz = this.args.content.timezone;
        this.value = (!val || val === "now")
            ? null // in the template this will be used as a flag
            : this.resolveTimezone(
                () => moment.unix(val).utc(),
                () => moment.unix(val).local(),
                v => moment.unix(val).tz(v),
                tz
            );
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
}
