export default [
    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "Bool + Select",
            title: "Bool + Select",
            fields: [
                {
                    type: "bool",
                    name: "ready_or_not",
                    label: "Bool, selected",
                    value: 1,
                },
                {
                    type: "bool",
                    name: "ready_or_not_optional",
                    label: "Bool, optional",
                    is_optional: 1,
                },
                {
                    type: "select",
                    name: "select_no_preset",
                    label: "Select, no preset",
                    options: [
                        { value: 1, label: "Major" },
                        { value: 2, label: "Tom" },
                    ],
                    placeholder: "Please select an option",
                },
                {
                    type: "select",
                    name: "select_no_preset_default_placeholder",
                    label: "Select, no preset, default placeholder",
                    options: [
                        { value: 1, label: "Major" },
                        { value: 2, label: "Tom" },
                    ],
                    placeholder: "_default",
                },
                {
                    type: "select",
                    name: "select_no_preset_no_placeholder",
                    label: "Select, no preset, no placeholder",
                    options: [
                        { value: 1, label: "Major" },
                        { value: 2, label: "Tom" },
                    ],
                },
                {
                    type: "select",
                    name: "select_preset",
                    label: "Select, preset 'Tom'",
                    options: [
                        { value: 1, label: "Major" },
                        { value: 2, label: "Tom" },
                    ],
                    value: 2,
                },
                {
                    type: "select",
                    name: "select_maybe",
                    label: "Select, optional",
                    options: [
                        { value: 1, label: "Major" },
                        { value: 2, label: "Tom" },
                    ],
                    is_optional: 1,
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
                    name: "select_maybe_editable",
                    label: "Select, editable, optional",
                    editable: 1,
                    is_optional: 1,
                    options: [
                        { value: 1, label: "Major" },
                        { value: 2, label: "Tom" },
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
                {
                    type: "select",
                    name: "select_inline",
                    label: "Inline select",
                    inline: true,
                    options: [
                        { value: 1, label: "Apocalypse Peaks" },
                        { value: 2, label: "Bishop's Itchington" },
                        { value: 3, label: "Cape Disappointment" },
                        { value: 4, label: "Port Circumcision" },
                        { value: 5, label: "Eggs and Bacon Bay" },
                        { value: 6, label: "Foulness Island" },
                    ],
                },
            ],
        },
    },
]
