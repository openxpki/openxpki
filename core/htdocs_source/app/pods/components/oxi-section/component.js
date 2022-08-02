import Component from '@glimmer/component';
import { action, set } from "@ember/object";
import { debug } from '@ember/debug';
import { service } from '@ember/service';
import { tracked } from '@glimmer/tracking';

/*
 * Button data
 */
class Button {
    /*
     * oxi-section
     */
    action;

    /*
     * oxi-base/button
     */
    // common
    format;
    label;      // mandatory
    tooltip;
    image;
    @tracked loading = false; // pure client-side status
    // <a href> mode
    href;       // mandatory - triggers the <a href...> format
    target;
    // <button> mode
    page;
    disabled;
    /* confirm = {
     *     label: "Really sure?",          // mandatory if "confirm" exists
     *     description: "Think!",          // mandatory if "confirm" exists
     *     confirm_label: ""
     *     cancel_label: ""
     * }
     */
    confirm;

    /*
     * oxi-base/button-container
     */
    section;
    description;
    break_before;
    break_after;

    static fromHash(sourceHash) {
        let instance = new this(); // "this" in static methods refers to class
        for (const attr of Object.keys(sourceHash)) {
            // @tracked properties are prototype properties, the others instance properties
            if (! (Object.prototype.hasOwnProperty.call(Object.getPrototypeOf(this), attr) || Object.prototype.hasOwnProperty.call(instance, attr))) {
                /* eslint-disable-next-line no-console */
                console.error(
                    `oxi-section: unknown property "${attr}" in button "${sourceHash.label}". ` +
                    `If it's a new property, please add it to class 'Button' defined in app/pod/components/oxi-section/component.js`
                );
            }
            else {
                instance[attr] = sourceHash[attr];
            }
        }
        return instance;
    }
}

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
            buttons.push(Button.fromHash(buttonHash))
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
        debug("oxisection/main: buttonClick");
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
