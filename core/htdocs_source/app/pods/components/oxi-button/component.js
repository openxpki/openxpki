import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action, computed, set } from "@ember/object";
import { debug } from '@ember/debug';

/**
Shows a button with an optional confirm dialog.

The component has two modes:

1. show a `<a href/>` tag and simply open the given URL:
   ```html
   <OxiButton @button={{myDef2}} class="btn btn-default"/>
   ```
2. show a `<button/>` tag and handle clicks via callback:
   ```html
   <OxiButton @button={{myDef1}} @onClick={{sendData}} class="btn btn-default"/>
   ```

@module oxi-button
@param { hash } button - Hash containing the button definition.
Mode 1 `<a href>`:
```javascript
{
    isPrimary: 1,
    label: "Learn",                     // mandatory
    tooltip: "Just fyi",
    href: "https://www.openxpki.org",   // mandatory
    target: "_blank",
}
```
Mode 2 `<button>`:
```javascript
{
    isPrimary: 0,
    label: "Move",                      // mandatory
    tooltip: "This should move it",
    disabled: false,
    confirm: {
        label: "Really sure?",          // mandatory if "confirm" exists
        description: "Think!",          // mandatory if "confirm" exists
        confirm_label: ""
        cancel_label: ""
    },
}
```
@param { callback } onClick - Action handler to be called.
The `button` hash will be passed on to the handler as single parameter.
*/

// mapping of format codes to CSS classes applied to the button
let format2css = {
    expected:       "oxi-btn-expected",
    failure:        "oxi-btn-failure",
    optional:       "oxi-btn-optional",
    alternative:    "oxi-btn-alternative",
    exceptional:    "oxi-btn-exceptional",
    cancel:         "oxi-btn-cancel",
    reset:          "oxi-btn-reset",
};

export default class OxiButtonComponent extends Component {
    @tracked showConfirmDialog = false;

    @computed("args.button.format")
    get additionalCssClass() {
        return format2css[this.args.button.format] ?? "";
    }

    @action
    click() {
        debug("oxi-button: click");
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
