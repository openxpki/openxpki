OXI.GridView = OXI.View.extend({
    
    jsClassName:'OXI.GridView',
    templateName: "grid-view",
    
    label:null,
    description:null,
        
    grid_id:function(){
            js_debug('grid_id called ');
            return 'cya';
        }.property(),
    
    init:function(){
        //Ember.debug('OXI.FormView :init ');
        this._super();
        this.label = this.content.header;
        this.description = this.content.description;
        
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