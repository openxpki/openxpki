import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { scheduleOnce } from '@ember/runloop';

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
    @tracked value = null;

    constructor() {
        super(...arguments);
        /*
        We need to decouple the input field from the 'value' parameter because
        otherwise our custom onPaste() handler triggers a refresh of the input
        field and always moves the cursor to the end (i.e. unexpected
        behaviour if sth. is inserted in the middle
        */
        this.value = this.args.content.value;
    }

    @action
    onInput(event) {
        this.value = this.cleanup(event.target.value);
        this.args.onChange(this.value);
    }

    // Own "paste" implementation to allow for text cleanup
    @action
    onPaste(event) {
        let paste = (event.clipboardData || window.clipboardData).getData('text');
        let pasteCleaned = this.cleanup(paste, { trimTrailingStuff: true });
        let inputField = event.target;
        let oldVal = this.value || "";

        let newCursorPos = inputField.selectionStart + pasteCleaned.length;

        // put cursor into right position after Ember rendered all updates
        scheduleOnce('afterRender', this, () => {
            inputField.focus();
            inputField.setSelectionRange(newCursorPos, newCursorPos);
        });

        this.value =
            oldVal.slice(0, inputField.selectionStart) +
            pasteCleaned +
            oldVal.slice(inputField.selectionEnd);

        this.args.onChange(this.value);
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
