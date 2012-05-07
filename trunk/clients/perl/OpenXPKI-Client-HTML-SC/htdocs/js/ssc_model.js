/*
 * dbSSC - Smartcard Badge Self Service Center
 *   
 * ssc model
 *
 *
 * @package	dbSSC
 * @param  	 
 * @param  	 
 * @return        
 *         
 */

var SSC_MODEL = new Class(
		{
			Implements : [ Options ],
			Binds : [ 'init_env', 'sc_run_command', 'sc_cb_run_command',
					'server_getCardStatus', 'sc_getCertificates',
					'sc_changePIN', 'sc_cb_changePIN', 'processAuthCodes',
					'processPins', 'server_cb_pinreset_verify',
					'sc_cb_login_changePIN', 'sc_cb_resetpin',
					'server_cb_cardstatus', 'server_pinrest_verify',
					'server_cb_pinreset_confirm',
					'server_personalization_loop', 'sc_installRND_pin',
					'server_cb_start_resetpin', 'sc_start_personalization',
					'sc_installPUK', 'sc_cb_installPUK', 'sc_DeleteUserData',
					'sc_cb_DeleteUserData', 'sc_cb_installRND_pin',
					'sc_cb_GenerateKeypair', 'sc_GenerateKeypair',
					'sc_cb_persoSendCardStatus', 'determineRequiredAction',
					'sc_cb_installx509', 'sc_cb_importP12', 'sc_resetToken',
					'sc_cb_resetToken', 'sc_GetTokenID' , 'sc_cb_GetTokenID' , 
					'cb_server_get_status','sc_getCardList', 'server_get_status' , 'sc_checkCardPresence'],

			options : {
				baseUrl : '/'
			},

			initialize : function(options) {

				window.dbg.log(
						'sscModel initialize at ' + new Date().format("db"));
				// get options
				this.setOptions(options);
				this.init_env();


			},
			
			init_env: function (){
				//
				// change plugin classid here
				//
				this.plgIn_classId = "clsid:71BC7410-4214-4943-9C63-4A6C7A77CBB1";
				this.puk_pin_encryption = 'yes';
				this.cardReadCounter = 0;
				this.PKCS11Plugin = $('PKCS11Plugin');
				this.cardID = null;
				this.cardType = null;
				this.StdCardType = "Gemalto .NET";
				this.pinResetRetry = null;
				this.serverPUK = null;
				this.serverPIN = null;
				this.state = null;
				this.rnd_pin_installed = 0;
				this.new_puk_installed = 0;
				this.perso_wfID;
				this.unblock_wfID;
				this.userPIN = null;
				this.maxrequests = 0;
				this.user = {};
				this.user.cardholder_surname = null;
				this.user.cardholder_givenname = null;
				this.user.entity = null;
				this.user.accounts = null;
				this.user.parsedCerts = null;
				this.user.workflows = null;
				this.user.cardstatus = null;
				this.user.firstTimePerso = true;
				this.user.cardActivation = true;
				this.user.authEmail1 = 'Auth Person 2';
				this.user.authEmail2 = 'Auth Person 1';
				this.overAllStatus = null;
				this.resetTokenRSA = 0;
				this.resetToken = false;
				this.keysize = 2048;
				this.newUserPin = null;
				this.selectedAccount = null;
				this.reCert = false;
				this.stateFilter = new Array();
				this.stateFilter[0]= 'PEND_PIN_CHANGE';
				this.stateFilter[1]= 'PEND_ACT_CODE';
				this.stateFilter[2]= 'PUK_TO_INSTALL';
				this.stateFilter[3]= 'NEED_NON_ESCROW_CSR';
				this.stateFilter[4]= 'CERT_TO_INSTALL';
				this.stateFilter[5]= 'PKCS12_TO_INSTALL';
				this.stateFilter[6]= 'HAVE_CERT_TO_DELETE';
				this.stateFilter[7]= 'HAVE_TOKEN_OWNER';
				//this.stateFilter[8]= 'CAN_WRITE_PIN';
				this.stateFilter[8]= 'ISSUE_CERT';
				this.stateFilter[9]= 'HAVE_CERT_TO_PUBLISH';
				this.stateFilter[10]= 'HAVE_CERT_TO_UNPUBLISH';
				this.ECDH = null;
				this.allowOutlook = false;
				this.outlook = {};
				this.outlook.displayname = null;
				this.outlook.b64 = null;
				this.outlook.issuerCN = null;
				
				//this.stateFilter[8]= 'NON_ESCROW_CSR_AVAIL';
				// test json
				
				this.test = false;
			},

			initializeCardReaderPlugin : function(cb) {

				var rc = true;

				window.dbg.log("initializeCardReaderPlugin(begin)");

				if (!window.ActiveXObject) {

					// sscView.setStatusMsg('E_wrongBrowser','P_ContactAdmin',
					// 'red');
					sscView.showPopUp('E_wrongBrowser', 'cross', '0001');
					rc = false;
					this.ajax_log('missing activeX plugin','warn');

				} else {
					
					// define plugin
					var plugincode = '<object id="PKCS11Plugin"'
							+ 'width="0" height="0"'
							+ 'classid= '+ this.plgIn_classId +'>'
						//	+ 'codebase="dbSignedPKCS11_v1212.cab#Version=1,2,1,4">'
							+ '<param name="UseJavaScript" value="1">'
							//+ 'Missing DBSMARTCARD PLUGIN v1.3. '
							//+ 'Please install via Automatic Software Distribution(ASD) or contact your local help desk.'
							+ '</object>';
					// and inject it to start activation
				 	$("pluginDiv").innerHTML = plugincode;

					window.dbg.log("plugin element injected");
					
					// test on plugin
					this.PKCS11Plugin = $('PKCS11Plugin');
					// check for funtion GetCardList, should return unknown if plugin is loaded, otherwise undefined
					if (typeof this.PKCS11Plugin.GetCardList === 'undefined'){
						sscView.showPopUp('E_ax-failure', 'cross', '0001');
						rc = false;
						
					} else if (this.PKCS11Plugin === null || this.PKCS11Plugin === 0) {
						// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
						// 'red');
						sscView.showPopUp('E_ax-plugin-double', 'cross', '0002');
						rc = false;
						this.ajax_log('E_ax-plugin-double','error');
					}
					
				}

				window.dbg.log("initializeCardReaderPlugin(end), available: " + rc);
				cb(rc);
			},

			readCard : function(cardId, viewCb) {

				window.dbg.log("readCard - " + cardId);

				var SCPlugin = document.getElementById("PKCS11Plugin");
				var pluginDHValue;
				
				sscView.setStatusMsg('I_commSc', "P_pleaseWait", "blue");
				var result = SCPlugin.SelectCard(cardId, pluginDHValue);
				sscView.setStatusMsg("T_idle", ' ', 'idle');
				
				var res = new Querystring(result);
				
				var set = res.get("Result");
				// alert("sc_cb_delete_cert:"+ res);
				var reason = res.get("Reason");
				
				window.dbg.log("Result ="+ set +"-"+reason);
				
				if (set == "SUCCESS") {
						
					this.ECDH = res.get("ECDHPubkey");
					
					this.cardID = cardId; 
					window.dbg.log("readCard set cardID- " + this.cardID);
					
					this.cardType = res.get("CardType");
					
					this.sc_getCertificates(this.server_getCardStatus ,  viewCb);
					
				}else{
					
					window.dbg.log("reason " + reason + ' '+ res);
					this.ajax_log('error selecting card: '+res, 'error');
									
					sscView.showPopUp('E_sc-error-select-card ',
							'cross', '1000');
					viewCb('error');
					
					
					return;
	
				}
				
				
		


			},
			
			server_get_status : function(viewCb) {

				window.dbg.log('get server status ');
				
				if(this.test === true)
					{	
						window.dbg.log("server_get_status:  skip server status ");
						//var testData = "{\"cardID\":null,\"loadavg 1 min\":\"0.14\",\"pslist\":\"4\",\"id_cardID\":null,\"get_server_status\":\"Server OK\",\"log4perl init\":\"YES\",\"logs reached: \":3,\"is initialized log4perl: \":1,\"loadavg\":\"0.14 0.06 0.01 1/275 20399\n\",\"cardtype\":null,\"loadavg 15 min\":\"0.01\",\"loadavg 5 min\":\"0.06\"}"; 
						//var data = JSON.decode(testData);
						//alert( testData.pslist );
						viewCb('ok'); 
						//this.cb_server_get_status(null,viewCb);	
					}else{
						window.dbg.log("server_get_status:  call server status ");
						
						this.ajax_request("functions/utilities/get_server_status",
								  '', 
								  this.cb_server_get_status,
								  viewCb);		
						
					}
		
			},
			
			cb_server_get_status : function(data, viewCb) {

				window.dbg.log('get server status cb');
				sscView.setStatusMsg("T_idle", ' ', 'idle');
				window.dbg.log(data);

				window.dbg.log('skip since there is no criteria avaiable at the moment');
				viewCb('ok'); 				
				//window.dbg.log('list:' + data.pslist );
	//			if (data.pslist >= 5 )
	//				{
	//					viewCb('serverbusy');
	//					this.PKCS11Plugin.StopPlugin();
	//				}else{
	//					this.sc_getCardList(viewCb);
	//				}
			},
			
			sc_getCardList : function(viewCb) {
				
				var timeout = 500;

				window.dbg.log('sscModel.sc_getCardList');
				if(this.test === true){	
					// note: delimiter ; of card list elements should only be used if there are more than one card reader
					//viewCb('Result=SUCCESS&CardList=Cherry SmartTerminal XX44 0|Gemalto .NET|0.0.0.0|68F461BB875E797A|000000000000000000000000|Matthias Kraft;'); return;
					viewCb('Result=SUCCESS&CardList=Cherry SmartTerminal XX44 0|Gemalto .NET|0.0.0.0|68F461BB875E797A|000000000000000000000000|Matthias Kraft;My second CardReader XX55 1|Gemalto .NET|0.0.0.0|999666-BBCCDD|000000000000000000000000|Matthias Kraft'); return;
				}
				// fs fixme
				sscView.setStatusMsg('I_commSc', "P_pleaseWait", "blue");
				var r = this.PKCS11Plugin.GetCardList();
				
				
				var res = new Querystring(r);
				var cardlist = res.get("CardList");
				//alert(cardlist);
				if(res.get("Result") === 'SUCCESS' )
				{
					window.dbg.log('sscModel.sc_getCardList r=' + r);
					if(cardlist === "no cards present;" )
					{
						setTimeout(function() {
							this.sc_getCardList(viewCb);
						}.bind(this), timeout);
					
					}else{
						
						sscView.setStatusMsg("T_idle", ' ', 'idle');
						viewCb(r);
					}
					
				}else{
					window.dbg.log('get card list r=' +  r );
					
					if(res.get("Result") === 'ERROR' && res.get("Reason") === 'SCARD_E_NO_SERVICE'  )
						{
						sscView.setStatusMsg("T_idle", ' ', 'idle');
						window.dbg.log('Error Reson: ' + res.get("Reason"));
						sscView.showPopUp('E_IE-Error_Protected', 'cross',
								'0001');
						viewCb('error');
						this.ajax_log('E_IE-Error_Protected', 'warn');
						}
					
				}
				
			},


			personalizeAccount : function(account, cb) {

				window.dbg.log('sscModel.personalizeAccount');
				// fs fixme

				// callback
				cb();

			},
			
			configureOutlook : function(cb) {

				window.dbg.log('sscModel.configureOutlook');
				// fs fixme
				window.dbg.log(this.cardID + " "+ this.outlook.displayname+ " "+  this.outlook.b64+ " "+  this.outlook.issuerCN);
				var result = this.PKCS11Plugin.ConfigureOutlook( this.cardID, this.outlook.displayname, this.outlook.b64, this.outlook.issuerCN);
				window.dbg.log('sscModel.configureOutlook' + result);
				// callback
				cb(result);

			},

			processAuthPersons : function(authPerson1, authPerson2, cb) {

				window.dbg.log('sscModel.processAuthPersons');
				this.server_start_resetpin(authPerson1, authPerson2, cb);
				// cb();
			},

			processAuthCodes : function(pin, authcode1, authcode2,cb) {

				window.dbg.log('sscModel.processAuthCodes');
				
				if(this.pinResetRetry === null ){
					window.dbg.log('sscModel.processAuthCodes verify authcodes');
					this.server_pinrest_verify(pin, authcode1, authcode2, cb);
				}else{
					window.dbg.log('sscModel.processAuthCodes invalid PIN retry ' + this.pinResetRetry );
					sscView.setStatusMsg('I_commSc', "P_pleaseWait", "blue");
					
					var r = this.PKCS11Plugin.SimonSays(data.exec,true,"",this.userPIN);
					sscView.setStatusMsg("T_idle", ' ', 'idle');
					
					var results = new Querystring(r);
					window.dbg.log("SimanSays Res:"+r);

					var set = results.get("Result");
					
					//alert("Res:"+ r);
					if (set == "SUCCESS") {
						pinSetCount = 0;

						var reqData = "unblock_wfID=" + this.unblock_wfID + "&"
								+ res;
						var server_cb = this.server_cb_pinreset_confirm;
						var targetURL = "functions/pinreset/pinreset_confirm";

						this.ajax_request(targetURL,  reqData,  server_cb, viewCb);
						// this.ajax_request("sc/functions/pinreset/pinreset_confirm",server_cb_pinreset_confirm,
						// res );

					} else if (set == "ERROR") {
						this.pinSetCount++;
						
						// alert("ERROR Pinsetcount="+pinSetCount);
						
						var reason = results.get("Reason");
						window.dbg.log("reason " + reason + ' ' + res);

						if (reason === 'PUKError') {
							sscView.showPopUp('E_sc-error-resetpin-puk-error ',
									'cross', '0113');
							viewCb('error');
							this.ajax_log('processAuthCodes: '+r, 'error');
							return;
						} else if (reason === 'TokenInternalError') {
							// Invalid PIN is an user Error no popup here
							window.dbg.log("invalid pin" + reason);
							this.ajax_log('processAuthCodes: '+r, 'error');
							viewCb('invalidPin');
							return;
						}
					
					}
				}
				
				// callback
				// cb();
			},

			processPins : function(userpin, newpin, morepin, viewCb) {
				window.dbg.log("viewCb" + viewCb);
				window.dbg.log('sscModel.processPins');
				// this.server_cb_pinreset_verify(authcode1,authcode2,pin,cb);
				this.newUserPin = newpin;
				this.userPin = userpin;
				
				sscView.setStatusMsg('I_commSc', "P_pleaseWait", "blue");
				var res = this.PKCS11Plugin.ChangePIN(this.cardID,userpin, newpin);
				sscView.setStatusMsg("T_idle", ' ', 'idle');
				
				var results = new Querystring(res);

				var set = results.get("Result");

				//~ if(set)
				//~ {
				//~ set.trim();
				//~ }
				//window.dbg.log(res + this.PKCS11Plugin.PluginStatus);
				if (set === "SUCCESS") {
					viewCb('success');

					//popup( "PIN changed successfully. <br> Your PIN has been changed please use the new PIN from now on to access your smartcard." , "info", function () { 
					//});
				} else if (set === "ERROR") {
					var reason = results.get("Reason");
					window.dbg.log("Error: " + reason);

					if (reason == 'TokenInternalError') {
						viewCb('newPinError');
						return;
					} else if (reason == 'PINLockedError') {
						viewCb('cardBlocked');
						return;
					} else {
						viewCb('pinError');
						return;
					}
				}
				return;

				// cb();
			},

			
			sc_getCertificates : function(cb, viewCb) {
				
			//reset TestTokens ONLY with predefined PUK
	
				if (this.resetToken){
					window.dbg.log("reset testToken");

						this.sc_resetTestToken(this.cardID,viewCb);
					return;		
				}
				
				//var p = this.PKCS11Plugin.CheckCardPresence(this.cardID);
				//window.dbg.log("card preasent? = "+ p);
				
				window.dbg.log("sc_getCertificates");
				var certList= "";

				sscView.setStatusMsg('I_commSc', "P_pleaseWait", "blue");
				var r = $('PKCS11Plugin').GetCertificates(this.cardID, certList);
				sscView.setStatusMsg("T_idle", ' ', 'idle');
								
				var results = new Querystring(r);
				var set = results.get("Result");

				window.dbg.log(r);
				if (set === "SUCCESS") {
					
					cb(r, viewCb);
	
				} else {
					this.ajax_log('sc_getCertificates: '+r, 'error');
				}
				
				
				
				
			},
			
			sc_test_card: function(pin, viewCb) {

				window.dbg.log("sc_test_card"+ this.cardID);
				this.userPIN = pin; 
				
				var r;
				if(this.test === true)
				{
					 //test DATA Test Result anythign but PASS is a FAIL. 
			
				   r = "Result=SUCCESS&CardType=Gemalto .NET&TokenID=838AD0AE3B7A8090&Test=299e9554bf630e376dd14e10c04adb5e7b3b5b3a|PASS;299e9554bf6530e376dd14e10c04adb5e7b3b5b3a|FAIL;299e9554bf6530e376dd14e10c04adb5e7b3b5b3a|PRIVKEYFAULTY;299e9554bf6530e376dd14e10c04adb5e7b3b5b3a|PUBKEYFAULTY;299e9554bf6530e376dd14e10c04adb5e7b3b5b3a|NOPUBKEY;";
				
				}else {
					sscView.setStatusMsg('I_commSc', "P_pleaseWait", "blue");
					r = this.PKCS11Plugin.TestAllKeypairs(this.cardID,pin);
					sscView.setStatusMsg("T_idle", ' ', 'idle');	
		
					this.ajax_log('processAuthCodes: '+r, 'error');
				}				
				
				window.dbg.log("sc_test_all_keypairs: "+ r);
				viewCb(r);
	
			},
			

			server_getCardStatus : function(reqData, viewCb) {
				
				var rc = true;
					window.dbg.log("sc_cb_getCardStatus");
					//var reqData;
					/* try {
						this.cardID = this.PKCS11Plugin.TokenID;
						reqData = this.PKCS11Plugin.Data;
						// var results = new Querystring(reqData);
						window.dbg.log("ID"+this.PKCS11Plugin.TokenID+" Data:"+reqData);
					} catch (e) {
						// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
						// 'red');
						sscView.showPopUp('E_ax-failure-reading-certificates',
								'cross', '0100');
						window.dbg.log("error reading certificates");
						rc = false;
					}
					
					if(this.PKCS11Plugin.TokenID === '' || this.PKCS11Plugin.TokenID === undefined || reqData === null || reqData === '')
					{
						window.dbg.log("sc_cb_getCardStatus - empty results retry after pluginreset");
						
						//this.PKCS11Plugin.ResetPlugin();
						
						this.sc_getCertificates(this.sc_cb_getCardStatus, viewCb);
						
						rc = false;
											
					*/	
					sscView.setStatusMsg("T_idle", ' ', 'idle');

					reqData = reqData+"&ECDHPubkey="+$.URLEncode(this.ECDH);
					window.dbg.log("sc_cb_getCardStatus reqData:"+reqData);
					if (rc) {
	
						var server_cb = this.server_cb_cardstatus;
						var targetURL = "functions/utilities/get_card_status";
						this.ajax_request(targetURL,  reqData,  server_cb, viewCb);
					}
					/*
					if (rc) {
						window.dbg.log("sc_cb_getCardStatus - call server status ");
					this.server_get_status(viewCb, reqData);
					}*/

			},

			
			
			test_status : function(viewCb) {

				this.server_cb_cardstatus(this.status, viewCb);
			},

			server_cb_cardstatus : function(data, viewCb) {
				sscView.setStatusMsg("T_idle", ' ', 'idle');
				window.dbg.log("server_cb_cardstatus");
				
				var rc = true;

				try {
					var err = data.error;
				} catch (e) {
					// sscView.setStatusMsg('T_Server_Error','P_ContactAdmin','red');
					sscView.showPopUp('T_Server_Error', 'cross', '0200');
					viewCb('error');
					window.dbg.log('server error');
					this.ajax_log('server_cb_cardstatus invalid data', 'error');
					rc = false;
					// sscView.showPopUp('T_Server_Error'+error ,'critical');
				}
				
				var r ;

				if (rc && data.error !== 'error') {
					
					try {
						window.dbg.log(this.cardId+ " set pubkey"+ data.ecdhpubkey + "\n" );
						window.dbg.log("data.cardid : " + data.cardID);
						this.cardId = data.cardID;
						var ecdhpub = data.ecdhpubkey;
						r = this.PKCS11Plugin.SetRemoteDH(this.cardId, ecdhpub);
						window.dbg.log("set pubkey res:"+r);
						var results = new Querystring(r);
						var set = results.get("Result");

						window.dbg.log(r);
						if (set === "SUCCESS") {
							window.dbg.log("ecdh set call cb:"+r);
							cb(data, viewCb);
			
						} else {
							sscView.showPopUp('E-Error-accessing-smartcard', 'cross', '0300');
							this.ajax_log('sc_getCertificates: '+r, 'error');
						}
						
						
						
					} catch (e) {
						// sscView.setStatusMsg('T_Server_Error','P_ContactAdmin','red');
						//sscView.showPopUp('T_Server_Error_missing_pubkey', 'cross', '0200');
						//viewCb('error');
						window.dbg.log('server error'+ e);
						//this.ajax_log('server_cb_cardstatus missing pubkey '+ r, 'error');
						rc = false;
						// sscView.showPopUp('T_Server_Error'+error ,'critical');
					}
					
					var cardStatus;
					var cardholder_surname;
					var cardholder_givenname;
					var entity;
					try {
						// window.dbg.log

						this.user.cardholder_surname = data.msg.PARAMS.SMARTCARD.assigned_to.sn;
						this.user.cardholder_givenname = data.msg.PARAMS.SMARTCARD.assigned_to.givenname;
						this.user.entity = data.msg.PARAMS.SMARTCARD.assigned_to.dblegalentity;
						
						if(this.user.entity === 'undefined')this.user.entity = '';
						this.user.accounts = data.msg.PARAMS.SMARTCARD.assigned_to.dbntloginid;
						this.keysize = data.msg.PARAMS.SMARTCARD.keysize;
						this.user.parsedCerts = data.msg.PARAMS.PARSED_CERTS;
						window.dbg.log("parsed certs:"+ this.user.parsedCerts);
						this.user.workflows = data.userWF;
						this.user.cardstatus = data.msg.PARAMS.SMARTCARD.status;
						this.overAllStatus = data.msg.PARAMS.OVERALL_STATUS;
						this.resetTokenRSA = data.msg.PARAMS.PROCESS_FLAGS.purge_token_before_unblock; 
						window.dbg.log('resetToken: ' + this.resetTokenRSA);
						this.cardType = data.cardtype;
						this.outlook.displayname = data.outlook_displayname;
						this.outlook.b64 = data.outlook_b64;
						this.outlook.issuerCN = data.outlook_issuerCN;
					} catch (e) {
						// JSON SERVER ERROR OR PKI ERROR
						sscView.showPopUp('E_ajax_backend-Error-status',
								'cross', '0201');
						window.dbg.log('Error fetching user data');
					}
					try{
						for (i = 0; i < this.user.parsedCerts.length; i++) {

							// determine cert type
							if (this.user.parsedCerts[i].CERTIFICATE_TYPE === 'nonescrow') {
								// FAKE UPN STATUS FIXME
								
								if (this.user.accounts.length > 1) {
									this.user.parsedCerts[i].SUBJECT_UPN = this.user.cardholder_givenname
											+ ' ' + this.user.cardholder_surname;
								} else {
									this.user.parsedCerts[i].SUBJECT_UPN = this.user.accounts[0];
								}

							}
						}// END FOR
					}catch(e){
						
					}
					this.determineRequiredAction(viewCb, data);

				} else {
					var error;
					// for(var i=0; i < data.errors.length ; i++) { error +=
					// '<br>' + data.errors[i] ; }
					// I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_GET_CARD_STATUS
					try {
						for ( var i = 0; i < data.errors.length; i++) {
							
							if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CARDID_NOTACCEPTED') {
								window.dbg.log('Error ' + i + ' ' + data.errors[i]);
								//sscView.showPopUp('E_card_id_error', 'cross',	'0222');
								var PKCS11Plugin = $('PKCS11Plugin');
								
								try {
									// force an exception if PuginStatus not available
									//PKCS11Plugin.StopPlugin();
								} catch (e) {
									//alert('not supported');
								}
								//setTimeout(window.location.reload(),2000);
								window.dbg.log('card change read card again after server has reset HTTP session' + data.cardID );
								this.init_env();
								this.cardID = data.cardID;
								sscView.insertCard(data.cardID);
								
								//viewCb('error');
							}else if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER') {
								window.dbg.log('Error ' + i + ' ' + data.errors[i]);
								sscView.showPopUp('E_card_id_error', 'cross',
										'0222');
								var PKCS11Plugin = $('PKCS11Plugin');
								this.ajax_log('I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER', 'error');
								try {
									// force an exception if PuginStatus not available
									//PKCS11Plugin.StopPlugin();
								} catch (e) {
									//alert('not supported');
								}
								//setTimeout(window.location.reload(),2000);
								
								
								viewCb('error');
							}else if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI') {
								window.dbg.log('Error ' + i + ' ' + data.errors[i]);
								sscView.showPopUp('E_pki_offline', 'cross',
										'0222');
								this.ajax_log( data.errors[i], 'error');
								viewCb('error');
							}
							else {
								window.dbg.log('Error ' + i + ' ' + data.errors[i]);
								sscView.showPopUp('E_backend-Error', 'cross',
										'0200');
								this.ajax_log( data.errors[i], 'error');
								viewCb('error');
							}
						}
					} catch (e) {
					}

					//sscView.showPopUp('E_backend-Error', 'cross', '0200');
				}
			},

			getUserInfo : function() {
				return this.user;
			},

			getOverAllStatus : function() {
				return this.overAllStatus;
			},

			getReCert : function() {
				return this.reCert;
			},

			determineRequiredAction : function(viewCb, data) {
				window.dbg.log("determineRequiredAction");
				var ret = 0;
				var pos = baseUrl.lastIndexOf('/sc/');
				
				sscView.startCardObserver();

				switch (this.user.cardstatus) {
				case 'unknown':
					// ERROR Card not registered please contact badge office
					// sscView.showPopUp('E_unknownSmartcard','cross','0010');
					viewCb('cardUnknown');
					
//					if(data.cardtype === 'RSA_2.0'){
//						window.location = this.options.baseUrl.substring(0, pos)+'/appsso';
//					}
					return;
					break;
				case 'initial':
					// ERROR Card not activated please contact badge office
					// sscView.showPopUp('E_cardNotActivated','cross','0020');
					viewCb('cardNotActivated');
					
					return;
					break;
				case 'deactivated':
					// ERROR MSG Card Blocked Contact Badge Office
					// sscView.showPopUp('E_cardBlocked','cross','0030');
					viewCb('cardBlocked');
					return;
					break;
				case 'activated':
					ret = 0;
					break;
				}
				
				var numWf = null;
				try {
					numWf = this.user.workflows.length;
					window.dbg.log('fetching user WFs ' + this.user.workflows.length);

				} catch (e) {
					window.dbg.log('error fetching Perso WF count');
				}

				var activePersoWf = null;
				var activeUnblockWf = null;
				var lastSuccessPersoWf = null;
				var lastSuccessUnblockWf = null;

				if (numWf > 0) {
					window.dbg.log('found WFs');
					for ( var i = 0; i < numWf; i++) {
						window.dbg.log('-------fetching user wf-------');
						window.dbg.log('wf serial'
								+ this.user.workflows[i].WORKFLOW_SERIAL);
						window.dbg.log('wf type'
								+ this.user.workflows[i].WORKFLOW_TYPE);
						window.dbg.log('wf state'
								+ this.user.workflows[i].WORKFLOW_STATE);
						window.dbg.log('wf last update'
								+ this.user.workflows[i].WORKFLOW_LAST_UPDATE);
						window.dbg.log('wf last update epoch'
								+ this.user.workflows[i].LAST_UPDATE_EPOCH);
						
						if (this.user.workflows[i].WORKFLOW_TYPE === 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION_V4') {
		
								if (this.user.workflows[i].WORKFLOW_STATE !== 'SUCCESS'
										&& this.user.workflows[i].WORKFLOW_STATE !== 'FAILURE') {
									
									//filter workflows that has been started with a differnt cardID
									window.dbg.log(this.user.workflows[i].TOKEN_ID+' == '+ data.id_cardID);
									if(this.user.workflows[i].TOKEN_ID === data.id_cardID){
									
										if (activePersoWf === null) {
											activePersoWf = this.user.workflows[i];
											window.dbg.log('fetch activePersoWf');
										} else if (this.user.workflows[i].LAST_UPDATE_EPOCH > activePersoWf.LAST_UPDATE_EPOCH) {
											activePersoWf = this.user.workflows[i];
											window.dbg.log('fetch newer activePersoWf');
										}
									}
								}
								if ((lastSuccessPersoWf === null || lastSuccessPersoWf.LAST_UPDATE_EPOCH < this.user.workflows[i].LAST_UPDATE_EPOCH)
										&& (this.user.workflows[i].WORKFLOW_STATE === 'SUCCESS')) {
									window.dbg.log('fetched lastSuccessPersoWf '
													+ this.user.workflows[i].LAST_UPDATE_EPOCH);
									lastSuccessPersoWf = this.user.workflows[i];
								}
								
							
						}
						if (this.user.workflows[i].WORKFLOW_TYPE === 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK') {
							if (this.user.workflows[i].WORKFLOW_STATE !== 'SUCCESS'
									&& this.user.workflows[i].WORKFLOW_STATE !== 'FAILURE') {
								
								//filter workflows that has been started with a differnt cardID
								if(this.user.workflows[i].TOKEN_ID === data.id_cardID){
									if (activeUnblockWf === null) {
										activeUnblockWf = this.user.workflows[i];
										//this.unblock_wfID = activeUnblockWf.WORKFLOW_SERIAL;
										window.dbg.log('fetch activeUnblockWf');
									} else if (this.user.workflows[i].LAST_UPDATE_EPOCH > activeUnblockWf.LAST_UPDATE_EPOCH) {
										activeUnblockWf = this.user.workflows[i];
										//this.unblock_wfID = activeUnblockWf.WORKFLOW_SERIAL;
										window.dbg.log('fetch newer activeUnblockWf');
									}
								}else{
									window.dbg.log('cardID does not match WF token_id '+this.user.workflows[i].TOKEN_ID+" != "+data.id_cardID);
								}
							}

							if ((lastSuccessUnblockWf === null || lastSuccessUnblockWf.LAST_UPDATE_EPOCH < this.user.workflows[i].LAST_UPDATE_EPOCH)
									&& (this.user.workflows[i].WORKFLOW_STATE === 'SUCCESS')) {
								window.dbg.log('fetched lastSuccessUnblockWf '
												+ this.user.workflows[i].LAST_UPDATE_EPOCH);
								lastSuccessUnblockWf = this.user.workflows[i];
							}

						}

					}//end for
				}
				window.dbg.log('determine correct action call view');
				if(activeUnblockWf !== null){
					var validWorkflow = activeUnblockWf;
					activeUnblockWf = null;
					
					for(var i=0; i < this.stateFilter.length ; i++)
					{
						if(this.stateFilter[i] === validWorkflow.WORKFLOW_STATE)
						{
							window.dbg.log('valid unblockWf state found '+ validWorkflow.WORKFLOW_STATE);
							activeUnblockWf = validWorkflow;
							validWorkflow = null;
							this.unblock_wfID = activeUnblockWf.WORKFLOW_SERIAL;
							this.user.authEmail1 = activeUnblockWf.email_ldap1;
							this.user.authEmail2 = activeUnblockWf.email_ldap2;
							break;
						}
					}
					
					if(validWorkflow !== null)
					{
						window.dbg.log('invalid unblockWf state found '+ validWorkflow.WORKFLOW_STATE);
					}
					
				}
				if(activePersoWf !== null){
					var validWorkflow = activePersoWf;
					activePersoWf = null;
					
					for(var i=0; i < this.stateFilter.length ; i++)
					{
						if(this.stateFilter[i] === validWorkflow.WORKFLOW_STATE)
						{
							window.dbg.log('valid persoWf state found '+ validWorkflow.WORKFLOW_STATE);
							activePersoWf = validWorkflow;
							validWorkflow = null;
							this.perso_wfID = activePersoWf.WORKFLOW_SERIAL;
							break;
						}
					}
					
					if(validWorkflow !== null)
					{
						window.dbg.log('invalid persoWf state found '+ validWorkflow.WORKFLOW_STATE);
						
					}
					
				}

				if (lastSuccessPersoWf !== null) {
					this.user.firstTimePerso = false;
					window.dbg.log('firstTimePerso'+ this.user.firstTimePerso);
				}
				if (lastSuccessUnblockWf !== null && lastSuccessPersoWf !== null && lastSuccessUnblockWf.LAST_UPDATE_EPOCH > lastSuccessPersoWf.LAST_UPDATE_EPOCH ) {
					this.user.cardActivation = false;
					window.dbg.log('cardActivation false');
				}

				
				// sscView.setTopMenu(true);
				window.dbg.log('overall state:'+this.overAllStatus);
				window.dbg.log('CardType :'+data.cardtype );
				
				if(data.cardtype === 'RSA_2.0'){
					
					this.user.cardActivation = true;
					if(this.resetTokenRSA === '1' )
					{
						window.dbg.log('enable reset RSA Token :'+this.resetTokenRSA ) ;
					}	
						
					if (activeUnblockWf !== null) {
						if (activeUnblockWf !== null) {
							window.dbg.log('continue unblock - active wf found id:'
									+ activeUnblockWf.WORKFLOW_SERIAL);
							//this.user.cardActivation = true;
							this.overAllStatus = 'red';
							//this.unblock_wfID = activeUnblockWf.WORKFLOW_SERIAL;
							if (activeUnblockWf.WORKFLOW_STATE === 'PEND_ACT_CODE'
									|| activeUnblockWf.WORKFLOW_STATE === 'PEND_PIN_CHANGE') {
								viewCb('enterAuthcodes');
							} else {
								viewCb('enterAuthPersons');
							}
						}
					}else{
						viewCb('enterAuthPersons');
					}
					return;
					
				}
			



				if (this.overAllStatus === 'green') {
					this.user.firstTimePerso = false;
					if (activePersoWf !== null) {
						window.dbg.log('continue Personalization -active wf found id:'
								+ activePersoWf.WORKFLOW_SERIAL);
						//this.perso_wfID = activePersoWf.WORKFLOW_SERIAL;
						this.overAllStatus = 'red';
						this.reCert = true;
						viewCb('contPerso');
						return;
					}else{ 

						if (activeUnblockWf !== null) {
							window.dbg.log('continue unblock - active wf found id:'
									+ activeUnblockWf.WORKFLOW_SERIAL);
							//this.user.cardActivation = true;
							this.overAllStatus = 'red';
							//this.unblock_wfID = activeUnblockWf.WORKFLOW_SERIAL;
							if (activeUnblockWf.WORKFLOW_STATE === 'PEND_ACT_CODE'
									|| activeUnblockWf.WORKFLOW_STATE === 'PEND_PIN_CHANGE') {
								viewCb('enterAuthcodes');
							} else {
								viewCb('enterAuthPersons');
							}
							return;
	
						}
					}

					window.dbg.log('status green');
					//this.user.firstTimePerso = true;
					

					if (lastSuccessPersoWf !== null) {
						if (lastSuccessUnblockWf !== null) {

							if (lastSuccessPersoWf.LAST_UPDATE_EPOCH > lastSuccessUnblockWf.LAST_UPDATE_EPOCH
									|| lastSuccessUnblockWf === null) {
								window.dbg.log('card personalized successfull but not activated - start Unblock');
								this.overAllStatus = 'red';
								this.user.cardActivation = true;
								viewCb('enterAuthPersons');
								return;
							} else {
								window.dbg.log('card personalized successfull and activated show certificates');
								viewCb('showStatus');
								return;
							}
						} else {
							window.dbg.log('card personalized successfull but not activated - start Unblock');
							this.overAllStatus = 'red';
							this.user.cardActivation = true;
							viewCb('enterAuthPersons');
							return;
						}
					} else {
						window.dbg.log('card personalized successfull and activated show certificates');
						sscView.setTopMenu(true);
						viewCb('showStatus');
						return;
					}

				} else if (this.overAllStatus === 'amber') {
					window.dbg.log('status amber');
					this.user.firstTimePerso = false;
					this.reCert = true;
					sscView.setTopMenu(true);
					if (activePersoWf !== null) {
						window.dbg.log('continue Personalization -active wf found id:'
								+ activePersoWf.WORKFLOW_SERIAL);
						//this.perso_wfID = activePersoWf.WORKFLOW_SERIAL;
						this.reCert = true;
						viewCb('contPerso');
						return;
					}else{
						if (activeUnblockWf !== null) {
							sscView.setTopMenu(true);
							window.dbg.log('continue unblock - active wf found id:'
									+ activeUnblockWf.WORKFLOW_SERIAL);
							this.user.cardActivation = true;
							this.overAllStatus = 'red';
							this.unblock_wfID = activeUnblockWf.WORKFLOW_SERIAL;
							if (activeUnblockWf.WORKFLOW_STATE === 'PEND_ACT_CODE'
									|| activeUnblockWf.WORKFLOW_STATE === 'PEND_PIN_CHANGE') {
								viewCb('enterAuthcodes');
							} else {
								viewCb('enterAuthPersons');
							}
							return;

						}	
					}

					window.dbg.log('status amber- start personalization');
					viewCb('startRecert');
					return;
				} else if (this.overAllStatus === 'red') {
					sscView.setTopMenu(false);
					window.dbg.log('status red');
					if (activePersoWf !== null) {
						window.dbg.log('continue Personalization -active wf found id:'
								+ activePersoWf.WORKFLOW_SERIAL);
						//this.perso_wfID = activePersoWf.WORKFLOW_SERIAL;
						this.reCert = true;
						viewCb('contPerso');
						return;
					}
//					else{
//						if (activeUnblockWf !== null) {
//							window.dbg.log('continue unblock - active wf found id:'
//									+ activeUnblockWf.WORKFLOW_SERIAL);
//							this.user.cardActivation = true;
//							this.overAllStatus = 'red';
//							this.unblock_wfID = activeUnblockWf.WORKFLOW_SERIAL;
//							if (activeUnblockWf.WORKFLOW_STATE === 'PEND_ACT_CODE'
//									|| activeUnblockWf.WORKFLOW_STATE === 'PEND_PIN_CHANGE') {
//								viewCb('enterAuthcodes');
//							} else {
//								viewCb('enterAuthPersons');
//							}
//							return;
//
//						}	
//					}
					
					
					//this.reCert = true;
					
					window.dbg.log('status red- start personalization');
					if(this.user.firstTimePerso)
					{
						viewCb('startPerso');
					}else{
						//sscView.setTopMenu(true);
						viewCb('startRecert');
					}
					return;
				}
					
			},

			sc_start_personalization : function(viewCb) {
				window.dbg.log("sc_start_personalization");

				this.sc_getCertificates(this.sc_cb_persoSendCardStatus, viewCb);

			},

			sc_cb_persoSendCardStatus : function(res , viewCb) {
				sscView.setStatusMsg("T_idle", ' ', 'idle');

				var rc = true;
				window.dbg.log("sc_cb_persoSendCardStatus");
				var reqData;

				reqData = 'wf_action=get_status&perso_wfID=' + this.perso_wfID + "&"
							+ res; 

				if (rc) {
					
					var server_cb = this.server_personalization_loop;
					var targetURL = 'functions/personalization/server_personalization';
					this.ajax_request(targetURL,  reqData,  server_cb, viewCb);
				}

			},

			server_status_personalization : function(viewCb) {
				window.dbg.log("server_status_personalization");

				var reqData = "wf_action=get_status&perso_wfID="
						+ this.perso_wfID;
				var server_cb = this.server_personalization_loop;
				var targetURL = "functions/personalization/server_personalization";

				this.ajax_request(targetURL,  reqData,  server_cb, viewCb);

			},

			server_personalization_loop : function(data, viewCb) {
				window.dbg.log("server_personalization_loop");

				sscView.setStatusMsg('T_idle', ' ', 'idle');

				var state;
				var rc = true;
				var action=null;

				try {
					var err = data.error;
				} catch (e) {
					// sscView.setStatusMsg('T_Server_Error','P_ContactAdmin',
					// 'red');
					sscView.showPopUp('E_backend-Error-perso', 'cross', '0206');
					
					window.dbg.log('server json error');
					rc = false;
					// sscView.showPopUp('T_Server_Error'+error ,'critical');
				}
				if (rc && err !== 'error') {
			
					try {
						this.state = data.wf_state;
					} catch (e) {
						sscView.showPopUp('E_backend-error-missing-state',
								'cross', '0204');
						window.dbg.log("catched error no wf_state");
						return;
					}

					try {
						this.perso_wfID = data.perso_wfID;
						// alert("wf_ID:"+wf_ID);

					} catch (e) {
						sscView.showPopUp('E_backend-error-missing-perso-wfID',
								'cross', '0205');
						window.dbg.log("E_catched_error_missing_perso_wfID");
						return;
					}

					try {
						// var count = dom_get_persocount();
						if (data.exec != null) {
							window.dbg.log("SC_command: " + data.exec);
							// dom_set_persocount( data.pending_operations);
						}

					} catch (e) {

					}
					try {
						// var count = dom_get_persocount();
						if (data.action != null) {
							window.dbg.log("SC_command: " + data.action);
							action = data.action;
							// dom_set_persocount( data.pending_operations);
						}

					} catch (e) {

					}
					
					
				if(this.state === 'SUCCESS' ){
					
					window.dbg.log('Success personalization, -unblock card next');
					sscView.showPersonalizationStatus(3);
					this.reCert = false;
					this.user.cardActivation = true;
					// Start card activation
					viewCb('success');
					return;
				}
	
					if(this.state === 'FAILIURE') {
						window.dbg.log('Failiure personalization');
						sscView.showPopUp(
								'E_process-error-perso-failed',
								'cross', '0211');
						return;
						
					}
			
					
					
					window.dbg.log('this.state: ' + this.state);
					
					
					sscView.setStatusMsg('I_commSc', "P_pleaseWait", "blue");
					window.dbg.log('exec: ' + data.exec );
					var r = this.PKCS11Plugin.SimonSays(data.exec,true,"");
					sscView.setStatusMsg("T_idle", ' ', 'idle');
					
					var results = new Querystring(r);
					window.dbg.log("SimanSays Res:"+r);

					var set = results.get("Result");
					
					//alert("Res:"+ r);
					if (set === "SUCCESS") {
						if(action === 'prepare'){
							sscView.showPersonalizationStatus(2);				
						}
						
						var reqData = "perso_wfID=" + this.perso_wfID
								+ "&wf_action=" +action+ '&' + r;
						var server_cb = this.server_personalization_loop;
						var targetURL = "functions/personalization/server_personalization";

						this.ajax_request(targetURL,  reqData,  server_cb, viewCb);

					} else {
						
						var re = results.get("Reason");
						//this.ajax_log("personalization loop:"+ r, 'error');
						
						if (re === 'TokenInternalError') {
							sscView.showPopUp('E_sc-error-pin-policy-violated',
									'cross', '0106');
						} else if (re === 'PUKLockedError') {
							sscView.showPopUp('E_sc-error-puk-locked',
									'cross', '0106');
						} else if (re === 'PUKError') {
							//sscView.showPopUp('E_sc-error-puk-notaccepted','cross', '0107');
							//PUK was invalid if two PUKs available try to install PUK and continue
							
							//FIXME add resume support for a not installed PUK
							window.dbg.log("rndPIN install failed - install puk. " + set);
							//this.sc_installPUK(viewCb);
							return;
						} else if (re === 'PUKInvalid') {
							sscView.showPopUp('E_sc-error-puk-invalid', 'cross',
									'0108');
							
						} else {
							sscView.showPopUp('E_sc-error-install-rnd-pin',
									'cross', '0109');
						}
						
						
						var reqData = "perso_wfID=" + this.perso_wfID
							+ "&wf_action=" +action+ '&' + r;
						var server_cb = this.server_personalization_loop;
						var targetURL = "functions/personalization/server_personalization";

						sscView.showPopUp('E_sc-perso_error ',
								'cross', '0102');
						
						this.ajax_log('server_personalization_loop: '+r, 'error');
						// ajax_request(targetURL,server_cb, reqData );
					}

					
					/*	
					if (this.perso_wfID !== 'undefined'
							&& this.perso_wfID !== null) {
					if (this.serverPIN === null || this.serverPUK === null
								|| this.serverPUK === undefined
								|| this.serverPIN === undefined) {
							// FIXME next perso step
							window.dbg.log('I_serverPUK_PIN_EMPTY_FETCH_PUK');

							var reqData = "wf_action=fetch_puk&perso_wfID="
									+ this.perso_wfID;
							var server_cb = this.server_personalization_loop;
							var targetURL = "functions/personalization/server_personalization";

							// alert("fetch PIN");
							if (this.maxrequests < 1) {
								this.maxrequests++;
								this.ajax_request(targetURL, server_cb,
										reqData, viewCb);
								return;
							} else {
								// IF we try to install the PUK more then 2
								// Times, the card would be made useless after
								// 3rd try
								// critical contact support before any other
								// action or retry
								sscView.showPopUp('E_carderror-PUK-invalid',
										'cross', '0007');
								window.dbg.log('E_ERROR_FETCHING_PUK_CARD_MIGHT_BE_UNUSEABLE');
							}

						} else {

							window.dbg.log('E_serverPUK :' + this.serverPUK + 'END'
									+ typeof (this.serverPUK));
							if (this.rnd_pin_installed == 0) {
								
								if (this.state === 'PUK_TO_INSTALL') {
									this.sc_installPUK(viewCb);
									return;
								} else {
									this.sc_installRND_pin(viewCb);
									return;
								}

							} else 
							{
								window.dbg.log('perso State:' + this.state);

								switch (this.state) {
								case 'NEED_NON_ESCROW_CSR':
									var keysize;
									try {
										// FIXME move var location
										keysize = data.msg.PARAMS.WORKFLOW.CONTEXT.keysize;
										// alert("wf_ID:"+wf_ID);
									} catch (e) {
										window.dbg.log("error keysize catched");
									}

									if (this.user.accounts.length === 1) {
										this.personalizeAccount(
												this.user.accounts[0], viewCb);
										// this.user.accounts.push(this.user.accounts[0]);
									} else {
										sscView.showAccountDlg(this.user.accounts);
									}

									break;

								case 'CERT_TO_INSTALL':
									// alert("cert to install");
									window.dbg.log('CERT_TO_INSTALL');
									var installtype;
									var keyID;
									var cert_to_install;

									// try{
									// installtype = data.cert_install_type;
									// }catch(e){
									// window.dbg.log('Error missing certificate
									// type'+e);
									// }
									command = 'ImportX509';
									try {
										cert_to_install = data.cert_to_install;
									} catch (e) {
										window.dbg.log('Error missing certificate to install'
														+ e);
									}

									try {
										keyID = data.msg.PARAMS.WORKFLOW.CONTEXT.keyid;
									} catch (e) {
										sscView
												.showPopUp(
														'E_backend-error-missing-keyid',
														'cross', '0207');
										window.dbg.log('Error missing key to install identifier'
														+ e);
									}

									var plugin_parameter = "KeyID="
											+ keyID + ";Overwrite=yes;UserPIN="
											+ this.serverPIN
											+ ";UserPINEncrypted="
											+ this.puk_pin_encryption + ";";
									// alert(plugin_parameter);
									window.dbg.log(plugin_parameter);

									this.PKCS11Plugin.ParamList = plugin_parameter;
									//this.PKCS11Plugin.Data = cert_to_install;
									//FIXME added = padding to certdata to avoid plugin import problem with non padded base64 data
									this.PKCS11Plugin.Data = cert_to_install;
									this.PKCS11Plugin.UserPIN = this.serverPIN;
									this.PKCS11Plugin.Request = command;
									// alert(cert_to_install);

									this.sc_run_command(this.sc_cb_installx509,
											viewCb);

									break;
								case 'PKCS12_TO_INSTALL':
									window.dbg.log('PKCS12_TO_INSTALL');

									var installtype;
									var p12;

									// try{
									// installtype = data.cert_install_type;
									// }catch(e){
									// window.dbg.log('Error missing certificate
									// type'+e);
									// }

									// alert(installtype);

									// if(installtype == 'p12')
									// {
									command = 'ImportP12';
									try {
										cert_to_install = data.p12;
									} catch (e) {
										sscView.showPopUp(
												'E_backend-error-missing-p12',
												'cross', '0208');
										window.dbg.log('Error missing certificate'
												+ e);
									}

									try {

										p12 = data.p12_p;
									} catch (e) {
										sscView.showPopUp(
												'E_backend-error-missing-p12p',
												'cross', '0209');
										window.dbg.log('Error missing p12 password'
												+ e);
									}

									if (cert_to_install !== null
											&& keyID !== null) {

										var plugin_parameter = "FilePIN=" + p12
												+ ";FilePINEncrypted="
												+ this.puk_pin_encryption
												+ ";UserPIN=" + this.serverPIN
												+ ';UserPINEncrypted='
												+ this.puk_pin_encryption + ';';
										window.dbg.log('importp12 para: '
												+ plugin_parameter);
										this.PKCS11Plugin.ParamList = plugin_parameter;
										this.PKCS11Plugin.Data = cert_to_install;
										this.PKCS11Plugin.UserPIN = this.serverPIN;
										this.PKCS11Plugin.Request = command;

										this.sc_run_command(
												this.sc_cb_importP12, viewCb);
									} else {
										window.dbg.log('error.....pw:' + keyID
												+ 'p12:' + cert_to_install);
									}
									// }

									break;

								case 'HAVE_CERT_TO_DELETE':

									var cert_to_delete;
									command = 'DeleteUserData';
									try {
										cert_to_delete = data.cert_id_to_delete;
									} catch (e) {
										sscView
												.showPopUp(
														'E_backend-error-missing-cert-to-delete',
														'cross', '0210');
										window.dbg.log('Error missing certificate id to delete'
														+ e);
									}

									if (cert_to_delete != null) {

										var plugin_parameter = 
												"KeyID="
												+ cert_to_delete
												+ ";DeleteCert=yes;DeleteKey=yes;"
												+ ";UserPIN=" + this.serverPIN
												+ ';UserPINEncrypted=yes';
										// alert(plugin_parameter);
										window.dbg.log(plugin_parameter);
										this.PKCS11Plugin.ParamList = plugin_parameter;
										//this.PKCS11Plugin.UserPIN = this.serverPIN;

										this.PKCS11Plugin.Request = command;
										// alert(cert_to_install);

										this.sc_run_command(
												this.sc_cb_DeleteUserData,
												viewCb);
									} else {
										window.dbg.log('error.....pw:' + keyID
												+ 'p12:' + cert_to_install);
									}
									break;

								case 'SUCCESS':
									window.dbg.log('Success personalization, -unblock card next');
									sscView.showPersonalizationStatus(3);
									this.reCert = false;
									this.user.cardActivation = true;
									// Start card activation
									viewCb('success');
									return;
									break;
								case 'FAILIURE':
									window.dbg.log('Failiure personalization');
									sscView.showPopUp(
											'E_process-error-perso-failed',
											'cross', '0211');

									break;
								default:
									sscView.showPopUp(
											'E_process-error-unknown-state '
													+ this.state, 'cross',
											'0219');
									break;
								}
								return;
							}
						}
					}*/
					
					
				} else {

					for ( var i = 0; i < data.errors.length; i++) {
						if (data.errors[i] === '18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CARDID_NOTACCEPTED') {
							window.dbg.log('Error ' + i + ' ' + data.errors[i]);
							sscView.showPopUp('E_card_id_error', 'cross',
									'0222');
							viewCb('error');
						} 
						if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER') {
							window.dbg.log('Error ' + i + ' ' + data.errors[i]);
							sscView.showPopUp('E_session_timeout_error', 'cross',
									'0222');
							viewCb('error');
							return;
						}
						else {
							this.ajax_log('server_personalization_loop: '+ data.errors[i], 'error');
							sscView.showPopUp('E_process-unknown-backend-error</br>'
									+ data.errors[i], 'cross', '0212');
							this.ajax_log('server_personalization_loop: '+data.errors[i], 'error');
							viewCb('error');
						}
					}
				}
			},

			
			sc_checkCardPresence : function (){
				//window.dbg.log("sc_checkCardPresence");
				
				var res = this.PKCS11Plugin.CheckCardPresence(this.cardID);
				
				var results = new Querystring(res);

				var set = results.get("Result");
				if (set == "SUCCESS"){
					return true;
				}else{
					return false;
				}
				
				
			},
			
			sc_card_cleanup : function (viewCB){
				window.dbg.log("sc_card_cleanup");
				alert("missing plugin function");
		/*
				var res = this.PKCS11Plugin.CheckCardPresence(this.cardID);
				
				var results = new Querystring(res);

				var set = results.get("Result");
				if (set == "SUCCESS"){
					return true;
				}else{
					return false;
				}
	*/		
				
			},

