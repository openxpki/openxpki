import Component from '@glimmer/component';
import { action } from '@ember/object';
import moment from "moment";

export default class OxifieldDatetimeComponent extends Component {
    format = "DD.MM.YYYY HH:mm";
    value;

    constructor() {
        super(...arguments);
        let val = this.args.content.value;
        this.value = (!val || val === "now")
            ? null // in the template this will be used as a flag
            : moment.unix(val).local();
    }

    @action
    datePicked(value) {
        let datetime;
        if (value && value !== "0") {
            datetime = moment(value, this.format).unix();
        } else {
            datetime = "";
        }
        this.args.onChange(datetime);
    }
}
