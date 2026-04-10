export default [
    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "Cloneable fields",
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
        },
    },
]
