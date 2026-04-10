export default [
    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "Various",
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
        },
    },
]
