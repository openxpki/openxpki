OXI.TextView = OXI.View.extend({
    
    jsClassName:'OXI.TextView',
    templateName: "text-view",
    
    content:null,
    label:null,
    description:null,

    init:function(){
        Ember.debug('OXI.TextView :init ');
        this._super();
        this.label = this.content.label;
        this.description = this.content.description;
    }

});