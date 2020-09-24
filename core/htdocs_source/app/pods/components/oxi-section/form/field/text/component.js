import Component from '@glimmer/component';
import { action } from '@ember/object';

/*
// Please note that currently (Ember 3.20.3) inheriting the template does not work:

import OxiFieldRawtextComponent from '../rawtext/component';
import OxiFieldRawtextTemplate from '../rawtext/template';

export default class OxiFieldTextComponent extends OxiFieldRawtextComponent {
    layout OxiFieldRawtextTemplate;

    @action
    onInput(event) {
        this.args.onChange(event.target.value);
    }
}
*/

export default class OxiFieldTextComponent extends Component {
    @action
    onInput(event) {
        let val = this.cleanup(event.target.value);
        this.args.onChange(val);
    }

    // Own "paste" implementation to allow for text cleanup
    @action
    onPaste(event) {
        let paste = (event.clipboardData || window.clipboardData).getData('text');
        let oldVal = this.args.content.value || "";

        let val =
            oldVal.slice(0, event.target.selectionStart) +
            this.cleanup(paste, { trimTrailingStuff: true }) +
            oldVal.slice(event.target.selectionEnd)

        this.args.onChange(val);
        event.preventDefault();
    }

    // Strips newlines + leading (and if chosen trailing) whitespaces and quotation marks
    cleanup(text, args = { trimTrailingStuff: false }) {
        let result = text.replace(/\r?\n/gm, '').replace(/^["'„\s]*/, '');
        if (args.trimTrailingStuff) {
            result = result.replace(/["'“\s]*$/, '');
        }
        return result;
    }
}
