import Component from '@glimmer/component';
import { DateTime } from 'luxon';
import { action } from '@ember/object';

/**
 * Shows a formatted piece of text or data.
 *
 * ```html
 * <OxiBase::Formatted @format="timestamp" @value="1617102928" @class="big" @truncate={{true}} />
 * ```
 *
 * @param { string } format - how the value shall be formatted.
 *
 * Possible formats:
 * - `text`
 * - `raw`
 * - `subject`
 * - `nl2br`
 * - `timestamp`
 * - `styled`
 * - `certstatus`
 * - `link` (uses {@link OxiBase::Formatted::Link})
 * - `extlink`
 * - `email`
 * - `tooltip`
 * - `code`
 * - `asciidata`
 * - `download`
 * - `arbitrary` (uses {@link OxiBase::Formatted::Arbitrary})
 * - `unilist`
 * - `deflist` (deprecated)
 * - `ullist` (deprecated)
 * - `rawlist` (deprecated)
 * - `linklist` (deprecated)
 * @param value - value to be formatted - the data type depends on the format
 * @class OxiBase::Formatted
 */
export default class OxiFormattedComponent extends Component {
    get format() {
        return (this.args.format || "text");
    }

    get valueStr() {
        return (new String(this.args.value || "")).replace(/\r/gm, "");
    }

    get valueArray() {
        let strOrArray = this.args.value
        let result

        if (strOrArray === null) {
            result = []
        } else if (Array.isArray(strOrArray)) {
            result = strOrArray
        } else if (typeof strOrArray === 'undefined') {
            result = []
        } else {
            result = [strOrArray]
        }

        return result.map(e => (new String (e||"")).replace(/\r/gm, ""))
    }

    get valueSplitByNewline() {
        return this.valueStr.split(/\n/);
    }

    get timestamp() {
        return (this.args.value > 0
            ? DateTime.fromSeconds(parseInt(this.args.value)).setZone('utc').toFormat('yyyy-MM-dd HH:mm:ss') + ' UTC'
            : '---');
    }

    get styledValue() {
        let val = this.args.value || ''
        let m = val.match(/^(([a-z]+):)?(.*)$/m)
        return {
            style: m[2] || '',
            label: m[3] || '',
        }
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
