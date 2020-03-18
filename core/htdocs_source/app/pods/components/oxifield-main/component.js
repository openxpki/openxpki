import Component from '@ember/component';

const OxifieldMainComponent = Component.extend({
    classNameBindings: ["content.is_optional:optional:required", "content.class"],
    type: Em.computed("content.type", function() {
        return "oxifield-" + this.get("content.type");
    }),
    isBool: Em.computed.equal("content.type", "bool"),
    sFieldSize: Em.computed("content.size", "content.keysize", function() {
        var keys, keysize, size;
        keys = this.get("content.keys");
        size = this.get("content.size");
        keysize = this.get("content.keysize");
        if (!size) {
            if (keys) {
                if (!keysize) { keysize = 2 }
                size = 7 - keysize;
            } else {
                size = 7;
            }
        }
        return 'col-md-' + size;
    }),
    hasError: Em.computed.bool("content.error"),
    resetError: Em.observer("content.value", function() {
        return this.set("content.error");
    }),
    handleActionOnChange: Em.observer("content.value", function() {
        return this.sendAction("valueChange", this.get("content"));
    }),
    keyPress: function(event) {
        if (event.keyCode === 9) {
            if (this.get("content.clonable")) {
                if (this.get("content.value")) {
                    this.send("addClone");
                    event.stopPropagation();
                    return event.preventDefault();
                }
            }
        }
    },
    actions: {
        addClone: function(field) {
            return this.sendAction("addClone", this.get("content"));
        },
        delClone: function(field) {
            return this.sendAction("delClone", this.get("content"));
        },
        optionSelected: function(value, label) {
            return this.set("content.value", value);
        }
    }
});

export default OxifieldMainComponent;
