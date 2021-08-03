import Component from '@glimmer/component';
import moment from "moment-timezone";
import { action } from '@ember/object';
import copy from 'copy-text-to-clipboard';

/**
 * Shows a formatted piece of text or data.
 *
 * ```html
 * <OxiBase::Formatted @format="timestamp" value="1617102928"/>
 * ```
 *
 * @param { string } format - how the value shall be formatted
 * Possible formats:
 * - `certstatus`
 * - `link`
 * - `extlink`
 * - `timestamp`
 * - `text`
 * - `nl2br`
 * - `code`
 * - `asciidata`
 * - `download`
 * - `raw`
 * - `deflist`
 * - `ullist`
 * - `rawlist`
 * - `linklist`
 * - `styled`
 * - `tooltip`
 * @param value - value to be formatted - the data type depends on the format
 * @module component/oxi-base/formatted
 */
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
