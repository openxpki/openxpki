/*
 * dbSSC - Smartcard Badge Self Service Center
 *   
 * Frontend Helper
 *
 *
 * @package	dbSSC
 * @param  	url  an absolute URL giving the base location of the image
 * @param  	name the location of the image, relative to the url argument
 * @return       the image at the specified URL
 * @see          Image
 */

var SSC_HELPER = new Class({
	
	initialize: function()
	{
	    
	},
	
	/*
	 * helper function to log to firebug console
	 */
	//log: function (content)	{ return; }
	
	log: function (content)
	{
		
		// is firebug or firebug lite active?  
		if ( window.console !== undefined &&
		    console instanceof Object &&
			console.log &&
			typeof console.log === 'function'){
			
			// yes -> write to console log
			console.log (content);
			
			}
	}
	
	
});