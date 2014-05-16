var ajaxErrorAlertTimeout = 0;

var ajaxIgnoreErrors = false;

function ajaxErrorAlert(script_url,textStatus,errDetail){
    if(ajaxIgnoreErrors){
        return;
    }
    //nur so geht das Übermitteln der Parameter im IE
    setTimeout( (function(param){
        return function(){
            alert('ajaxCall: An error occurred while calling '+param.script_url+': status '+param.textStatus + ', detail: '+param.errDetail);
        }
    })({script_url:script_url,textStatus:textStatus,errDetail:errDetail}),
        ajaxErrorAlertTimeout);

    }

    
    function js_debug(data,depth,with_trace){
        var message = _dataToString(data,0,depth);

        if(with_trace){
            var error;

            // When using new Error, we can't do the arguments check for Chrome. Alternatives are welcome
            try { __fail__.fail(); } catch (e) { error = e; }

            if (error.stack) {
                var stack, stackStr = '';
                if (error['arguments']) {
                    // Chrome
                    stack = error.stack.replace(/^\s+at\s+/gm, '').
                    replace(/^([^\(]+?)([\n$])/gm, '{anonymous}($1)$2').
                    replace(/^Object.<anonymous>\s*\(([^\)]+)\)/gm, '{anonymous}($1)').split('\n');
                    stack.shift();
                } else {
                    // Firefox
                    stack = error.stack.replace(/(?:\n@:0)?\s+$/m, '').
                    replace(/^\(/gm, '{anonymous}(').split('\n');
                }

                stackStr = "\n    " + stack.slice(2).join("\n    ");
                message = message + stackStr;
            }
        }

        my_debug(message);
    }

    var iMaxDebugLevel = 1;
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