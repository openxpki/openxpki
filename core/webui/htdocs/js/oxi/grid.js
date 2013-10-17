OXI.GridView = OXI.View.extend({
    
    jsClassName:'OXI.GridView',
    templateName: "grid-view",
    
    label:null,
    description:null,
    grid_id:null,    
    
    
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
        this.debug('DOM is ready!'+this.$().attr('id'));   
        var $table = this.$('table');
        //give the table element a unique ID
        this.grid_id = this.$().attr('id')+'-grid';
        $table.attr('id',this.grid_id);
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
                                //js_debug({rowStatus:rowStatus, nRow:nRow, aData:aData, iDataIndex:iDataIndex});
                                if(rowStatus && rowStatus!='[none]'){
                                    $(nRow).addClass('gridrow-'+rowStatus);
                                }else{
                                    $(nRow).addClass('gridrow');
                                }
                            };
            //display status-filter
            if(bFilter){
                var availableStati = this._getAvailableStati(statusIndex);
                //js_debug({availableStati:availableStati},2);
                if(availableStati.length>1){
                    tableInit.fnDrawCallback = this._getStatusFilterDrawCallback(statusIndex,availableStati); 
                }
            }
        }
        
        if(this.content.actions  ){
            var actions = this.content.actions;
            tableInit.fnRowCallback = function( nRow, aData, iDisplayIndex ) {
                //js_debug('fnRowCallback ... '+iDisplayIndex);  
                var strTooltip='',i;
                for(i=0;i<actions.length;i++){
                   strTooltip += '<div action-path="'+actions[i].path+'">'+actions[i].label +'</div>';  
                }
                $('td', nRow).popover(
                    {trigger:'click',
                     html:true,
                     placement:'auto',
                     title:'Possible actions',
                     content:strTooltip,
                     container: 'body'
                        }
                );
            };   
        }
        
        $table.dataTable(tableInit );
        js_debug('dataTable tableInit');
    },
    
    _getStatusFilterDrawCallback: function(statusIndex, availableStati){
        var grid_id = this.grid_id;
        var StatusFilterContainer = $('<div/>').attr('id',grid_id+'_statusfilter_cont').addClass('dataTables_filter').css('padding-left','10px');
        var StatusFilter = $('<select/>').attr('id',grid_id+'_statusfilter');
        StatusFilter.change(function(){
                var sel_status = $( this ).val();
                js_debug('status filter changed: '+sel_status);
                var DataTable = $('#'+grid_id).dataTable();
                if(sel_status){
                    DataTable.fnFilter(sel_status,statusIndex);
                }else{
                    DataTable.fnFilter('',statusIndex);
                }
            });
        //empty option
        $("<option />", {value: '', text: 'all'}).appendTo(StatusFilter);
        var i;
        for(i = 0;i<availableStati.length;i++){
            $("<option />", {value: availableStati[i], text: availableStati[i]}).appendTo(StatusFilter);
        }
        var StatusFilterLabel = $('<label/>').html('Status: ');
        StatusFilterLabel.append(StatusFilter);
        StatusFilterContainer.html(StatusFilterLabel);
        return function(oSettings ){
              var oFilterContainer = $('#'+grid_id+'_filter');
              js_debug('check grid-filter-wrapper...' + oFilterContainer.attr('id'))  ;
              StatusFilterContainer.appendTo(oFilterContainer);
            };
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
    
    _getAvailableStati: function(iStatusIndex){
        var seen = new Object();
        var i;
        for(i=0;i<this.content.data.length;i++){
            if(!this.content.data[i][iStatusIndex]){
                this.content.data[i][iStatusIndex] = '[none]';
            }
            seen[this.content.data[i][iStatusIndex]] = 1;
        }
        var key,keys=[];
        for(key in seen){
            keys.push(key);   
        }
        
        return keys;
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