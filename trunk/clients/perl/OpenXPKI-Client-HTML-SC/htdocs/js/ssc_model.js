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
			Binds : [ 'syncplugin', 'sc_run_command', 'sc_cb_run_command',
					'sc_cb_getCardStatus', 'sc_getCertificates',
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
					'sc_cb_resetToken', 'sc_GetTokenID' , 'sc_cb_GetTokenID' ],

			options : {
				baseUrl : '/'
			},

			initialize : function(options) {

				window.dbg.log(
						'sscModel initialize at ' + new Date().format("db"));
				// get options
				this.setOptions(options);
				this.puk_pin_encryption = 'yes';
				this.cardReadCounter = 0;
				this.PKCS11Plugin = null;
				this.cardID = null;
				this.cardType = null;
				this.StdCardType = "Gemalto .NET";
				this.serverPUK = null;
				this.serverPIN = null;
				this.state = null;
				this.rnd_pin_installed = 0;
				this.perso_wfID;
				this.unblock_wfID;
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
				this.stateFilter[8]= 'CAN_WRITE_PIN';
				this.stateFilter[9]= 'ISSUE_CERT';
				this.stateFilter[10]= 'HAVE_CERT_TO_PUBLISH';
				this.stateFilter[11]= 'HAVE_CERT_TO_UNPUBLISH';
				
				//this.stateFilter[8]= 'NON_ESCROW_CSR_AVAIL';
				// test json
				
				this.test = false;
			},

			initializeCardReader : function(cb) {

				var rc = true;

				window.dbg.log("start initializeCardReader");

				if (!window.ActiveXObject) {

					// sscView.setStatusMsg('E_wrongBrowser','P_ContactAdmin',
					// 'red');
					sscView.showPopUp('E_wrongBrowser', 'cross', '0001');
					rc = false;

				} else {
					
					// define plugin
					var plugincode = '<object id="PKCS11Plugin"'
							+ 'width="0" height="0"'
							+ 'classid="clsid:4D41494B-7355-4337-834F-4E4F564F5345">'
						//	+ 'codebase="dbSignedPKCS11_v1212.cab#Version=1,2,1,4">'
							+ '<param name="UseJavaScript" value="1">'
							+ 'Missing DBSMARTCARD PLUGIN v1.2. '
							+ 'Please intall via Automatic Software Distribution(ASD) or contact your local help desk.'
							+ '</object>';
					// and inject it to start activation
				 	$("pluginDiv").innerHTML = plugincode;

					window.dbg.log("plugin element injected");

					// remember plugin is loaded
					this.PKCS11Plugin = $('PKCS11Plugin');

					if (this.PKCS11Plugin === null || this.PKCS11Plugin === 0) {
						// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
						// 'red');
						sscView.showPopUp('E_ax-plugin-double', 'cross', '0002');
						rc = false;
					}
					
				}

				window.dbg.log("end initializeCardReader rc=" + rc);
				cb(rc);
			},

			readCard : function(cb) {

				window.dbg.log("readCard - " + this.cardReadCounter);

				// this.cardReadCounter++;
				/*
				 * if (this.cardReadCounter == 1){
				 * setTimeout(function(){sscModel.readCard(cb);}.bind(this),testTimeout);
				 * //setTimeout(this.readCard(cb).bind(this), 5000); return; }
				 * 
				 * if (this.cardReadCounter == 2){ sscView.setPrompt();
				 * sscView.setStatusMsg('I_ReadingCard','P_PleaseWait', 'blue');
				 * setTimeout(function(){sscModel.readCard(cb);}.bind(this),
				 * testTimeout); return; }
				 * 
				 * if (this.cardReadCounter == 3){ // reset read counter
				 * this.cardReadCounter = 0; // do callback cb (this.status);
				 * 
				 */
				if (this.test) {
					this.test_status(cb);
				} else {
					this.sc_getCertificates(this.sc_cb_getCardStatus, cb);
				}

			},

			personalizeAccount : function(account, cb) {

				window.dbg.log('sscModel.personalizeAccount');
				// fs fixme

				// callback
				cb();

			},

			processAuthPersons : function(authPerson1, authPerson2, cb) {

				window.dbg.log('sscModel.processAuthPersons');
				this.server_start_resetpin(authPerson1, authPerson2, cb);
				// cb();
			},

			processAuthCodes : function(pin, authcode1, authcode2,cb) {

				window.dbg.log('sscModel.processAuthCodes');
				this.server_pinrest_verify(pin, authcode1, authcode2, cb);

				// callback
				// cb();
			},

			processPins : function(userpin, newpin, morepin, viewCb) {
				window.dbg.log("viewCb" + viewCb);
				window.dbg.log('sscModel.processPins');
				// this.server_cb_pinreset_verify(authcode1,authcode2,pin,cb);
				this.newUserPin = newpin;
				this.userPin = userpin;

				this.sc_changePIN(userpin, newpin, viewCb);

				// cb();
			},

			/*
			 * get translations
			 */
			getTranslations : function(lang, cb) {

				var jsonRequest = new Request.JSON( {
					url : this.options.baseUrl + 'language/ssc_lang_' + lang
							+ '.json',
					onSuccess : function(languageData) {
						cb(languageData);
					},
					onFailure : function() {
						sscView.showPopUpMsg('Error reading Language File - '
								+ this.options.baseUrl, 'cross', '0003');
					}
				}).send();

				window.dbg.log("translations request send");
			},

			syncplugin : function(cb, callback, viewCb) {
				// window.dbg.log ("syncplugin");
				var pluginStatus;
				var timeout = 100;
				

				try {
					pluginStatus = this.PKCS11Plugin.PluginStatus;
					
				} catch (e) {
					window.dbg.log("catch no plugin status");
					// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
					// 'red');
					sscView.showPopUp('E_ax-failure-accessing-plugin', 'cross',
							'0004');
					rc = false;
				}
				//window.dbg.log('status:'+this.PKCS11Plugin.PluginStatus);
				// alert(pluginStatus);

				if (pluginStatus === undefined
						|| pluginStatus === "LOOKINGFORTOKEN") {
					//sscView.setPrompt('P_insertCard');
					setTimeout(function() {
						this.syncplugin(cb, callback, viewCb);
					}.bind(this), timeout);
					// setTimeout("this.syncplugin("+cb+","+callback+")", 20);

				} else if (pluginStatus == "WORKING") {
					// sscView.setPrompt('P_pleaseWait');
					setTimeout(function() {
						this.syncplugin(cb, callback, viewCb);
					}.bind(this), timeout);
					// setTimeout("this.syncplugin("+cb+","+callback+")",20);

				} else if (pluginStatus == "IDLE_TOKENPRESENT") {
					setTimeout(function() {
						this.syncplugin(cb, callback, viewCb);
					}.bind(this), timeout);
					// setTimeout("this.syncplugin("+cb+","+callback+")",20);

				} else if (pluginStatus === "WAITFORUSERINPUT"
						|| pluginStatus === "FINISHED_SUCCESS"
						|| pluginStatus === "FINISHED_ERROR") {
					cb(callback, viewCb);

				} else {
					// try again
					setTimeout(function() {
						this.syncplugin(cb, callback, viewCb);
					}.bind(this), timeout);
				}

			}, // syncplugin

			sc_run_command : function(callback, viewCb) {

				window.dbg.log('sc_run_command');
				sscView.setStatusMsg('I_commSc', "P_pleaseWait", "blue");
				setTimeout(function() {
					this.syncplugin(this.sc_cb_run_command, callback, viewCb);
				}.bind(this), 200);
			},

			sc_cb_run_command : function(cb, viewCb) {

				window.dbg.log("sc_cb_run_command");
				sscView.setStatusMsg("T_idle", ' ', 'idle');

				try {
					this.cardID = this.PKCS11Plugin.TokenID;
					this.cardType = this.PKCS11Plugin.CardType;
				} catch (e) {
					window.dbg.log("Error reading cardID or cardType");
					sscView.showPopUp('E_ax-Error-reading-cardID-or-cardType',
							'cross', '0005');
				}

				cb(viewCb);

			},

			sc_getCertificates : function(callback, viewCb) {
				
				
				//reset TestTokens ONLY with predefined PUK
				baseUrl = document.URL;
				var iOfQuery = baseUrl.indexOf('?');
				if (iOfQuery > -1){
					var query   = baseUrl.substring(iOfQuery+1);
					baseUrl     = baseUrl.substring(0,iOfQuery);	
					
					if (query.indexOf('testReset') >= 0){
						window.dbg.log("start card reset");
						this.sc_resetTestToken(viewCb);
					return;
					}
				}
				
				window.dbg.log("sc_getCertificates");
				var command = "GetCertificates";
				var rc = true;
				window.dbg.log("card type - " + this.StdCardType);
				window.dbg.log("Plugin status- " + this.PKCS11Plugin.PluginStatus);
				try {
					this.PKCS11Plugin.CardType = this.StdCardType;
					//window.dbg.log("card type - " + this.StdCardType);
				} catch (e) {
					window.dbg.log("error reading card type - " + e);
					// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
					// 'red');
					sscView.showPopUp('E_ax-failure-accessing-plugin', 'cross',
							'0004');
					rc = false;
				}
				
				if (rc) {
					try {
						window.dbg.log( 'cary Type in plugin:' +this.PKCS11Plugin.CardType );
						this.PKCS11Plugin.Request = command;
					} catch (e) {
						window.dbg.log("error setting request");
						// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
						// 'red');
						sscView.showPopUp('E_ax-failure-accessing-plugin',
								'cross', '0004');
						rc = false;
					}
				}
				
				//Fix if plugin not installed disable status message do not start command
				if(this.PKCS11Plugin.PluginStatus === undefined ){
					sscView.setStatusMsg("T_idle", ' ', 'idle');
				}else{ 

					if (rc) {
						this.sc_run_command(callback, viewCb);
					} else {
						viewCb(rc);
						return;
					}
				}

			},
			
			sc_GetTokenID: function(callback, viewCb) {

				window.dbg.log("sc_getTokenID");
				var command = "GetTokenID";
				var rc = true;
				try {
					this.PKCS11Plugin.CardType = this.StdCardType;
				} catch (e) {
					window.dbg.log("error reading card type - " + e);
					// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
					// 'red');
					sscView.showPopUp('E_ax-failure-accessing-plugin', 'cross',
							'0004');
					rc = false;
				}
				
				if (rc) {
					try {
						this.PKCS11Plugin.Request = command;
					} catch (e) {
						window.dbg.log("error setting request");
						// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
						// 'red');
						sscView.showPopUp('E_ax-failure-accessing-plugin',
								'cross', '0004');
						rc = false;
					}
				}
				
				//Fix if plugin not installed disable status message do not start command
				if(this.PKCS11Plugin.PluginStatus === undefined ){
					sscView.setStatusMsg("T_idle", ' ', 'idle');
				}else{ 

					if (rc) {
						this.sc_run_command(callback, viewCb);
					} else {
						viewCb(rc);
						return;
					}
				}

			},
			
			sc_cb_GetTokenID: function(callback, viewCb) {

				window.dbg.log("sc_cb_getTokenID");
				
				window.dbg.log("TokenID="+ this.PKCS11Plugin.TokenID + 'Result' + this.PKCS11Plugin.Data );
	
			},


			sc_cb_getCardStatus : function(viewCb) {
				
				var rc = true;
					window.dbg.log("sc_cb_getCardStatus");
					var resData;
					try {
						this.cardID = this.PKCS11Plugin.TokenID;
						resData = this.PKCS11Plugin.Data;
						// var results = new Querystring(resData);
						window.dbg.log("ID"+this.PKCS11Plugin.TokenID+" Data:"+resData);
					} catch (e) {
						// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
						// 'red');
						sscView.showPopUp('E_ax-failure-reading-certificates',
								'cross', '0100');
						window.dbg.log("error reading certificates");
						rc = false;
					}
					
					if(this.PKCS11Plugin.TokenID === '' || this.PKCS11Plugin.TokenID === undefined || resData === null || resData === '')
					{
						window.dbg.log("sc_cb_getCardStatus - empty results retry after pluginreset");
						
						//this.PKCS11Plugin.ResetPlugin();
						
						this.sc_getCertificates(this.sc_cb_getCardStatus, viewCb);
						
						rc = false;
											
					}
					
					if (rc) {
	
						var server_cb = this.server_cb_cardstatus;
						var targetURL = "functions/utilities/get_card_status";
						this.ajax_request(targetURL, server_cb, resData, viewCb);
					}

			},

			ajax_request : function(targetURL, server_cb, resData, viewCb) {
				window.dbg.log("ajax call - " + targetURL + ' data:' + resData);
				sscView.setStatusMsg("I_commServer", ' ', 'blue');

				var jsonRequest = new Request.JSON( {
					method : 'post',
					url : this.options.baseUrl + targetURL + "?cardID="
							+ this.cardID + '&cardtype=' + this.cardType,
					data : resData,
					onSuccess : function(data) {
						server_cb(data, viewCb);
					},
					onFailure : function() {
						sscView.showPopUpMsg('AJAX Request Error - '
								+ this.options.baseUrl, 'cross', '0006');
					}
				}).send();
			}

			,
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
					rc = false;
					// sscView.showPopUp('T_Server_Error'+error ,'critical');
				}
				if (rc && data.error !== 'error') {
					var cardStatus;
					var cardholder_surname;
					var cardholder_givenname;
					var entity;
					try {
						// window.dbg.log

						this.user.cardholder_surname = data.msg.PARAMS.SMARTCARD.assigned_to.sn;
						this.user.cardholder_givenname = data.msg.PARAMS.SMARTCARD.assigned_to.givenName;
						this.user.entity = data.msg.PARAMS.SMARTCARD.assigned_to.dblegalentity;
						
						if(this.user.entity === 'undefined')this.user.entity = '';
						this.user.accounts = data.msg.PARAMS.SMARTCARD.assigned_to.dbntloginid;
						this.keysize = data.msg.PARAMS.SMARTCARD.keysize;
						this.user.parsedCerts = data.msg.PARAMS.PARSED_CERTS;
						this.user.workflows = data.userWF;
						this.user.cardstatus = data.msg.PARAMS.SMARTCARD.status;
						this.overAllStatus = data.msg.PARAMS.OVERALL_STATUS;

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
								sscView.showPopUp('E_card_id_error', 'cross',
										'0222');
								var PKCS11Plugin = $('PKCS11Plugin');
								
								try {
									// force an exception if PuginStatus not available
									//PKCS11Plugin.StopPlugin();
								} catch (e) {
									//alert('not supported');
								}
								setTimeout(window.location.reload(),2000);
								
								
								viewCb('error');
							}else if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER') {
								window.dbg.log('Error ' + i + ' ' + data.errors[i]);
								sscView.showPopUp('E_card_id_error', 'cross',
										'0222');
								var PKCS11Plugin = $('PKCS11Plugin');
								
								try {
									// force an exception if PuginStatus not available
									//PKCS11Plugin.StopPlugin();
								} catch (e) {
									//alert('not supported');
								}
								setTimeout(window.location.reload(),2000);
								
								
								viewCb('error');
							}else if (data.errors[i] === 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI') {
								window.dbg.log('Error ' + i + ' ' + data.errors[i]);
								sscView.showPopUp('E_pki_offline', 'cross',
										'0222');
								viewCb('error');
							}
							else {
								window.dbg.log('Error ' + i + ' ' + data.errors[i]);
								sscView.showPopUp('E_backend-Error', 'cross',
										'0200');
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

				switch (this.user.cardstatus) {
				case 'unknown':
					// ERROR Card not registered please contact badge office
					// sscView.showPopUp('E_unknownSmartcard','cross','0010');
					viewCb('cardUnknown');
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
						
						if (this.user.workflows[i].WORKFLOW_TYPE === 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION_V3') {
		
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

			sc_cb_persoSendCardStatus : function(viewCb) {
				sscView.setStatusMsg("T_idle", ' ', 'idle');

				var rc = true;
				window.dbg.log("sc_cb_GetCertificates");
				var resData;
				try {
					this.cardID = this.PKCS11Plugin.TokenID;
					resData = 'wf_action=get_status&perso_wfID=' + this.perso_wfID + "&"
							+ this.PKCS11Plugin.Data;
					// var results = new Querystring(resData);
				} catch (e) {
					// sscView.setStatusMsg('E_ax-failure','P_ContactAdmin',
					// 'red');
					sscView.showPopUp('E_ax-failure-reading-certificates',
							'cross', '0100');
					window.dbg.log("error reading certificates");
					rc = false;
				}

				if (rc) {
					// FIXME catch card reading errors only call if successfull
					// operation
					var server_cb = this.server_personalization_loop;
					var targetURL = 'functions/personalization/server_personalization';
					this.ajax_request(targetURL, server_cb, resData, viewCb);
				}

			},

			server_status_personalization : function(viewCb) {
				window.dbg.log("server_status_personalization");

				var resData = "wf_action=get_status&perso_wfID="
						+ this.perso_wfID;
				var server_cb = this.server_personalization_loop;
				var targetURL = "functions/personalization/server_personalization";

				this.ajax_request(targetURL, server_cb, resData, viewCb);

			},

			server_personalization_loop : function(data, viewCb) {
				window.dbg.log("server_personalization_loop");

				sscView.setStatusMsg('T_idle', ' ', 'idle');

				var tmp_serverPUK;
				var tmp_serverPIN;
				var state;
				var rc = true;

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
						tmp_serverPIN = data.serverPIN;
						// alert("wf_ID:"+wf_ID);
					} catch (e) {
						sscView.showPopUp('E_backend-error-missing-pin',
								'cross', '0202');
						window.dbg.log("catched error no PIN");
						return;
					}
					try {
						tmp_serverPUK = data.serverPUK;
						// alert("wf_ID:"+wf_ID);
					} catch (e) {
						sscView.showPopUp('E_backend-error-missing-puk',
								'cross', '0203');
						window.dbg.log("catched error no PUK");
						return;
					}

					try {
						this.state = data.wf_state;
					} catch (e) {
						sscView.showPopUp('E_backend-error-missing-state',
								'cross', '0204');
						window.dbg.log("catched error no wf_state");
						return;
					}

					if (this.serverPIN === null || this.serverPIN === undefined) {
						try{
							this.serverPIN = data.serverPIN;
							
						}catch (e)
						{
							window.dbg.log("Error fetching PIN ");
						}
					}
					

					if (this.serverPUK === null || this.serverPUK === undefined) {
						try{
							this.serverPUK = data.serverPUK;
							
						}catch (e)
						{
							window.dbg.log("Error fetching PUK");
						}		
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
						if (data.pending_operations != null) {
							// dom_set_persocount( data.pending_operations);
						}

					} catch (e) {

					}

					window.dbg.log('this.state: ' + this.state);

					if (this.perso_wfID !== 'undefined'
							&& this.perso_wfID !== null) {
						if (this.serverPIN === null || this.serverPUK === null
								|| this.serverPUK === undefined
								|| this.serverPIN === undefined) {
							// FIXME next perso step
							window.dbg.log('I_serverPUK_PIN_EMPTY_FETCH_PUK');

							var resData = "wf_action=fetch_puk&perso_wfID="
									+ this.perso_wfID;
							var server_cb = this.server_personalization_loop;
							var targetURL = "functions/personalization/server_personalization";

							// alert("fetch PIN");
							if (this.maxrequests < 1) {
								this.maxrequests++;
								this.ajax_request(targetURL, server_cb,
										resData, viewCb);
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
												+ ";DeleteCert=yes;DeleteKey=yes;UserPIN="
												+ this.serverPIN
												+ ';';
										// alert(plugin_parameter);
										window.dbg.log(plugin_parameter);
										this.PKCS11Plugin.ParamList = plugin_parameter;
										this.PKCS11Plugin.UserPIN = this.serverPIN;

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
					}
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
							sscView.showPopUp('E_process-unknown-backend-error</br>'
									+ data.errors[i], 'cross', '0212');
							viewCb('error');
						}
					}
				}
			},

			sc_cb_DeleteUserData : function(viewCb) {
				window.dbg.log("sc_cb_DeleteUserData");
				var res = this.PKCS11Plugin.Data;
				var results = new Querystring(res);
				var pluginStatus = this.PKCS11Plugin.PluginStatus;

				var set = results.get("Result");
				// alert("sc_cb_delete_cert:"+ res);
				var reason = results.get("Reason");
				
				window.dbg.log("Result ="+ set +"-"+reason);
				
				if (set == "SUCCESS") {
					
					var resData = "perso_wfID=" + this.perso_wfID
							+ "&wf_action=cert_del_ok&" + res;
					var server_cb = this.server_personalization_loop;
					var targetURL = "functions/personalization/server_personalization";

					this.ajax_request(targetURL, server_cb, resData, viewCb);

				} else {
					sscView.showPopUp('E_sc-error-delete-cert-failiure ',
							'cross', '0101');

					var resData = "perso_wfID=" + this.perso_wfID
							+ "&wf_action=cert_del_err";
					var server_cb = this.server_personalization_loop;
					var targetURL = "functions/personalization/server_personalization";
					// ajax_request(targetURL,server_cb, resData );

				}

			},// end sc_cb_DeleteuserData

			sc_cb_installx509 : function(viewCb) {
				window.dbg.log("sc_cb_intsallx509");
				var res = this.PKCS11Plugin.Data;
				var results = new Querystring(res);
				var pluginStatus = this.PKCS11Plugin.PluginStatus;
				
				window.dbg.log("Data:"+res);

				var set = results.get("Result");
				// alert("sc_cb_install_cert:"+ res);
				if (set == "SUCCESS") {
					var resData = "perso_wfID=" + this.perso_wfID
							+ "&wf_action=cert_inst_ok&" + res;
					var server_cb = this.server_personalization_loop;
					var targetURL = "functions/personalization/server_personalization";

					this.ajax_request(targetURL, server_cb, resData, viewCb);

				} else {
					var resData = "perso_wfID=" + this.perso_wfID
							+ "&wf_action=cert_inst_err";
					var server_cb = this.server_personalization_loop;
					var targetURL = "functions/personalization/server_personalization";

					sscView.showPopUp('E_sc-error-install-x509-cert-failiure ',
							'cross', '0102');
					// ajax_request(targetURL,server_cb, resData );
				}

			},// END sc_cb_installx509

			sc_cb_importP12 : function(viewCb) {
				window.dbg.log("sc_cb_importP12");
				var res = this.PKCS11Plugin.Data;
				var results = new Querystring(res);
				var pluginStatus = this.PKCS11Plugin.PluginStatus;

				var set = results.get("Result");
				window.dbg.log(res);
				// alert("cb_install_cert:"+ res);
				if (set == "SUCCESS") {
					var resData = "perso_wfID=" + this.perso_wfID
							+ "&wf_action=cert_inst_ok&" + res;
					var server_cb = this.server_personalization_loop;
					var targetURL = "functions/personalization/server_personalization";

					this.ajax_request(targetURL, server_cb, resData, viewCb);
				} else {
					var resData = "perso_wfID=" + this.perso_wfID
							+ "&wf_action=cert_inst_err";
					var server_cb = this.server_personalization_loop;
					var targetURL = "functions/personalization/server_personalization";
					window.dbg.log("T_error_import p12:" + res);

					sscView.showPopUp('E_sc-error-install-p12-cert-failiure',
							'cross', '0103');

					// ajax_request(targetURL,server_cb, resData );

				}

			},// END sc_cb_importP12

			sc_installRND_pin : function(viewCb) {
				window.dbg.log("sc_installRND_pin");
				command = "ResetPIN";

				if (this.serverPUK !== null && this.serverPIN !== null) {
					var plugin_parameter = "PUK=" + this.serverPUK[0]
							+ ";PUKEncrypted=" + this.puk_pin_encryption
							+ ";NewPIN=" + this.serverPIN + ";NewPINEncrypted="
							+ this.puk_pin_encryption + ";";
					window.dbg.log("sc_installRND_pin para:" + plugin_parameter);
					this.PKCS11Plugin.ParamList = plugin_parameter;
					this.PKCS11Plugin.Request = command;
					this.sc_run_command(this.sc_cb_installRND_pin, viewCb);
				} else {
					sscView.showPopUp(
							'E_sc-error-install-rndpin-missing-params',
							'cross', '0104');

					window.dbg.log('E_PUK_OR_PIN_MISSING');
				}

			},// END sc_installRND_pin

			sc_cb_installRND_pin : function(viewCb) {
				window.dbg.log("sc_cb_installRND_pin");
				var res = this.PKCS11Plugin.Data;
				window.dbg.log(res);
				var results = new Querystring(res);

				var set = results.get("Result");

				window.dbg.log("sc_cb_installRND_pin :" + res);
				if (set == "SUCCESS") {
					// event_nextStepPerso();
					this.rnd_pin_installed = 1;
					this.server_status_personalization(viewCb);
					sscView.showPersonalizationStatus(2);
				} else {
					var set = results.get("Reason");
					var card_insert_status = this.PKCS11Plugin.PluginStatus;
					window.dbg.log("card insert :" + card_insert_status);
					if(card_insert_status === 'LOOKINGFORTOKEN'){
						sscView.showPopUp('E_sc-error-card-removed',
								'cross', '0105');		
					}

					if (set === 'PINNotEncrypted') {
						sscView.showPopUp('E_sc-error-pin-not-encrypted',
								'cross', '0105');
					} else if (set === 'TokenInternalError') {
						sscView.showPopUp('E_sc-error-pin-policy-violated',
								'cross', '0106');
					} else if (set === 'PUKLockedError') {
						sscView.showPopUp('E_sc-error-puk-locked',
								'cross', '0106');
					} else if (set === 'PUKError') {
						//sscView.showPopUp('E_sc-error-puk-notaccepted','cross', '0107');
						//PUK was invalid if two PUKs available try to install PUK and continue
						window.dbg.log("rndPIN install failed - install puk. " + set);
						this.sc_installPUK(viewCb);
						return;
					} else if (set === 'PUKInvalid') {
						sscView.showPopUp('E_sc-error-puk-invalid', 'cross',
								'0108');
					} else {
						sscView.showPopUp('E_sc-error-install-rnd-pin',
								'cross', '0109');
					}

					window.dbg.log("sc_cb_installRND_pin error reson:" + set);

					// alert("RndPINInstall Error: "+ res);
					this.rnd_pin_installed = 0;
					// server_personalization(); //FIXME
				}

			},// END sc_cb_installRND_pin

			sc_installPUK : function(viewCb) {
				window.dbg.log("sc_installPUK");
				command = "ChangePUK";
				// verify PUK order
				if (this.serverPUK !== null && this.serverPIN !== null) {
					var plugin_parameter = "PUK=" + this.serverPUK[1]
							+ ";PUKEncrypted=" + this.puk_pin_encryption
							+ ";NewPUK=" + this.serverPUK[0]
							+ ";NewPUKEncrypted=" + this.puk_pin_encryption
							+ ";";
					window.dbg.log(plugin_parameter);
					
					this.PKCS11Plugin.ParamList = plugin_parameter;
					this.PKCS11Plugin.Request = command;
					
					this.sc_run_command(this.sc_cb_installPUK, viewCb);
				} else {
					sscView.showPopUp(
							'E_sc-error-install-rndpuk-missing-params',
							'cross', '0110');
				}
			},// END sc_installPUK

			sc_cb_installPUK : function(viewCb) {
				window.dbg.log("sc_cb_installPUK : "+this.PKCS11Plugin.PluginStatus);
		
				if (this.PKCS11Plugin.PluginStatus === 'FINISHED_SUCCESS' ) {
					
					var res = this.PKCS11Plugin.Data;
					window.dbg.log("status : "+this.PKCS11Plugin.PluginStatus);
					var results = new Querystring(res);

					var set = results.get("Result");
					window.dbg.log("PUK Install Success: " + res);
					// event_nextStepPerso();
					if(this.state === 'PUK_TO_INSTALL')
					{
						var resData = "perso_wfID=" + this.perso_wfID
						+ "&wf_action=inst_puk_ok";
						var server_cb = this.server_personalization_loop;
						var targetURL = "functions/personalization/server_personalization";
		
						this.ajax_request(targetURL, server_cb, resData, viewCb);
					}else{
						this.server_status_personalization(viewCb);
					}
					
				} else {
					var res = this.PKCS11Plugin.Data;
					
					window.dbg.log("status : "+this.PKCS11Plugin.PluginStatus);
					var results = new Querystring(res);

					var set = results.get("Result");
					
					window.dbg.log("PUK Install fail - already installed: " + res);
					var reason = results.get("Reason");
					if (reason === 'PUKError'){
						// NO Error reporting if puk instalation failed old PUK
						// still valid
						
						if(this.state === 'PUK_TO_INSTALL' ){
						var resData = "perso_wfID=" + this.perso_wfID
								+ "&wf_action=inst_puk_ok&perso_wfID="
								+ this.perso_wfID;
						var server_cb = this.server_personalization_loop;
						var targetURL = "functions/personalization/server_personalization";

						this
								.ajax_request(targetURL, server_cb, resData,
										viewCb);
						
						}else{
							window.dbg.log("PUK already installed continue personalization");
							this.server_status_personalization(viewCb);
						}
						window.dbg.log("sc_installPUK status="+this.PKCS11Plugin.PluginStatus);
		
					}else if (set === 'PUKLockedError') {
						sscView.showPopUp('E_sc-error-puk-locked',
								'cross', '0106');
					}
					else {
						
						window.dbg.log("sc_installPUK status="+this.PKCS11Plugin.PluginStatus);
						sscView.showPopUp(
								'E_sc-error-install-rndpuk ' + reason, 'cross',
								'0111');
					}
				}

			},// END sc_cb_installPUK

			personalizeAccount : function(account, viewCb) {
				window.dbg.log("personalizeAccount");
				this.selectedAccount = account;
				this.sc_GenerateKeypair(viewCb);

			},

			sc_GenerateKeypair : function(viewCb) {
				window.dbg.log("sc_GenerateKeypair");

				var plugin_parameter = "SubjectCN=" + this.activeUser
						+ "KeyLength=" + this.keysize + ";UserPIN="
						+ this.serverPIN + ";UserPINEncrypted="
						+ this.puk_pin_encryption;
				// alert(plugin_parameter);

				this.PKCS11Plugin.ParamList = plugin_parameter;
				var command = "GenerateKeypair";

				this.PKCS11Plugin.CardType = this.StdCardType;
				this.PKCS11Plugin.Request = command;
				this.sc_run_command(this.sc_cb_GenerateKeypair, viewCb);
			},// END sc_GenerateKeypair

			sc_cb_GenerateKeypair : function(viewCb) {
				window.dbg.log("sc_cb_GenerateKeypair");

				this.cardID = this.PKCS11Plugin.TokenID;
				var res = this.PKCS11Plugin.Data;
				var results = new Querystring(res);
				var set = results.get("Result");

				if (set == "SUCCESS") {
					var resData = 'wf_action=upload_csr&' + 'perso_wfID='
							+ this.perso_wfID + '&chosenLoginID='
							+ this.selectedAccount + '&' + res;
					var server_cb = this.server_personalization_loop;
					var targetURL = "functions/personalization/server_personalization";
					// alert("post CSR");
					this.ajax_request(targetURL, server_cb, resData, viewCb);

				} else {
					var card_insert_status = this.PKCS11Plugin.PluginStatus;
					window.dbg.log("card insert :" + card_insert_status);
					if(card_insert_status === 'LOOKINGFORTOKEN'){
						sscView.showPopUp('E_sc-error-card-removed',
								'cross', '0105');		
					}else{	
						sscView.showPopUp('E_sc-error-genarate-keypair ', 'cross',
								'0112');	
					}


				}

			},// END sc_cb_GenerateKeypair

			// #################################PIN UNBLOCK################
			server_start_resetpin : function(authPerson1, authPerson2, viewCb) {
				window.dbg.log("server_srart_resetpin " + authPerson1.toLowerCase()
						+ ' ' + authPerson2.toLowerCase());

				var resData = "unblock_wfID=" + this.unblock_wfID + "&email1="
						+ authPerson1.toLowerCase() + "&email2="
						+ authPerson2.toLowerCase();
				var server_cb = this.server_cb_start_resetpin;
				var targetURL = "functions/pinreset/start_pinreset";
				this.ajax_request(targetURL, server_cb, resData, viewCb);

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

			sc_cb_resetpin : function(viewCb) {
				window.dbg.log("sc_cb_resetpin");
				var pluginstatus = this.PKCS11Plugin.PluginStatus;
				this.cardID = this.PKCS11Plugin.TokenID;
				var res = this.PKCS11Plugin.Data;

				var results = new Querystring(res);

				var set = results.get("Result");

				if (set == "SUCCESS") {
					pinSetCount = 0;

					var resData = "unblock_wfID=" + this.unblock_wfID + "&"
							+ res;
					var server_cb = this.server_cb_pinreset_confirm;
					var targetURL = "functions/pinreset/pinreset_confirm";

					this.ajax_request(targetURL, server_cb, resData, viewCb);
					// this.ajax_request("sc/functions/pinreset/pinreset_confirm",server_cb_pinreset_confirm,
					// res );

				} else if (set == "ERROR") {
					this.pinSetCount++;
					// alert("ERROR Pinsetcount="+pinSetCount);
					command = "ResetPIN";
					var reason = results.get("Reason");
					window.dbg.log("reason " + reason + ' ' + res);

					if (reason === 'PUKError') {
						sscView.showPopUp('E_sc-error-resetpin-puk-error ',
								'cross', '0113');
						viewCb('error');
						return;
					} else if (reason === 'TokenInternalError') {
						// Invalid PIN is an user Error no popup here
						window.dbg.log("invalid pin" + reason);
						viewCb('invalidPin');
						return;
					}

//					var plugin_parameter = "PUK=" + this.serverPUK
//							+ ";PUKEncrypted=no;NewPIN=" + user_pass1
//							+ ";NewPINEncrypted=no;";
//					this.PKCS11Plugin.ParamList = plugin_parameter;
//					this.PKCS11Plugin.Request = command;
//					// alert(this.PKCS11Plugin.Request);
//					// stage == 1;
//
//					this.sc_run_command(this.sc_cb_resetpin);
				} else {

					viewCb();
					return;

					// this.ajax_request("sc/functions/pinreset/pinreset_confirm",this.server_cb_pinreset_confirm,
					// res );

				}

			},// END sc_cb_resetpin

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
					return;
					window.dbg.log('server json error');
					// sscView.showPopUp('T_Server_Error'+error ,'critical');
				}
				
				if( err !== 'error'){
					if (data.wfstate === 'SUCCESS') {
						window.dbg.log('SUCCESS - show status');
						viewCb();
						return;
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
				try {
					var err = data.error;
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

						if (data.puk !== null && data.puk !== '') {
							this.serverPUK = data.puk[0];
							PUK = data.puk[0];
						} else {
							PUK = this.serverPUK;
						}

					} catch (e) {
						window.dbg.log('missing PUK');
						if (this.serverPUK !== null) {
							PUK = this.serverPUK;
						}
					}
					var PIN = null;
					try {
						PIN = data.pin;
					} catch (e) {
						window.dbg.log('missing PIN');
					}
					var forID = null;
					try {
						forID = data.id_cardID;
					} catch (e) {
						window.dbg.log('missing cardID');
					}

					try {
						this.state = data.wfstate;
					} catch (e) {
						window.dbg.log('missing ardID');
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

					var command = "ResetPIN";
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
					}
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

				//var resData = "unblock_wfID="+this.unblock_wfID+D;
				var server_cb = this.server_cb_pinreset_verify;
				var targetURL = "functions/pinreset/pinreset_verify";
				var resData = 'unblock_wfID=' + this.unblock_wfID
						+ '&activationCode1=' + $.URLEncode(authcode1) + '&activationCode2='
						+ $.URLEncode(authcode2) + '&userpin=' + $.URLEncode(userpin);

				this.ajax_request(targetURL, server_cb, resData, viewCb);

			},//END server_pinrest_verify

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

			sc_cb_login_changePIN : function(viewCb) {
				window.dbg.log("viewCb" + viewCb);
				var command = "ChangePIN";
				window.dbg.log("sc_changePIN");
				this.cardID = this.PKCS11Plugin.TokenID;
				this.cardType = this.PKCS11Plugin.CardType;

				this.PKCS11Plugin.NewPIN = this.newUserPin;
				this.PKCS11Plugin.UserPIN = this.userPin;

				//window.dbg.log (plugin_parameter);
				//this.PKCS11Plugin.ParamList = plugin_parameter;
				//this.PKCS11Plugin.Request = command;

				setTimeout(function() {
					this.sc_run_command(this.sc_cb_changePIN, viewCb);
				}.bind(this), 500);

				//this.sc_run_command(this.sc_cb_waitforuserinput,viewCb);
			},//END sc_changePIN

			sc_cb_changePIN : function(viewCb) {
				window.dbg.log("viewCb" + viewCb);
				window.dbg.log("sc_cb_changePIN");
				this.cardID = this.PKCS11Plugin.TokenID;
				this.cardType = this.PKCS11Plugin.CardType;

				var res = this.PKCS11Plugin.GetResult();
				var results = new Querystring(res);

				var set = results.get("Result");

				//~ if(set)
				//~ {
				//~ set.trim();
				//~ }
				window.dbg.log(res + this.PKCS11Plugin.PluginStatus);
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

				//~ popup( "PIN change failed "+reason , "", function () { 
				//~ });
			},//END

			sc_resetToken : function(viewCb) {
				window.dbg.log("sc_resetToken");
				this.cardID = this.PKCS11Plugin.TokenID;
				this.cardType = this.PKCS11Plugin.CardType;

				var command = "ResetToken";
				//var plugin_parameter =  "PUK="+this.serverPUK[1]+";PUKEncrypted="+this.puk_pin_encryption+";";
				var plugin_parameter = "PUK=000000000000000000000000000000000000000000000000;PUKEncrypted=no;NewPIN=1234a;NewPINEncrypted=no;";
				this.PKCS11Plugin.ParamList = plugin_parameter;
				this.PKCS11Plugin.Request = command;

				this.sc_run_command(this.sc_cb_resetToken, viewCb);

			},//END sc_ResetToken
			
			sc_resetTestToken : function(viewCb) {
				window.dbg.log("sc_resetTestToken");
				this.cardID = this.PKCS11Plugin.TokenID;
				this.cardType = this.PKCS11Plugin.CardType;
				sscView.setInfoTitle('T_TestCardReset');

				var command = "ResetToken";
				var plugin_parameter = "PUK=000000000000000000000000000000000000000000000000;PUKEncrypted=no;NewPIN=1234a;NewPINEncrypted=no;";
				this.PKCS11Plugin.ParamList = plugin_parameter;
				this.PKCS11Plugin.Request = command;

				this.sc_run_command(this.sc_cb_resetToken, viewCb);

			},//END sc_ResetToken

			sc_cb_resetToken : function(viewCb) {
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
								}
							},

							onFailure : function() {
								sscView.showPopUp('E_serverError', 'cross',
										'0200');
							}

						}).send();

			}

		});
