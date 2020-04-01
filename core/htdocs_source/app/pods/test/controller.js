import Controller from '@ember/controller';
import { tracked } from '@glimmer/tracking';
import { action, set } from "@ember/object";

export default class TestController extends Controller {
    testButton = {
        label: "Button",
        format: "primary",
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
                    type: "bool",
                    name: "ready_or_not",
                    label: "Ready?",
                    value: 1,
                },
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
                    type: "select",
                    name: "test_select_2",
                    label: "Only one choice",
                    options: [
                        { value: "", label: "The Void" },
                    ],
                    value: "",
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
                {
                    type: "datetime",
                    name: "dt_empty",
                    label: "Date, no preset",
                },
                {
                    type: "datetime",
                    name: "dt_now",
                    label: "Date, now",
                },
                {
                    type: "datetime",
                    name: "dt_some",
                    label: "Date, 02.01.2020 02:05",
                    value: "1577927100",
                },
            ],
            buttons: [
                {
                    label: "Link to external",
                    format: "failure",
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
