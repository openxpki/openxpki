OXI.KeyValueView = OXI.View.extend({
    
    jsClassName:'OXI.KeyValueView',
    templateName: "keyvalue-view",
    
    content:null,
    label:null,
    data:null,

    init:function(){
        Ember.debug('OXI.TextView :init ');
        this._super();
        this.label = this.content.label;
        this.data = this.content.data;
    }

});