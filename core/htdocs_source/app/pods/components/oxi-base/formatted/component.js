import Component from '@glimmer/component';
import moment from "moment-timezone";

export default class OxiFormattedComponent extends Component {
    get format() {
        return (this.args.content.format || "text");
    }

    get valueStr() {
        return (new String(this.args.content.value || "")).replace(/\r/gm, "");
    }

    get valueSplitByNewline() {
        return this.valueStr.split(/\n/);
    }

    get timestamp() {
        return (this.args.content.value > 0
            ? moment.unix(this.args.content.value).utc().format("YYYY-MM-DD HH:mm:ss UTC")
            : "---");
    }

    get styledValue() {
        let m = this.args.content.value.match(/^(([a-z]+):)?(.*)$/m);
        return {
            style: m[2],
            label: m[3],
        };
    }
}
