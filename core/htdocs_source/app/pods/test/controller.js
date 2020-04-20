import Controller from '@ember/controller';
import { tracked } from '@glimmer/tracking';

export default class TestController extends Controller {
    testButton = {
        label: "Button",
        format: "primary",
        tooltip: "This should do it",
        disabled: false,
    };

    @tracked formDef = {
        type: "form",
        action: "login!password",
        content: {
            title: "Test input",
            submit_label: "Perform",
            fields: [
                {
                    type: "bool",
                    name: "ready_or_not",
                    label: "Bool, selected",
                    value: 1,
                },
                {
                    type: "select",
                    name: "select_it",
                    label: "Select, no preset",
                    options: [
                        { value: 1, label: "Major" },
                        { value: 2, label: "Tom" },
                    ],
                },
                {
                    type: "select",
                    name: "select_editable",
                    label: "Select, editable",
                    editable: 1,
                    options: [
                        { value: 1, label: "Tusen" },
                        { value: 2, label: "Takk" },
                    ],
                },
                {
                    type: "select",
                    name: "test_select_2",
                    label: "Select, one choice",
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
                    label: "Password, verifiable",
                },
                {
                    type: "passwordverify",
                    name: "pwd_verified",
                    label: "Password, verifiable, preset",
                    value: "123\n",
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
                    label: "Clone field with 2 presets",
                    value: ["sheep #1", "sheep #2"],
                    clonable: 1,
                },
                {
                    type: "text",
                    name: "attributes",
                    label: "Dynamic, clonable, 2 presets",
                    clonable: 1,
                    is_optional: 1,
                    keys: [
                        {
                            value: "cert_subject",
                            label: "Certificate Subject",
                        },
                        {
                            value: "requestor",
                            label: "Requestor",
                        },
                        {
                            value: "transaction_id",
                            label: "Transaction Id",
                        },
                    ],
                    value: [
                        { key: "cert_subject", value: "Subject" },
                        { key: "transaction_id", value: "TransId" },
                    ],
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
                {
                    type: "textarea",
                    name: "prosa",
                    label: "Textarea",
                    value: "Hi there!\nHow are you?",
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

    @tracked gridDef = {
        "content": {
            "pager": {
                "startat": 0,
                "reverse": 1,
                "count": 3,
                "pagersize": 20,
                "pagesizes": [
                    25,
                    50,
                    100,
                    250,
                    500
                ],
                "pagerurl": "certificate!pager!id!rJdrIbg1P6xsE6b9RtQCXp291SE",
                "limit": 25,
                "order": "notbefore"
            },
            "empty": "No data available",
            "buttons": [
                {
                    "format": "expected",
                    "page": "certificate!search!query!rJdrIbg1P6xsE6b9RtQCXp291SE",
                    "label": "Reload Search Form"
                },
                {
                    "format": "alternative",
                    "page": "redirect!certificate!result!id!rJdrIbg1P6xsE6b9RtQCXp291SE",
                    "label": "Refresh Result"
                },
                {
                    "label": "New Search",
                    "format": "failure",
                    "page": "certificate!search"
                },
                {
                    "label": "Export Result",
                    "format": "optional",
                    "target": "_blank",
                    "href": "/cgi-bin/webui.fcgi?page=certificate!export!id!rJdrIbg1P6xsE6b9RtQCXp291SE"
                }
            ],
            "actions": [
                {
                    "label": "Download",
                    "icon": "download",
                    "path": "certificate!detail!identifier!{identifier}",
                    "target": "modal"
                },
                {
                    "label": "Check",
                    "icon": "download",
                    "path": "certificate!detail!identifier!{identifier}",
                    "target": "modal"
                }
            ],
            "columns": [
                {
                    "sTitle": "Certificate Serial",
                    "sortkey": "cert_key"
                },
                {
                    "sTitle": "Subject",
                    "sortkey": "subject"
                },
                {
                    "format": "certstatus",
                    "sortkey": "status",
                    "sTitle": "Status"
                },
                {
                    "sTitle": "not before",
                    "sortkey": "notbefore",
                    "format": "timestamp"
                },
                {
                    "format": "raw",
                    "sortkey": "notafter",
                    "sTitle": "raw"
                },
                {
                    "sTitle": "Issuer",
                    "sortkey": "issuer_dn"
                },
                {
                    "sortkey": "identifier",
                    "sTitle": "Certificate Identifier"
                },
                {
                    "sTitle": "identifier",
                    "bVisible": 0
                },
                {
                    "sTitle": "_className"
                }
            ],
            "data": [
                [
                    "0x3ff536fff8da93943aa",
                    "CN=e.d.c:pkiclient,DC=Test Deployment,DC=OpenXPKI,DC=org",
                    {
                        "value": "ISSUED",
                        "label": "Issued"
                    },
                    "1585959633",
                    1617495633,
                    "CN=OpenXPKI Demo Issuing CA 1,OU=PKI,O=OpenXPKI,C=DE",
                    "0qLkfCTwwj-8SoSOTtlRQLqS20o",
                    "0qLkfCTwwj-8SoSOTtlRQLqS20o",
                    {
                        "label": "Issued",
                        "value": "ISSUED"
                    }
                ],
                [
                    "0x2ff8fa8ee5590e2553a",
                    "CN=sista.example.org:pkiclient,DC=Test Deployment,DC=OpenXPKI,DC=org",
                    {
                        "label": "Issued",
                        "value": "ISSUED"
                    },
                    "1585434533",
                    "<a href=\"test\" onclick=\"alert('huh')\">test</a>",
                    "CN=OpenXPKI Demo Issuing CA 1,OU=PKI,O=OpenXPKI,C=DE",
                    "fPF_JVAco7Eg0d3kANRFLYRPu5o",
                    "fPF_JVAco7Eg0d3kANRFLYRPu5o",
                    {
                        "label": "Issued",
                        "value": "ISSUED"
                    }
                ],
            ]
        },
        "type": "grid",
        "className": "certificate"
    };
}
