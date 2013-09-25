function js_debug(data){
    var str = _dataToString(data);
    my_debug(str);
}
var iMaxDebugLevel = 2;

function _dataToString(data){
    var k;
    var level =  (_dataToString.arguments[1])?_dataToString.arguments[1]:0;
    level++;
    
    var str = '';
    var einrueck='';
    var i;
    for(i=1;i<level*5;i++){
        einrueck+=' ';
    }
    var type = typeof(data);
    if(level < iMaxDebugLevel && (type == 'object' || type=='function')){
        for (k in data){
            str +=  einrueck+ k+':'+ _dataToString(data[k],level)+"\n";   
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