//
//			sc_cb_installRND_pin : function(viewCb) {
//				window.dbg.log("sc_cb_installRND_pin");
//				var res = this.PKCS11Plugin.Data;
//				window.dbg.log(res);
//				var results = new Querystring(res);
//
//				var set = results.get("Result");
//
//				window.dbg.log("sc_cb_installRND_pin :" + res);
//				if (set == "SUCCESS") {
//					// event_nextStepPerso();
//					this.rnd_pin_installed = 1;
//					this.server_status_personalization(viewCb);
//					sscView.showPersonalizationStatus(2);
//				} else {
//					var set = results.get("Reason");
//					var card_insert_status = this.PKCS11Plugin.PluginStatus;
//					window.dbg.log("card insert :" + card_insert_status);
//					if(card_insert_status === 'LOOKINGFORTOKEN'){
//						sscView.showPopUp('E_sc-error-card-removed',
//								'cross', '0105');		
//					}
//
//					if (set === 'PINNotEncrypted') {
//						sscView.showPopUp('E_sc-error-pin-not-encrypted',
//								'cross', '0105');
//					} else if (set === 'TokenInternalError') {
//						sscView.showPopUp('E_sc-error-pin-policy-violated',
//								'cross', '0106');
//					} else if (set === 'PUKLockedError') {
//						sscView.showPopUp('E_sc-error-puk-locked',
//								'cross', '0106');
//					} else if (set === 'PUKError') {
//						//sscView.showPopUp('E_sc-error-puk-notaccepted','cross', '0107');
//						//PUK was invalid if two PUKs available try to install PUK and continue
//						window.dbg.log("rndPIN install failed - install puk. " + set);
//						this.sc_installPUK(viewCb);
//						return;
//					} else if (set === 'PUKInvalid') {
//						sscView.showPopUp('E_sc-error-puk-invalid', 'cross',
//								'0108');
//					} else {
//						sscView.showPopUp('E_sc-error-install-rnd-pin',
//								'cross', '0109');
//					}
//
//					window.dbg.log("sc_cb_installRND_pin error reson:" + set);
//
//					// alert("RndPINInstall Error: "+ res);
//					this.rnd_pin_installed = 0;
//					// server_personalization(); //FIXME
//				}
//
//			},// END sc_cb_installRND_pin


