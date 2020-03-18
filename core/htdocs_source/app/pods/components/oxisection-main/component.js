import Component from '@glimmer/component';
import { action } from "@ember/object";

export default class OxisectionMainComponent extends Component {
    get type() {
        return "oxisection-" + this.args.content.type;
    }

    @action
    buttonClick(button) {
        console.error("oxisection-main buttonClick");
        Em.set(button, "loading", true);
        if (button.action) {
            return this.container.lookup("route:openxpki")
            .sendAjax({
                data: {
                    action: button.action
                }
            })
            .then(
                () => Em.set(button, "loading", false),
                () => Em.set(button, "loading", false)
            );
        }
        else {
            return this.container.lookup("route:openxpki").transitionTo("openxpki", button.page);
        }
    }
}
