export default [
    {
        type: "form",
        action: "login!password",
        reset: "login!password",
        content: {
            label: "Tooltips",
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
        },
    },
]
