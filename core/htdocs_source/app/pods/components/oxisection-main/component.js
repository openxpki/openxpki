import Component from '@ember/component';

const OxisectionMainComponent = Component.extend({
    classNameBindings: ["type"],
    type: Em.computed("content.type", function() {
        return "oxisection-" + this.get("content.type");
    }),
    actions: {
        buttonClick: function(button) {
            Em.set(button, "loading", true);
            if (button.action) {
                return this.container.lookup("route:openxpki")
                .sendAjax({
                    data: {
                        action: button.action
                    }
                })
                .then(
                    () => Em.set(button, "loading", false),
                    () => Em.set(button, "loading", false)
                );
            }
            else {
                return this.container.lookup("route:openxpki").transitionTo("openxpki", button.page);
            }
        }
    }
});

export default OxisectionMainComponent;