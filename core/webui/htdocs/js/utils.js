var ajaxErrorAlertTimeout = 0;

var ajaxIgnoreErrors = false;

function ajaxErrorAlert(script_url,textStatus,errDetail){
    if(ajaxIgnoreErrors){
        return;
    }
    //nur so geht das Übermitteln der Parameter im IE
    setTimeout( (function(param){
<<<<<<< HEAD
        	           return function(){             
        	                    alert('ajaxCall: An error occurred while calling '+param.script_url+': status '+param.textStatus + ', detail: '+param.errDetail);
                           }
        	                    })({script_url:script_url,textStatus:textStatus,errDetail:errDetail}),
             ajaxErrorAlertTimeout);
                                    
}

var iMaxDebugLevel = 1;
function js_debug(data,depth){
    var str = _dataToString(data,0,depth);
    my_debug(str);
}


function _dataToString(data){
    var k;
    var level =  (_dataToString.arguments[1])?_dataToString.arguments[1]:0;
    var depth =  (_dataToString.arguments[2])?_dataToString.arguments[2]:iMaxDebugLevel;
    level++;
    
    var str = '';
    var einrueck='';
    var i;
    for(i=1;i<level*5;i++){
        einrueck+=' ';
    }
    var type = typeof(data);
    if(level <= depth && (type == 'object')){
        for (k in data){
            if(typeof(data[k])!='function'){
               str +=  einrueck+ k+':'+ _dataToString(data[k],level,depth)+"\n"; 
            }  
        }
    }else{
        str = type+':'+data ;    
    }
    return str;
}

function my_debug(str){
    if(window.console && console.log){
        console.log(str);
    }else{
       
        if((typeof(IS_DEVELOPER) != 'undefined' && IS_DEVELOPER) || typeof(APPLICATION_STAGE) != 'undefined' && APPLICATION_STAGE=='LOCAL'){
            alert(str);
        }
    }
}
=======
        return function(){
            alert('ajaxCall: An error occurred while calling '+param.script_url+': status '+param.textStatus + ', detail: '+param.errDetail);
        }
    })({script_url:script_url,textStatus:textStatus,errDetail:errDetail}),
        ajaxErrorAlertTimeout);

    }

    var iMaxDebugLevel = 1;
    function js_debug(data,depth){
        var str = _dataToString(data,0,depth);
        my_debug(str);
    }


    function _dataToString(data){
        var k;
        var level =  (_dataToString.arguments[1])?_dataToString.arguments[1]:0;
        var depth =  (_dataToString.arguments[2])?_dataToString.arguments[2]:iMaxDebugLevel;
        level++;

        var str = '';
        var einrueck='';
        var i;
        for(i=1;i<level*5;i++){
            einrueck+=' ';
        }
        var type = typeof(data);
        if(level <= depth && (type == 'object')){
            for (k in data){
                if(typeof(data[k])!='function'){
                    str +=  einrueck+ k+':'+ _dataToString(data[k],level,depth)+"\n";
                }
            }
        }else{
            str = type+':'+data ;
        }
        return str;
    }

    function my_debug(str){
        if(window.console && console.log){
            console.log(str);
        }else{

            if((typeof(IS_DEVELOPER) != 'undefined' && IS_DEVELOPER) || typeof(APPLICATION_STAGE) != 'undefined' && APPLICATION_STAGE=='LOCAL'){
                alert(str);
            }
        }
    }
>>>>>>> dsiebeck/feature/webui
