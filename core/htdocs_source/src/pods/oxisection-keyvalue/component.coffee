`import Em from "vendor/ember"`

Component = Em.Component.extend
    actions:
        buttonClick: (button) -> @sendAction "buttonClick", button

`export default Component`
