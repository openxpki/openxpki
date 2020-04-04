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
                    name: "select_it",
                    label: "Your choice:",
                    options: [
                        { value: 1, label: "Major" },
                        { value: 2, label: "Tom" },
                    ],
                },
                {
                    type: "select",
                    name: "select_editable",
                    label: "Your choice:",
                    editable: 1,
                    options: [
                        { value: 1, label: "Tusen" },
                        { value: 2, label: "Takk" },
                    ],
                },
                {
                    type: "select",
                    name: "test_select_2",
                    label: "Only one choice",
                    options: [
                        { value: "11", label: "Ocean" },
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
                    name: "dt_now",
                    label: "Date, now",
                },
                {
                    type: "datetime",
                    name: "dt_some_local",
                    label: "Date, 2020-03-03 03:33",
                    timezone: "local",
                    value: "1583206380",
                },
                {
                    type: "datetime",
                    name: "dt_some",
                    label: "Date, 2020-03-03 03:33",
                    value: "1583206380",
                },
                {
                    type: "datetime",
                    name: "dt_some_local",
                    label: "Date, 2020-03-03 03:33",
                    value: "1583206380",
                    timezone: "Pacific/Pitcairn",
                },
                {
                    type: "text",
                    name: "plaintext",
                    label: "Dolly",
                    value: ["Please enter..."],
                    clonable: 1,
                },
                {
                    type: "static",
                    name: "label1",
                    label: "Label",
                    value: "on my shirt",
                },
                {
                    type: "static",
                    name: "label2",
                    label: "Label",
                    value: "on my shirt",
                    verbose: "is sewed onto my shirt"
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
