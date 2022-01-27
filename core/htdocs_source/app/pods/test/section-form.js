const _testButton = {
    label: "Button",
    format: "primary",
    tooltip: "This should do it",
    disabled: false,
}

export default [
    {
        type: "form",
        action: "login!text",
        reset: "login!text",
        content: {
            label: "oxi-section/form #0",
            title: "Text",
            fields: [
                {
                    type: "text",
                    name: "text",
                    label: "Text",
                    value: "",
                },
                {
                    type: "text",
                    name: "comment",
                    label: "Comment (will be used in autocomplete below)",
                    value: "rain",
                },
                {
                    type: "encrypted",
                    name: "enc_param",
                    value: "fake_jwt_token",
                },
                {
                    type: "text",
                    name: "text_autocomplete",
                    label: "Autocomplete",
                    value: "pre",
                    tooltip: "Simulated autocomplete: Enter anything to get three results, or 'boom' to simulate server-side error, or 'void' for empty result list.",
                    autocomplete_query: {
                        action: "text!autocomplete",
                        params: {
                            the_comment: "comment",
                            secure_param: "enc_param",
                        },
                    },
                },
                {
                    type: "textarea",
                    name: "text_autofill",
                    label: "Autofill",
                    rows: 5,
                    autofill: {
                        request: {
                            url: `${window.location.protocol}//${window.location.host}/autofill`,
                            method: 'GET',
                            params: {
                                user: { the_comment: "comment" },
                                static: { forest: "deep" },
                            },
                        },
                        autorun: true,
                        label: "The Oracle",
                        button_label: "Per Smartcard erzeugen",
                    },
                },
            ],
        }
    },

    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "oxi-section/form #1",
            title: "Bool + Select",
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
                    value: 2,
                    options: [
                        { value: 1, label: "Tusen" },
                        { value: 2, label: "Takk" },
                    ],
                },
                {
                    type: "select",
                    name: "select_2",
                    label: "Select, one choice",
                    options: [
                        { value: "11", label: "Ocean" },
                    ],
                    value: "",
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
                _testButton,
                {
                    ..._testButton,
                    label: "With confirmation",
                    confirm: {
                        label: "Really sure?",
                        description: "Think about it one more time.",
                    },
                    break_before: 1,
                },
                {
                    ..._testButton,
                    label: "Disabled",
                    disabled: true,
                },
            ],
        }
    },

    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "oxi-section/form #2",
            title: "Password",
            fields: [
                {
                    type: "password",
                    name: "pwd",
                    label: "Password",
                    tooltip: "Please choose wisely",
                },
                {
                    type: "passwordverify",
                    name: "pwd_verified",
                    label: "Password, verifiable",
                },
                {
                    type: "passwordverify",
                    name: "pwd_verified_preset",
                    label: "Password, verifiable, preset",
                    value: "123\n",
                    tooltip: "Rinse and repeat",
                },
            ],
        }
    },

    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "oxi-section/form #3",
            title: "Datetime",
            fields: [
                {
                    type: "datetime",
                    name: "dt_now",
                    label: "Date, now",
                    placeholder: "Please select a date...",
                    tooltip: "It's now or never!",
                },
                {
                    type: "datetime",
                    name: "dt_now_preset",
                    label: "Date, now (preset)",
                    timezone: "local",
                    value: "now",
                },
                {
                    type: "datetime",
                    name: "dt_some_local",
                    label: "Date, 2020-03-03 03:33 UTC\nepoch = 1583206380",
                    timezone: "local",
                    value: "1583206380",
                },
                {
                    type: "datetime",
                    name: "dt_some",
                    label: "Date, 2020-03-03 03:33 UTC",
                    value: "1583206380",
                    is_optional: 1,
                },
                {
                    type: "datetime",
                    name: "dt_some_pitcairn",
                    label: "Date, 2020-03-03 03:33 UTC",
                    value: "1583206380",
                    timezone: "Pacific/Pitcairn",
                    is_optional: 1,
                },
            ],
        }
    },

    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "oxi-section/form #4",
            title: "Cloneable fields",
            fields: [
                {
                    type: "text",
                    name: "plaintext",
                    label: "Text, cloneable, 2 presets",
                    value: ["sheep #1", "sheep #2"],
                    clonable: 1,
                },
                {
                    type: "text",
                    name: "attributes",
                    label: "Text, dynamic, clonable, 2 presets",
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
            ],
        }
    },

    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "oxi-section/form #5",
            title: "Various",
            fields: [
                {
                    type: "rawtext",
                    name: "rawtext",
                    label: "Raw text",
                    value: "",
                },
                {
                    type: "static",
                    name: "static",
                    label: "Static",
                    value: "on my shirt",
                },
                {
                    type: "static",
                    name: "static (verbose)",
                    label: "Static",
                    value: "on my shirt",
                    verbose: "is sewed onto my shirt"
                },
                {
                    type: "static",
                    name: "static (empty)",
                    label: "Static",
                    value: "",
                },
                {
                    type: "textarea",
                    name: "prosa",
                    label: "Textarea",
                    value: "Hi there!\nHow are you?\n",
                },
                {
                    type: "textarea",
                    name: "prosa_autofill",
                    label: "Textarea (Autofill)",
                    value: "",
                    autofill: {
                        request: {
                            url: `${window.location.protocol}//${window.location.host}/autofill`,
                            method: 'GET',
                            params: {
                                static: { this: "it" },
                            },
                        },
                        label: "The Oracle",
                        button_label: "Per Smartcard erzeugen",
                    },
                },
                {
                    type: "textarea",
                    name: "textarea_upload",
                    value: "...data...",
                    label: "Textarea (Autofill + Upload)",
                    allow_upload: 1,
                    autofill: {
                        request: {
                            url: `${window.location.protocol}//${window.location.host}/autofill`,
                            method: 'GET',
                            params: {
                                user: { text: "rawtext" },
                                static: { forest: "deep" },
                            },
                        },
                        autorun: 1,
                        label: "The Oracle",
                    },
                },
            ],
        }
    },

    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "oxi-section/form #6",
            title: "Tooltips",
            fields: [
                {
                    type: "rawtext",
                    name: "rawtext #1",
                    label: "Raw text",
                    value: "",
                    tooltip: "Hidden message found."
                },
                {
                    type: "rawtext",
                    name: "rawtext #2",
                    label: "Raw text",
                    value: "",
                    tooltip: "Use sushi in fish bowl in sink."
                },
                {
                    type: "textarea",
                    name: "prosa",
                    label: "Textarea",
                    value: "Hi there!\nHow are you?\n",
                    tooltip: "You should give the peanuts to the two-headed squirrel."
                },
            ],
        }
    },
]
