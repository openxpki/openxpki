import Component from '@ember/component'

OxisectionTextComponent = Component.extend
    actions:
        buttonClick: (button) -> @sendAction "buttonClick", button

export default OxisectionTextComponent
