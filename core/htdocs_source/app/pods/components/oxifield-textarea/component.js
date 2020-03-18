import Component from '@ember/component';

const OxifieldTextareaComponent = Component.extend({
    cols: Em.computed("content.textAreaSize.width", function() {
        return this.get("content.textAreaSize.width") || 150;
    }),
    rows: Em.computed("content.textAreaSize.height", function() {
        return this.get("content.textAreaSize.height") || 10;
    })
});

export default OxifieldTextareaComponent;