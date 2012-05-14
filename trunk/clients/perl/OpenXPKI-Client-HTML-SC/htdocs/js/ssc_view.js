/* SVN FILE: $Id$ */
/**
* dbSSC - Smartcard Badge Self Service Center
* Frontend View
* 
* @package SCC
* @subpackage SSC_FRONTEND
* @author $Author$
* @copyright $Copyright$
* @version $Revision$
* @lastrevision $Date$
* @modifiedby $LastChangedBy$
* @lastmodified $LastChangedDate$
* @license $License$
* @filesource $URL$
*/
var SSC_VIEW = new Class(
		{
			Implements : [ Options ],

			/**
			 * default language
			 */
			options : {
				language : 'us',
				baseUrl  : '/',
				query 	 : '',
				mode	 : 'perso'
			},
			/**
			 * bindings
			 */
			Binds : ['init_step2', '_performBackAction', '_performNextAction',
					'processAccountSelection', 'processAccountSelection_step2',
					'processAuthPersons', 'processAuthPersons_done',
					'processPersonalization','processPersonalization_done',
					'processPins', 'processPins_done', 'processAuthCodes_done',
					'handleStatus', 'processCardSelection', 'showSmartcardStatus','showAuthCode',
					'showAuthPersonDlg','processBackUnblock',
					'init_step3', 'init_step4', 'init_step5', 'unblockCard', 'changePin', '_tr' ,'setTranslatedElementText',
					'_changeLanguage_step2','cardObserver','cardObserverCB','testPrivateKey','enableSSO', 'confOutlook', 'showHints',
					'processTestPrivateKey','testPrivateKeyCB', 'cleanUpCard', 'setButton' , 'handleKeyDown'],
			
			/*
			 * chain of command params
			 */	
			
			expFnc:[
			         {name : 'kiosk',fnc: function (){
			        	 				$('windowCloser').addClass('active');
			        	 				$('windowCloser').addEvent('click', function(){alert ('close'); window.close();});
			        	 				return true;
		           	   					}
			  		 },
			  		 
			  		 {name : 'addHello',fnc: function (){
						        	   		this.mainMenu.push({'text':'Hello','id':'btnHello', 'fnc': function(){alert('hello');}});
						        	   		return true;
						        	      }
					 },
					 
			         {name : 'testReset',fnc:function (){
			        	 	sscModel.resetToken = true;
						   	return true;
						    }
			         },
			         
			         {name : 'outlook',fnc:function (){
			        	 	sscModel.allowOutlook = true;
						   	return true;
						    }
			         },
			         
			        
			         
			         
			         {name: 'lkeys',fnc:  function (){this._showLanguageKeys(); return true;}
			         },
			         
			         {name: 'dbg',fnc:  function (){
						        	   if (this.options.query.length > 3)
						        		   window.dbg.log('we are in debug mode');
						        	   return true;
					       			}
				     }
			],
			
			statusHandler:[
			               
			     {status: 'activateSc', handler: function(){}},
							               
				 {status: 'cardBlocked', handler: function(){
					 						this.setPrompt('P_cardBlocked');
					 						this.setInfoRight('IT_Info','I_cardBlocked');}},
				 			
	 			 {status: 'cardNotActivated', handler: function(){
	 				 						this.setPrompt('P_cardNotActivated');
	 				 						this.setInfoRight('IT_Info','I_cardNotActivated');}},
				
	 			 {status: 'cardUnknown', handler: function(){
											this.setPrompt('P_cardUnknown');
											this.setInfoRight('IT_Info','I_cardUnknown');}},
											
				 {status: 'contPerso', handler: function(){
											if (sscModel.getReCert()){
												// continue recertification
												this.setInfoRight('IT_Info','I_Recert');
												this.setInfoTitle('T_RecertTitle');
												this.setNextAction('T_contRecert',this.processPersonalization, true);
											} else {
												// continue personalization
												this.setInfoRight('IT_Info','I_notPersonalized');
												this.setInfoTitle('T_PersoTitle');
												this.setNextAction('T_contPerso',this.processPersonalization, true);
											}}},
				
			 
				 			
				 {status:  'error', handler: function(){this.setInfoTitle('');}},
							
			     {status: 'enterAuthcodes', handler: function(){
									this.actCode1 = this.actCode2 = ''; // clear authcodes 
									this.showPinDlg(false);
									this.setInfoRight('IT_Info', 'I_actStep2');
									if (sscModel.user.cardActivation  === true ){
										this.setInfoTitle('T_ScActivationStep2');
										this.setNextAction('T_proceedActStep2', this.processPins, true);
										this.setBackAction('T_chooseAuthPers', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
									}else{
										this.setInfoTitle('T_cardUnblock');
										this.setNextAction('T_cardUnblock', this.processPins, true);
										this.setBackAction('T_chooseAuthPers', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
								
									}}},
									
				{status: 'enterAuthPersons', handler: function(){	
					 				this.actCode1='';
					 				this.actCode2='';
				 					this.showAuthPersonDlg();
									if (sscModel.user.cardActivation === true){
										this.setInfoTitle('T_ScActivationStep1');
										this.setInfoRight('IT_Info', 'I_authPers');
										this.setNextAction('T_startActivation', this.processAuthPersons, true);
									} else {
										this.setInfoTitle('T_cardUnblock');
										this.setInfoRight('IT_Info', 'I_unblock');
										this.setNextAction('T_cardUnblock', this.processAuthPersons, true);
										this.setBackAction('T_back',this.processBackUnblock, true);
									}}},
									
				{status: 'enterAuthPersonFailure', handler: function(){
									this.showAuthPersonDlg();
									if (sscModel.user.cardActivation === true){
										this.setInfoTitle('T_ScActivationStepFailureRestartUnblock');
										this.setInfoRight('IT_Info', 'I_authPers');
										this.setNextAction('T_startActivation', this.processAuthPersons, true);
									} else {
										this.setInfoTitle('T_ScActivationStepFailureRestartUnblock');
										this.setInfoRight('IT_Info', 'I_unblock');
										this.setNextAction('T_cardUnblock', this.processAuthPersons, true);
										this.setBackAction('T_back',this.processBackUnblock, true);
									}
									this.setNextAction('T_startActivation', this.processAuthPersons, true);
								}},
								
				{status: 'serverbusy', handler: function(){
									this.setPrompt('P_server_busy');
									this.setInfoRight('IT_Info','I_server_busy');}},
									
				{status: 'showStatusActSuccess', handler: function(){
									this.setInfoRight('IT_Info','I_fullyOperational');
									sscModel.readCard(sscModel.cardID ,this.handleStatus);}},
			   
				
			 
				{status: 'showStatus', handler: function(){
										if (sscModel.getReCert()){
											// continue recertification
											this.setInfoRight('IT_Info','I_Recert');
											this.setInfoTitle('T_RecertTitle');
											this.setNextAction('T_startRecert',this.processPersonalization, true);
										} else {
											this.setInfoRight('IT_Info','I_fullyOperational');
										}
										this.setTopMenu(true);
										// get user info and display status accordion
										this.showSmartcardStatus();
							}},
					
				{status: 'startPerso', handler: function(){
								this.setInfoRight('IT_Info','I_notPersonalized');
								this.setInfoTitle('T_PersoTitle');
								this.setNextAction('T_startPerso',this.processPersonalization, true);
							}},
			
				
				{status:'startRecert', handler: function(){
									this.showSmartcardStatus(sscModel.getUserInfo());
									if(sscModel.overAllStatus == 'amber'){this.setInfoRight('IT_Info','I_expiresSoon');}
									if(sscModel.overAllStatus == 'red'){this.setInfoRight('IT_Info','I_expired');}
									this.setNextAction('T_startRecert',this.processPersonalization, true);
						  }}
							
								
				
				
			 ],
			
				     
			/*----------------------------------------------------------------------------------*/
			/* Initialization */
			/*----------------------------------------------------------------------------------*/
			/**
			 * initialization of sscView
			 * 
			 * @constructor
			 */
			initialize : function(options) {
				
				window.dbg.log(
						'sscView initialize at ' + new Date().format("db"));

				// get options
				this.setOptions(options);
				
				// initialize vars
				this.nextActionFnc = null;
				this.userId = '';
				this.user	= null;   // user status from model
				this.overallStatus = ''; // from model
				this.cardId = null;
				this.cardObserverId = null;
				
				// main menu defiition - must be done here because of this scope
				this.mainMenu =  [
				                 {text:'T_ChangePin', 	id:'btnChangePin', 	fnc: this.changePin},
				                 {text:'T_Unblock', 	id:'btnUnblock', 	fnc: this.unblockCard},
				                 {text:'T_KeyTest', 	id:'btnKeyTest', 	fnc: this.testPrivateKey},
				                 {text:'T_EnableSSO', 	id:'btnEnableSSO', 	fnc: this.enableSSO},
				                 {text:'T_outlook', id:'btnOutlook', fnc: this.confOutlook}
				                 ];
				 
				// set popup closer
				if ($('popupCloser') != null) {
					$('popupCloser').addEvent('click', this.closePopup);
				}
				// instantiate model
				
				//alert(typeof sscModel === 'undefined');
				sscModel = new SSC_MODEL({ 'baseUrl' :  baseUrl});
				//alert(typeof sscModel === 'undefined');
				//sscModel2 = new SSC_MODEL({ 'baseUrl' :  baseUrl});
			
				// get Translations and continue at initialization step 2
				sscModel.getTranslations(this.options.language, this.init_step2);

			}, // initialize

			/**
			 * 
			 * intialization step 2 will be called from sscModel after
			 * getTranslations ajax call has finished
			 * 
			 * @param {json}
			 *            translations - json object containing all
			 *            translatation strings
			 */
			init_step2 : function(translations) {

				window.dbg.log("translations loaded");
							
				// store translations
				this.translations = translations;
				
							
				// determine other params in query (chain of command)
				this.dynFnc = this.options.query.split('&');
				var rc = true;
				for (var i = 0; i < this.dynFnc.length && rc === true; i++){
					
					window.dbg.log(this.dynFnc[i]);
					for (var n = 0; n < this.expFnc.length && rc === true; n++){
						if (this.expFnc[n].name === this.dynFnc[i]){
							rc = this.expFnc[n].fnc.call(this);
							 
						}
					}
					
				}
				
				// set last changes
				this.setTranslatedElementText($('lastChanges'), 'T_lastChanges');
				
				/*
				 *  handle genCode mode
				 */
				if (this.options.mode === 'genCode'){
					// prepare menues
					this._initMenues(false);
					
					// set title
					this.setInfoTitle('T_authCodeGenFor');
					
					// info message
					this.setInfoRight('IT_Info','I_authCodeFor');
					
					// call genCode
					sscModel.getActivationCode(this.showActivationCode);
														
				/*
				 *  handle normal mode
				 */
				} else {
					
					//prepare menues
					this._initMenues(true);
					
					// set title
					this.setInfoTitle('T_seekingCard');
				
					// set status and info message
					this.setStatusMsg("I_StartUp", "P_pleaseWait", 'blue');
					this.setInfoRight('IT_Info','I_welcome');
				
					// add a keydown event to capture the enter key
					document.addEvent('keydown', this.handleKeyDown);

					// initialize card reader
					sscModel.initializeCardReaderPlugin(this.init_step3);
					/*
					setTimeout(function() {
						sscModel.initializeCardReaderPlugin(this.init_step3);
					}.bind(this), testTimeout);
					*/
				}

			}, // init_step2

			/**
			 * initialization step 3 will be called after sscModel finished Card
			 * Reader PlugIn Initialization
			 * 
			 * @param {boolean}
			 *            true if cardReader PlugIn is available and successfully
			 *            initialized
			 */
			init_step3 : function(cardReaderPluginAvailable) {
				
				window.dbg.log('init_step3 - cardReader plugin available = '+ cardReaderPluginAvailable);
				//this.closePopup();

				if (cardReaderPluginAvailable) {

					// clear status msg
					this.setStatusMsg('T_idle','', 'idle');
					// get server status
					sscModel.server_get_status(this.init_step4);
					//sscModel.sc_getCardList(this.init_step4);

				} else {
					this.setInfoRight('IT_Info','I_contactAdmin');
					this.setPrompt('E_no-card-reader');
					this.setOverallStatus('red');
					this.setStatusMsg('T_idle','', 'idle');

				}
				
			}, // init_step3
			
			/**
			 * initialization step 4 will be called after sscModel finished getServerStatus
			 * 
			 * @param {boolean}
			 *            true if cardReader is available and successfully
			 *            initialized
			 */
			init_step4 : function(serverStatus) {
				
				window.dbg.log('init_step4 - serverStatus = '+ serverStatus);
				
				if (serverStatus == 'ok'){ 
					// get server status
					sscModel.sc_getCardList(this.init_step5);
				} else {
					this.setInfoRight('IT_Info','I_contactAdmin');
					this.setPrompt('E_bad-server-status');
					this.setOverallStatus('red');
					this.setStatusMsg('T_idle','', 'idle');
				}
				
			}, // init_step4
			
			/**
			 * initialization step 5 will be called after sscModel finished getCardList
			 * 
			 * @param {boolean}
			 *            true if cardReader is available and successfully
			 *            initialized
			 */
			init_step5 : function(cardList) {
				
				window.dbg.log('init_step5 - cardList = '+ cardList);
				var queries = cardList.split('&');
				// get rc
				var rc = queries[0].split('=')[1];
				window.dbg.log(queries);
				if (rc === 'SUCCESS'){
					
					// get the parameter...
					var params = queries[1].split('=');
					// ...and save second parameter as card list
					var cList = params[1].split(';');
					//window.dbg.log(cList);
					
					// eliminate last empty array element (caused by delimiter and split behavior)
					if (cList[cList.length-1] === '') cList.pop();
					
					// more than 1 card reader ?
					if (cList.length > 1){
						// yes -> select list
						//window.dbg.log('init_step5 - select card ' + cList.length);
						this.showSelectCardDlg(cList);
						this.setInfoTitle('T_selectCard');
						sscView.setInfoRight('IT_Info', 'I_selectCard');
						this.setNextAction('T_proceed', this.processCardSelection, true);
					// only one card reader	
					} else {
						
						// prompt to insert card
						//window.dbg.log('init_step5 - only one card reader available');
						var cardParams = cList[0].split('|');
						this.cardId = cardParams[3];
						this.insertCard(this.cardId);
					}
					 
				} else {
					this.setInfoRight('IT_Info','I_contactAdmin');
					this.setPrompt('E_cant-get-cardlist');
					this.setOverallStatus('red');
					this.setStatusMsg('T_idle','', 'idle');
					
				}
				
				
			}, // init_step5

			/*----------------------------------------------------------------------------------*/
			/* public methods */
			/*----------------------------------------------------------------------------------*/
			
			/**
			 * handleStatus 
			 * 
			 * @param status
			 *
			 */
			handleStatus : function(status) {

				window.dbg.log('handleStatus status: ' + status);
				
				this.setPrompt('');
				// get user info
				var user = sscModel.getUserInfo();
				// display user info at left side
				this.setInfoLeft(user.firstTimePerso ? 'T_regFor' : 'T_persoFor' , 
								 user.cardholder_givenname  
						         + ' ' 
						         + user.cardholder_surname
						         +'<br />' + user.entity);
				this.userId = user.cardholder_givenname + ' ' + user.cardholder_surname;
				
				// get overall status and display it
				this.setOverallStatus(sscModel.getOverAllStatus());
				this.setStatusMsg('T_idle','', 'idle');
				
				
				// call status handler function
				for (var n = 0; n < this.statusHandler.length; n++){
					if (this.statusHandler[n].status === status){
						this.statusHandler[n].handler.call(this);
						return;
					}
				}
				 
				// no status handler found
				window.dbg.log('handleStatus unknown status: ' + status);
	
			},
			
			/**
			 * functions for card observing
			 * 
			 */
			startCardObserver : function(){
				window.dbg.log('startCardObserver');
				if (this.cardObserverId === null)
					this.cardObserverId = setInterval(this.cardObserver, 500);
				 
			},
			
			stopCardObserver : function(){
				window.dbg.log('stopCardObserver');
				if (this.cardObserverId != null)
					clearInterval(this.cardObserverId);
				this.cardObserverId = null;
			},
			
			cardObserver : function(){
				//window.dbg.log('cardObserver');
				if (!sscModel.sc_checkCardPresence()){
					this.stopCardObserver();
					$('infoMore').empty();
					this.showPopUp('T_Card_Out', '', '0906 - card ejected', true);
					this.setPrompt('');
					
					
					this.setInfoTitle('T_seekingCard');
					$('infoPrompt').style.display = 'block';
					
			// set status and info message
					this.setStatusMsg("I_StartUp", "P_pleaseWait", 'blue');
					this.setInfoRight('IT_Info','I_welcome');
					//$('infoLeft').empty();
					this.setNextAction('',null);
					this.setBackAction('',null);
					this.setInfoLeft('' , '' 
					         + ' ' 
					         + ' ' 
					         +'<br />' + '');
					this.setTopMenu(false);
					this.setOverallStatus('red');
					
					
					setTimeout( function(){sscModel.server_get_status(this.init_step4);$('popupInfo').set('html', '');
					$('popupFrame').style.display = 'none';  }.bind(this), 3000 );
					
				
					// add a keydown event to capture the enter key
					//document.addEvent('keydown', this._performBackAction);
					//setInterval(this.init_step3(true), 1500)
					//this.init_step3(true);
				}
				//window.dbg.log('cardObserver return');
			},
			
			/*
			cardObserverCB : function(r){
				window.dbg.log('cardObserverCB - ' + r);
			
				
				 
			},
			*/
			
			/**
			 * account processing retrieves the account from user selection (if
			 * not only one account) of Account Dialog and calls the
			 * sscModel.personalizeAccount method
			 * 
			 */
			processAccountSelection : function(select) {

				window.dbg.log('processAccountSelection');

				this.account = '';

				// handle single account
				if ($('singleAccount')) {
					this.account = $('singleAccount').innerHTML;

					// handle account selection
				} else {
					
					if(select){
						this.account = $('accountDlgSelect').value;
						//alert("selectBox Activated "+ this.account);
						
						if (this.account === '') {
							//this.setNextAction('T_startPerso', this.processAccountSelection, true);
							this.setStatusMsg('T_idle','', 'idle');
							this.setOverallStatus('red');
							this.setPrompt('E_noAccount');
							
						} else {
							this.setPrompt('');
						// account selected change message	
						this.showAccountDlg([this.account]);
						return;
						}
						
						return;
					}else{
					
					for (i = 0;; i++) {
						el = $('account' + i);
						if (!el)
							break;
						if ($('account' + i).checked)
							this.account = $('account' + i).value;
					}

					// nothing selected
					if (this.account === '') {
						//this.setNextAction('T_startPerso', this.processAccountSelection, true);
						this.setStatusMsg('T_idle','', 'idle');
						this.setOverallStatus('red');
						this.setPrompt('E_noAccount');
						
					} else {
					// account selected change message	
						this.setPrompt('');
					this.showAccountDlg([this.account]);
					return;
					}
					
					}
					
				}
				
				// account successfully selected
				if (this.account) {
					this.setStatusMsg();
					//this.setInfoLeft('T_Perso', this.account);
					sscModel.personalizeAccount(this.account,
							this.processPersonalization_done);
				}

			},
			
			/**
			 * Auth Person processing handles input from showAuthPersonsDlg
			 * 
			 */
			processAuthPersons : function() {

				window.dbg.log('processAuthPersons');
				this.setPrompt('');

				var error = false;

				// save values
				this.authPers1 = $('authPers1').value;
				this.authPers2 = $('authPers2').value;

				// check email addr 1
				if (!this.authPers1.length || !this._isEmail(this.authPers1)) {

					$('authPers1').style.backgroundColor = "red";
					$('authPers1').focus();
					$('authPers1').addEvent('keydown', this._resetInputErr);
					error = true;

				} else {
					$('authPers1').style.backgroundColor = "white";
				}

				// check email addr 2
				if (!this.authPers2.length || !this._isEmail(this.authPers2)) {

					$('authPers2').style.backgroundColor = "red";
					$('authPers2').addEvent('keydown', this._resetInputErr);
					if (!error)
						$('authPers2').focus();
					error = true;

				} else {
					$('authPers2').style.backgroundColor = "white";
				}

				if (error) {
					this.setStatusMsg('T_idle','', 'idle');
					this.setOverallStatus('red');
					this.setPrompt('E_invalidEmail');
					// same action again
					
					if (sscModel.user.cardActivation){
						//no back action
						
					} else {
						// set back action
						//this.setBackAction('T_back',function(){ this.handleStatus('showStatus');}.bind(this), true);
						this.setBackAction('T_back',this.processBackUnblock, true);
					}
					
					
					this.setNextAction('T_proceedActivation',this.processAuthPersons, true);
				}

				else {
					this.setStatusMsg();
					sscModel.processAuthPersons(this.authPers1,this.authPers2,this.processAuthPersons_done);
				}

			},
			
			
			/**
			 * callback function called after Auth Persons has been processed by model
			 * 
			 * @params				
			 * rc					0 no error 
			 * invalidMail: 	 	1 = authPers1 invalid
			 *						2 = authPers2 invalid
			 *						3 = both invalid
             *
			 */
			processAuthPersons_done : function(rc, invalidMail) {

				window.dbg.log('auth persons done - ' + status);
				
				// any error
				if (rc){
					//this.setPrompt('Plase insert valid email addresses');
					
					// try it again
					// this.showAuthPersonDlg();
					this.setStatusMsg('T_idle','', 'idle');
					this.setOverallStatus('red');
					this.setPrompt('E_invalidEmail');
					if (invalidMail !== undefined){
						if (invalidMail === 1 || invalidMail === 3){
							$('authPers1').style.backgroundColor = "red";
							$('authPers1').focus();
							$('authPers1').addEvent('keydown', this._resetInputErr);
						}
						if (invalidMail === 2 || invalidMail === 3){
							$('authPers2').style.backgroundColor = "red";
							$('authPers2').focus();
							$('authPers2').addEvent('keydown', this._resetInputErr);
						}
					}
					// FIX END
					
					// set title
					
					
					// set right info text
					sscView.setInfoRight('IT_Info', 'I_authPers');
					var user = sscModel.getUserInfo();
					if (user.cardActivation === true){
						this.setInfoTitle('T_ScActivationStep1');
						// set next action
						this.setNextAction('T_startActivation', this.processAuthPersons, true); 
					} else {
						this.setInfoTitle('T_cardUnblock');
						// set next action
						this.setNextAction('T_cardUnblock', this.processAuthPersons, true);
						//this.setBackAction('T_back',function(){ this.handleStatus('showStatus');}.bind(this), true);		
						this.setBackAction('T_back',this.processBackUnblock, true);
					}
					
					
				
				} else {
					// enter authcodes
					this.setPrompt('');
					
					// clear authcodes (myight be saved from prevoius attempt)
					this.actCode1 = '';
					this.actCode2 = '';
					 
					this.showPinDlg(false);
					
					// set right info text
					sscView.setInfoRight('IT_Info', 'I_actStep2');
					window.dbg.log('cardActivation ? = ' + sscModel.user.cardActivation);
					// set title
					if (sscModel.user.cardActivation === true ){
						this.setInfoTitle('T_ScActivationStep2');
						// set next & back action
						this.setNextAction('T_proceedActStep2', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
					}else{
						this.setInfoTitle('T_cardUnblock');
						// set next & back action
						this.setNextAction('T_cardUnblock', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
					}			
				}
			},
			
			processCardSelection : function() {

				window.dbg.log('processCardSelection');
				//alert('processCardSelection');
				//this.setPrompt('');
				for (i = 0;; i++) {
					el = $('sCard' + i);
					if (!el)
						break;
					if ($('sCard' + i).checked)
						this.cardId = $('sCard' + i).value;
				}
				window.dbg.log('selected Card: ' + this.cardId);
				this.setPrompt('');
				$('infoMore').empty();
				this.insertCard(this.cardId);
			},
			
			processPersonalization : function() {

				window.dbg.log('processPersonalization');
				this.setPrompt('');
				
				// diff between repersonalization ---> first time
				
				this.setInfoRight('IT_Info','I_persoStep1');
				this.showPersonalizationStatus(1);
				sscModel.sc_start_personalization(this.processPersonalization_done);

			},
			
			processPersonalization_done: function (){
				sscModel.user.firstTimePerso = false;
				// display user info at left side
				this.setInfoLeft(sscModel.user.firstTimePerso ? 'T_regFor' : 'T_persoFor' , 
								  sscModel.user.cardholder_givenname  
						         + ' ' 
						         + sscModel.user.cardholder_surname
						         +'<br />' + sscModel.user.entity);
				
				this.setPrompt('P_success_perso');
				this.setInfoRight('IT_Info','I_persoSuccess');
				this.setNextAction('T_proceedActivation', 
							function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
				window.dbg.log('processPersonalization done');
			},
			
			
			processPins : function() {

				window.dbg.log('processPins');
				this.setPrompt('');

				var error = false;
				this.currentPin = false;

				// pin change?
				if ($('pin')) {

					this.currentPin = true;

					// save current pin
					this.pin = $('pin').value;

					// and check it
					if (this.pin.length < 4) {
						$('pin').style.backgroundColor = "red";
						$('pin').addEvent('keydown', this._resetInputErr);
						if (!error)
							$('pin').focus();
						error = true;
					} else {
						$('pin').style.backgroundColor = "white";
					}

					// clear authcodes
					this.actCode1 = '';
					this.actCode2 = '';

					// activation codes
				} else {
					this.currentPin = false;

					// save auth1 code
					this.actCode1 = $('actCode1').value;
					// save auth1 code
					this.actCode2 = $('actCode2').value;
					
				}

				// save pin 1...
				this.pin1 = $('pin1').value;
				// ... and check length
				if (this.pin1.length < 4) {
					$('pin1').style.backgroundColor = "red";
					$('pin1').addEvent('keydown', this._resetInputErr);
					if (!error)
						$('pin1').focus();
					error = true;
				} else {
					$('pin1').style.backgroundColor = "white";
				}

				// save pin2...
				this.pin2 = $('pin2').value;
				// ...check length
				if (this.pin2.length < 4) {
					$('pin2').style.backgroundColor = "red";
					$('pin2').addEvent('keydown', this._resetInputErr);
					if (!error)
						$('pin2').focus();
					error = true;
				} else {
					$('pin2').style.backgroundColor = "white";
				}

				// test on length and other errors
				if (error) {
					this.setStatusMsg('T_idle','', 'idle');
					this.setOverallStatus('red');
					this.setPrompt('E_invalidPins');
					// same action again
					this.setNextAction('T_enterPins', this.processPins, true);
					this.setBackAction('T_back',function(){ this.handleStatus('showStatus');}.bind(this), true);
					

					// test on new pin unequal current pin
				} else if (this.currentPin && this.pin === this.pin1) {
					this.setStatusMsg('T_idle','', 'idle');
					this.setOverallStatus('red');
					this.setPrompt('E_eqPins');
					//this.setStatusMsg('E_eqPins', 'P_insertUePins', 'red');
					$('pin1').style.backgroundColor = "red";
					$('pin1').addEvent('keydown', this._resetInputErr);
					$('pin1').focus();
					this.setNextAction('T_enterPins', this.processPins, true);
					this.setBackAction('T_back',function(){ this.handleStatus('showStatus');}.bind(this), true);
					

					// test on confirmation pin
				} else if (this.pin1 !== this.pin2) {
					//this.setStatusMsg('E_uneqPins', 'P_insertEqPins', 'red');
					this.setStatusMsg('T_idle','', 'idle');
					if($('pin')){
						
						this.setNextAction('T_enterPins', this.processPins, true);
						this.setBackAction('T_back',function(){ this.handleStatus('showStatus');}.bind(this), true);
						
						
					}else{
						
						if (sscModel.user.cardActivation){
							this.setInfoTitle('T_ScActivationStep2');
							// set next & back action
							this.setNextAction('T_proceedActStep2', this.processPins, true);
							this.setBackAction('T_chooseAuthPers', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
						}else{
							this.setInfoTitle('T_cardUnblock');
							// set next & back action
							this.setNextAction('T_cardUnblock', this.processPins, true);
							this.setBackAction('T_chooseAuthPers', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
						}
						
					}
					this.setOverallStatus('red');
					this.setPrompt('E_uneqPins');
					$('pin2').style.backgroundColor = "red";
					$('pin2').addEvent('keydown', this._resetInputErr);
					$('pin2').focus();


				} else {
					this.setStatusMsg();
					if ($('pin')) {
						sscModel.processPins(this.pin, this.pin1, this.pin2,
								this.processPins_done);
					} else {
						sscModel.processAuthCodes(this.pin1, 
												  this._trim(this.actCode1),
												  this._trim(this.actCode2),
												  this.processAuthCodes_done);
					}
				}
			}, // processPins

			
			processPins_done : function(status) {

				window.dbg.log('processPins done');
				
				// policy error
				if (status === 'newPinError'){
					
					this.showPinDlg(true);
					// set title
					this.setInfoTitle('T_changePin');
					this.setInfoRight('IT_Info', 'I_userPinPolicy');
					$('pin1').style.backgroundColor = "red";
					$('pin1').focus();
					$('pin1').addEvent('keydown', this._resetInputErr);
					$('pin2').style.backgroundColor = "red";
					$('pin2').focus();
					$('pin2').addEvent('keydown', this._resetInputErr);
					
					// set next & back action
					this.setNextAction('T_enterPins', this.processPins, true);
					this.setBackAction('T_back', function(){ this.handleStatus('showStatus');}.bind(this), true);
					this.setPrompt('T_newPinError');
				
				// old pin wrong					
				} else if (status === 'pinError'){
					
					this.showPinDlg(true);
					// set title
					this.setInfoTitle('T_changePin');
					// set right info text
					this.setInfoRight('IT_Info', 'I_userPinWrong');
					$('pin').style.backgroundColor = "red";
					$('pin').focus();
					$('pin').addEvent('keydown', this._resetInputErr);
					// set next & back action
					this.setNextAction('T_enterPins', this.processPins, true);
					this.setBackAction('T_back', function(){ this.handleStatus('showStatus');}.bind(this), true);
					this.setPrompt('T_pinError');
				// card blocked
				} else if (status === 'cardBlocked'){
				
					//this.showPinDlg(true);
					this.showAuthPersonDlg();
					// set title
					this.setInfoTitle('T_ScActivationStepFailureRestartUnblock');
					// set right info text
					sscView.setInfoRight('IT_Info', 'I_unblock');
					// set next & back action
					this.setNextAction('T_cardUnblock', this.processAuthPersons, true);
					this.setBackAction('T_back',function(){ this.handleStatus('showStatus');}.bind(this), true);
	
//					this.setInfoTitle('T_changePin');
//					// set right info text
//					this.setInfoRight('IT_Info', 'I_cardBlocked');
//					// set next & back action
//					this.setNextAction('T_cardUnblock', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
//					this.setBackAction('T_back', function(){ this.handleStatus('showStatus');}.bind(this), true);				 
					this.setPrompt('T_cardBlocked');
				// everything ok
				} else {
					this.setPrompt('T_changePinSuccess');
					// set right info text
					this.setInfoRight('IT_Info', 'I_changePin');
					// set next & back action
					this.setNextAction('T_enterPins', this.processPins, true);
					this.setBackAction('T_back', function(){ this.handleStatus('showStatus');}.bind(this), true);
					//this.setNextAction('T_continue','T_changePinSuccess',
					//		function(){this.handleStatus('showStatus');}.bind(this));
				}
				
				
			},
			
			/**
			 * callback function called after Auth Code has been processed by model
			 * 
			 * @params	
			 * status				invalidAuthCode, invalidPin
			 * invalidActCode:  	1 = actCode1 invalid
			 *						2 = actCode2 invalid
			 *						3 = both invalid
             *
			 */
			processAuthCodes_done : function(status, invalidActCode) {

				window.dbg.log('processAuthCode done');
				
				// invalid authcode
				if (status === 'invalidAuthCode'){
					this.setPrompt('T_invalidAuthCode');
					//this.showPinDlg(false);
					// FIXME: return code to mark field
					// try it again
					// this.showAuthPersonDlg();
					this.setStatusMsg('T_idle','', 'idle');
					this.setOverallStatus('red');
					if (invalidActCode !== undefined){
						if (invalidActCode === 1 || invalidActCode === 3){
							$('actCode1').style.backgroundColor = "red";
							$('actCode1').focus();
							$('actCode1').addEvent('keydown', this._resetInputErr);
						} 
						if (invalidActCode === 2 || invalidActCode === 3){
							$('actCode2').style.backgroundColor = "red";
							$('actCode2').focus();
							$('actCode2').addEvent('keydown', this._resetInputErr);
						}
					}
					// FIX END
					
					if (sscModel.user.cardActivation){
						this.setInfoTitle('T_ScActivationStep2');
						// set next & back action
						this.setNextAction('T_proceedActStep2', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
					}else{
						this.setInfoTitle('T_cardUnblock');
						// set next & back action
						this.setNextAction('T_cardUnblock', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
					}
					
				// invalid pin	
				} else if (status === 'invalidPin'){
					this.setPrompt('T_invalidPolicy');
					//this.showPinDlg(false);
					$('pin1').style.backgroundColor = "red";
					$('pin1').focus();
					$('pin1').addEvent('keydown', this._resetInputErr);
					$('pin2').style.backgroundColor = "red";
					$('pin2').addEvent('keydown', this._resetInputErr);
					// set title
					
					this.setInfoRight('IT_Info','I_userPinPolicy');
					if (sscModel.user.cardActivation){
						this.setInfoTitle('T_ScActivationStep2');
						// set next & back action
						this.setNextAction('T_proceedActStep2', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
					}else{
						this.setInfoTitle('T_cardUnblock');
						// set next & back action
						this.setNextAction('T_cardUnblock', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.handleStatus('enterAuthPersons');}.bind(this), true);
					}
					
				// general failure
				} else  if (status === 'failure'){
					this.setPrompt('T_generalAuthCodeFailure');
					this.setInfoRight('IT_Info','I_generalAuthCodeFailure');
					this.handleStatus('enterAuthPersonFailure');
					
				
				// everything ok
				} else {
					$('infoMore').empty();
					this.showHints();
					//this.setPrompt('T_cardActivationSuccess');
					this.setNextAction('T_cardStatus',function(){this.handleStatus('showStatusActSuccess');}.bind(this), true);
				}
				
				
				
			},
			
			processRecertification : function(){
				window.dbg.log('processRecertification');
				sscModel.sc_start_personalization(this.processRecertification_done);
			},
			
			processRecertification_done : function(){
				window.dbg.log('processRecertification_done');
				
			},
			
			processBackUnblock : function(){
				window.dbg.log('processBackUnblock');
				sscModel.server_cancel_unblock(this.handleStatus);
				
			},
			
			// -----------------------------------------------------------
			// helper
			// -----------------------------------------------------------
			/**
			 * initializes the pin Dialog for pin change
			 * 
			 */
			changePin : function() {

				this.showPinDlg(true);
				// set title
				this.setInfoTitle('T_changePin');
				this.setPrompt();
				// set right info text
				this.setInfoRight('IT_Info', 'I_changePin');
				// set next & back action
				this.setNextAction('T_enterPins', this.processPins, true);
				this.setBackAction('T_back', function(){ this.handleStatus('showStatus');}.bind(this), true);

			}, // changePin

			/**
			 * prompt for "insert card" and calls the appropriate mode function
			 * 
			 */
			
			insertCard : function(cardId) {
				window.dbg.log('insertCard', cardId);
				this.setInfoTitle('T_Analyse');
				this.setPrompt('P_insertCard');
				
				// call model to read card with callback 
				sscModel.readCard(cardId,this.handleStatus);

			}, // insertCard
			
			
			unblockCard : function() {

				window.dbg.log('unblockCard');
				
				this.handleStatus('enterAuthPersons');	

//				this.setPrompt();
//				this.showAuthPersonDlg();
//				// set title
//				this.setInfoTitle('T_Unblock');
//				// set right info text
//				sscView.setInfoRight('IT_Info', 'I_authPers');
//				// set next & back action
//				this.setNextAction('T_cardUnblock', this.processAuthPersons, true);  
//				this.setBackAction('T_back', function(){ this.handleStatus('showStatus');}.bind(this), true);
//				
			},
			
			testPrivateKey : function(){
				window.dbg.log('testPrivateKey');
				this.setPrompt('');
							
				//this.setInfoLeft('');
				//this.setInfoRight('');
									
				// get overall status and display it
				this.setOverallStatus(sscModel.getOverAllStatus());
				this.setStatusMsg('T_idle','', 'idle');
				this.setInfoTitle('T_testPrivateKey');
				this.setInfoRight('IT_privatekeytest', 'I_privatekeytest');
				
				this.showGetPinDlg();			
				this.setBackAction('T_back',function(){ this.handleStatus('showStatus');}.bind(this), true);				 
				this.setNextAction('T_testPrivateKey',this.processTestPrivateKey, true);
				
			},
			
			processTestPrivateKey : function(){
			   var pin = $('pin').value;
			   sscModel.sc_test_card(pin,this.testPrivateKeyCB);
			},
			
			testPrivateKeyCB : function(r){
				window.dbg.log('testPrivateKeyCB');
				var result= 'PASS';
				var str = r.split('&');
				str = str[3].split('=');
				str = str[1].split(';');
				str.pop(); // eleminate last ;
				var e = '<h2>'+this._tr('P_privatekeyresults')+'<br /></h2><table>';
				for (var i = 0; i < str.length; i++){
					var tokens = str[i].split('|');
					var keyId = tokens[0];
					var keyStatus = tokens[1];
					if(keyStatus !== 'PASS'){
						result = keyStatus;
					}
					e += '<tr><td class="crdId">'  
					   + this._tr('T_keyPair') + ' ' + (i+1) + ' <a class="errCodeToggle" href="#">' + this._tr('...') + '</a>'
					   + '<div class="errCode">' + keyId + ' - ' + keyStatus + '</div>'
					   + '</td><td class="crdResult"><span class="' + keyStatus + '"></span></td></tr>';
				}
				e += '</table>';
				
				// show result
				if (e != ''){
					window.dbg.log(e);
					
					$('infoMore').empty();
					var div = new Element('div', {
						'class' : 'selectCardDlg',
						'html'  : e
					});
					div.inject($('infoMore'));
				}
				
				// enable toggler for all elements
				$$('.errCodeToggle').each(function(el) {
					var mySlide = new Fx.Slide(el.getNext());
					mySlide.hide();
					el.addEvent('click', function(event){
											event.stop();
											console.log('click');
											mySlide.toggle();
						});
				});
				
				if(result === 'PASS'){
					this.setInfoRight('IT_Info', 'I_workingKeys');
					this.setBackAction('T_back',function(){ this.handleStatus('showStatus');}.bind(this), true)
					
				}else{
					this.setInfoRight('IT_Info', 'I_brokenKey');
					this.setNextAction('P_cleanupCard', this.cleanUpCard, true);
				}

			},
			
			cleanUpCard : function(){
				window.dbg.log('cleanUpCard ');
				var self = this;
				sscModel.sc_card_cleanup(function(rc){
											if (rc === 'success'){self.setInfoTitle('T_cleanupSuccess');} 
											else {self.setInfoTitle('T_cleanupFailed');}
											self.setNextAction('',null, false);
											$('infoMore').empty();
											}
				);
			},
			
			
			
			enableSSO : function(){
				window.dbg.log('enableSSO');
				this.setPrompt('');
				
				//this.setInfoLeft('');
				//this.setInfoRight('');
									
				// get overall status and display it
				this.setOverallStatus(sscModel.getOverAllStatus());
				this.setStatusMsg('T_idle','', 'idle');
				this.setInfoTitle('T_EnableSSO');
				this.setInfoRight('IT_enableSSO', 'I_enableSSO');
				
				
				var div = new Element('div', {
					'class' : 'selectCardDlg'
				});
				new Element('h2', {
					'html' : this._tr('P_enableSSO')
				}).inject(div);
				
				
				// inject div into info
				$('infoMore').empty();
				div.inject($('infoMore'));
				this.setBackAction('T_back',function(){ this.handleStatus('showStatus');}.bind(this), true);
				this.setNextAction('T_EnableSSO',this.processEnableSSO, true);
			},
			
			processEnableSSO : function(){
				window.dbg.log('processEnableSSO');
				var self = this;
				sscModel.sc_enable_sso(function(rc){
							if (rc === 'success'){self.setInfoTitle('T_enableSsoSuccess');} 
							else {self.setInfoTitle('T_enableSsoFailed');}
							self.setNextAction('',null, false);
							$('infoMore').empty();
					}
				);
			},
			
			confOutlook : function(){
				window.dbg.log('Configure outlook');
				this.setPrompt('');
				//this.setInfoLeft('');
				//this.setInfoRight('');
									
				// get overall status and display it
				this.setOverallStatus(sscModel.getOverAllStatus());
				this.setStatusMsg('T_idle','', 'idle');
				this.setInfoTitle('T_outlook');
				this.setInfoRight('IT_Info', 'I_confOutlook');
				
				// build info block in the middle
				var div = new Element('div', {
					'class' : 'selectCardDlg'
				});
				new Element('h2', {
					'html' : this._tr('P_outlook')
				}).inject(div);
				// inject div into info
				$('infoMore').empty();
				div.inject($('infoMore'));
				
				//set back Action
				this.setBackAction('T_back',function(){ this.handleStatus('showStatus');}.bind(this), true);
				// and set next action
				this.setNextAction('T_outlook',this.processConfOutlook, true);
			},
			
			processConfOutlook: function(){
				window.dbg.log('processConfOutlook');
				sscModel.configureOutlook(this.processConfOutlook_done);
				
			},
			
			processConfOutlook_done: function(r){
				
				var results = new Querystring(r);
				var set = results.get("Result");
				if(set === 'SUCCESS'){
					this.setPrompt('T_outlook_conf_success');
				}else{
					this.setPrompt('T_outlook_conf_error');
				}
				
				//configureOutlookResult=ERROR&Reason=SeekError&CardType=Gemalto .NET&TokenID=857E976B742FE5CB
				//alert('processConfOutlook_done');	
			},
			
			reload: function(){
				location.reload(true);

			},
			
			// -----------------------------------------------------------
			// setter methods
			// -----------------------------------------------------------

			setButton : function(enable, btn, fnc) {

				window.dbg.log('setButton');

				if (!btn.getParent().hasClass('active') && enable) {
					btn.getParent().addClass('active');
					btn.addEvent('click', fnc);
				} else if (btn.getParent().hasClass('active') && !enable) {
					btn.getParent().removeClass('active');
					btn.removeEvent('click', fnc);
				}
			},

			setInfoLeft : function(titleId, textId) {

				window.dbg.log('setInfoLeft ' + textId + '-' + titleId);

				this.setTranslatedElementText($('infoLeftTitle'), titleId);
				this.setTranslatedElementText($('infoLeftContent'), textId);

			},

			setInfoRight : function(titleId, textId) {

				window.dbg.log('setInfoRight ' + textId + '-' + titleId);

				this.setTranslatedElementText($('infoRightTitle'), titleId);
				
// fs test 	: todo evtl analoges verhalten by setInfoLeft		
				
				var anim =  new Fx.Tween($('infoRight'), {
		    		property: 'opacity',
		    		link: 'chain'
				});
				
				anim.start(0).chain(function(){
					anim.start(1).chain(function(){
						this.setTranslatedElementText($('infoRightContent'), textId);
					}.bind(this));		
				}.bind(this));
				
			
					
				this.setTranslatedElementText($('infoRightContent'), textId);

			},

			setInfoTitle : function(textId) {

				window.dbg.log('setInfoTitle ' + textId);
				this.setTranslatedElementText($('infoCenterTitle'), textId);

			},
			
			
			setBackAction : function(textId, backAction, active) {

				window.dbg.log('setBackAction ' + textId);

				if (backAction !== undefined
						&& typeof backAction === 'function') {
					this.backActionFnc = backAction;
					window.dbg.log('setBackAction Fnc');
				} else {
					this.backActionFnc = null;
					window.dbg.log('setBackAction Fnc cleared', true);
				}

				// create link
				var actionLnk = new Element('a', {
					'html' : this._tr(textId),
					'id'   : 'backActionLnk',
					'class': (active !== undefined && active ? 'active' : ''),
					'events' : {
						'click' : (active !== undefined && active 
								? function() {this._performBackAction();}.bind(this)
								: function() {}
								)		
					}
				});
 
				actionLnk.inject($('backActionDiv').empty());

			},
			
			
			setNextAction : function(textId, nextAction, active) {

				window.dbg.log('setNextAction ' + textId);

				if (nextAction !== undefined
						&& typeof nextAction === 'function') {
					this.nextActionFnc = nextAction;
					window.dbg.log('setNextAction Fnc');
				} else {
					this.nextActionFnc = null;
					window.dbg.log('setNextAction Fnc cleared', true);
				}

				// create link
				var actionLnk = new Element('a', {
					'html' : this._tr(textId),
					'id'   : 'nextActionLnk',
					'class': (active !== undefined && active ? 'active' : ''),
					'events' : {
						'click' : function() {
							this._performNextAction();
						}.bind(this)
					}
				});
 
				actionLnk.inject($('nextActionDiv').empty());

			},
			
			setNextActionActive: function(active){
				
				window.dbg.log('setNextActionActive - ' + active);
				
				if (active) $('nextActionLnk').addClass('active');
				else $('nextActionLnk').removeClass('active');
			},

			setPrompt : function(msgId) {

				window.dbg.log('setPrompt ' + msgId);

				if (msgId !== undefined && msgId !== '') {
					$('infoPrompt').innerHTML = '<h2 class="tl" id="' + msgId
							+ '">' + this._tr(msgId) + '</h2>';
					$('infoPrompt').style.display = 'block';
				} else {
					$('infoPrompt').innerHTML = "";
					$('infoPrompt').style.display = 'none';
				}

			},

			setOverallStatus : function(statusLightClass) {
				window.dbg.log('setOverallStatus ' + statusLightClass);
				this.setTranslatedElementText($('overallStatus'),
						'T_StatusTitle');
				$('overallStatus').setProperty('class',
						statusLightClass + 'OaS');

			},
			setStatusMsg : function(msgId, promptId, statusLightClass) {

				window.dbg.log('setStatusMsg ' + msgId + '-' + promptId + '-'
						+ statusLightClass);

				if (statusLightClass !== undefined) {
					this.setStatusLight(statusLightClass);
				} else {
					this.setStatusLight('');
				}

				if (msgId !== undefined) {
					$('statusText').innerHTML = this._tr(msgId);
				} else {
					$('statusText').innerHTML = '';
				}

				//this.setPrompt(promptId);

			},

			setStatusLight : function(className) {

				$('statusLight').setProperty('class', className);

			},

			setTopMenu : function(enable) {

				window.dbg.log('setTopMenu');
				// enable each mainMenu entry
				for (var i = 0; i < this.mainMenu.length; i++){
					this.setButton(enable, $(this.mainMenu[i].id), this.mainMenu[i].fnc);
				}
				
				if(! sscModel.allowOutlook){		
				
					this.setButton( 0 , $(this.mainMenu[4].id) , this.mainMenu[4].fnc );				
					var r = $('PKCS11Plugin').GetDomainUser();
					var res = new Querystring(r);
					var set = res.get("Result");
					var DomainUser = null;
	
					window.dbg.log(res );
					window.dbg.log("set:" + set  );
					if (set === "SUCCESS") {
						//viewCb('success');
						DomainUser = res.get("DomainUser");
						
						//popup( "PIN changed successfully. <br> Your PIN has been changed please use the new PIN from now on to access your smartcard." , "info", function () { 
						//});
					}
					window.dbg.log("Domainuser: "+DomainUser + " No login ids:"+ sscModel.user.accounts.length );
					
					for( var i=0; i < sscModel.user.accounts.length ; i++){
						window.dbg.log(sscModel.user.accounts[i] + sscModel.user.accounts.length );
						
						if( sscModel.user.accounts[i].toLowerCase() === DomainUser.toLowerCase() ){
							this.setButton( 1 , $(this.mainMenu[4].id) , this.mainMenu[4].fnc );
						}
					}
				}
				
				
			},

			setTranslatedElementText : function(el, textId) {

				// set text
				el.set('html', this._tr(textId));
				// remember it is translated text
				// if (!el.hasClass('tt')) el.addClass('tt');

				// el.empty();
				// new Element('span',{'id' : textId, 'class' : 'tt', 'html':
				// this._tr(textId)}).inject(el);

			},

			// -----------------------------------------------------------
			// show methods
			// -----------------------------------------------------------

			showAccountDlg : function(accounts) {

				window.dbg.log('showAccountDlg');

				// clear account
				this.account = '';

				// clear info
				$('accountDlg').empty();
				//$('infoMore').empty();

				// more than one account?
				
				if (accounts instanceof Array && accounts.length >= 10)
				{
					window.dbg.log('more than 10 accouts');
					// create form
					var form = new Element('form', {
						'id' : 'accountDlgForm'
					});
					
					// set sub title
					new Element('h2', {
						'html' : this._tr('T_persAccountSel')
					}).inject($('accountDlg'));
					
//					new Element('h2', {
//						'html' : this._tr('T_actCodeTitle')
//					}).inject(form);
//					new Element('input', {
//						'id' : 'actCode1',
//						'value' : this.actCode1
//					}).inject(form);
					
					var accountDlgSelect = new Element('select', {
						'name' : 'accountDlgSelect',
						'id' : 'accountDlgSelect'
					});					
					window.dbg.log('more than 10 accouts step1 ');
					// build selection
					new Element('option', {
						'id' : 'account',
						'text' : '',
						'name' : 'account',
						'value' : ''
					}).inject(accountDlgSelect);	
					for (var i = 0; i < accounts.length; i++) {
//						var fs = new Element('fieldset', {
//							'class' : 'accountSel'
//						}).inject(form);
						new Element('option', {
							'id' : 'account' + i,
							'text' : accounts[i],
							'name' : 'account',
							'value' : accounts[i]
						}).inject(accountDlgSelect);	
					}					
					window.dbg.log('more than 10 accouts step2  ');
					
					var actionLnk = new Element('a', {
						'html' : this._tr('T_selAccount'),
						'id'   : 'accountActionLnk',
						'events' : {
							'click' : function() {
								this.processAccountSelection(true);
							}.bind(this)
						}
					});
					window.dbg.log('more than 10 accouts step 3 ');
					
					actionLnk.inject(form);
					// next Action processAccount +Selection
					this.account= null;
					accountDlgSelect.inject(form);
					
					// inject form
					form.inject($('accountDlg'));
					window.dbg.log('more than 10 accouts step4 ');
					
				}else if (accounts instanceof Array && accounts.length > 1 ) {
					window.dbg.log('more than one accout');
					// create form
					var form = new Element('form', {
						'id' : 'accountDlgForm'
					});

					// set sub title
					new Element('h2', {
						'html' : this._tr('T_persAccountSel')
					}).inject($('accountDlg'));

					// build selection
					for (i = 0; i < accounts.length; i++) {
						var fs = new Element('fieldset', {
							'class' : 'accountSel'
						}).inject(form);
						new Element('input', {
							'id' : 'account' + i,
							'type' : 'radio',
							'name' : 'account',
							'value' : accounts[i]
						}).inject(fs);
						new Element('label', {
							'html' : accounts[i]
						}).inject(fs);
						fs.inject(form);

					}
					
					
					var actionLnk = new Element('a', {
						'html' : this._tr('T_selAccount'),
						'id'   : 'accountActionLnk',
						'events' : {
							'click' : function() {
								this.processAccountSelection();
							}.bind(this)
						}
					});
					
					
					actionLnk.inject(form);
					// next Action processAccount +Selection
					this.account= null;
					
					// inject form
					form.inject($('accountDlg'));

				} else {

					// set sub title
					new Element('h2', {
						'html' : this._tr('T_persAccount')
					}).inject($('accountDlg'));
					new Element('p', {
						'id' : 'singleAccount',
						'html' : accounts instanceof Array ? accounts[0]
								: accounts
					}).inject($('accountDlg'));
					this.account = accounts[0];
					this.processAccountSelection();
					return;

				}

				// set right info text
				sscView.setInfoRight('IT_Info', 'I_accountSel');

				// set next action
				//this.setNextAction(action, actionFnc, true);

			},
			
			showAuthCode : function(code){
				
				window.dbg.log('showAuthCode');
				
				var div = new Element('div',{'class' : 'genCode'});
						
				new Element('h2', {
					'html' : code
				}).inject(div);
				
				this.setPrompt('');
				
				div.inject($('infoMore'));
				
			},
			
			showAuthPersonDlg : function() {

				window.dbg.log('showAuthPersonDlg');

				// clear persons
				this.authPers1 = this.authPers2 = '';

				// build form
				var form = new Element('form');
				new Element('h2', {
					'html' : this._tr('T_authPersTitle')
				}).inject(form);
				new Element('label', {
					'html' : this._tr('T_authPers1')
				}).inject(form);
				new Element('input', {
					'id' : 'authPers1',
					'value' : this.authPers1
				}).inject(form);
				new Element('label', {
					'html' : this._tr('T_authPers2')
				}).inject(form);
				new Element('input', {
					'id' : 'authPers2',
					'value' : this.authPers2
				}).inject(form);

				// build wrapping div and header
				var div = new Element('div', {
					'class' : 'authPersonsDlg'
				});

				// inject form
				form.inject(div);

				// inject div into info
				$('infoMore').empty();
				div.inject($('infoMore'));
				
			},
			
			showGetPinDlg: function(){
				 
				
				// build form
				var form = new Element('form');
				// pin Abfrage
				var div = new Element('div', {
					'class' : 'pinDlg'
				});
				new Element('h2', {
					'html' : this._tr('T_pinTitle2')
				}).inject(div);
				new Element('h2', {
					'html' : this._tr('')
				}).inject(form);
				new Element('input', {
					'id' : 'pin',
					'type' : 'PASSWORD',
					'value' : ''
				}).inject(form);
				// inject form
				form.inject(div);
				
				// inject it to info
				$('infoMore').empty();
				div.inject($('infoMore'));
				$('pin').focus();
				
			},
			
			showPersonalizationStatus : function(status) {

				window.dbg.log('showPersonalizationStatus');

				var el = $('infoMore');
				el.empty();

				new Element('h2', {
					'class' : (status >= 1 ? 'persoStatOk' : 'persoStat'),
					'html' : this._tr('T_validStatus')
				}).inject(el);

				new Element('h2', {
					'class' : (status >= 2 ? 'persoStatOk' : 'persoStat'),
					'html' : this._tr('T_creatDigId') + ' ' + this.userId
				}).inject(el);

				// fixme --- if more than one account
				if (status === 2)
					new Element('div', {
						'id' : 'accountDlg'
					}).inject(el);

				new Element('h2', {
					'class' : (status == 3 ? 'persoStatOk' : 'persoStat'),
					'html' : this._tr('T_instDigId')
				}).inject(el);

				switch (status) {

				case 1:
					this.setInfoRight('IT_Info', 'I_persoStep1');
					break;
				case 2:
					this.setInfoRight('IT_Info', 'I_persoStep2');
					break;
				case 3:
					this.setInfoRight('IT_Info', 'I_persoStep3');
					break;
				
				}

			},
			
			
			showHelp : function() {
				this.showPopUp('T_Help','I_Contact');
			},
			
			showHints : function(){
				
				window.dbg.log('showHints');
				this.setInfoTitle('T_HintTitle');
				this.setInfoTitle('T_cardActivationSuccess');
				this.setInfoLeft('','');
				this.setInfoRight('T_HintTitleR','I_HintInfoR');
				var infoHtml = '';
				
				infoHtml += this._createInfoAccordionEntry(this._tr('T_HintSubTitle1'),
																  'hint',
																  this._tr('I_Hint_1'));
								
				/*infoHtml += this._createInfoAccordionEntry(this._tr('T_HintSubTitle2'),
						  'hint',
						  this._tr('I_Hint_2'));
				*/
				/*
				infoHtml += this._createInfoAccordionEntry(this._tr('T_HintSubTitle3'),
						  'hint',
						  this._tr('I_Hint_3'));
				*/
				//window.dbg.log(infoHtml);
				
				this._createInfoAccordion(infoHtml);
				
			},

			showPinDlg : function(change) {

				window.dbg.log('showPinDlg');

				// clear all pins
				this.pin = this.pin1 = this.pin2 = '';

				// build form
				var form = new Element('form');

				// change Pin Dialog
				if (change) {
					new Element('h2', {
						'html' : this._tr('T_currPinTitle')
					}).inject(form);
					new Element('input', {
						'id' : 'pin',
						'type' : 'PASSWORD',
						'value' : this.pin
					}).inject(form);
					
					new Element('label', {
						'html' : this._tr('T_pin')
					}).inject(form);
					
					// create unblock link as forgot your PIN link
					new Element('a', {
						'html' : this._tr('T_forgotPIN'),
						'id' : 'btnForgotPIN',
						'class' : 'btnForgotPIN',
							events : {
								'click' : this.unblockCard.bind(this)
							}
					}).inject(form);
					
					
						//this.setButton('true', $('btnForgotPIN'), this.unblockCard);

					

					// activation Code Dialog
				} else {
					new Element('h2', {
						'html' : this._tr('T_actCodeTitle')
					}).inject(form);
					new Element('input', {
						'id' : 'actCode1',
						'value' : this.actCode1
					}).inject(form);
					new Element('label', {
						'html' : this._tr('T_actCode1') +' '+sscModel.user.authEmail1
					}).inject(form);
					new Element('input', {
						'id' : 'actCode2',
						'value' : this.actCode2
					}).inject(form);
					new Element('label', {
						'html' : this._tr('T_actCode2') +' '+sscModel.user.authEmail2
					}).inject(form);
					
				}

				new Element('h2', {
					'html' : this._tr('T_pinTitle')
				}).inject(form);
				new Element('input', {
					'id' : 'pin1',
					'type' : 'PASSWORD',
					'value' : this.pin1
				}).inject(form);
				new Element('label', {
					'html' : this._tr('T_pin1')
				}).inject(form);
				new Element('input', {
					'id' : 'pin2',
					'type' : 'PASSWORD',
					'value' : this.pin2
				}).inject(form);
				new Element('label', {
					'html' : this._tr('T_pin2')
				}).inject(form);

				// build wrapping div and header
				var div = new Element('div', {
					'class' : 'pinDlg'
				});

				// inject form
				form.inject(div);

				// inject it to info
				$('infoMore').empty();
				div.inject($('infoMore'));
			},
			
			
			showSelectCardDlg : function(cards) {

				window.dbg.log('showSelectCardDlg - ' + cards);

				// build form
				var form = new Element('form');
				// build title
				new Element('h2', {
					'html' : this._tr('P_selectCard')
				}).inject(form);
				
				for (var i = 0; i < cards.length; i++ ){
					var fs = new Element('fieldset', {
						'class' : 'cardSel'
					}).inject(form);
					var str = cards[i].split('|');
					new Element('input', {
						'id' : 'sCard' + i,
						'type' : 'radio',
						'name' : 'sCard',
						'value' : str[3],
						'checked' : (i === 0 ? true : false)
					
					}).inject(fs);
					
					// build label
					var name = str[5];
					if (name === 'empty'){
						name = this.translations['S_unpersonalized'] !== undefined ? this.translations['S_unpersonalized']: 'S_unpersonalized';
					}
					new Element('label', {
						'html' : str[0] + ' - ' + name
					}).inject(fs);
					fs.inject(form);
							
				}
				
				
				
				// build wrapping div and header
				var div = new Element('div', {
					'class' : 'selectCardDlg'
				});

				// inject form
				form.inject(div);

				// inject div into info
				$('infoMore').empty();
				div.inject($('infoMore'));
				
			},
			
			showSmartcardStatus : function() {

				window.dbg.log('showSmartcardStatus');

				this.setInfoTitle('T_StatusTitle');
				var infoHtml = '';
				
				var user = sscModel.getUserInfo();
				
				this.setPrompt();
				this.dataPrivacyHtml = this.digitalSignatureHtml = this.digitalIdHtml = this.otherCertsHtml = '';
				this.digitalIdStatus = this.otherCertsStatus = 'green';
				this.digitalSignatureStatus = 'green';
				this.dataPrivacyStatus = 'red';
				
				
				//if (user !== undefined && user.certs !== undefined && user.certs.length > 0){
					this._certs2Html(user.parsedCerts);
					
					if (this.digitalIdHtml){				
						infoHtml += this._createInfoAccordionEntry(this._tr('T_DigitalIdentity'),
																	  'certStatus_'+this.digitalIdStatus,
																	  this.digitalIdHtml);
					}
					
					if (this.dataPrivacyHtml){	
						infoHtml += this._createInfoAccordionEntry(this._tr('T_DataPrivacy'),
																	  'certStatus_'+this.dataPrivacyStatus,
																	  this.dataPrivacyHtml);
					}
					if (this.digitalSignatureHtml){	
						infoHtml += this._createInfoAccordionEntry(this._tr('T_digitalSignature'),
																	  'certStatus_'+this.digitalSignatureStatus,
																	  this.digitalSignatureHtml);
					}
					
					if ( this.otherCertsHtml){
							infoHtml += this._createInfoAccordionEntry(this._tr('T_OtherCerts'),
									 								 'certStatus_'+this.otherCertsStatus,
																	  this.otherCertsHtml);
					}	
					
					

					this._createInfoAccordion(infoHtml);
				//}
			},

			showPopUp : function(msgId, sign, errorCode, noSupportMsg) {
					
				window.dbg.log('showPopUp - ' + msgId + '-' + errorCode );
				this.showPopUpMsg( errorCode !== undefined 
						             ? this._tr(msgId) + '<br/><a id="errCodeToggle" href="#">' + this._tr('...') + '</a><br /><div id="errCode">' + errorCode + '</div>'
						             : this._tr(msgId)
						             , sign , noSupportMsg !== undefined ? true : undefined);

			},

			showPopUpMsg : function(msg, sign, noSupportMsg) {
				window.dbg.log('showPopUpMsg');
				$('popupInfo').set('html', msg);
				if (noSupportMsg === undefined ){
				   $('popupInfo2').set('html', this._tr('T_popupSupportContact'));
				} else {
				   $('popupInfo2').hide();
				}
				//$('popupSign').setProperty('class', sign);
				$('popupFrame').style.display = 'block';
				var el = $('errCodeToggle');
				if (el){
					console.log(el);
					var mySlide = new Fx.Slide('errCode');
					mySlide.hide();
					el.addEvent('click', function(event){
											event.stop();
											console.log('click');
											mySlide.toggle();
					});
				}

			},

			
			closePopup : function() {
				
				$('popupInfo').set('html', '');
				$('popupFrame').style.display = 'none';
				
				window.location.reload();
			},

			/*----------------------------------------------------------------------------------*/
			/* private functions */
			/*----------------------------------------------------------------------------------*/

			// -----------------------------------------------------------
			// formater methods
			// -----------------------------------------------------------
			_certs2Html : function(certs) {
				
				var html = '';
				var title = '';
				var subject = '';
				var certType = 0; // 1 = escrow, 2 = nonescrow, 3 = other
				
				window.dbg.log('_certs2Html');
				
				for (i = 0; i < certs.length; i++) {
					
					// determine cert type
					// nonescrow
					if (certs[i].CERTIFICATE_TYPE ===  'nonescrow'){
						certType = 2;
						title = certs[i].SUBJECT_UPN;
						subject = '<tr><td>Subject</td><td>'+ certs[i].SUBJECT + '</td></tr>';
				    // escrow
					} else if (certs[i].CERTIFICATE_TYPE ===  'escrow'){
						certType = 1;
					    title = certs[i].SUBJECT;
					    subject = '';	
					// digital signature
					}  else if (certs[i].CERTIFICATE_TYPE ===  'signature'){
						certType = 4;
					    title = certs[i].SUBJECT;
					    subject = '<tr><td>Subject</td><td>'+ certs[i].SUBJECT + '</td></tr>';		    
					// other certs
					} else {
						certType = 3;
						title = certs[i].SUBJECT;
						subject = '<tr><td>Subject</td><td>'+ certs[i].SUBJECT + '</td></tr>';
					}
					
					
					html   = '<div class="certInfo">'
							+ '<div class="certSubject">' 
							+ title   
							+ '</div>'

							+ '<table class="certDetails">'
							+ subject
							+ '<tr><td>Validity</td><td>'
							+ certs[i].NOTBEFORE_ISO + ' to '
							+ certs[i].NOTAFTER_ISO + '</td></tr>'
							+ '<tr><td>Serial</td><td>'
							+ certs[i].CERTIFICATE_SERIAL + '</td></tr>'
							+ '<tr><td>Issuer</td><td>' + certs[i].ISSUER_DN
							+ '</td></tr>' + '</table>' 
							
							+ '</div>';
					window.dbg.log(html);	
					
					// setStatus
					switch(certType){
					case 1:
						this.dataPrivacyHtml += html;
						if (certs[i].VISUAL_STATUS === 'green' && this.dataPrivacyStatus === 'red'){
						    this.dataPrivacyStatus = certs[i].VISUAL_STATUS;
						}
						break;
					case 2:
						this.digitalIdHtml += html;
						if (certs[i].VISUAL_STATUS !== 'green' && this.digitalIdStatus !== 'red'){
						    this.digitalIdStatus = certs[i].VISUAL_STATUS;
						}
						break;
					case 3:
						this.otherCertsHtml += html;
						if (certs[i].VISUAL_STATUS !== 'green' && this.otherCertsStatus !== 'red'){
						   // this.otherCertsStatus = certs[i].VISUAL_STATUS;
						}
						break;
					case 4:	
						this.digitalSignatureHtml += html;
						if (certs[i].VISUAL_STATUS === 'green' && this.digitalSignatureStatus === 'red'){
						    this.dataPrivacyStatus = certs[i].VISUAL_STATUS;
						}
						break;
					}
					
					
				}
			window.dbg.log("leaving _certs2Html");
			},
			
			
			_createInfoAccordionEntry : function(title, signClass, content) {

				html = '<div class="infoCenterSubHeadline">'
						+ '<h2>'
						+ title
						+ '</h2>'
						+ '<img  class="acc_toggler"  src="'+this.options.baseUrl+'img/arrow_down.gif"/>'
						+ '<div class="' + signClass + '"></div>'

						+ '</div>' + '<div class="infoCenterSubInfo">'
						+ '<div>' + content + '</div>' + '</div>';

				return html;
			},

			_createInfoAccordion : function(html) {

				$('infoMore').style.display = 'block';
				$('infoMore').innerHTML = html;

				this.infoAccordion = new Fx.Accordion($('infoMore'),
						'img.acc_toggler', 'div.infoCenterSubInfo', {
							opacity : false,
							display : -1,
							alwaysHide : true,
							onActive : function(toggler, element) {
								toggler.setProperty('src',this.options.baseUrl+'img/arrow_up.gif');
							}.bind(this),
							onBackground : function(toggler, element) {
								toggler.setProperty('src',
										this.options.baseUrl+'img/arrow_down.gif');
							}.bind(this)
						});
			},

			// -----------------------------------------------------------
			// language related methods
			// -----------------------------------------------------------
			
			// showe all language keys for debugging/information
			_showLanguageKeys : function(){
					this._changeLanguage_step2([]);
			},
			
			_changeLanguage : function() {

				window.dbg.log('_changeLanguage');

				// only us and de supported
				if (this.options.language === 'de')
					this.options.language = 'us';
				else
					this.options.language = 'de';

				// get Translations and continue at initialization step 2
				sscModel.getTranslations(this.options.language,
						this._changeLanguage_step2);

				window.dbg.log('_changeLanguage');
			},

			_changeLanguage_step2 : function(translations) {

				window.dbg.log('_changeLanguage_step2');
				/*
				 * write error msg to log (sorted) 
				 */
				
				// first create a hash from object
				if (sscDebug === true){
					var hash = new Hash(translations);
					// build an array from hash
					arr = [];
					hash.each(function(value, key){ arr.push('"'+key+'"' + ':' + '"'+ value + '",'); });
					// sort the array
					out = '';
					arr.sort().each(function(value, key){ window.dbg.log(value + '\n'); });
				}
				// store translations
				this.translations = translations;
			
				// translate static buttons
				$$('.btnLang').set('html', this._tr('T_Lang'));
				$$('.btnHelp').set('html', this._tr('T_Help'));
				if ($('btnUnblock'))   $('btnUnblock').set('html', this._tr('T_Unblock'));
				if ($('btnChangePin')) $('btnChangePin').set('html', this._tr('T_ChangePin'));

				// translate all elements with class tt
				$$('.tt').each(function(el) {
					this._trE(el.id).replaces(el);
					}.bind(this));
		 

			},

			_tr : function(msgId) {

				var spo = '<span class="tt" id="' + msgId + '">';
				var spc = '</span>';
				// return this.translations[msgId] !== undefined ?
				// this.translations[msgId] : msgId;
				return this.translations[msgId] !== undefined 
						? spo + this.translations[msgId] + spc 
						: spo + msgId + spc;

			},

			_trE : function(msgId) {

				return new Element(
						'span',
						{
							'html' : (this.translations[msgId] !== undefined ? this.translations[msgId]
									: msgId),
							'id' : msgId,
							'class' : 'tt'
						});
			
			},

			// -----------------------------------------------------------
			// menu & action methods
			// -----------------------------------------------------------

			_initMenues : function(main) {

				window.dbg.log('_initMenues - ' + main);

				// create Language link/// and inject it
				var el = new Element('a', {
					'html' : this._tr('T_Lang'),
					'class' : 'btnLang',
					events : {
						'click' : this._changeLanguage.bind(this)
					}
				});
				el.inject(new Element('li', {
					'class' : 'first'
				}).inject($('footerMenuList')));
				el = new Element('a', {
					'html' : this._tr('T_Lang'),
					'class' : 'btnLang',
					events : {
						'click' : this._changeLanguage.bind(this)
					}
				});
				el.inject(new Element('li', {
					'class' : 'first'
				}).inject($('topMenuList')));

				// create main menu if desired
				if (main){
					// create menu entries
					for (var i = 0; i < this.mainMenu.length; i++){
						// create dom element
						el = new Element('a', {
							'html' : this._tr(this.mainMenu[i].text),
							'id' :this.mainMenu[i].id
						});
						
						// and inject it
						if (i == 0)
							el.inject(new Element('li', {'class' : 'first'}).inject($('mainMenuList')));
						else
							el.inject(new Element('li').inject($('mainMenuList')));
						
					}
	
				} 

			},

			_performNextAction : function() {

				window.dbg.log('_performNextAction');

				// remember fnc
				var fnc = this.nextActionFnc;
				// and clear it
				this.nextActionFnc = null;
				$('nextActionDiv').empty();
				$('backActionDiv').empty();
				
				// perform action
				if (fnc && typeof fnc === 'function') {
					fnc();
				}
			},
			
			_performBackAction : function() {

				window.dbg.log('_performBackAction');

				// remember fnc
				var fnc = this.backActionFnc;
				// and clear it
				this.backActionFnc = null;
				$('backActionDiv').empty();
				$('nextActionDiv').empty();
				
				// perform action
				if (fnc && typeof fnc === 'function') {
					fnc();
				}
			},

			/*
			 * handle enter key
			 */
			handleKeyDown : function(e) {
				if (e.key === 'enter') {
					window.dbg.log('enter pressed');
					if (this.nextActionFnc !== null) {
						this._performNextAction();
					}
				}
			},

		// -----------------------------------------------------------
		// evaluation methods
		// -----------------------------------------------------------
			_trim : function (s) {
				   return s.replace (/^\s+/, '').replace (/\s+$/, '');
				},
	
			_resetInputErr: function(){
				this.removeEvent('keydown', this._resetInputErr);
				this.style.backgroundColor = "white";
			},
			
			_isEmail : function(s) {

				var a = false;
				var res = false;
	
				if (typeof (RegExp) == 'function') {
					var b = new RegExp('abc');
					if (b.test('abc') == true) {
						a = true;
					}
				}
	
				if (a == true) {
					reg = new RegExp(
							'^([a-zA-Z0-9\-\.\_]+)' + '(\@)([a-zA-Z0-9\-\.]+)' + '(\.)([a-zA-Z]{2,4})$');
					res = (reg.test(s));
				} else {
					res = (s.search('@') >= 1
							&& s.lastIndexOf('.') > s.search('@') && s
							.lastIndexOf('.') >= s.length - 5);
				}
				return (res);

			},

			// -----------------------------------------------------------
			// json handling methods
			// -----------------------------------------------------------

			_traverseJson : function(o, func) {
				for (i in o) {
					func.apply(this, [ i, o[i] ]);
					if (typeof (o[i]) == "object") {
						// going on step down in the object tree!!
						this._traverseJson(o[i], func);
					}
				}
			},

			// called with every property and it's value
			_keyvalue2Log : function(key, value) {
				window.dbg.log(key + " : " + value);
			},

			// called with every property and it's value
			_keyvalue2HtmlTabRow : function(key, value) {
				this.tabEntriesHtml += '<tr><td>' + key.replace(/_/g, ' ')
						+ '</td><td>' + value + '</td></tr>';
			}

		});