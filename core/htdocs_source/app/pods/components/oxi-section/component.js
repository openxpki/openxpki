import Component from '@glimmer/component';
import { action, set } from "@ember/object";
import { debug } from '@ember/debug';
import { service } from '@ember/service';
import { tracked } from '@glimmer/tracking';
import Button from 'openxpki/data/button';

export default class OxiSectionComponent extends Component {
    @service router;
    @service('oxi-content') content;

    get type() {
        return `oxi-section/${this.args.content.type}`;
    }

    get sectionData() {
        let buttons = []
        for (const buttonHash of this.args.content?.content?.buttons ?? []) {
            // convert hash into field
            buttons.push(Button.fromHash({
                ...buttonHash,
                onClick: this.buttonClick, // add click handler
            }))
        }

        return {
            ...this.args.content.content,
            buttons, // replaces this.args.content.content.buttons (array of hashes) with our array of Button objects
            // map some inconsistently placed properties into the section data
            action:     this.args.content.action,       // used by oxisection/form
            reset:      this.args.content.reset,        // used by oxisection/form
            className:  this.args.content.className,    // used by oxisection/grid
        }
    }

    @action
    buttonClick(button) {
        debug("oxisection: buttonClick");
        set(button, "loading", true);
        if (button.action) {
            this.content.updateRequest({ action: button.action })
            .finally(() => set(button, "loading", false));
        }
        else {
            this.router.transitionTo("openxpki", button.page)
            .then(() => set(button, "loading", false));
        }
    }

    @action
    initialized() {
        if (this.args.onInit) this.args.onInit();
    }
}
