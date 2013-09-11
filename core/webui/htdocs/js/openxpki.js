$(document).ready(function() {
	var pstyle = 'border: 1px solid #dfdfdf; padding: 5px; margin:0;';
	$('#layout').w2layout({
		name: 'layout',
		panels: [
			{ type: 'top', size: 55, style: pstyle, content: '<div id="head"><span>Open Source Trustcenter</span></div>' },
			{ type: 'left', size: 200, style: pstyle, content: 'left' },
			{ type: 'main', style: pstyle, content: 'main' },
		    { type: 'preview', size: '20%', resizable: true, style: pstyle, content: 'preview' },
	        { type: 'right', size: 200, resizable: true, style: pstyle, content: 'right' },
	        { type: 'bottom', size: 50, resizable: true, style: pstyle, content: 'bottom' }
		]
	});
	
	w2ui['layout'].content('left', $().w2sidebar({
		name: 'sidebar',
		img: null,		
		nodes: [ 
			{ id: 'home', text: 'Home', expanded: true, group: true, 
		      nodes: [ 
                { id: 'home-tasks', text: 'My Tasks', img: 'icon-page' },
                { id: 'home-workflows', text: 'My Workflows', img: 'icon-page' },
                { id: 'home-entity', text: 'My Certificates', img: 'icon-page' },			    
			    { id: 'home-keystate', text: 'Key Status', img: 'icon-page' }
			]},
			{ id: 'req', text: 'Request', expanded: true, group: true, 
			  nodes: [ 			                                                                    
                { id: 'req-cert', text: 'Request new certificate', img: 'icon-add' },
				{ id: 'req-renewal', text: 'Request renewal', img: 'icon-reload' },
				{ id: 'req-revoke', text: 'Request revocation', img: 'icon-delete' },					   
				{ id: 'req-crl', text: 'Issue CRL', img: 'icon-save' }
		    ]},
			{ id: 'publish', text: 'Information', img: 'icon-folder', expanded: true, group: true,
			  nodes: [ { id: 'info-cacert', text: 'CA Certificates', img: 'icon-page' },
					   { id: 'info-crl', text: 'Revocation Lists', img: 'icon-page' },
					   { id: 'info-policy', text: 'Policy Documents', img: 'icon-page' }
					 ]
			},	
			{ id: 'search', text: 'Search', img: 'icon-folder', expanded: true, group: true,
				  nodes: [ { id: 'search-cert', text: 'Certificates', img: 'icon-search' },
						   { id: 'search-wfl', text: 'Workflows', img: 'icon-search' },						   
						 ]
			},			
			
		],
		onClick: function (cmd, data) {
			testme();
			//w2ui['layout'].content('main', 'id: ' + cmd);
		}
	}));
	
});

var callMap = {
     'search-cert': 'testme'
};

function testme() {
		
	$().w2layout({
		name: 'inner',
		panels: [
			{ type: 'top', size: 35 },
			{ type: 'main'   },
		]
	});
	
	
	w2ui['layout'].content('main', w2ui['inner']);
	
	w2ui['inner'].content('top', $().w2tabs({
		name: 'tabs',
		active: 'tab1',
		tabs: [
			{ id: 'tab1', caption: 'Your Search' },			
		]
	}));
	
	w2ui['inner'].content('main', '<div id="form"><div class="w2ui-page page-0"> \
	<div class="w2ui-label">Subject:</div> \
	<div class="w2ui-field"> \
	<input name="subject" type="text" maxlength="100" size="60"/> \
	</div> \
	<div class="w2ui-label">Issuer:</div> \
	<div class="w2ui-field"> \
		<input name="issuer" type="text" maxlength="100" size="60"/> \
	</div>	 \
</div> \
			 \
<div class="w2ui-buttons"> \
	<input type="button" value="Reset" name="reset"> \
	<input type="button" value="Search" name="search"> \
			</div></div>');
	
	$('#form').w2form({ 
		name: 'form',
		url: '/cgi-bin/ui.cgi',
		fields: [
		   { name: 'subject', type: 'text' },
		   { name: 'issuer', type: 'text' }
        ],	
		actions: {
			reset: function () {
				this.clear();
			},
			search: function (target, data) {	
				w2ui['tabs'].add({ id:'result', caption:'Search Result' });				
				w2ui['inner'].content('main', $().w2grid({ 
					name: 'cert-grid',	
					columns: [			    
						{ field: 'serial', caption: 'Serial', size: '120px' },
						{ field: 'subject', caption: 'Common Name', size: '40%' },
						{ field: 'email', caption: 'Email address', size: '20%'  },
						{ field: 'notbefore', caption: 'Notbefore Date', size: '120px'  },
						{ field: 'notafter', caption: 'Notafter Date', size: '120px' },
						{ field: 'issuer', caption: 'Issuer', size: '40%' }
					],	
					onClick: function(target, eventData) {
						console.log(target);
					}
				}));	
				w2ui['tabs'].select( 'result' );
				this.save({ 'cmd': 'search-cert'},function(data){  
					console.log( data );
					w2ui['cert-grid'].records = data.records;
					w2ui['cert-grid'].refresh();
				});
				//w2ui['inner'].content('main').load('/cgi-bin/ui.cgi');
			}
		}
	});
	
	
		
}
