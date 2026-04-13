import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { service } from '@ember/service';

/**
 * Shows a label (a text) and escapes special characters.
 * ```javascript
 * hint = "A <b>bold</b> statement"
 * ```
 * ```html
 * <OxiBase::Label @text={{this.hint}} @tooltip="Oh!" @raw={{true}} />
 * ```
 *
 * @param { string|array } text - The text to display. If an array is given, the contents are separated via `<span>` tags.
 * @param { string } [tooltip] - Tooltip text to display.
 * @param { bool } [raw] - Set to `true` to allow HTML entities incl. `<script>` tags etc.
 * @param { bool } [nowrap] - Do not wrap long text.
 * @param { bool } [truncate] - Truncate long text.
 * @class OxiBase::Label
 */
export default class OxiLabelComponent extends Component {
    @service('oxi-content') content;
    @service('oxi-config') config;

    @tracked tooltipContent = null;

    /**
     * Returns the space-separated CSS classes to apply to the label wrapper.
     * @memberOf OxiBase::Label
     */
    get cssClasses() {
        let classes = [];
        if (Array.isArray(this.args.text)) classes.push('d-inline-flex');
        if (this.args.tooltip || this.args.raw_tooltip || this.args.tooltip_page) classes.push('oxi-has-tooltip')
        return classes.join(' ');
    }

    /**
     * Lazily fetches tooltip content from the backend (`@tooltip_page`) and stores
     * it in `tooltipContent`. Only fires once; subsequent calls are no-ops.
     * @memberOf OxiBase::Label
     */
    @action
    fetchTooltip(event) {
        if (this.tooltipContent) return;
        this.content.requestUpdate({
            page: this.args.tooltip_page,
            ...this.args.tooltip_page_args,
        }).then((doc) => {
            this.tooltipContent = doc;
        });
    }
}
