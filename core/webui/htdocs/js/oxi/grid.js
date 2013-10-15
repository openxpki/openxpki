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
        
        var columnDef = this._getColumnDef();
        
        var tableInit = {
              aaData: this.content.data ,
			  aoColumns:columnDef,
			  bPaginate:bPaginate,
			  bFilter:bFilter,
			  oLanguage: {
                  sSearch: "Filter records:"
                }
        };
        
        
        //do we have a "status"-column defined?
        var statusIndex = this._getStatusColumnIndex(columnDef);
        if(statusIndex >-1){
            $table.removeClass('table-striped').removeClass('table-hover');
            tableInit.fnCreatedRow = function(nRow, aData, iDataIndex){
                                var rowStatus = aData[statusIndex];
                                js_debug({rowStatus:rowStatus, nRow:nRow, aData:aData, iDataIndex:iDataIndex});
                                if(rowStatus){
                                    $(nRow).addClass('gridrow-'+rowStatus);
                                }else{
                                    $(nRow).addClass('gridrow');
                                }
                            }   
        }
        
        $table.dataTable(tableInit );
    },
    
    _getColumnDef: function(){
        var aColumns = this.content.columns;
        //determine hidden cols:
        var i;
        for(i=0;i<aColumns.length;i++){
            if(aColumns[i].sTitle.indexOf('_')==0){
                //column-name begins with "_" - its a hidden column
                aColumns[i].bVisible = false;
            }
            if(aColumns[i].format){
                //special format-dependent rendering:
                aColumns[i].mRender = this._getColRenderCallback(aColumns[i].format);
            }
        }
        return aColumns; 
    },
    
    _getColRenderCallback: function(format){
        switch(format){
            case 'timestamp':
                return function(data, type, full){
                    if(type=='display' || type=='filter'){
                        var D = new Date(parseInt(data)*1000);
                        //return D.toLocaleString();
                        return D.toGMTString();
                    }
                    return data;
                };
           default://format not implemented:
                return function(data, type, full){
                    return data;
                }
                 
        }
    },
    
    _getStatusColumnIndex: function(aColumns){
        var index = -1;
        var i;
        for(i=0;i<aColumns.length;i++){
            if(aColumns[i].sTitle == '_status'){
               index = i;    
            }   
        }
        return index;
    },
    
    
    
});