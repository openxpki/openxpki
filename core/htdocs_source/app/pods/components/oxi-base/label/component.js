import Component from '@glimmer/component';

/**
 * Shows a label (a text) and escapes special characters.
 *
 * ```html
 * <OxiBase::Label @text="A <b>bold</b> statement" @tooltip="Oh!" @raw={{true}} />
 * ```
 *
 * @module oxi-base/label
 * @param { string|array } text - the text to display. If an array is given, the contents are separated via <span> tags
 * @param { string } tooltip - a tooltop text to display. Optional.
 * @param { bool } raw - set to `true` to allow HTML entities incl. `<script>` tags etc.
 */
export default class OxiLabelComponent extends Component {
    get useSpan() {
        return (this.args.tooltip || this.args.class || Array.isArray(this.args.text));
    }
}
