import Component from '@ember/component';
import types from "../oxivalue-format/types";

const OxisectionKeyvalueComponent = Component.extend({
    items: Em.computed("content.content.data", function() {
        let items = this.get("content.content.data");
        for (const i of items) {
            if (i.format === 'head') { i.isHead = 1 }
        }
        return items.filter(item => types[item.format || 'text'](item.value) !== '');
    }),
    actions: {
        buttonClick: function(button) {
            return this.sendAction("buttonClick", button);
        }
    }
});

export default OxisectionKeyvalueComponent;