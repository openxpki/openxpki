import Component from '@ember/component';

const OxisectionTextComponent = Component.extend({
    actions: {
        buttonClick: function(button) {
            return this.sendAction("buttonClick", button);
        }
    }
});

export default OxisectionTextComponent;