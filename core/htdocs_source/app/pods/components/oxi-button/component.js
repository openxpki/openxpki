import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action, set } from "@ember/object";

/**
Shows a button with an optional confirm dialog.
The component has two modes:

1. show a `<button/>` tag and handle clicks via callback:
   `<OxiButton @button={{myDef1}} @onClick={{sendData}}/>`
2. show a `<a href/>` tag and simply open the given URL:
   `<OxiButton @button={{myDef2}}/>`

@module oxi-button
@param { hash } button - Hash containing the button definition.
    Mode 1:
    ```json
        {
            label: "Move",
            className: "green",
            tooltip: "This should move it"
            disabled: false,
            confirm: {
                label: "Really sure?",
                description: "Think about it one more time."
            },
        }
    ```
    Mode 2:
    ```json
        {
            label: "Learn",
            className: "blue",
            tooltip: "Just fyi"
            href: "https://www.openxpki.org",
            target: "_blank",
        }
    ```

*/
export default class OxiButtonComponent extends Component {
    tagName = "span";

    @tracked showConfirmDialog = false;

    @action
    click() {
        if (this.args.button.confirm) {
            set(this.args.button, "loading", true);
            this.showConfirmDialog = true;
        } else {
            this.executeAction();
        }
    }

    @action
    executeAction() {
        this.resetConfirmState();
        this.args.onClick(this.args.button);
    }

    @action
    resetConfirmState() {
        set(this.args.button, "loading", false);
        this.showConfirmDialog = false;
    }
}
