/**
Base Class for all Views in OXI namespace
*/

OXI.View = Ember.View.extend({
   jsClassName:'OXI.View: you must define jsClassName in your subclass!',
   
   _toString:function(){
      return this.jsClassName + ' '+ this.toString();
   },
   
   setError:function(msg){
      this.errors.push(msg);
      this.set('_hasError',true);
   },

   getErrorsAsString:function(){
      return this.errors.join(' - ');
   }.property('_hasError'),

   hasError:function(){
      this.debug('has error?' + this._hasError );
      return (this.errors.length>null);
   }.property('_hasError'),
   
   resetErrors:function(){
      this.set('errors',[]);
      this.set('_hasError',false);
   },

   init:function(){
      //Ember.debug(this.jsClassName+':init' + this.toString());
      this.resetErrors();
      this._super();
   },
   
   debug:function(data){
      js_debug({jsClassName:this._toString(),data:data},3);
   }
});