//			sc_cb_installPUK : function(viewCb) {
//				window.dbg.log("sc_cb_installPUK : "+this.PKCS11Plugin.PluginStatus);
//		
//				if (this.PKCS11Plugin.PluginStatus === 'FINISHED_SUCCESS' ) {
//					
//					var res = this.PKCS11Plugin.Data;
//					window.dbg.log("status : "+this.PKCS11Plugin.PluginStatus);
//					var results = new Querystring(res);
//
//					var set = results.get("Result");
//					window.dbg.log("PUK Install Success: " + res);
//					// event_nextStepPerso();
//					if(this.state === 'PUK_TO_INSTALL')
//					{
//						var reqData = "perso_wfID=" + this.perso_wfID
//						+ "&wf_action=inst_puk_ok";
//						var server_cb = this.server_personalization_loop;
//						var targetURL = "functions/personalization/server_personalization";
//		
//						this.ajax_request(targetURL,  reqData,  server_cb, viewCb);
//					}else{
//						this.server_status_personalization(viewCb);
//					}
//					
//				} else {
//					var res = this.PKCS11Plugin.Data;
//					
//					window.dbg.log("status : "+this.PKCS11Plugin.PluginStatus);
//					var results = new Querystring(res);
//
//					var set = results.get("Result");
//					
//					window.dbg.log("PUK Install fail - already installed: " + res);
//					var reason = results.get("Reason");
//					if (reason === 'PUKError'){
//						// NO Error reporting if puk instalation failed old PUK
//						// still valid
//						
//						if(this.state === 'PUK_TO_INSTALL' ){
//						var reqData = "perso_wfID=" + this.perso_wfID
//								+ "&wf_action=inst_puk_ok&perso_wfID="
//								+ this.perso_wfID;
//						var server_cb = this.server_personalization_loop;
//						var targetURL = "functions/personalization/server_personalization";
//
//						this
//								.ajax_request(targetURL, server_cb, reqData,
//										viewCb);
//						
//						}else{
//							window.dbg.log("PUK already installed continue personalization");
//							this.new_puk_installed = 1;
//							this.server_status_personalization(viewCb);
//							
//						}
//						window.dbg.log("sc_installPUK status="+this.PKCS11Plugin.PluginStatus);
//		
//					}else if (set === 'PUKLockedError') {
//						sscView.showPopUp('E_sc-error-puk-locked',
//								'cross', '0106');
//					}
//					else {
//						
//						window.dbg.log("sc_installPUK status="+this.PKCS11Plugin.PluginStatus);
//						sscView.showPopUp(
//								'E_sc-error-install-rndpuk ' + reason, 'cross',
//								'0111');
//					}
//				}
//
//			},// END sc_cb_installPUK

