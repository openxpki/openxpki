import Component from '@glimmer/component';
import { action, set } from "@ember/object";
import { debug } from '@ember/debug';
import { getOwner } from '@ember/application';

export default class OxisectionMainComponent extends Component {
    get type() {
        return "oxisection-" + this.args.content.type;
    }

    @action
    buttonClick(button) {
        debug("oxisection-main: buttonClick");
        set(button, "loading", true);
        if (button.action) {
            getOwner(this).lookup("route:openxpki")
            .sendAjax({ action: button.action })
            .finally(() => set(button, "loading", false));
        }
        else {
            getOwner(this).lookup("route:openxpki").transitionTo("openxpki", button.page);
        }
    }
}
