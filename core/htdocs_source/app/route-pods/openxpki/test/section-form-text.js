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
            label: "Text",
            title: "Text",
            fields: [
                {
                    type: "text",
                    name: "text",
                    label: "Text (small)",
                    value: "",
                    width: "small",
                },
                {
                    type: "text",
                    name: "text",
                    label: "Text (small, disabled)",
                    value: "",
                    width: "small",
                    readonly: 1,
                },
                {
                    type: "text",
                    name: "text_maybe",
                    label: "Text (large)",
                    value: "",
                    is_optional: 1,
                    width: "large",
                },
                {
                    type: "text",
                    name: "text_optional_regex",
                    label: "Text (optional, only digits)",
                    is_optional: 1,
                    ecma_match: "^[0-9]+$",
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
            buttons: [
                { ..._testButton },
                {
                    ..._testButton,
                    label: "With confirmation",
                    confirm: {
                        label: "Really sure?",
                        description: "Think about it one more time.",
                    },
                },
                {
                    ..._testButton,
                    label: "Disabled",
                    disabled: true,
                },
            ],
        },
    },
]
