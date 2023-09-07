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
 * @param { string|array } text - the text to display. If an array is given, the contents are separated via <span> tags
 * @param { string } tooltip - a tooltop text to display. Optional.
 * @param { bool } raw - set to `true` to allow HTML entities incl. `<script>` tags etc.
 * @param { bool } nowrap - do not wrap long text
 * @param { bool } truncate - truncate long text
 * @class OxiBase::Label
 */
export default class OxiLabelComponent extends Component {
    @service('oxi-content') content;
    @service('oxi-config') config;

    @tracked tooltipContent = null;

    get cssClasses() {
        let classes = [];
        if (Array.isArray(this.args.text)) classes.push('d-inline-flex');
        if (this.args.tooltip || this.args.raw_tooltip || this.args.tooltip_page) classes.push('oxi-has-tooltip')
        return classes.join(' ');
    }

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
