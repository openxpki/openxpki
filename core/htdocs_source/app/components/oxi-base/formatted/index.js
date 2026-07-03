import Component from '@glimmer/component';
import { fromUnixTime } from 'date-fns';
import { formatInTimeZone } from 'date-fns-tz';
import { action } from '@ember/object';

/**
 * Shows a formatted piece of text or data.
 *
 * ```html
 * <OxiBase::Formatted @format="timestamp" @value="1617102928" @class="big" @truncate={{true}} />
 * ```
 *
 * @param { string } [format] - How the value shall be formatted. Default: `'text'`.
 *   Possible formats:
 *   - `text`
 *   - `raw`
 *   - `subject`
 *   - `nl2br`
 *   - `timestamp`
 *   - `styled`
 *   - `certstatus`
 *   - `link` (uses {@link OxiBase::Formatted::Link})
 *   - `extlink`
 *   - `email`
 *   - `tooltip`
 *   - `code`
 *   - `asciidata`
 *   - `download`
 *   - `arbitrary` (uses {@link OxiBase::Formatted::Arbitrary})
 *   - `unilist`
 *   - `deflist` (deprecated)
 *   - `ullist` (deprecated)
 *   - `rawlist` (deprecated)
 *   - `linklist` (deprecated)
 * @param value - Value to be formatted. The data type depends on the format.
 * @class OxiBase::Formatted
 */
export default class OxiFormattedComponent extends Component {
    /**
     * Returns `@format`, defaulting to `"text"` when not provided.
     * @memberOf OxiBase::Formatted
     */
    get format() {
        return (this.args.format || "text");
    }

    /**
     * Returns `@value` coerced to a string with carriage returns stripped.
     * @memberOf OxiBase::Formatted
     */
    get valueStr() {
        return (new String(this.args.value || "")).replace(/\r/gm, "");
    }

    /**
     * Returns `@value` normalized to an array of strings (carriage returns stripped).
     * Scalars are wrapped in a single-element array; `null`/`undefined` produce `[]`.
     * @memberOf OxiBase::Formatted
     */
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

    /**
     * Returns `valueStr` split into an array of lines on `\n`.
     * @memberOf OxiBase::Formatted
     */
    get valueSplitByNewline() {
        return this.valueStr.split(/\n/);
    }

    /**
     * Returns a human-readable UTC timestamp string for a Unix epoch `@value`,
     * or `"---"` for zero/falsy values.
     * @memberOf OxiBase::Formatted
     */
    get timestamp() {
        return (this.args.value > 0
            ? formatInTimeZone(fromUnixTime(parseInt(this.args.value)), 'UTC', 'yyyy-MM-dd HH:mm:ss') + ' UTC'
            : '---');
    }

    /**
     * Parses `@value` as `"style:label"` and returns `{ style, label }`.
     * The style prefix is optional; if absent, `style` is an empty string.
     * @memberOf OxiBase::Formatted
     */
    get styledValue() {
        let val = this.args.value || ''
        let m = val.match(/^(([a-z]+):)?(.*)$/m)
        return {
            style: m[2] || '',
            label: m[3] || '',
        }
    }

    _parseNumeric(decimals = 0, multiplier = 1, suffix = '') {
        let v = this.args.value;
        if (v === null || v === undefined || v === '') return { text: '-', negative: false };
        let num = parseFloat(v) * multiplier;
        if (isNaN(num)) return { text: 'NaN', negative: false };
        return {
            text: num.toFixed(decimals) + suffix,
            negative: num < 0,
        };
    }

    get intValue() {
        let v = this.args.value;
        if (v === null || v === undefined || v === '') return { text: '-', negative: false };
        let num = parseFloat(v);
        if (isNaN(num)) return { text: 'NaN', negative: false };
        return { text: String(Math.trunc(num)), negative: num < 0 };
    }

    get floatValue() { return this._parseNumeric(2); }

    get percentValue() { return this._parseNumeric(2, 100, '%'); }

    /**
     * Selects all text inside the clicked `<code>` element via the browser Selection API.
     * @memberOf OxiBase::Formatted
     */
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
