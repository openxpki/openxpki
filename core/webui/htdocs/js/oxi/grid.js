OXI.GridView = OXI.View.extend({
    
    jsClassName:'OXI.GridView',
    templateName: "grid-view",
    
    headline:null,
    preambel:null,
    postambel:null,
    
    grid_id:function(){
            js_debug('grid_id called ');
            return 'cya';
        }.property(),
    
    init:function(){
        //Ember.debug('OXI.FormView :init ');
        this._super();
        this.headline = this.content.header;
        this.preambel = this.content.preambel;
        this.postambel = this.content.postambel;
        
        if( ! this.content.columns ){
            App.applicationAlert(this.jsClassName + ': no columns given!');
            return;
        }
        if( ! this.content.data ){
            App.applicationAlert(this.jsClassName + ': no data given!');
            return;
        }
        
    },
    
    
    didInsertElement: function(){
        //this.debug('DOM is ready!'+this.$('table').attr('id'));   
        var $table = this.$('table');
        var bPaginate = (this.content.data.length > 10);
        var bFilter = (this.content.data.length > 5);
        $table.dataTable( {
              aaData: this.content.data ,
			  aoColumns:this.content.columns,
			  bPaginate:bPaginate,
			  bFilter:bFilter,
			  oLanguage: {
                  sSearch: "Filter records:"
                }
        });
    }
    
});