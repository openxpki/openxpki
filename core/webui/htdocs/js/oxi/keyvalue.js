OXI.KeyValueView = OXI.ContentBaseView.extend({
    
    jsClassName:'OXI.KeyValueView',
    templateName: "keyvalue-view",

    data:null,
    

    init:function(){
        Ember.debug('OXI.TextView :init ');
        this._super();
        this.set('data',[]);

        var i;
        for(i=0;i<this.content.data.length;i++){
            var item = this.content.data[i];
            if(typeof(item.value) == 'object'){
                item.value.source = this;   
            }
            this.data[i] = OXI.KeyValueItem.create( item ); 
        }
    }
});

OXI.KeyValueItem = Ember.Object.extend({
    
    label:null,
    value:null,
    format:null,
    
    formatedVal: function(){
        if(this.format){
            return OXI.FormatHelperFactory.getHelper(this.format).format(this.value);   
        }else{
            return this.value;   
        }
    }.property('value','format')
    

});