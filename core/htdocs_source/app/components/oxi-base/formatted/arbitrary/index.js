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
 * @param { hash } value - data to show
 * @param { bool } raw - only for strings: `true` to prevent escaping of HTML characters
 * @class OxiBase::Formatted::Arbitrary
 */
export default class OxiFormattedArbitraryComponent extends Component {
    @tracked detailsOpen = false;

    get type() {
        return typeof this.args.value;
    }

    get isString() {
        // what we interpret as a string...
        return (
            (new RegExp(/^(string|number|undefined)$/)).test(this.type)
            || this.args.value === null
        );
    }

    get asJSON() {
        return JSON.stringify(this.args.value, null, 2);
    }

    @action
    toggleDetails() {
        this.detailsOpen = !this.detailsOpen;
    }
}
