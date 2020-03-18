import Component from '@ember/component';

const OxiButtonContainerComponent = Component.extend({
    classNameBindings: ["buttons:oxi-button-container"],
    hasDescription: Em.computed("buttons.@each.description", function() {
        var ref;
        return (ref = this.get("buttons")) != null ? ref.isAny("description") : void 0;
    }),
    actions: {
        click: function(button) {
            return this.sendAction("buttonClick", button);
        }
    }
});

export default OxiButtonContainerComponent;