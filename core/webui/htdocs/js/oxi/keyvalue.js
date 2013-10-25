OXI.KeyValueView = OXI.ContentBaseView.extend({
    
    jsClassName:'OXI.KeyValueView',
    templateName: "keyvalue-view",

    data:null,

    init:function(){
        Ember.debug('OXI.TextView :init ');
        this._super();
        
        this.data = this.content.data;
    }

});