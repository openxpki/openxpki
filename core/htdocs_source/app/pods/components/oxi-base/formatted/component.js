import Component from '@glimmer/component';
import moment from "moment-timezone";
import { action } from '@ember/object';
import copy from 'copy-text-to-clipboard';


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

    @action
    selectCode(event) {
        let element = event.target;
        if (window.getSelection) {
            const selection = window.getSelection();
            const range = document.createRange();
            range.selectNodeContents(element);
            selection.removeAllRanges();
            selection.addRange(range);
        } else {
            console.warn("Could not select text: Unsupported browser");
        }
    }

}
