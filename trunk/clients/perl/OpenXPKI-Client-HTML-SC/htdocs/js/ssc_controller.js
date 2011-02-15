/*
 * dbSSC - Smartcard Badge Self Service Center  
 * Frontend Controller
 *
 * 
 *
 *
 * @package	dbSSC
 * @param  	url  an absolute URL giving the base location of the application
 * @param  	db=1 indicates debug mode an firebug light will be loaded
 * @return       the image at the specified URL
 * @see          Image
 */

var testTimeout = 2000;
var sscDebug = false;
var baseUrl = '';

function reset_plugin()
{
	var PKCS11Plugin = $('PKCS11Plugin');
	
	try {
		// force an exception if PuginStatus not available
		//alert('release');
		PKCS11Plugin.StopPlugin();
		
	} catch (e) {
		//alert('not supported');
	}
}


/*
 * dynamic load firebug lite and start initDebug
 */
function initFirebugLite(){
	  //alert('initFirebugLite');
	  var firebug_js = document.createElement('script');
	  firebug_js.setAttribute('type', 'text/javascript');
	  firebug_js.src = 'js/firebug-lite.js';
	  document.getElementsByTagName('head')[0].appendChild(firebug_js);
			  
	  firebug_js.onreadystatechange = function () {
		//alert(firebug_js.readyState);	  
	    if (firebug_js.readyState == 'loaded' || firebug_js.readyState == 'complete') {
	    	
	    	initDebug(true);
	    }
	  }
}

/*
 *   provide window.dbg functions and start processing  
 */
function initDebug(enableDbg){
		var realConsole = window.console || null,
		fn = function(){},
		disabledConsole = {
			log: fn,
			warn: fn,
			info: fn,
			enable: function(quiet){
						window.dbg = realConsole ? realConsole : disabledConsole;
						if (!quiet) { window.dbg.log('dbg enabled.')};
			},
			disable: function(){
				window.dbg = disabledConsole;
			}
		};
	
		if (realConsole) {
			realConsole.disable = disabledConsole.disable;
			realConsole.enable = disabledConsole.enable;
		}
	
		disabledConsole.enable(true);
		startProcessing(enableDbg	);
}

/*
 *  start initialization when dom is ready    
 */
window.addEvent('domready', function() {
	
	baseUrl = document.URL;
	var iOfQuery = baseUrl.indexOf('?');
	
	// handle query string if any
	if (iOfQuery > -1){
		var query   = baseUrl.substring(iOfQuery+1);
		baseUrl     = baseUrl.substring(0,iOfQuery);	
			
		// include firebug light for ie
		if (query.indexOf('dbg') >= 0){
			sscDebug = true;	
			if (window.ActiveXObject)
				// init firebuglite which inits debug which starts processing
				initFirebugLite();
			else
				// init debug which start processing
				initDebug(true);
		}
	}
	
	// initialize empty debug functions to avoid undefines if 
	if (!sscDebug){
	   initDebug(false);
	}
	
	
});


/*
 *   main function - start of processing
 */
function startProcessing(enableDbg){
	
	if (enableDbg	){
		window.dbg.enable();	
	} else {
		window.dbg.disable();	
	}
	window.dbg.log('firebug lite is up and running');
	window.dbg.info('firebug lite info test call');
	window.dbg.warn('firebug lite warn test call');
	
	//eleminate index.html if any
	var pos = baseUrl.lastIndexOf('/index.html');
	if (pos >= 0){baseUrl = baseUrl.substring(0, pos) + '/';}
	//alert(baseUrl);

	// set language depending on language flag
	if (navigator.appName == 'Netscape') var lang = navigator.language.substring(0,2);
	else var lang = navigator.browserLanguage;
	// only german and english supported 
	if (lang !== 'de') lang = 'us';

		
	// instantiate model
	sscModel = new SSC_MODEL({ 'baseUrl' :  baseUrl});
		
	// instantiate view
	sscView   = new SSC_VIEW({'language' : lang , 'baseUrl' : baseUrl});
}