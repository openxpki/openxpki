import Controller from '@ember/controller';
import { tracked } from '@glimmer/tracking';
import { action, set } from "@ember/object";

export default class TestController extends Controller {
    testButton = {
        label: "Button",
        className: "btn-info",
        tooltip: "This should do it",
        disabled: false,
    };

    @tracked formDef = {
        type: "form",
        action: "dummy",
        content: {
            title: "Test input",
            submit_label: "Perform",
            fields: [
                {
                    type: "select",
                    name: "test_select",
                    label: "Your choice:",
                    options: [
                        { value: 1, label: "Major" },
                        { value: 2, label: "Tom" },
                    ],
                },
                {
                    type: "password",
                    name: "pwd",
                    label: "Password",
                },
                {
                    type: "passwordverify",
                    name: "pwd_verified",
                    label: "Verified password",
                },
            ],
            buttons: [
                {
                    label: "Link to external",
                    className: "btn-info",
                    tooltip: "Just fyi",
                    href: "https://www.openxpki.org",
                    target: "_blank",
                },
                this.testButton,
                {
                    ...this.testButton,
                    label: "With confirmation",
                    confirm: {
                        label: "Really sure?",
                        description: "Think about it one more time.",
                    },
                },
                {
                    ...this.testButton,
                    label: "Disabled",
                    disabled: true,
                },
            ],
        }
    };
}
