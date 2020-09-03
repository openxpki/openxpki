import Component from '@glimmer/component';
import moment from "moment-timezone";

export default class OxiFormattedComponent extends Component {
    get format() {
        return (this.args.format || "text");
    }

    get valueStr() {
        return (new String(this.args.value || "")).replace(/\r/gm, "");
    }

    get valueSplitByNewline() {
        return this.valueStr.split(/\n/);
    }

    get timestamp() {
        return (this.args.value > 0
            ? moment.unix(this.args.value).utc().format("YYYY-MM-DD HH:mm:ss UTC")
            : "---");
    }

    get styledValue() {
        let m = this.args.value.match(/^(([a-z]+):)?(.*)$/m);
        return {
            style: m[2],
            label: m[3],
        };
    }
}
