/*
 * dbSSC - Smartcard Badge Self Service Center  
 * Frontend Controller for getAuthcode mode 
 *
 * 
 *
 * @package	dbSSC
 * @param  	url  an absolute URL giving the base location of the image
 * @param  	
 * @return       
 * @see          
 */

var testTimeout = 2000;


window.addEvent('domready', function() {
	

	
	// set language depending on language flag
	if (navigator.appName == 'Netscape') var lang = navigator.language.substring(0,2);
	else var lang = navigator.browserLanguage;
	
	// only german and english supported 
	if (lang !== 'de') lang = 'us';

	// determine base URL
	var baseUrl     = document.URL.substring(0,document.URL.indexOf('sso/'));
	//alert(baseUrl);
	// instantiate model
	sscModel = new SSC_MODEL({ 'baseUrl' : baseUrl});
		
	// instantiate view
	sscView   = new SSC_VIEW({'language' : lang ,
							  'mode'     : 'genCode',
		                      'baseUrl'  : baseUrl
		                      });
});