//			personalizeAccount : function(account, viewCb) {
//				window.dbg.log("personalizeAccount");
//				this.selectedAccount = account;
//				this.sc_GenerateKeypair(viewCb);
//
//			},


			// #################################PIN UNBLOCK################
			server_start_resetpin : function(authPerson1, authPerson2, viewCb) {
				window.dbg.log("server_srart_resetpin " + authPerson1.toLowerCase()
						+ ' ' + authPerson2.toLowerCase());

				var reqData = "unblock_wfID=" + this.unblock_wfID + "&email1="
						+ authPerson1.toLowerCase() + "&email2="
						+ authPerson2.toLowerCase();
				var server_cb = this.server_cb_start_resetpin;
				var targetURL = "functions/pinreset/start_pinreset";
				this.ajax_request(targetURL,  reqData,  server_cb, viewCb);

			},// END server_start_resetpin

			server_cb_start_resetpin : function(data, viewCb) {
				window.dbg.log("server_cb_start_resetpin");

				sscView.setStatusMsg('T_idle', '', 'idle');

				try {
					var err = data.error;
				} catch (e) {

					sscView.showPopUp('E_backend-Error-unblock', 'cross',
							'0213');
					viewCb('error');
					return;
				}
				try {
					this.unblock_wfID = data.unblock_wfID;
				} catch (e) {
					sscView.showPopUp('E_backend-error-missing-unblock-wfID',
							'cross', '0214');
					viewCb('error');
					return;
					window.dbg.log("Server error missing unblock wfID");
				}
				var email1;
				var email2;
				try {
					email1 = data.auth1_ldap_mail;
					this.user.authEmail1 = data.auth1_ldap_mail;
				} catch (e) {
					sscView.showPopUp('E_backend-error-missing-unblock-email1',
							'cross', '0215');
					viewCb('error');
					return;
					window.dbg.log("Server error email1:" + this.unblock_wfID);
				}
				try {
					email2 = data.auth2_ldap_mail;
					this.user.authEmail2 = data.auth2_ldap_mail;
				} catch (e) {
					sscView.showPopUp('E_backend-error-missing-unblock-email2',
							'cross', '0216');
					viewCb('error');
					return;
					window.dbg.log("Server error email2:" + this.unblock_wfID);
				}

				if (err == "error") {
					// if error authpersons not accepted FIXME or could NOT
					// create workflow
					try{
					for ( var i = 0; i < data.errors.length; i++) {
						if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_CREATE_WORKFLOW_INSTANCE') {
							window.dbg.log('Error ' + i + ' ' + data.errors[i]);
						}

						if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_STATE_HAVE_TOKEN_OWNER_REQUIRED') {
							window.dbg.log('Error ' + i + ' ' + data.errors[i]);
						}
						if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_STORE_AUTH_IDS') {
							window.dbg.log('Error ' + i + ' ' + data.errors[i]);
							// error storing authId's
							viewCb(true);
							return;
						}
						if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER') {
							window.dbg.log('Error ' + i + ' ' + data.errors[i]);
							sscView.showPopUp('E_session_timeout_error', 'cross',
									'0222');
							viewCb('error');
							return;
						}

						if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_STATE_PAND_ACT_CODE_REQUIRED') {
							window.dbg.log('Error ' + i + ' ' + data.errors[i]);
							// error storing authId's
