import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { inject } from '@ember/service';

/**
 * Shows a label (a text) and escapes special characters.
 *
 * ```html
 * <OxiBase::Label @text="A <b>bold</b> statement" @tooltip="Oh!" @raw={{true}} />
 * ```
 *
 * @param { string|array } text - the text to display. If an array is given, the contents are separated via <span> tags
 * @param { string } tooltip - a tooltop text to display. Optional.
 * @param { bool } raw - set to `true` to allow HTML entities incl. `<script>` tags etc.
 * @param { bool } nowrap - do not wrap long text
 * @param { bool } truncate - truncate long text
 * @module component/oxi-base/label
 */
export default class OxiLabelComponent extends Component {
    @inject('oxi-content') content;
    @inject('oxi-config') config;

    @tracked tooltipContent = null;
    @tracked tooltipReady = false;

    get cssClasses() {
        let classes = [];
        if (this.args.inline || Array.isArray(this.args.text)) classes.push('d-inline-flex');
        if (this.args.tooltip || this.args.raw_tooltip || this.args.tooltip_page) classes.push('oxi-has-tooltip')
        return classes.join(' ');
    }

    @action
    fetchTooltip(event) {
        if (this.tooltipContent) return;
        this.content.updateRequestQuiet({
            page: this.args.tooltip_page,
            ...this.args.tooltip_page_args,
        }).then((doc) => {
            this.tooltipContent = doc;
        });
    }

    @action
    setTooltipReady(element) {
        // Referenced via @updateFor={{this.tooltipReady}} -- this
        // will trigger a repositioning if the content is too big
        this.tooltipReady = true;
    }
}
