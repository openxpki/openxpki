const _testButton = {
    label: "Button",
    format: "primary",
    tooltip: "This should do it",
    disabled: false,
}

const buttons = [
    {
        label: "Link",
        format: "failure",
        tooltip: "Just fyi",
        href: "https://www.openxpki.org",
        target: "_blank",
        break_before: 1,
    },
    {
        label: "Link (confirm)",
        format: "exceptional",
        tooltip: "Just fyi",
        href: "https://www.openxpki.org",
        target: "_blank",
        confirm: {
            label: "Really sure?",
            description: "This opens an external page.",
        },
    },
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
        break_after: 1,
    },
]

for (const format of [
    'primary',
    'submit',
    'expected',
    'loading',
    'exceptional',
    'terminate',
    'cancel',
    'failure',
    'reset',
    'alternative',
    'optional',
    'info',
    'tile',
    'card',
]) {
    buttons.push({ ..._testButton, format, label: format })
}

export default [{
    type: "form",
    action: "login!text",
    reset: "login!text",
    content: {
        label: "Button formats",
        fields: [],
        buttons,
    },
}]
