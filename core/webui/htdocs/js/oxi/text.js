OXI.TextView = OXI.View.extend({
    
    jsClassName:'OXI.TextView',
    templateName: "text-view",
    
    content:null,
    headline:null,
    paragraphs:null,

    init:function(){
        Ember.debug('OXI.TextView :init ');
        this._super();
        this.headline = this.content.headline;
        this.paragraphs = this.content.paragraphs;
    }

});