//							sscView.showPopUp(
//									'E_backend-error-creating-workflow',
//									'cross', '0221');
							var missing=0;
							window.dbg.log("email1 " + email1 + " " + data.auth1_ldap_mail);
							if(email1 === null || email1 === undefined ){
								missing = 1;
							}
							window.dbg.log("email2 " + email2 + " "+ data.auth2_ldap_mail);
							if(email2 === null || email1 === undefined){
								missing += 2;
							}		
							viewCb(true,missing);
							return;
						}		
						
					}
					
					}catch (e){
						
					}

				} else {
					// Continue unblock show enter recived authcode dlg
					viewCb(false);
					return;
				}

			},

//			sc_cb_resetpin : function(viewCb) {
//				window.dbg.log("sc_cb_resetpin");
//				var pluginstatus = this.PKCS11Plugin.PluginStatus;
//				this.cardID = this.PKCS11Plugin.TokenID;
//				var res = this.PKCS11Plugin.Data;
//
//				var results = new Querystring(res);
//
//				var set = results.get("Result");
//
//				if (set == "SUCCESS") {
//					pinSetCount = 0;
//
//					var reqData = "unblock_wfID=" + this.unblock_wfID + "&"
//							+ res;
//					var server_cb = this.server_cb_pinreset_confirm;
//					var targetURL = "functions/pinreset/pinreset_confirm";
//
//					this.ajax_request(targetURL,  reqData,  server_cb, viewCb);
//					// this.ajax_request("sc/functions/pinreset/pinreset_confirm",server_cb_pinreset_confirm,
//					// res );
//
//				} else if (set == "ERROR") {
//					this.pinSetCount++;
//					// alert("ERROR Pinsetcount="+pinSetCount);
//					command = "ResetPIN";
//					var reason = results.get("Reason");
//					window.dbg.log("reason " + reason + ' ' + res);
//
//					if (reason === 'PUKError') {
//						sscView.showPopUp('E_sc-error-resetpin-puk-error ',
//								'cross', '0113');
//						viewCb('error');
//						return;
//					} else if (reason === 'TokenInternalError') {
//						// Invalid PIN is an user Error no popup here
//						window.dbg.log("invalid pin" + reason);
//						viewCb('invalidPin');
//						return;
//					}
//
////					var plugin_parameter = "PUK=" + this.serverPUK
////							+ ";PUKEncrypted=no;NewPIN=" + user_pass1
////							+ ";NewPINEncrypted=no;";
////					this.PKCS11Plugin.ParamList = plugin_parameter;
////					this.PKCS11Plugin.Request = command;
////					// alert(this.PKCS11Plugin.Request);
////					// stage == 1;
////
////					this.sc_run_command(this.sc_cb_resetpin);
//				} else {
//
//					viewCb();
//					return;
//
//					// this.ajax_request("sc/functions/pinreset/pinreset_confirm",this.server_cb_pinreset_confirm,
//					// res );
//
//				}
//
//			},// END sc_cb_resetpin

			server_cb_pinreset_confirm : function(data, viewCb) {
				window.dbg.log("server_cb_pinreset_confirm");
				sscView.setStatusMsg('T_idle', '', 'idle');

				try {
					var err = data.error;
				} catch (e) {
					// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
					// 'red');
					sscView.showPopUp('E_server-error-confirming-reset',
							'cross', '0217');
					viewCb('error');
					this.ajax_log('server_cb_pinreset_confirm E_server-error-confirming-reset', 'error');
					return;
					window.dbg.log('server json error');
					// sscView.showPopUp('T_Server_Error'+error ,'critical');
				}
				
				
				if( err !== 'error'){
					if (data.wfstate === 'SUCCESS') {
						window.dbg.log('SUCCESS - show status');
						
						if(this.cardType === 'RSA_2.0')
						{
													
							window.dbg.log("RSA unblock successful");
							viewCb(); //only to clear the main field Hack ugly 
								sscView.setOverallStatus('green');
								sscView.setPrompt('P_RSAunblock');
								sscView.setNextAction('', null );
								return;
								
						}else{
							viewCb();
							return;
						}
					
					} else {
						sscView.showPopUp('E_server-error-confirming-reset',
								'cross', '0217');
						viewCb('error');
						return;
					}	
						
				}else{
					try{
						for ( var i = 0; i < data.errors.length; i++) {
							if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER') {
								window.dbg.log('Error ' + i + ' ' + data.errors[i]);
								sscView.showPopUp('E_session_timeout_error', 'cross',
										'0222');
								viewCb('error');
								return;
							}else {
								sscView.showPopUp('E_process-unknown-backend-error</br>'
										+ data.errors[i], 'cross', '0212');
								this.ajax_log('server_cb_pinreset_confirm E_process-unknown-backend-error', 'error');
								viewCb('error');
							}
						}
					}catch (e){
						
					}
				}
				
				// dom_popup('Card unblocked ', "Finished card unblock :"+
				// data.wfstate, "info" );

			},// END server_cb_pinreset_confirm

			server_cb_pinreset_verify : function(data, viewCb) {
				window.dbg.log("server_cb_pinreset_verify");
				var exec = null;
				var err = null;
				try {
					err = data.error;
				} catch (e) {
					// sscView.setStatusMsg('T_Server_Error','P_ContactAdmin',
					// 'red');
					sscView.showPopUp('E_backend-Error-unblock-verify',
							'cross', '0218');
					window.dbg.log('server json error');
					// sscView.showPopUp('T_Server_Error'+error ,'critical');
				}
				if (err !== "error") {

					var PUK = null;
					try {	
							exec = data.exec ;
						
					} catch (e) {
						window.dbg.log('missing data.exec');
					}
					
					try {
						this.state = data.wfstate;
					} catch (e) {
						window.dbg.log('missing wf state');
					}
					try {
						this.unblock_wfID = data.unblock_wfID;
					} catch (e) {
						window.dbg.log('missing wfID');
					}
					if (this.state === 'FAILURE') {
						viewCb('failure'); // FIXME return code
						return;
					}
					
					
					if(this.cardType === 'RSA_2.0')
					{
						window.dbg.log("start RSA unblock");
						
						
						if(this.resetTokenRSA === 1 )
							{
//								var command = "ResetToken";
//											
//								var plugin_parameter = "PUK=" + PUK + ";PUKEncrypted="
//								+ this.puk_pin_encryption + ";NewPIN=" + PIN
//								+ ";NewPINEncrypted=" + this.puk_pin_encryption
//								+ ";";
//
//						this.PKCS11Plugin.ParamList = plugin_parameter;
//						this.PKCS11Plugin.Request = command;
//						this.sc_run_command(this.sc_cb_resetpin, viewCb);
						//FIXME not yet tested with RSA tokens
							
//							sscView.setStatusMsg('I_commSc', "P_pleaseWait", "blue");
//							window.dbg.log('exec: ' + data.exec );
//							var r = this.PKCS11Plugin.SimonSays(data.exec,true,this.userPIN);
//							sscView.setStatusMsg("T_idle", ' ', 'idle');
//							
//							return;	
						}
						
					
					}
									
					window.dbg.log('this.state: ' + this.state);		
					sscView.setStatusMsg('I_commSc', "P_pleaseWait", "blue");
					window.dbg.log('exec: ' + data.exec );
					var r = this.PKCS11Plugin.SimonSays(data.exec,true,this.userPIN);
					sscView.setStatusMsg("T_idle", ' ', 'idle');
					
					var results = new Querystring(r);
					window.dbg.log("SimanSays Res:"+r);

					var set = results.get("Result");
					
					//alert("Res:"+ r);
					if (set == "SUCCESS") {
						pinSetCount = 0;

						var reqData = "unblock_wfID=" + this.unblock_wfID + "&"
								+ r;
						var server_cb = this.server_cb_pinreset_confirm;
						var targetURL = "functions/pinreset/pinreset_confirm";

						this.ajax_request(targetURL,  reqData,  server_cb, viewCb);
						// this.ajax_request("sc/functions/pinreset/pinreset_confirm",server_cb_pinreset_confirm,
						// res );

					} else if (set == "ERROR") {
						this.pinSetCount++;
						// alert("ERROR Pinsetcount="+pinSetCount);
						
						var reason = results.get("Reason");
						window.dbg.log("reason " + reason + ' '+ r);
						this.ajax_log('server_cb_pinreset_verify'+ r, 'error');
						

						if (reason === 'PUKError') {
							sscView.showPopUp('E_sc-error-resetpin-puk-error ',
									'cross', '0113');
							viewCb('error');
							return;
						} else if (reason === 'TokenInternalError') {
							// Invalid PIN is an user Error no popup here
							window.dbg.log("invalid pin" + reason);
							
							this.pinResetRetry = data.exec ; 
							viewCb('invalidPin');
							return;
						}

//						var plugin_parameter = "PUK=" + this.serverPUK
//								+ ";PUKEncrypted=no;NewPIN=" + user_pass1
//								+ ";NewPINEncrypted=no;";
//						this.PKCS11Plugin.ParamList = plugin_parameter;
//						this.PKCS11Plugin.Request = command;
//						// alert(this.PKCS11Plugin.Request);
//						// stage == 1;
	//
//						this.sc_run_command(this.sc_cb_resetpin);
					}

/*					var command = "ResetPIN";
					// alert("PUK:" + data.puk +"\n state"+data.wfstate +" \n
					// wf_ID"+ data.wf_ID + data.msg +" \n "+ data.error );
					if (PUK) {

						var plugin_parameter = "PUK=" + PUK + ";PUKEncrypted="
								+ this.puk_pin_encryption + ";NewPIN=" + PIN
								+ ";NewPINEncrypted=" + this.puk_pin_encryption
								+ ";";
						//alert(plugin_parameter);

						this.PKCS11Plugin.ParamList = plugin_parameter;

						this.PKCS11Plugin.Request = command;
						//alert(this.PKCS11Plugin.Request);

						this.sc_run_command(this.sc_cb_resetpin, viewCb);
					} else {
						//FIXME ERROR PUK MISSING
					}*/
				} else {
					//if data error 
					for ( var i = 0; i < data.errors.length; i++) {
						if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_AUTHCODES_INCORRECT') {
							window.dbg.log('Error ' + i + ' ' + data.errors[i]);
							viewCb('invalidAuthCode',3); 
							return;
						}
						if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_WF_FAILURE') {
							window.dbg.log('Error ' + i + ' ' + data.errors[i]);
							window.dbg.log('Restart Unblock WF failed');
							this.user.cardActivation = true;
							viewCb('failure');
							return;
							
						}
						if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER') {
							window.dbg.log('Error ' + i + ' ' + data.errors[i]);
							sscView.showPopUp('E_session_timeout_error', 'cross',
									'0222');
							return;
						}

					}
					//sscView.setStatusMsg('E_ax-failure','P_ContactAdmin', 'red');
					sscView.showPopUp('E_backend-Error-unblock-verify-json',
							'cross', '0219');
					window.dbg.log('server_cb_pinreset_verify server error');
				}

			},//END server_cb_pinreset_verify

			server_pinrest_verify : function(userpin, authcode1, authcode2,
					viewCb) {
				window.dbg.log("server_pinreset_verify");
				//this.cardID = this.PKCS11Plugin.TokenID;
				//this.cardType = this.PKCS11Plugin.CardType;
				
				//FIXME PIN enter retry 
				this.userPIN = userpin; 

				//var reqData = "unblock_wfID="+this.unblock_wfID+D;
				var server_cb = this.server_cb_pinreset_verify;
				var targetURL = "functions/pinreset/pinreset_verify";
				var reqData = 'unblock_wfID=' + this.unblock_wfID
						+ '&activationCode1=' + $.URLEncode(authcode1) + '&activationCode2='
						+ $.URLEncode(authcode2);

				this.ajax_request(targetURL,  reqData,  server_cb, viewCb);

			},//END server_pinrest_verify
			
			
			server_cancel_unblock : function(viewCb) {
				window.dbg.log("server_cancel_unblock");
				
				
				window.dbg.log("unblock WF id:" + this.unblock_wfID);
				if(this.unblock_wfID !== undefined){
							
				var server_cb = this.server_cb_cancel_unblock;
				var targetURL = "functions/pinreset/pinreset_cancel";
				var reqData = 'unblock_wfID=' + this.unblock_wfID
						+ '&TokenID=' + this.cardID + '&CardType='
						+ this.cardType ;
				
				
				this.ajax_request(targetURL,  reqData,  server_cb, viewCb);
				
				}else{
					window.dbg.log("no active workflow return to status" );
					viewCb('showStatus');
				}
			
			},
			
			server_cb_cancel_unblock : function(data, viewCb) {
				window.dbg.log("server_cb_cancel_unblock");
				
				try {
					var err = data.error;
				} catch (e) {
					// sscView.setStatusMsg('T_Server_Error','P_ContactAdmin',
					// 'red');
					sscView.showPopUp('E_backend-Error-unblock-cancel',
							'cross', '0218');
					window.dbg.log('server backend error');
					// sscView.showPopUp('T_Server_Error'+error ,'critical');
				}
				for ( var i = 0; i < data.errors.length; i++) {
					if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER') {
						window.dbg.log('Error ' + i + ' ' + data.errors[i]);
						sscView.showPopUp('E_session_timeout_error', 'cross',
								'0222');
						return;
					}

				}
				this.unblock_wfID = undefined;
				window.dbg.log("show card status");
				viewCb('showStatus');
				sscView.setOverallStatus('green');
				
				
				
				
			},

			//######################PIN CHANGE#########################	
			sc_changePIN : function(userpin, newpin, viewCb) {
				var command = "ChangePIN";
				window.dbg.log("sc_changePIN");
				window.dbg.log("viewCb" + viewCb);
				this.cardID = this.PKCS11Plugin.TokenID;
				this.cardType = this.PKCS11Plugin.CardType;

				var plugin_parameter = "UserPIN=" + userpin
						+ ";UserPINEncrypted=no;NewPIN=" + newpin
						+ ";NewPINEncrypted=no;";
				window.dbg.log(plugin_parameter);
				this.PKCS11Plugin.ParamList = plugin_parameter;
				this.PKCS11Plugin.Request = command;

				this.sc_run_command(this.sc_cb_login_changePIN, viewCb);

				//this.sc_run_command(this.sc_cb_waitforuserinput,viewCb);
			},//END sc_changePIN

