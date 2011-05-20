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
				mode	 : 'perso'
			},
			/**
			 * bindings
			 */
			Binds : ['init_step2', 'handleKeyDown', 'performNextAction',
					'processAccountSelection', 'processAccountSelection_step2',
					'processAuthPersons', 'processAuthPersons_done',
					'processPersonalization','processPersonalization_done',
					'processPins', 'processPins_done', 'processAuthCodes_done',
					'processCardInfo', 'showSmartcardStatus','showAuthCode',
					'showAuthPersonDlg',
					'init_done', 'unblockCard', 'changePin', 'tr_' ,'setTranslatedElementText',
					'changeLanguage_step2'],

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
				
				// set popup closer
				if ($('popupCloser') != null) {
					$('popupCloser').addEvent('click', this.closePopup);
				}

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
				
				// set last changes
				this.setTranslatedElementText($('lastChanges'), 'T_lastChanges');
				
				/*
				 *  handle genCode mode
				 */
				if (this.options.mode === 'genCode'){
					// prepare menues
					this.initMenues(false);
					
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
					this.initMenues(true);
					
					// set title
					this.setInfoTitle('T_Initializing');
				
					// set status and info message
					this.setStatusMsg("I_StartUp", "P_pleaseWait", 'blue');
					this.setInfoRight('IT_Info','I_welcome');
				
					// add a keydown event to capture the enter key
					document.addEvent('keydown', this.handleKeyDown);

					// initialize card reader
					sscModel.initializeCardReader(this.init_done);
					/*
					setTimeout(function() {
						sscModel.initializeCardReader(this.init_done);
					}.bind(this), testTimeout);
					*/
				}

			}, // init_step2

			/**
			 * initialization step 3 will be called after sscModel finished Card
			 * Reader Initialization
			 * 
			 * @param {boolean}
			 *            true if cardReader is available and successfully
			 *            initialized
			 */
			init_done : function(cardReaderAvailable) {
				
				window.dbg.log('init_done - cardReaderAvailable = '+ cardReaderAvailable);

				if (cardReaderAvailable) {

					// clear status msg
					this.setStatusMsg('T_idle','', 'idle');
					// prompt to insert card
					this.insertCard();

				} else {
					this.setInfoRight('IT_Info','I_contactAdmin');
					this.setPrompt('E_no-card-reader');
					this.setOverallStatus('red');
					this.setStatusMsg('T_idle','', 'idle');

				}
				
			}, // init_done
			

			/*----------------------------------------------------------------------------------*/
			/* public methods */
			/*----------------------------------------------------------------------------------*/
			
			/**
			 * 
			 * processCardInfo - main task dispatcher depending on status
			 * 
			 * 
			 * @param status
			 * 
			 *            
			 */
			processCardInfo : function(status) {

				window.dbg.log('processCardInfo status: ' + status);
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
				switch (status) {
				
				case 'error':
					
					this.setInfoTitle('');
					
					// error from read card
					break;
				
				case 'cardBlocked':
					this.setPrompt('P_cardBlocked');
					this.setInfoRight('IT_Info','I_cardBlocked');
					break;
					
				case 'cardNotActivated':
					this.setPrompt('P_cardNotActivated');
					this.setInfoRight('IT_Info','I_cardNotActivated');
					break;
					
				case 'cardUnknown':
					this.setPrompt('P_cardUnknown');
					this.setInfoRight('IT_Info','I_cardUnknown');
					break;
					
				case 'startPerso':
					// start personalization
					this.setInfoRight('IT_Info','I_notPersonalized');
					this.setInfoTitle('T_PersoTitle');
					this.setNextAction('T_startPerso',this.processPersonalization, true);
					break;
				
				case 'contPerso':
					// FIXME: neues flag
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
					}
					
					break;
				
				case 'enterAuthcodes':
					// enter authcodes
					
					// clear authcodes (myight be saved from prevoius attempt)
					this.actCode1 = '';
					this.actCode2 = '';
					 
					this.showPinDlg(false);
					sscView.setInfoRight('IT_Info', 'I_actStep2');
					// set title
					if (user.cardActivation  === true ){
						this.setInfoTitle('T_ScActivationStep2');
						// set next & back action
						this.setNextAction('T_proceedActStep2', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
					}else{
						this.setInfoTitle('T_cardUnblock');
						// set next & back action
						this.setNextAction('T_cardUnblock', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);

					}
					break;
				
				case 'enterAuthPersons':	
					// do unblock
					this.actCode1='';
					this.actCode2='';
					  
					this.showAuthPersonDlg();
					
					// card activation?
					if (user.cardActivation === true){
						// set title
						this.setInfoTitle('T_ScActivationStep1');
						// set right info text
						sscView.setInfoRight('IT_Info', 'I_authPers');
						// set next & back action
						this.setNextAction('T_startActivation', this.processAuthPersons, true);
						//this.setBackAction('T_back', this.showSmartcardStatus, true);
					
					// unblock
					} else {
						// set title
						this.setInfoTitle('T_cardUnblock');
						// set right info text
						sscView.setInfoRight('IT_Info', 'I_unblock');
						// set next & back action
						this.setNextAction('T_cardUnblock', this.processAuthPersons, true);
						this.setBackAction('T_back',function(){ this.processCardInfo('showStatus');}.bind(this), true);
						
					}
					break;
					
				case 'enterAuthPersonFailure':
					this.showAuthPersonDlg();
					//this.setInfoTitle('T_ScActivationStepFailureRestartUnblock');
					// set right info text
					//sscView.setInfoRight('IT_Info', 'I_authPersFailure');
					// set next action
					if (user.cardActivation === true){
						// set title
						this.setInfoTitle('T_ScActivationStepFailureRestartUnblock');
						// set right info text
						sscView.setInfoRight('IT_Info', 'I_authPers');
						// set next & back action
						this.setNextAction('T_startActivation', this.processAuthPersons, true);
						//this.setBackAction('T_back', this.showSmartcardStatus, true);
					
					// unblock
					} else {
						// set title
						this.setInfoTitle('T_ScActivationStepFailureRestartUnblock');
						// set right info text
						sscView.setInfoRight('IT_Info', 'I_unblock');
						// set next & back action
						this.setNextAction('T_cardUnblock', this.processAuthPersons, true);
						this.setBackAction('T_back',function(){ this.processCardInfo('showStatus');}.bind(this), true);
						
					}
					
					this.setNextAction('T_startActivation', this.processAuthPersons, true);
				
				case 'activateSc':
					// activate smartcard
					break;
					
				case 'showStatusActSuccess':
					this.setInfoRight('IT_Info','I_fullyOperational');
					// call model to read card with callback 
					sscModel.readCard(this.processCardInfo);
				    break;
					
				// status	
				case 'showStatus':
					
					// FIXME: neues flag
					if (sscModel.getReCert()){
						// continue recertification
						this.setInfoRight('IT_Info','I_Recert');
						this.setInfoTitle('T_RecertTitle');
						this.setNextAction('T_startRecert',this.processPersonalization, true);
					}else{
						this.setInfoRight('IT_Info','I_fullyOperational');
					}
					this.setTopMenu(true);
					// get user info and display status accordion
					this.showSmartcardStatus();
					// this.setInfoLeft('T_regFor', 'testuser<br />Deutsche Bank AG'); 
					break;
					// status	
					
					
				case 'startRecert':
					this.showSmartcardStatus(sscModel.getUserInfo());
					if(sscModel.overAllStatus == 'amber'){
						this.setInfoRight('IT_Info','I_expiresSoon');
					}
					if(sscModel.overAllStatus == 'red'){
						this.setInfoRight('IT_Info','I_expired');
					}
					
					this.setNextAction('T_startRecert',this.processPersonalization, true);
					break;
								
					
				}
	
			},


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
				if (!this.authPers1.length || !this.isEmail(this.authPers1)) {

					$('authPers1').style.backgroundColor = "red";
					$('authPers1').focus();
					$('authPers1').addEvent('keydown', this.resetInputErr);
					error = true;

				} else {
					$('authPers1').style.backgroundColor = "white";
				}

				// check email addr 2
				if (!this.authPers2.length || !this.isEmail(this.authPers2)) {

					$('authPers2').style.backgroundColor = "red";
					$('authPers2').addEvent('keydown', this.resetInputErr);
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
						this.setBackAction('T_back',function(){ this.processCardInfo('showStatus');}.bind(this), true);
					}
					
					
					this.setNextAction('T_proceedActivation',this.processAuthPersons, true);
				}

				else {
					this.setStatusMsg();
					sscModel.processAuthPersons(this.authPers1,this.authPers2,this.processAuthPersons_done);
					/* FIXME: authPerson should not be trimmed and converted to uppercase
					sscModel.processAuthPersons(this.trim(this.authPers1.toUpperCase()), 
							                    this.trim(this.authPers2.toUpperCase()),
							                    this.processAuthPersons_done);
					*/
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
							$('authPers1').addEvent('keydown', this.resetInputErr);
						}
						if (invalidMail === 2 || invalidMail === 3){
							$('authPers2').style.backgroundColor = "red";
							$('authPers2').focus();
							$('authPers2').addEvent('keydown', this.resetInputErr);
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
						this.setBackAction('T_back',function(){ this.processCardInfo('showStatus');}.bind(this), true);		
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
					
					sscView.setInfoRight('IT_Info', 'I_actStep2');
					// set title
					if (sscModel.user.cardActivation  === true ){
						this.setInfoTitle('T_ScActivationStep2');
						// set next & back action
						this.setNextAction('T_proceedActStep2', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
					}else{
						this.setInfoTitle('T_cardUnblock');
						// set next & back action
						this.setNextAction('T_cardUnblock', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
					}			
				}
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
							function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
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
						$('pin').addEvent('keydown', this.resetInputErr);
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
					$('pin1').addEvent('keydown', this.resetInputErr);
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
					$('pin2').addEvent('keydown', this.resetInputErr);
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
					this.setBackAction('T_back',function(){ this.processCardInfo('showStatus');}.bind(this), true);
					

					// test on new pin unequal current pin
				} else if (this.currentPin && this.pin === this.pin1) {
					this.setStatusMsg('T_idle','', 'idle');
					this.setOverallStatus('red');
					this.setPrompt('E_eqPins');
					//this.setStatusMsg('E_eqPins', 'P_insertUePins', 'red');
					$('pin1').style.backgroundColor = "red";
					$('pin1').addEvent('keydown', this.resetInputErr);
					$('pin1').focus();
					this.setNextAction('T_enterPins', this.processPins, true);
					this.setBackAction('T_back',function(){ this.processCardInfo('showStatus');}.bind(this), true);
					

					// test on confirmation pin
				} else if (this.pin1 !== this.pin2) {
					//this.setStatusMsg('E_uneqPins', 'P_insertEqPins', 'red');
					this.setStatusMsg('T_idle','', 'idle');
					if($('pin')){
						
						this.setNextAction('T_enterPins', this.processPins, true);
						this.setBackAction('T_back',function(){ this.processCardInfo('showStatus');}.bind(this), true);
						
						
					}else{
						
						if (sscModel.user.cardActivation){
							this.setInfoTitle('T_ScActivationStep2');
							// set next & back action
							this.setNextAction('T_proceedActStep2', this.processPins, true);
							this.setBackAction('T_chooseAuthPers', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
						}else{
							this.setInfoTitle('T_cardUnblock');
							// set next & back action
							this.setNextAction('T_cardUnblock', this.processPins, true);
							this.setBackAction('T_chooseAuthPers', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
						}
						
					}
					this.setOverallStatus('red');
					this.setPrompt('E_uneqPins');
					$('pin2').style.backgroundColor = "red";
					$('pin2').addEvent('keydown', this.resetInputErr);
					$('pin2').focus();


				} else {
					this.setStatusMsg();
					if ($('pin')) {
						sscModel.processPins(this.pin, this.pin1, this.pin2,
								this.processPins_done);
					} else {
						sscModel.processAuthCodes(this.pin1, 
												  this.trim(this.actCode1),
												  this.trim(this.actCode2),
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
					$('pin1').addEvent('keydown', this.resetInputErr);
					$('pin2').style.backgroundColor = "red";
					$('pin2').focus();
					$('pin2').addEvent('keydown', this.resetInputErr);
					
					// set next & back action
					this.setNextAction('T_enterPins', this.processPins, true);
					this.setBackAction('T_back', function(){ this.processCardInfo('showStatus');}.bind(this), true);
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
					$('pin').addEvent('keydown', this.resetInputErr);
					// set next & back action
					this.setNextAction('T_enterPins', this.processPins, true);
					this.setBackAction('T_back', function(){ this.processCardInfo('showStatus');}.bind(this), true);
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
					this.setBackAction('T_back',function(){ this.processCardInfo('showStatus');}.bind(this), true);
	
//					this.setInfoTitle('T_changePin');
//					// set right info text
//					this.setInfoRight('IT_Info', 'I_cardBlocked');
//					// set next & back action
//					this.setNextAction('T_cardUnblock', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
//					this.setBackAction('T_back', function(){ this.processCardInfo('showStatus');}.bind(this), true);				 
					this.setPrompt('T_cardBlocked');
				// everything ok
				} else {
					this.setPrompt('T_changePinSuccess');
					// set right info text
					this.setInfoRight('IT_Info', 'I_changePin');
					// set next & back action
					this.setNextAction('T_enterPins', this.processPins, true);
					this.setBackAction('T_back', function(){ this.processCardInfo('showStatus');}.bind(this), true);
					//this.setNextAction('T_continue','T_changePinSuccess',
					//		function(){this.processCardInfo('showStatus');}.bind(this));
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
							$('actCode1').addEvent('keydown', this.resetInputErr);
						} 
						if (invalidActCode === 2 || invalidActCode === 3){
							$('actCode2').style.backgroundColor = "red";
							$('actCode2').focus();
							$('actCode2').addEvent('keydown', this.resetInputErr);
						}
					}
					// FIX END
					
					if (sscModel.user.cardActivation){
						this.setInfoTitle('T_ScActivationStep2');
						// set next & back action
						this.setNextAction('T_proceedActStep2', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
					}else{
						this.setInfoTitle('T_cardUnblock');
						// set next & back action
						this.setNextAction('T_cardUnblock', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
					}
					
				// invalid pin	
				} else if (status === 'invalidPin'){
					this.setPrompt('T_invalidPolicy');
					//this.showPinDlg(false);
					$('pin1').style.backgroundColor = "red";
					$('pin1').focus();
					$('pin1').addEvent('keydown', this.resetInputErr);
					$('pin2').style.backgroundColor = "red";
					$('pin2').addEvent('keydown', this.resetInputErr);
					// set title
					
					this.setInfoRight('IT_Info','I_userPinPolicy');
					if (sscModel.user.cardActivation){
						this.setInfoTitle('T_ScActivationStep2');
						// set next & back action
						this.setNextAction('T_proceedActStep2', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
					}else{
						this.setInfoTitle('T_cardUnblock');
						// set next & back action
						this.setNextAction('T_cardUnblock', this.processPins, true);
						this.setBackAction('T_chooseAuthPers', function(){this.processCardInfo('enterAuthPersons');}.bind(this), true);
					}
					
				// general failure
				} else  if (status === 'failure'){
					this.setPrompt('T_generalAuthCodeFailure');
					this.setInfoRight('IT_Info','I_generalAuthCodeFailure');
					this.processCardInfo('enterAuthPersonFailure');
					
				
				// everything ok
				} else {
					$('infoMore').empty();
					this.setPrompt('T_cardActivationSuccess');
					this.setNextAction('T_cardStatus',function(){this.processCardInfo('showStatusActSuccess');}.bind(this), true);
				}
				
				
				
			},
			
			processRecertification : function(){
				window.dbg.log('processRecertification');
				sscModel.sc_start_personalization(this.processRecertification_done);
			},
			
			processRecertification_done : function(){
				window.dbg.log('processRecertification_done');
				
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
				this.setBackAction('T_back', function(){ this.processCardInfo('showStatus');}.bind(this), true);

			}, // changePin

			/**
			 * prompt for "insert card" and calls the appropriate mode function
			 * 
			 */
			
			insertCard : function() {
				this.setInfoTitle('T_Analyse');
				this.setPrompt('P_insertCard');
				
				// call model to read card with callback 
				sscModel.readCard(this.processCardInfo);

			}, // insertCard
			
			
			unblockCard : function() {

				window.dbg.log('unblockCard');
				this.setPrompt();
				this.showAuthPersonDlg();
				// set title
				this.setInfoTitle('T_Unblock');
				// set right info text
				sscView.setInfoRight('IT_Info', 'I_authPers');
				// set next & back action
				this.setNextAction('T_cardUnblock', this.processAuthPersons, true);  
				this.setBackAction('T_back', function(){ this.processCardInfo('showStatus');}.bind(this), true);
				
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
				
			
				
//				var anim =  new Fx.Tween($('infoRight'), {
//		    		property: 'opacity',
//		    		link: 'chain'
//				});
//				
//				anim.start(0).chain(function(){
//					anim.start(1).chain(function(){
//						this.setTranslatedElementText($('infoRightContent'), textId);
//					}.bind(this));		
//				}.bind(this));
//				
			
					
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
					'html' : this.tr_(textId),
					'id'   : 'backActionLnk',
					'class': (active !== undefined && active ? 'active' : ''),
					'events' : {
						'click' : (active !== undefined && active 
								? function() {this.performBackAction();}.bind(this)
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
					'html' : this.tr_(textId),
					'id'   : 'nextActionLnk',
					'class': (active !== undefined && active ? 'active' : ''),
					'events' : {
						'click' : function() {
							this.performNextAction();
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
							+ '">' + this.tr_(msgId) + '</h2>';
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
					$('statusText').innerHTML = this.tr_(msgId);
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

				this.setButton(enable, $('btnChangePin'), this.changePin);
				this.setButton(enable, $('btnUnblock'), this.unblockCard);

			},

			setTranslatedElementText : function(el, textId) {

				// set text
				el.set('html', this.tr_(textId));
				// remember it is translated text
				// if (!el.hasClass('tt')) el.addClass('tt');

				// el.empty();
				// new Element('span',{'id' : textId, 'class' : 'tt', 'html':
				// this.tr_(textId)}).inject(el);

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
						'html' : this.tr_('T_persAccountSel')
					}).inject($('accountDlg'));
					
//					new Element('h2', {
//						'html' : this.tr_('T_actCodeTitle')
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
						'html' : this.tr_('T_selAccount'),
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
						'html' : this.tr_('T_persAccountSel')
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
						'html' : this.tr_('T_selAccount'),
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
						'html' : this.tr_('T_persAccount')
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
					'html' : this.tr_('T_authPersTitle')
				}).inject(form);
				new Element('label', {
					'html' : this.tr_('T_authPers1')
				}).inject(form);
				new Element('input', {
					'id' : 'authPers1',
					'value' : this.authPers1
				}).inject(form);
				new Element('label', {
					'html' : this.tr_('T_authPers2')
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

			showPersonalizationStatus : function(status) {

				window.dbg.log('showPersonalizationStatus');

				var el = $('infoMore');
				el.empty();

				new Element('h2', {
					'class' : (status >= 1 ? 'persoStatOk' : 'persoStat'),
					'html' : this.tr_('T_validStatus')
				}).inject(el);

				new Element('h2', {
					'class' : (status >= 2 ? 'persoStatOk' : 'persoStat'),
					'html' : this.tr_('T_creatDigId') + ' ' + this.userId
				}).inject(el);

				// fixme --- if more than one account
				if (status === 2)
					new Element('div', {
						'id' : 'accountDlg'
					}).inject(el);

				new Element('h2', {
					'class' : (status == 3 ? 'persoStatOk' : 'persoStat'),
					'html' : this.tr_('T_instDigId')
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

			showPinDlg : function(change) {

				window.dbg.log('showPinDlg');

				// clear all pins
				this.pin = this.pin1 = this.pin2 = '';

				// build form
				var form = new Element('form');

				// change Pin Dialog
				if (change) {
					new Element('h2', {
						'html' : this.tr_('T_currPinTitle')
					}).inject(form);
					new Element('input', {
						'id' : 'pin',
						'type' : 'PASSWORD',
						'value' : this.pin
					}).inject(form);
					new Element('label', {
						'html' : this.tr_('T_pin')
					}).inject(form);
					

					// activation Code Dialog
				} else {
					new Element('h2', {
						'html' : this.tr_('T_actCodeTitle')
					}).inject(form);
					new Element('input', {
						'id' : 'actCode1',
						'value' : this.actCode1
					}).inject(form);
					new Element('label', {
						'html' : this.tr_('T_actCode1') +' '+sscModel.user.authEmail1
					}).inject(form);
					new Element('input', {
						'id' : 'actCode2',
						'value' : this.actCode2
					}).inject(form);
					new Element('label', {
						'html' : this.tr_('T_actCode2') +' '+sscModel.user.authEmail2
					}).inject(form);
					
				}

				new Element('h2', {
					'html' : this.tr_('T_pinTitle')
				}).inject(form);
				new Element('input', {
					'id' : 'pin1',
					'type' : 'PASSWORD',
					'value' : this.pin1
				}).inject(form);
				new Element('label', {
					'html' : this.tr_('T_pin1')
				}).inject(form);
				new Element('input', {
					'id' : 'pin2',
					'type' : 'PASSWORD',
					'value' : this.pin2
				}).inject(form);
				new Element('label', {
					'html' : this.tr_('T_pin2')
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

			showSmartcardStatus : function() {

				window.dbg.log('showSmartcardStatus');

				this.setInfoTitle('T_StatusTitle');
				var infoHtml = '';
				
				var user = sscModel.getUserInfo();
				
				this.setPrompt();
				this.dataPrivacyHtml = this.digitalIdHtml = this.otherCertsHtml = '';
				this.digitalIdStatus = this.otherCertsStatus = 'green';
				this.dataPrivacyStatus = 'red';
				
				
				//if (user !== undefined && user.certs !== undefined && user.certs.length > 0){
					this.certs2Html(user.parsedCerts);
					
					if (this.digitalIdHtml){				
						infoHtml += this.createInfoAccordionEntry(this.tr_('T_DigitalIdentity'),
																	  'certStatus_'+this.digitalIdStatus,
																	  this.digitalIdHtml);
					}
					
					if (this.dataPrivacyHtml){	
						infoHtml += this.createInfoAccordionEntry(this.tr_('T_DataPrivacy'),
																	  'certStatus_'+this.dataPrivacyStatus,
																	  this.dataPrivacyHtml);
					}
					
					if ( this.otherCertsHtml){
							infoHtml += this.createInfoAccordionEntry(this.tr_('T_OtherCerts'),
									 								 'certStatus_'+this.otherCertsStatus,
																	  this.otherCertsHtml);
					}	
					
					

					this.createInfoAccordion(infoHtml);
				//}
			},

			showPopUp : function(msgId, sign, errorCode) {
					
				window.dbg.log('showPopUp - ' + msgId + '-' + errorCode );
				this.showPopUpMsg( errorCode !== undefined 
						             ? this.tr_(msgId) + '<br/>(Error-Code: #' + errorCode + ')'
						             : this.tr_(msgId)
						             , sign);

			},

			showPopUpMsg : function(msg, sign) {
				window.dbg.log('showPopUpMsg');
				$('popupInfo').set('html', msg);
				$('popupInfo2').set('html', this.tr_('T_popupSupportContact'));
				$('popupSign').setProperty('class', sign);
				$('popupFrame').style.display = 'block';

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
			certs2Html : function(certs) {
				
				var html = '';
				var title = '';
				var subject = '';
				var certType = 0; // 1 = escrow, 2 = nonescrow, 3 = other
				
				window.dbg.log('certs2Html');
				
				for (i = 0; i < certs.length; i++) {
					
					// determine cert type
					if (certs[i].CERTIFICATE_TYPE ===  'nonescrow'){
						certType = 2;
						title = certs[i].SUBJECT_UPN;
						subject = '<tr><td>Subject</td><td>'+ certs[i].SUBJECT + '</td></tr>';
					} else if (certs[i].CERTIFICATE_TYPE ===  'escrow'){
						certType = 1;
					    title = certs[i].SUBJECT;
					    subject = '';
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
					}
					
					
				}
			window.dbg.log("leaving certs2Html");
			},
			
			
			createInfoAccordionEntry : function(title, signClass, content) {

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

			createInfoAccordion : function(html) {

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

			changeLanguage : function() {

				window.dbg.log('changeLanguage');

				// only us and de supported
				if (this.options.language === 'de')
					this.options.language = 'us';
				else
					this.options.language = 'de';

				// get Translations and continue at initialization step 2
				sscModel.getTranslations(this.options.language,
						this.changeLanguage_step2);

				window.dbg.log('changeLanguage');
			},

			changeLanguage_step2 : function(translations) {

				window.dbg.log('changeLanguage_step2');
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
				$$('.btnLang').set('html', this.tr_('T_Lang'));
				$$('.btnHelp').set('html', this.tr_('T_Help'));
				if ($('btnUnblock'))   $('btnUnblock').set('html', this.tr_('T_Unblock'));
				if ($('btnChangePin')) $('btnChangePin').set('html', this.tr_('T_ChangePin'));

				// translate all elements with class tt
				$$('.tt').each(function(el) {
					this.trE_(el.id).replaces(el);
					}.bind(this));
		 

			},

			tr_ : function(msgId) {

				var spo = '<span class="tt" id="' + msgId + '">';
				var spc = '</span>';
				// return this.translations[msgId] !== undefined ?
				// this.translations[msgId] : msgId;
				return this.translations[msgId] !== undefined 
						? spo + this.translations[msgId] + spc 
						: spo + msgId + spc;

			},

			trE_ : function(msgId) {

				return new Element(
						'span',
						{
							'html' : (this.translations[msgId] !== undefined ? this.translations[msgId]
									: msgId),
							'id' : msgId,
							'class' : 'tt'
						});

				/*
				 * var spo = '<span class="tt" id="'+msgId+'">'; var spc = '</span>';
				 * //return this.translations[msgId] !== undefined ?
				 * this.translations[msgId] : msgId; return
				 * this.translations[msgId] !== undefined ? spo +
				 * this.translations[msgId] + spc : spo + msgId + spc;
				 */
			},

			// -----------------------------------------------------------
			// menu & action methods
			// -----------------------------------------------------------

			initMenues : function(main) {

				window.dbg.log('initMenues - ' + main);

				// create Language link/// and inject it
				var el = new Element('a', {
					'html' : this.tr_('T_Lang'),
					'class' : 'btnLang',
					events : {
						'click' : this.changeLanguage.bind(this)
					}
				});
				el.inject(new Element('li', {
					'class' : 'first'
				}).inject($('footerMenuList')));
				el = new Element('a', {
					'html' : this.tr_('T_Lang'),
					'class' : 'btnLang',
					events : {
						'click' : this.changeLanguage.bind(this)
					}
				});
				el.inject(new Element('li', {
					'class' : 'first'
				}).inject($('topMenuList')));

				// create Help link and inject it
//				el = new Element('a', {
//					'html' : this.tr_('T_Help'),
//					'class' : 'btnHelp',
//					events : {
//						'click' : this.showHelp.bind(this)
//					}
//				});
//				el.inject(new Element('li', {
//					'class' : 'help'
//				}).inject($('footerMenuList')));
//				el = new Element('a', {
//					'html' : this.tr_('T_Help'),
//					'class' : 'btnHelp',
//					events : {
//						'click' : this.showHelp.bind(this)
//					}
//				});
//				el.inject(new Element('li', {
//					'class' : 'help'
//				}).inject($('topMenuList')));


				// create main menu if desired
				if (main){
					// create change pin link and inject it
					el = new Element('a', {
						'html' : this.tr_('T_ChangePin'),
						'id' : 'btnChangePin'
					});
					el.inject(new Element('li', {
						'class' : 'first'
					}).inject($('mainMenuList')));

					// create unblock link and inject it
					el = new Element('a', {
						'html' : this.tr_('T_Unblock'),
						'id' : 'btnUnblock'
					});
					el.inject(new Element('li').inject($('mainMenuList')));
				}

			},

			performNextAction : function() {

				window.dbg.log('performNextAction');

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
			
			performBackAction : function() {

				window.dbg.log('performBackAction');

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
					this.performNextAction();
				}
			}
		},

		// -----------------------------------------------------------
		// evaluation methods
		// -----------------------------------------------------------
			trim : function (s) {
				   return s.replace (/^\s+/, '').replace (/\s+$/, '');
				},
	
			resetInputErr: function(){
				this.removeEvent('keydown', this.resetInputErr);
				this.style.backgroundColor = "white";
			},
			
			isEmail : function(s) {

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

			traverseJson : function(o, func) {
				for (i in o) {
					func.apply(this, [ i, o[i] ]);
					if (typeof (o[i]) == "object") {
						// going on step down in the object tree!!
						this.traverseJson(o[i], func);
					}
				}
			},

			// called with every property and it's value
			keyvalue2Log : function(key, value) {
				window.dbg.log(key + " : " + value);
			},

			// called with every property and it's value
			keyvalue2HtmlTabRow : function(key, value) {
				this.tabEntriesHtml += '<tr><td>' + key.replace(/_/g, ' ')
						+ '</td><td>' + value + '</td></tr>';
			}

		});