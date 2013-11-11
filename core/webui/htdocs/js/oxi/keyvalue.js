"use strict";

OXI.KeyValueView = OXI.ContentBaseView.extend({
    
    jsClassName:'OXI.KeyValueView',
    templateName: "keyvalue-view",

    data:null,
    

    init:function(){
        
        this._super();
        this.set('data',[]);
        //this.debug(this.content.data);
        var i;
        for(i=0;i<this.content.data.length;i++){
            var item = this.content.data[i];
            if(!item){
                next;
            }
            if(typeof(item.value) == 'object'){
                item.value.source = this;   
            }
            this.data[i] = OXI.KeyValueItem.create( item ); 
        }
    },
    _lastItem: '' //avoid trailing commas
});

OXI.KeyValueItem = Ember.Object.extend({
    
    label:null,
    value:null,
    format:null,
    
    init: function(){
        //js_debug('KeyValueItem init: '+this.value);  
    },
    
    formatedVal: function(){
    	if(this.format) {
    		if (this.format == 'raw') { return this.value }
            return OXI.FormatHelperFactory.getHelper(this.format).format(this.value);  
        }else{
        	return $('<div/>').text( this.value ).html();               
        }
    }.property('value','format'),
    
    _lastItem: '' //avoid trailing commas
});