//			sc_cb_login_changePIN : function(viewCb) {
//				window.dbg.log("viewCb" + viewCb);
//				var command = "ChangePIN";
//				window.dbg.log("sc_changePIN");
//				this.cardID = this.PKCS11Plugin.TokenID;
//				this.cardType = this.PKCS11Plugin.CardType;
//
//				this.PKCS11Plugin.NewPIN = this.newUserPin;
//				this.PKCS11Plugin.UserPIN = this.userPin;
//
//				//window.dbg.log (plugin_parameter);
//				//this.PKCS11Plugin.ParamList = plugin_parameter;
//				//this.PKCS11Plugin.Request = command;
//
//				setTimeout(function() {
//					this.sc_run_command(this.sc_cb_changePIN, viewCb);
//				}.bind(this), 500);
//
//				//this.sc_run_command(this.sc_cb_waitforuserinput,viewCb);
//			},//END sc_changePIN

//			sc_cb_changePIN : function(viewCb) {
//				window.dbg.log("viewCb" + viewCb);
//				window.dbg.log("sc_cb_changePIN");
//				this.cardID = this.PKCS11Plugin.TokenID;
//				this.cardType = this.PKCS11Plugin.CardType;
//
//				var res = this.PKCS11Plugin.GetResult();
//				var results = new Querystring(res);
//
//				var set = results.get("Result");
//
//				//~ if(set)
//				//~ {
//				//~ set.trim();
//				//~ }
//				window.dbg.log(res + this.PKCS11Plugin.PluginStatus);
//				if (set === "SUCCESS") {
//					viewCb('success');
//
//					//popup( "PIN changed successfully. <br> Your PIN has been changed please use the new PIN from now on to access your smartcard." , "info", function () { 
//					//});
//				} else if (set === "ERROR") {
//					var reason = results.get("Reason");
//					window.dbg.log("Error: " + reason);
//
//					if (reason == 'TokenInternalError') {
//						viewCb('newPinError');
//						return;
//					} else if (reason == 'PINLockedError') {
//						viewCb('cardBlocked');
//						return;
//					} else {
//						viewCb('pinError');
//						return;
//					}
//				}
//				return;
//
//				//~ popup( "PIN change failed "+reason , "", function () { 
//				//~ });
//			},//END
//
			sc_resetTestToken : function(cardID, viewCb) {
					window.dbg.log("sc_resetToken");

					var res = this.PKCS11Plugin.ResetToken(cardID,"1234a", "000000000000000000000000000000000000000000000000" );
					var results = new Querystring(res);
					
					window.dbg.log("sc_resetToken result" + res);
					var r = results.get("Result");
					if(r === 'SUCCESS'){
						sscView.setPrompt('I_Token_reset_success');
					}else{
						var reason = results.get("Reason");
						window.dbg.log("Error: " + reason);

						if (reason == 'PUKError') {
							sscView.showPopUp('E_sc-error-resetToken-puk-error ',
								'cross', '0113');
						viewCb('error');
						return;	
						}else {
							sscView.showPopUp('E_sc-error-resetToken-error ',
									'cross', '0113');
							viewCb('error');
							return;			
						}
					}
			

			},//END sc_ResetToken
			


