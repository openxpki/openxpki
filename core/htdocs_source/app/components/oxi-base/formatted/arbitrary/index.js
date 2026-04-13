import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';

/**
 * Show arbitrary data, e.g. a nested hash structure.
 *
 * ```html
 * <OxiBase::Formatted::Arbitrary @value={{val}} @raw={{true}} />
 * ```
 *
 * @param { object } value - Data to show.
 * @param { bool } [raw] - Only for strings: `true` to prevent escaping of HTML characters.
 * @class OxiBase::Formatted::Arbitrary
 */
export default class OxiFormattedArbitraryComponent extends Component {
    @tracked detailsOpen = false;

    /**
     * Returns the JavaScript `typeof` string for `@value`.
     * @memberOf OxiBase::Formatted::Arbitrary
     */
    get type() {
        return typeof this.args.value;
    }

    /**
     * Returns `true` when `@value` should be rendered as a plain string
     * (primitives, `null`, and `undefined`).
     * @memberOf OxiBase::Formatted::Arbitrary
     */
    get isString() {
        // what we interpret as a string...
        return (
            (new RegExp(/^(string|number|undefined)$/)).test(this.type)
            || this.args.value === null
        );
    }

    /**
     * Returns `@value` pretty-printed as a JSON string (2-space indent).
     * @memberOf OxiBase::Formatted::Arbitrary
     */
    get asJSON() {
        return JSON.stringify(this.args.value, null, 2);
    }

    /**
     * Toggles the expanded/collapsed state of the JSON details view.
     * @memberOf OxiBase::Formatted::Arbitrary
     */
    @action
    toggleDetails() {
        this.detailsOpen = !this.detailsOpen;
    }
}
