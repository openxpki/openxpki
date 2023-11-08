import ContainerButton from 'openxpki/data/container-button'

const _testButton = {
    label: "Button",
    format: "primary",
    tooltip: "This should do it",
    disabled: false,
}

export default [
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
    }),
]