/*			sc_cb_resetToken : function(viewCb) {
				window.dbg.log("sc_cb_resetToken");
				this.cardID = this.PKCS11Plugin.TokenID;
				this.cardType = this.PKCS11Plugin.CardType;

				var res = this.PKCS11Plugin.GetResult();
				var results = new Querystring(res);
				
				window.dbg.log("sc_resetToken result" + res);
				var r = results.get("Result");
				if(r === 'SUCCESS'){
					sscView.setPrompt('I_Token_reset_success');
				}else{
					var reason = results.get("Reason");
					window.dbg.log("Error: " + reason);

					if (reason == 'PUKError') {
						sscView.showPopUp('E_sc-error-resetToken-puk-error ',
							'cross', '0113');
					viewCb('error');
					return;	
					}else {
						sscView.showPopUp('E_sc-error-resetToken-error ',
								'cross', '0113');
						viewCb('error');
						return;			
					}
				}
						
			},//END sc_cb_resetToken
*/
			// fixme: should be in model
			getActivationCode : function(cb) {

				var qget = new Querystring();
				var wf_ID = qget.get("id");
				//var foruser = qget.get("foruser");

				window.dbg.log('getActivationCode');

				targetURL = this.options.baseUrl
						+ 'sso/functions/getauthcode/getauthcode' + '?id='
						+ wf_ID;

				window.dbg.log('targetURL =' + targetURL);

				var jsonRequest = new Request.JSON(
						{

							method : 'post',
							url : targetURL,

							onSuccess : function(data) {
								var err;
								try {
									err = data.error;
								} catch (e) {
									sscView.showPopUp('E_serverError', 'cross',
											'001');
									this.ajax_log('ajax request error get auth code','error');
								}

								if (err === 'error') {
									try {
										for ( var i = 0; i < data.errors.length; i++) {

											if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_GET_AUTH_CODE_WEBSSO_MISSING_USERNAME') {
												sscView
														.setPrompt('P_notAuthorized');
												return;
											}
											if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFTASK_GETCODE_ERROR_STATE_INVALID') {
												//sscView.setPrompt('P_invalidState');
												sscView
														.setPrompt('P_noAuthCode');
												return;
											}if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_GETAUTHCODE_ERROR_EXECUTING_SCPU_GENERATE_ACTIVATION_CODE') {
												//sscView.setPrompt('P_invalidState');
												sscView
														.setPrompt('P_noAuthCode');
												return;
											}					
											if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_GETCODE_ERROR_WORKFLOW_FINISHED') {
												//sscView.setPrompt('P_invalidState');
												sscView
														.setPrompt('P_noAuthCode');
												return;
											}  else {
												sscView
														.setPrompt('P_noAuthCode');
												return;
											}
										}
									} catch (e) {
										sscView.setPrompt('P_notAuthorized');
										this.ajax_log('person not authorized to pick up auth code','info');
										return;
									}

								}
								try {
									//alert(data.code);
									sscView.showAuthCode(data.code);
									sscView.setInfoLeft('T_authCodePerson',
											data.foruser);

									//							if( data.code !== undefined && data.code !== null ){
									//								
									//								
									//							}else{
									//								sscView.showPopUp('E_server_error_missing_code', 'cross', '002');
									//							}
								} catch (e) {
									sscView.showPopUp(
											'E_server_error_missing_code',
											'cross', '0220');
									this.ajax_log('no auth code available','warn');
								}
							},

							onFailure : function() {
								sscView.showPopUp('E_serverError', 'cross',
										'0200');
								this.ajax_log('error requesting auth code','error');
							}

						}).send();

			},
			
			
			/*-----------------------------------------------------------------
			 *  Helper Functions 
			/*-----------------------------------------------------------------*/
			ajax_request : function(targetURL,  reqData,  server_cb, viewCb) {
				if (typeof server_cb !== 'function') alert('fnc: ajax_request - wrong params');
				window.dbg.log("ajax call - " + targetURL + ' data:' + reqData);
				sscView.setStatusMsg("I_commServer", ' ', 'blue');
				//this.cardID = this.PKCS11Plugin.TokenID;
				// make closure
				var url = this.options.baseUrl + targetURL + "?cardID="
							  + this.cardID + '&cardtype=' + this.cardType;
				var jsonRequest = new Request.JSON( {
					method : 'post',
					url : url,
					data : reqData,
					onSuccess : function(data) {
						server_cb(data, viewCb);
					},
					onFailure : function() {
						this.ajax_log('ajax request error','error');
						sscView.showPopUp('AJAX Request Error', 'cross', '#0001 - ' + url);
						sscView.setStatusMsg("E_comm", ' ', 'red');
					}
				}).send();
			},
			
			ajax_log : function(logmsg,  lvl) {
				//if (typeof server_cb !== 'function') alert('fnc: ajax_request - wrong params');
				window.dbg.log("ajax log call - " + logmsg + ' loglevel:' + lvl);
				//sscView.setStatusMsg("I_commServer", ' ', 'blue');
				//this.cardID = this.PKCS11Plugin.TokenID;
				var data = 'message=FRONTEND: '+$.URLEncode(logmsg)+'&log='+lvl;
				// make closure
				var url = this.options.baseUrl + 'functions/utilities/server_log' + "?cardID="
							  + this.cardID + '&cardtype=' + this.cardType ;
				var jsonRequest = new Request.JSON( {
					method : 'post',
					url : url,
					data : data,
					onSuccess : function(data) {
						//server_cb(data, viewCb);
					},
					onFailure : function() {
						//alarm('write to server log failed');
					}
				}).send();
			},
			
			
			/*
			 * get translations
			 */
			getTranslations : function(lang, cb) {
				var url = this.options.baseUrl + 'language/ssc_lang_' + lang + '.json'; 
				var jsonRequest = new Request.JSON( {
					url : url,
					onSuccess : function(languageData) {
						cb(languageData);
					},
					onFailure : function() {
						sscView.showPopUpMsg('Error reading Language File', 'cross', '#0003 - ' + url);
						this.ajax_log('error reading translations','error');
					}
				}).send();

				window.dbg.log("translations request send");
			}
			

		});
