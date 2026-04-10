export default [
    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "Select with dependants",
            title: "Select with dependants",
            fields: [
                {
                    type: "select",
                    name: "select_dependants",
                    label: "Level 1",
                    editable: 1, // must be ignored in this case
                    value: 2,
                    options: [
                        {
                            value: 1,
                            label: "Tusen",
                        },
                        {
                            value: 2,
                            label: "Takk",
                            dependants: [
                                {
                                    type: "bool",
                                    name: "select_dep_ready_or_not",
                                    label: "Level 2 - Bool, selected",
                                    value: 1,
                                },
                                {
                                    type: "datetime",
                                    name: "select_dep_dt_now",
                                    label: "Level 2 - Date, now",
                                    placeholder: "Please select a date...",
                                    tooltip: "It's now or never!",
                                },
                                {
                                    type: "text",
                                    name: "select_dep_plaintext",
                                    label: "Level 2 - Text, cloneable, 2 presets",
                                    value: ["sheep #1", "sheep #2"],
                                    clonable: 1,
                                },
                                {
                                    type: "select",
                                    name: "select_dep_dependants",
                                    label: "Level 2 - Sub-select with dependants",
                                    value: 2,
                                    options: [
                                        {
                                            value: 1,
                                            label: "Vaer sa god",
                                        },
                                        {
                                            value: 2,
                                            label: "Ingen problemer",
                                            dependants: [
                                                {
                                                    type: "text",
                                                    name: "select_dep_dep_plaintext",
                                                    label: "Level 3 - Text",
                                                },
                                            ],
                                        },
                                    ],
                                },
                            ],
                        },
                    ],
                },
                {
                    type: "select",
                    name: "select_dependants2",
                    label: "Level 1",
                    options: [
                        {
                            value: 1,
                            label: "Only option",
                            dependants: [
                                {
                                    type: "select",
                                    name: "select_dep_dependants",
                                    label: "Level 2 - Sub-select",
                                    options: [
                                        {
                                            value: 3,
                                            label: "Only Option",
                                        },
                                    ],
                                },
                            ],
                        },
                    ],
                },
            ],
        },
    },
]
