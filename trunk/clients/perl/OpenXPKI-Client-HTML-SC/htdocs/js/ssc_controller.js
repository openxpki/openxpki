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

function reset_plugin()
{
	var PKCS11Plugin = $('PKCS11Plugin');
	
	try {
		// force an exception if PuginStatus not available
		PKCS11Plugin.StopPlugin();
	} catch (e) {
		//alert('not supported');
	}
}



window.addEvent('domready', function() {
	  
	var baseUrl = document.URL;
	var iOfQuery = baseUrl.indexOf('?');
	
	// handle query string if any
	if (iOfQuery > -1){
		var query   = baseUrl.substring(iOfQuery+1);
		baseUrl     = baseUrl.substring(0,iOfQuery);	
		
		// include firebug light for ie
		if (query === 'db=1' && window.ActiveXObject){
			var firebugJs = new Element('script', {'src' : 'js/firebug-lite.js',
		  									 'type': 'text/javascript'});
			document.getElementsByTagName('head')[0].appendChild(firebugJs);
		}
	   
	}  
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
	
	

});
