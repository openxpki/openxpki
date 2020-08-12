import Component from '@glimmer/component';

/**
Shows a label (a text) and escapes special characters.

@module oxi-label
@param { string|array } text - the text to display. If an array is given, the contents are shown separated via <span> tags
*/

export default class OxiLabelComponent extends Component {
    get useSpan() {
        return (this.args.tooltip || this.args.class || Array.isArray(this.args.text));
    }
}
