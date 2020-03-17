import Controller, { inject as injectCtrl } from '@ember/controller';
import { tracked } from '@glimmer/tracking';
import { action, set } from "@ember/object";

export default class TestController extends Controller {
    @tracked testLinkA = {
        label: "Learn",
        className: "btn-info",
        tooltip: "Just fyi",
        href: "https://www.openxpki.org",
        target: "_blank",
    };
    @tracked testLinkButton = {
        label: "Move",
        className: "btn-info",
        tooltip: "This should move it",
        disabled: false,
    };
    @tracked testLinkButtonConfirm = {
        ...this.testLinkButton,
        label: "Confirm & Move",
        confirm: {
            label: "Really sure?",
            description: "Think about it one more time.",
        },
    };
    @tracked list = [
        { value: 1, label: "Major" },
        { value: 2, label: "Tom" },
    ];
    @tracked listSelection = null;

    @action testAction(button) {
        console.log(button);
        set(this.testLinkButton, "className", "btn-warning");
    }

    @action itemSelected(value, label) {
        console.log("SELECTED", value, label);
    }
}
