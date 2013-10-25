OXI.GridView = OXI.ContentBaseView.extend({
    
    jsClassName:'OXI.GridView',
    templateName: "grid-view",
    
    
    grid_id:null,    
    
    
    init:function(){
        //Ember.debug('OXI.FormView :init ');
        this._super();
        
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
        //this.debug('DOM is ready!'+this.$().attr('id'));   
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
        
        var callbacksOnDraw = [];
        
        //do we have a "status"-column defined?
        var statusIndex = this._getStatusColumnIndex(columnDef);
        if(statusIndex >-1){
            $table.removeClass('table-striped').removeClass('table-hover');
            var grid_id = this.grid_id;
            tableInit.fnCreatedRow = function(nRow, aData, iDataIndex){
                                var rowStatus = aData[statusIndex];
                                //js_debug({rowStatus:rowStatus, nRow:nRow, aData:aData, iDataIndex:iDataIndex});
                                $(nRow).addClass('gridrow-'+grid_id);
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
                    callbacksOnDraw.push( this._getStatusFilterDrawCallback(statusIndex,availableStati)); 
                }
            }
        }else{
            var grid_id = this.grid_id;
            tableInit.fnCreatedRow = function(nRow, aData, iDataIndex){ $(nRow).addClass('gridrow-'+grid_id); };  
        }
        
        if(this.content.actions  ){
            callbacksOnDraw.push(this._getContextMenuCallback(columnDef,this.content.actions));
        }
        
        tableInit.fnDrawCallback = function(oSettings){
            var i;
            for(i=0;i< callbacksOnDraw.length;i++){
                var cb = callbacksOnDraw[i];
                //js_debug('exec callback on draw '+cb);
                cb(oSettings);    
            }  
        }
        
        $table.dataTable(tableInit );
        js_debug('dataTable tableInit');
    },
    
    doAction:function(action,data){
        var i;
        js_debug(action);
        if(!action.path){
            App.applicationAlert('action without path!');
            return;   
        }
        var path = action.path;
        var aColumns = this.content.columns;                
        for(i=0;i<aColumns.length;i++){
            var col = aColumns[i].sTitle;
            path = path.replace('{'+col+'}',data[i]);
        }
        //js_debug('dynamic path: '+path+ ', target '+action.target);
        action.page = path;
        action.source = this;
        App.handleAction(action);
    },
    
    _getContextMenuCallback: function(columnDef,actions){
        
        var grid_id = this.grid_id;
        var GridView = this;
        
        if(actions.length==1){
            //immediate action "on click"   
            
            var single_action = actions[0];
            if(!single_action){
                App.applicationAlert('no path for grid single action given!', actions[0]);
                return;
            }
            return function (oSettings){
                var DataTable = $('#'+grid_id).dataTable();
                $('tr.gridrow-'+grid_id).click(
                    function(){
                        js_debug("row with single action clicked");
                        var data = DataTable.fnGetData(this);  
                        GridView.doAction(single_action,data);
                    }
                );
                
            }
        }
        
        
        var i,items = {};
        var actionHash = {};
        for(i=0;i<actions.length;i++){
            var action = actions[i];
            items[action.path] = {name:action.label};
            actionHash[action.path] =action;
            if(action.icon){
                items[action.path].icon = action.icon;
            }
        }
        
        return function (oSettings){
                    var DataTable = $('#'+grid_id).dataTable();
                    var columns = columnDef;
                    $.contextMenu({
                    selector: 'tr.gridrow-'+grid_id, 
                    trigger: 'left',
                    callback: function(key, options) {
                        js_debug("menu clicked: " + key);// + " on " + $(this).text());
                        var data = DataTable.fnGetData(this[0]);
                        GridView.doAction(actionHash[key],data);
                    },
                    items: items
                });   
            };
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