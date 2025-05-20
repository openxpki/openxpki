import ContainerButton from 'openxpki/data/container-button'

const _testButton = {
    label: "Button",
    format: "primary",
    tooltip: "This should do it",
    disabled: false,
}

let buttons = [
    ContainerButton.fromHash({
        label: "External link",
        format: "failure",
        tooltip: "Just fyi",
        href: "https://www.openxpki.org",
        target: "_blank",
    }),
    ContainerButton.fromHash({
        label: "External link (with confirmation)",
        format: "exceptional",
        tooltip: "Just fyi",
        href: "https://www.openxpki.org",
        target: "_blank",
        confirm: {
            label: "Really sure?",
            description: "This opens an external page.",
        },
    }),
    ContainerButton.fromHash(_testButton),
    ContainerButton.fromHash({
        ..._testButton,
        label: "With confirmation",
        confirm: {
            label: "Really sure?",
            description: "Think about it one more time.",
        },
        break_before: 1,
    }),
    ContainerButton.fromHash({
        ..._testButton,
        label: "Disabled",
        disabled: true,
        break_after: 1,
    }),
]

for (const format of [
    'primary',
    'submit',
    'loading',
    'cancel',
    'reset',
    'expected',
    'failure',
    'optional',
    'alternative',
    'exceptional',
    'terminate',
    'tile',
    'card',
    'info',
]) {
    buttons.push(ContainerButton.fromHash({
        ..._testButton,
        format,
        label: format,
    }))
}

export default buttons