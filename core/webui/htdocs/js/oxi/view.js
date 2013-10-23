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
      //js_debug(this.jsClassName+':init' + this.toString());
      this.resetErrors();
      
      this._super();
   },
   
   
   destroy:function(){
      //js_debug(this.jsClassName+':destroy' + this.toString());
      this._super();
   },
   
   debug:function(data){
      js_debug({jsClassName:this._toString(),data:data},3);
   }
});

OXI.ContentBaseView = OXI.View.extend(
    {
    //content prop: must be set via create() , info comes fropm server
    content:null,
    label:null,
    description:null,
    ButtonList:[],
    
    init:function(){
      
      this.ButtonList = [];
      this.label=null;
      this.description=null;
      this._super();
      if(!this.content ){
        App.applicationError('ContentBaseView, init failed: no content definition!');
        return;
     }
     if (this.content.label){
            this.label = this.content.label;
        }
        if (this.content.description){
            this.description = this.content.description;
        }
      
   },
   
   addButton: function(ButtonView){
        this.ButtonList.push(this.createChildView(ButtonView));
   }
   
});

OXI.LoadingView = OXI.View.extend(
    {
        jsClassName:'OXI.LoadingView',
        templateName: "loading",
        
        show:function(){
            this.debug('show!');
            $('#ajaxLoadingModal').modal('show');
        },
        hide:function(){
            this.debug('hide!');
            $('#ajaxLoadingModal').modal('hide');
        }
        
    }
    
);
