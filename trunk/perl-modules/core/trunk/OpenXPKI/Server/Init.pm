## OpenXPKI::Server::Init.pm 
##
## Written by Michael Bell for the OpenXPKI project 2005
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision$

package OpenXPKI::Server::Init;

use strict;
use warnings;
use utf8;

## used modules

# use Smart::Comments;

use English;
use OpenXPKI::Debug 'OpenXPKI::Server::Init';
use OpenXPKI::i18n qw(set_language set_locale_prefix);
use OpenXPKI::Exception;

use OpenXPKI::XML::Config;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::Server::DBI;
use OpenXPKI::Server::Log;
use OpenXPKI::Server::Log::NOOP;
use OpenXPKI::Server::ACL;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Authentication;
use OpenXPKI::Server::Notification::Dispatcher;

use OpenXPKI::Server::Context qw( CTX );
                
use OpenXPKI::Crypto::X509;

use Data::Dumper;

# define an array of hash refs mapping the task id to the corresponding
# init code. the order of the array elements is also the default execution
# order.
my @init_tasks = qw(
  xml_config
  i18n
  dbi_log
  log
  redirect_stderr
  prepare_daemon
  dbi_backend
  dbi_workflow
  crypto_layer
  pki_realm
  volatile_vault
  acl
  api
  authentication
  notification
  server
);


my %is_initialized = map { $_ => 0 } @init_tasks;

sub init {
    my $keys = shift;

    my @tasks;

    if (defined $keys->{TASKS} && (ref $keys->{TASKS} eq 'ARRAY')) {
	@tasks = @{$keys->{TASKS}};
    } else {
	@tasks = @init_tasks;
    }

    delete $keys->{TASKS};
    
  TASK:
    foreach my $task (@tasks) {
	if (! exists $is_initialized{$task} && $task ne 'pki_realm_light') {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_INIT_TASK_ILLEGAL_TASK_ACTION",
		params  => {
		    task => $task,
		});
	}
	next TASK if $is_initialized{$task};

	eval "__do_init_$task(\$keys);";
	if (my $exc = OpenXPKI::Exception->caught())
	{
	    my $msg = $exc->message() || '<no message>';
	    log_wrapper(
		{
		    MESSAGE  => "Exception during initialization task '$task': " . $msg,
		    PRIORITY => "fatal",
		    FACILITY => "system",
		});

	    $exc->rethrow();
	}
	elsif ($EVAL_ERROR)
	{
	    log_wrapper(
		{
		    MESSAGE  => "Exception during initialization task '$task': " . $EVAL_ERROR,
		    PRIORITY => "fatal",
		    FACILITY => "system",
		});
	    
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_INIT_TASK_INIT_FAILURE",
		params  => {
		    task => $task,
		    EVAL_ERROR => $EVAL_ERROR,
		});
	}

	$is_initialized{$task}++;

	# suppress informational output if SILENT is specified
	if (! (exists $keys->{SILENT} && $keys->{SILENT})) {
	    log_wrapper(
		{
		    MESSAGE  => "Initialization task '$task' finished",
		    PRIORITY => "info",
		    FACILITY => "system",
		});
	}
    }
    return 1;
}


sub log_wrapper {
    my $arg = shift;

    if ($is_initialized{'log'}) {
	CTX('log')->log(
	    %{$arg},
	    );
    } else {
	print STDERR $arg->{FACILITY} . '.' . $arg->{PRIORITY} . ': ' . $arg->{MESSAGE} . "\n";
    }
    return 1;
}


sub get_remaining_init_tasks {
    my @remaining_tasks;

    foreach my $task (@init_tasks) {
	if (! $is_initialized{$task}) {
	    push @remaining_tasks, $task;
	}
    }

    return @remaining_tasks;
}



###########################################################################
# init functions to be called during init task processing
sub __do_init_xml_config {
    my $keys = shift;
    ##! 1: "init xml config"
    my $xml_config = get_xml_config(CONFIG => $keys->{"CONFIG"});
    OpenXPKI::Server::Context::setcontext(
	{
	    xml_config => $xml_config,
	});
}

sub __do_init_i18n {
    ##! 1: "init i18n"
    init_i18n(CONFIG => CTX('xml_config'));
}

sub __do_init_log {
    ##! 1: "init log"
    my $log          = get_log();
    ### $log
    OpenXPKI::Server::Context::setcontext(
	{
	    log => $log,
	});
    ##! 64: 'log during init: ' . ref $log
}


sub __do_init_prepare_daemon {
    ##! 1: "init prepare daemon"

    # create new session
    POSIX::setsid or
	die "unable to create new session!: $!";
    
    # prepare daemonizing myself
    # redirect filehandles
    open STDOUT, ">/dev/null" or
	die "unable to write to /dev/null!: $!";
    open STDIN, "/dev/null" or
	die "unable to read from /dev/null!: $!";
    
    # FIXME: if we change to / the daemon works properly in production but
    # our tests fail (because there are a lot of relative path names in the
    # test configuration).
    # FIXME RECONSIDER uncommenting this in the future.
    # chdir '/';

    # we redirect stderr to our debug log file, so don't do it here:
    # open STDERR, '>&STDOUT' or
    # die "unable to attach STDERR to STDOUT!: $!";
}

sub __do_init_crypto_layer {
    ##! 1: "init crypto layer"
    OpenXPKI::Server::Context::setcontext(
	{
	    crypto_layer => get_crypto_layer(),
	});
}

sub __do_init_redirect_stderr {
    ##! 1: "init stderr redirection"
    redirect_stderr();
}


sub __do_init_pki_realm {
    ##! 1: "init pki_realm"
    my $pki_realm    = get_pki_realms();
    
    OpenXPKI::Server::Context::setcontext(
	{
	    pki_realm => $pki_realm,
	});
}

sub __do_init_pki_realm_light {
    ##! 1: 'start'
    my $pki_realm  = get_pki_realms({
        LIGHT => 1,
    });

    OpenXPKI::Server::Context::setcontext(
	{
	    pki_realm => $pki_realm,
	});
}
    
sub __do_init_volatile_vault {
    ##! 1: "init volatile vault"

    my $realms = CTX('pki_realm');
    
    # get a default token
    # FIXME: We use the first PKI realm's default token. This is an 
    # arbitrary choice - we should consider to have a "global" default 
    # token that is not bound to a specific realm.

    my $firstrealm = (sort keys %{$realms})[0];
    if (! defined $firstrealm) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DO_INIT_VOLATILEVAULT_MISSING_PKI_REALM");
	
    }
    my $token =  $realms->{$firstrealm}->{crypto}->{default};

    if (! defined $token) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DO_INIT_VOLATILEVAULT_MISSING_TOKEN");
    }

    OpenXPKI::Server::Context::setcontext(
	{
	    volatile_vault => OpenXPKI::Crypto::VolatileVault->new(
		{
		    TOKEN => $token,
		}),
	});
}

sub __do_init_dbi_backend {
    ### init backend dbi...
    my $dbi = get_dbi(
	{
	    PURPOSE => 'backend',
	});
    
    OpenXPKI::Server::Context::setcontext(
	{
	    dbi_backend => $dbi,
	});
    # delete leftover secrets
    CTX('dbi_backend')->connect();
    CTX('dbi_backend')->delete(
        TABLE => 'SECRET',
        ALL   => 1, 
    );
    CTX('dbi_backend')->commit();
    CTX('dbi_backend')->disconnect();
}

sub __do_init_dbi_workflow {
    ### init backend dbi...
    my $dbi = get_dbi(
	{
	    PURPOSE => 'workflow',
	});
    
    OpenXPKI::Server::Context::setcontext(
	{
	    dbi_workflow => $dbi,
	});
}

sub __do_init_dbi_log {
    ### init backend dbi...
    my $dbi = get_dbi(
	{
	    PURPOSE => 'log',
	});
    
    OpenXPKI::Server::Context::setcontext(
	{
	    dbi_log => $dbi,
	});
    CTX('dbi_log')->connect();
}

sub __do_init_acl {
    ### init acl...
    OpenXPKI::Server::Context::setcontext(
	{
	    acl => OpenXPKI::Server::ACL->new(),
	});
}

sub __do_init_api {
    ### init api...
    OpenXPKI::Server::Context::setcontext(
	{
	    api => OpenXPKI::Server::API->new(),
	});
}

sub __do_init_authentication {
    ### init authentication...
    my $obj = OpenXPKI::Server::Authentication->new();
    if (! defined $obj) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DO_INIT_AUTHENTICATION_INSTANTIATION_FAILURE");
    }
    OpenXPKI::Server::Context::setcontext(
	{
	    authentication => $obj,
	});
}

sub __do_init_server {
    my $keys = shift;
    ### init server ref...
    if (defined $keys->{SERVER}) {
	OpenXPKI::Server::Context::setcontext(
	    {
		server => $keys->{SERVER},
	    });
    }
}

sub __do_init_notification {
    OpenXPKI::Server::Context::setcontext({
        notification => OpenXPKI::Server::Notification::Dispatcher->new(),
    });
    return 1;
}

###########################################################################

sub get_xml_config
{
    my $keys = { @_ };

    ##! 1: "start"

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_XML_CONFIG_MISSING_CONFIG");
    }
    if (not -e $keys->{"CONFIG"})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_XML_CONFIG_FILE_DOES_NOT_EXIST",
            params  => {"FILENAME" => $keys->{CONFIG}});
    }
    if (not -r $keys->{"CONFIG"})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_XML_CONFIG_FILE_NOT_READABLE",
            params  => {"FILENAME" => $keys->{CONFIG}});
    }

    return OpenXPKI::XML::Config->new (CONFIG => $keys->{"CONFIG"});
}

sub init_i18n
{
    my $keys = { @_ };
    ##! 1: "start"

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_I18N_MISSING_CONFIG");
    }

    set_locale_prefix ($keys->{CONFIG}->get_xpath (XPATH => "common/i18n/locale_directory"));
    set_language      ($keys->{CONFIG}->get_xpath (XPATH => "common/i18n/default_language"));

    binmode STDOUT, ":utf8";
    binmode STDIN,  ":utf8";

    return 1;
}


sub get_crypto_layer
{
    ##! 1: "start"

    return OpenXPKI::Crypto::TokenManager->new();
}



sub get_pki_realms
{
    my $arg_ref = shift;
    ##! 1: "start"

    my $config = CTX('xml_config');
    my $crypto = CTX('crypto_layer');


    ### get all PKI realms
    my %realms = ();
    my $count = $config->get_xpath_count (XPATH => "pki_realm");
    for (my $i = 0 ; $i < $count ; $i++)
    {
        ## prepare crypto stuff for every PKI realm

        my $name = $config->get_xpath (
                       XPATH    => [ 'pki_realm', 'name' ],
                       COUNTER  => [ $i, 0 ]);

	my $defaulttoken = __get_default_crypto_token (
	    PKI_REALM => $name
	    );

        $realms{$name}->{crypto}->{default} = $defaulttoken;
	log_wrapper(
	    {
		MESSAGE  => "Attached default token for PKI realm '$name'",
		PRIORITY => "info",
		FACILITY => "system",
	    });
	
	my @xpath   = ( 'pki_realm', 'common', 'profiles' );
	my @counter = ( $i,         0,        0 );
	
	foreach my $entrytype (qw( endentity selfsignedca crl )) {
	    ### entrytype: $entrytype

	    my $nr_of_entries = $config->get_xpath_count(
		XPATH   => [ @xpath,   $entrytype, 'profile' ],
		COUNTER => [ @counter, 0 ]);
	    
	    ### entries: $nr_of_entries
	    foreach (my $jj = 0; $jj < $nr_of_entries; $jj++) {
		my $entryid = $config->get_xpath(
			    XPATH   => [ @xpath,   $entrytype, 'profile', 'id' ],
			    COUNTER => [ @counter, 0,          $jj,       0 ],
			    );
		    
	      VALIDITYTYPE:
		foreach my $validitytype (qw( notbefore notafter )) {
		    next VALIDITYTYPE if (($entrytype eq "crl") &&
					  ($validitytype eq "notbefore"));
		    
		    ### validitytype: $validitytype

		    my $validity;
		    my $format;
		    # parse validity entry
		    eval {
			$format = $config->get_xpath(
			    XPATH   => [ @xpath,   $entrytype, 'profile', 'validity', $validitytype, 'format' ],
			    COUNTER => [ @counter, 0,          $jj,       0,          0,             0 ],
			    );

			$validity = $config->get_xpath(
			    XPATH   => [ @xpath,   $entrytype, 'profile', 'validity', $validitytype ],
			    COUNTER => [ @counter, 0,          $jj,        0,         0 ],
			    );
			
		    };
		    if (my $exc = OpenXPKI::Exception->caught()) {
			# ignore exception for missing 'notbefore' entry
			if (($exc->message() 
			    eq "I18N_OPENXPKI_XML_CONFIG_GET_SUPER_XPATH_NO_INHERITANCE_FOUND")
			    && ($validitytype eq "notbefore")) {
			    # default: "now"
			    $validity = undef;
			}
			else
			{
			    $exc->rethrow();
			}
		    } elsif ($EVAL_ERROR) {
			OpenXPKI::Exception->throw (
			    message => "I18N_OPENXPKI_SERVER_INIT_GET_PKI_REALMS_VALIDITY_ERROR",
			    params  => {
				EVAL_ERROR => $EVAL_ERROR,
			    });
		    }
		    
		    ### got format: $format
		    ### got validity: $validity

		    if (defined $validity) {
			$realms{$name}->{$entrytype}->{id}->{$entryid}->{validity}->{$validitytype} = 
			{
			    'format' => $format,
			    'validity' => $validity,
			};

			log_wrapper(
			    {
				MESSAGE  => "Accepted '$entryid' $entrytype $validitytype validity ($format: $validity) for PKI realm '$name'",
				PRIORITY => "info",
				FACILITY => "system",
			    });
			
		    }
		}
	    }
	}
        #############################################################
        # get ldap options  
	#
        eval {
        my $ldap_enable = $config->get_xpath(
		        XPATH   => [ 'pki_realm', 'common','ldap','ldap_enable' ],
  		        COUNTER => [          $i,        0,     0,           0  ],
		      );
         $realms{$name}->{ldap_enable} = $ldap_enable;

	 my $ldap_excluded_roles = $config->get_xpath(
              XPATH   => [ 'pki_realm', 'common','ldap','ldap_excluded_roles' ],
              COUNTER => [          $i,        0,     0,                    0 ],
		      );
         $realms{$name}->{ldap_excluded_roles} = $ldap_excluded_roles;

	 my $ldap_suffix = $config->get_xpath(
                         XPATH   => [ 'pki_realm', 'common','ldap','ldap_suffix' ],
	                 COUNTER => [          $i,        0,     0,           0  ],
		      );
         $realms{$name}->{ldap_suffix} = $ldap_suffix;

	 my $ldap_server = $config->get_xpath(
                         XPATH   => [ 'pki_realm', 'common','ldap','ldap_server' ],
	                 COUNTER => [          $i,        0,     0,           0  ],
		      );
         $realms{$name}->{ldap_server} = $ldap_server;

	 my $ldap_port = $config->get_xpath(
                         XPATH   => [ 'pki_realm', 'common','ldap','ldap_port' ],
	                 COUNTER => [          $i,        0,     0,           0  ],
		      );
         $realms{$name}->{ldap_port} = $ldap_port;

	 my $ldap_version = $config->get_xpath(
                         XPATH   => [ 'pki_realm', 'common','ldap','ldap_version' ],
	                 COUNTER => [          $i,        0,     0,           0  ],
		      );
         $realms{$name}->{ldap_version} = $ldap_version;
	 
         my $ldap_tls = $config->get_xpath(
                         XPATH   => [ 'pki_realm', 'common','ldap','ldap_tls' ],
	                 COUNTER => [          $i,        0,     0,           0  ],
		      );
         $realms{$name}->{ldap_tls} = $ldap_tls;

	 my $ldap_sasl = $config->get_xpath(
                         XPATH   => [ 'pki_realm', 'common','ldap','ldap_sasl' ],
	                 COUNTER => [          $i,        0,     0,           0  ],
		      );
         $realms{$name}->{ldap_sasl} = $ldap_sasl;
	 
         my $ldap_chain = $config->get_xpath(
                         XPATH   => [ 'pki_realm', 'common','ldap','ldap_chain' ],
	                 COUNTER => [          $i,        0,     0,           0  ],
		      );
         $realms{$name}->{ldap_chain} = $ldap_chain;

	 my $ldap_login = $config->get_xpath(
                         XPATH   => [ 'pki_realm', 'common','ldap','ldap_login' ],
	                 COUNTER => [          $i,        0,     0,           0  ],
		      );
         $realms{$name}->{ldap_login} = $ldap_login;
	 
         my $ldap_password = $config->get_xpath(
                         XPATH   => [ 'pki_realm', 'common','ldap','ldap_password' ],
	                 COUNTER => [          $i,        0,     0,           0  ],
		      );
         $realms{$name}->{ldap_password} = $ldap_password;
         }; 
	    if ($EVAL_ERROR) {
    		log_wrapper({
    		    MESSAGE  => "No LDAP options found, LDAP turned off",
    		    PRIORITY => "warn",
    		    FACILITY => "system",
		});
		$realms{$name}->{ldap_enable} = "no";
		} 
        # The End of ldap section
        ################################################################


	### %realms
	
	# get all CA certificates for PKI realm
	# $realms{$name}->{ca}->{$ca}->{certificate} =
	# get end entity validities
	my $nr_of_ca_entries
	    = $config->get_xpath_count(
	    XPATH   => ['pki_realm', 'ca'],
	    COUNTER => [$i]);

	my $issuing_ca_count = 0;
        my $scep_count = 0;

      ISSUINGCA:
	for (my $jj = 0; $jj < $nr_of_ca_entries; $jj++) {
	    my $ca_id = $config->get_xpath(
		XPATH =>   ['pki_realm', 'ca', 'id'],
		COUNTER => [$i,          $jj,  0 ],
		);

	    
	    # sanity check: there must be a CRL validity configuration
	    # for this issuing CA
	    if (! exists $realms{$name}->{crl}->{id}->{$ca_id}->{validity}) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_INIT_PKI_REALMS_NO_CRL_VALIDITY",
		    params => {
			CAID   => $ca_id,
		    },
		);
	    }
	    

	    # record this issuing CA as potentially present in the 
	    # PKI Realm configuration
	    $realms{$name}->{ca}->{id}->{$ca_id}->{status} = 0;

            # cert identifier
            if (! $arg_ref->{LIGHT}) { # FIXME: "light" initialisation is obsolete!
                eval {
                    my $cert_identifier;
                    eval {
                      ##! 128: 'eval'
                      $cert_identifier = $config->get_xpath(
                        XPATH   => [ 'pki_realm', 'ca', 'cert', 'identifier' ],
                        COUNTER => [ $i,           $jj, 0     , 0            ],
                      );
                    };
                    if (!defined $cert_identifier) {
                      ##! 128: 'undefined'
                      my $cert_alias = $config->get_xpath(
                        XPATH   => [ 'pki_realm', 'ca', 'cert', 'alias' ],
                        COUNTER => [ $i,          $jj,  0     , 0       ],
                      );
                      my $cert_realm = $config->get_xpath(
                        XPATH   => [ 'pki_realm', 'ca', 'cert', 'realm' ],
                        COUNTER => [ $i,          $jj,  0     , 0       ],
                      );
                      ##! 128: 'cert_alias: ' . $cert_alias
                      ##! 128: 'cert_realm: ' . $cert_realm
                      my $dbi = CTX('dbi_backend');
                      $dbi->connect();
                      my $cert = $dbi->first(
                          TABLE   => 'ALIASES',
                          DYNAMIC => {
                              ALIAS     => $cert_alias,
                              PKI_REALM => $cert_realm,
                          },
                      );
                      $dbi->disconnect();
                      ##! 128: 'cert: ' . Dumper($cert)
                      if (defined $cert) {
                          $cert_identifier = $cert->{IDENTIFIER};
                      }
                      else {
                        OpenXPKI::Exception->throw(
                            message => 'I18N_OPENXPKI_SERVER_INIT_NO_IDENTIFIER_FOUND_IN_ALIASES_DB',
                            params  => {
                                'ALIAS'     => $cert_alias,
                                'PKI_REALM' => $cert_realm,
                            },
                        );
                      }
                    }
                    ##! 16: 'identifier: ' . $cert_identifier
                    $realms{$name}->{ca}->{id}->{$ca_id}->{identifier} = $cert_identifier;
                };
                if ($EVAL_ERROR) {
    		    log_wrapper({
    			MESSAGE  => "Could not determine CA identifier for CA '$ca_id' (PKI realm $name)",
    			PRIORITY => "warn",
    			FACILITY => "system",
		    });
		
		    log_wrapper({
			MESSAGE  => "Issuing CA '$ca_id' (PKI realm $name) is unavailable",
			PRIORITY => "warn",
			FACILITY => "monitor",
		    });
		
		    next ISSUINGCA;
                }
    
                ###########################################################
                # get certificate from DB and save it in the pki_realms CTX
    
                my $dbi = CTX('dbi_backend');
                $dbi->connect();
                my $certificate_db_entry = $dbi->first(
                    TABLE   => 'CERTIFICATE',
                    DYNAMIC => {
                        IDENTIFIER => $realms{$name}->{ca}->{id}->{$ca_id}->{identifier},
                    },
                );
                $dbi->disconnect();
                my $certificate = $certificate_db_entry->{DATA}; # in PEM
                ##! 16: 'certificate: ' . $certificate
                if (! defined $certificate_db_entry
                 || ! defined $certificate) {
    		    log_wrapper({
			    MESSAGE  => "Could not read issuing CA certificate from database for CA '$ca_id' (PKI realm $name)",
			    PRIORITY => "warn",
			    FACILITY => "system",
		    });

		    log_wrapper({
			    MESSAGE  => "Issuing CA '$ca_id' (PKI realm $name) is unavailable",
			    PRIORITY => "warn",
			    FACILITY => "monitor",
		    });
			
		    next ISSUINGCA;
                }
    	        my $cacert
    		  = OpenXPKI::Crypto::X509->new(TOKEN => $defaulttoken,
    		    			        DATA  => $certificate);
    	    
    	        if (! defined $cacert) {
    		    log_wrapper({
    			MESSAGE  => "Could not parse issuing CA certificate from database for CA '$ca_id' (PKI realm $name)",
    			PRIORITY => "warn",
    			FACILITY => "system",
		    });
		
		    log_wrapper({
			MESSAGE  => "Issuing CA '$ca_id' (PKI realm $name) is unavailable",
			PRIORITY => "warn",
			FACILITY => "monitor",
		    });
		
		    next ISSUINGCA;
	        }

                ##! 16: 'certificate: ' . $certificate
                my $token = $crypto->get_token(
                    TYPE        => "CA",
                    ID          => $ca_id,
                    PKI_REALM   => $name,
                    CERTIFICATE => $certificate,
                );
            
                $realms{$name}->{ca}->{id}->{$ca_id}->{certificate}
                    = $certificate;
	        $realms{$name}->{ca}->{id}->{$ca_id}->{crypto} = $token;
	        $realms{$name}->{ca}->{id}->{$ca_id}->{cacert} = $cacert;
	        $realms{$name}->{ca}->{id}->{$ca_id}->{status} = 1;
                $realms{$name}->{ca}->{id}->{$ca_id}->{notbefore} 
                    = $cacert->get_parsed("BODY", "NOTBEFORE");
                $realms{$name}->{ca}->{id}->{$ca_id}->{notafter} 
                    = $cacert->get_parsed("BODY", "NOTAFTER");

	        $issuing_ca_count++;

	        log_wrapper({
		    MESSAGE  => "Attached CA token for issuing CA '$ca_id' of PKI realm '$name'",
		    PRIORITY => "info",
		    FACILITY => "system",
	        });

    	        log_wrapper({
		    MESSAGE  => "Issuing CA $ca_id of PKI realm '$name' validity is " 
			. OpenXPKI::DateTime::convert_date(
			{
			    DATE => $realms{$name}->{ca}->{id}->{$ca_id}->{notbefore},
			    OUTFORMAT => 'printable',
		        }) 
			. ' - '
			. OpenXPKI::DateTime::convert_date(
			{
			    DATE => $realms{$name}->{ca}->{id}->{$ca_id}->{notafter},
			    OUTFORMAT => 'printable',
			}
			),
		    PRIORITY => "info",
		    FACILITY => "system",
		});
            }

         ###############################################
         # crl_publication info

         my @base_path = ('pki_realm', 'ca', 'crl_publication');
         my @base_ctr  = ($i,          $jj,   0);
         eval {
	     my $crl_publication_id = $config->get_xpath(
	        XPATH   => [ @base_path ],
	        COUNTER => [ @base_ctr  ],
	     );
             $realms{$name}->{ca}->{id}->{$ca_id}->{crl_publication} = 1; # only executed if get_xpath does not crash
         };
         eval {
             my $number_of_files = $config->get_xpath_count(
                 XPATH   => [ @base_path, 'file'],
                 COUNTER => [ @base_ctr ],
             );
             my @files;
             ##! 16: 'nr_of_files: ' . $number_of_files
             for (my $kkk = 0; $kkk < $number_of_files; $kkk++) {
                 my $filename = $config->get_xpath(
                     XPATH   => [ @base_path, 'file', 'filename' ],
                     COUNTER => [ @base_ctr, $kkk   , 0          ],
                 );
                 ##! 16: 'filename: ' . $filename
                 my $format = $config->get_xpath(
                     XPATH   => [ @base_path, 'file', 'format'   ],
                     COUNTER => [ @base_ctr, $kkk   , 0          ],
                 );
                 ##! 16: 'format: ' . $format
                 push @files, {
                     'FILENAME' => $filename,
                     'FORMAT'   => $format,
                 };
             }
             ##! 16: '@files: ' . Dumper(\@files)
             $realms{$name}->{ca}->{id}->{$ca_id}->{crl_files} = \@files;
          };
        }
          
	# get all SCEP identifier for the PKI realm
	# $realms{$name}->{scep}->{$scep_id}->{identifier}
        my $nr_of_scep_entries = 0;
        eval { # this might fail because no scep server is defined
               # at all
	    $nr_of_scep_entries = $config->get_xpath_count(
	        XPATH   => ['pki_realm', 'scep'],
	        COUNTER => [$i]
            );
        };
        
      SCEP_SERVER:
	for (my $jj = 0; $jj < $nr_of_scep_entries; $jj++) {
	    my $scep_id = $config->get_xpath(
		XPATH =>   ['pki_realm', 'scep', 'id'],
		COUNTER => [$i,          $jj,  0 ],
	    );

            # cert identifier
            eval {
                my $cert_identifier;
                eval {
                  ##! 128: 'eval'
                  $cert_identifier = $config->get_xpath(
                    XPATH   => [ 'pki_realm', 'scep', 'cert', 'identifier' ],
                    COUNTER => [ $i,           $jj, 0     , 0            ],
                  );
                };
                if (!defined $cert_identifier) {
                  ##! 128: 'undefined'
                  my $cert_alias = $config->get_xpath(
                    XPATH   => [ 'pki_realm', 'scep', 'cert', 'alias' ],
                    COUNTER => [ $i,          $jj,  0     , 0       ],
                  );
                  my $cert_realm = $config->get_xpath(
                    XPATH   => [ 'pki_realm', 'scep', 'cert', 'realm' ],
                    COUNTER => [ $i,          $jj,  0     , 0       ],
                  );
                  ##! 128: 'cert_alias: ' . $cert_alias
                  ##! 128: 'cert_realm: ' . $cert_realm
                  my $dbi = CTX('dbi_backend');
                  $dbi->connect();
                  my $cert = $dbi->first(
                      TABLE   => 'ALIASES',
                      DYNAMIC => {
                          ALIAS     => $cert_alias,
                          PKI_REALM => $cert_realm,
                      },
                   );
                   $dbi->disconnect();
                   ##! 128: 'cert: ' . Dumper($cert)
                   if (defined $cert) {
                       $cert_identifier = $cert->{IDENTIFIER};
                   }
                   else {
                     OpenXPKI::Exception->throw(
                         message => 'I18N_OPENXPKI_SERVER_INIT_NO_IDENTIFIER_FOUND_IN_ALIASES_DB',
                         params  => {
                             'ALIAS'     => $cert_alias,
                             'PKI_REALM' => $cert_realm,
                         },
                     );
                   }
                }
                ##! 16: 'identifier: ' . $cert_identifier
                $realms{$name}->{scep}->{id}->{$scep_id}->{identifier} = $cert_identifier;
            };
            if ($EVAL_ERROR) {
    		log_wrapper({
    		    MESSAGE  => "Could not determine identifier for SCEP server '$scep_id' (PKI realm $name)",
    		    PRIORITY => "warn",
    		    FACILITY => "system",
		});
		
		log_wrapper({
		    MESSAGE  => "SCEP server '$scep_id' (PKI realm $name) is unavailable",
		    PRIORITY => "warn",
		    FACILITY => "monitor",
		});
		
		next SCEP_SERVER;
            }
            my $dbi = CTX('dbi_backend');
            $dbi->connect();
            my $certificate_db_entry = $dbi->first(
                TABLE   => 'CERTIFICATE',
                DYNAMIC => {
                    IDENTIFIER => $realms{$name}->{scep}->{id}->{$scep_id}->{identifier},
                },
            );
            $dbi->disconnect();
            my $certificate = $certificate_db_entry->{DATA}; # in PEM
            my $token = $crypto->get_token(
                    TYPE        => "SCEP",
                    ID          => $scep_id,
                    PKI_REALM   => $name,
                    CERTIFICATE => $certificate,
            );
            $realms{$name}->{scep}->{id}->{$scep_id}->{crypto} = $token;
	    log_wrapper({
		MESSAGE  => "Attached SCEP token for SCEP server '$scep_id' of PKI realm '$name'",
		PRIORITY => "info",
		FACILITY => "system",
	    });

            $scep_count++;
          }
	    
	log_wrapper(
	    {
		MESSAGE  => "Identified $issuing_ca_count issuing CAs for PKI realm '$name'",
		PRIORITY => "info",
		FACILITY => "system",
	    });

	log_wrapper(
	    {
		MESSAGE  => "Identified $scep_count SCEP servers for PKI realm '$name'",
		PRIORITY => "info",
		FACILITY => "system",
	    });
    }

    ### realms: %realms
    return \%realms;
}

sub __get_default_crypto_token
{
    my $keys = { @_ };
    ##! 1: "start"

    my $crypto = CTX('crypto_layer');

    if (not $keys->{PKI_REALM})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DEFAULT_CRYPTO_TOKEN_MISSING_PKI_REALM");
    }

    return $crypto->get_token (TYPE      => "DEFAULT",
			       ID        => "default",
			       PKI_REALM => $keys->{PKI_REALM});
}

sub get_dbi
{
    my $args = shift;

    ##! 1: "start"

    my $config = CTX('xml_config');

    my %params;

    my $dbpath = 'database';
    if (exists $args->{PURPOSE} && $args->{PURPOSE} eq 'log') {
        ##! 16: 'purpose: log'
        $dbpath = 'log_database';
        %params = (LOG => OpenXPKI::Server::Log::NOOP->new());
    }
    else {
        %params = (LOG => CTX('log'));
    }

    ## setup of the environment

    ## determine database vendor
    $params{TYPE} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/type" ],
                   COUNTER  => [ 0 ]);

    ## determine configuration for infrastructure
    $params{SERVER_ID} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/server_id" ],
                   COUNTER  => [ 0 ]);
    $params{SERVER_SHIFT} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/server_shift" ],
                   COUNTER  => [ 0 ]);

    ## find configuration and detect number of options
    my ($vendor_name, $vendor_number, $vendor_envs) = ("", -1, 0);
    my $vendor_count = $config->get_xpath_count (
                            XPATH    => [ "common/$dbpath/environment/vendor" ],
                            COUNTER  => []);
    for (my $k = 0; $k<$vendor_count; $k++)
    {
        $vendor_name = $config->get_xpath (
                            XPATH    => [ "common/$dbpath/environment/vendor", "type" ],
                            COUNTER  => [ $k, 0 ]);
        next if ($vendor_name ne $params{TYPE});
        $vendor_number = $k;
        eval { $vendor_envs = $config->get_xpath_count (
		   XPATH    => [ "common/$dbpath/environment/vendor", "option" ],
		   COUNTER  => [ $k ]);
	};
    }

    ## load environment
    for (my $i = 0; $i<$vendor_envs; $i++)
    {
        my $env_name = $config->get_xpath (
                           XPATH    => [ "common/$dbpath/environment/vendor", "option", "name" ],
                           COUNTER  => [ $vendor_number, $i, 0 ]);
        my $env_value = $config->get_xpath (
                           XPATH    => [ "common/$dbpath/environment/vendor", "option", "value" ],
                           COUNTER  => [ $vendor_number, $i, 0 ]);
        $ENV{$env_name} = $env_value;
        ##! 4: "NUMBER: $i"
        ##! 4: "OPTION: $env_name"
        ##! 4: "VALUE:  $env_value"
    }

    ## load database config
    $params{NAME} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/name" ],
                   COUNTER  => [ 0 ]);
    eval{ $params{HOST} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/host" ],
                   COUNTER  => [ 0 ]) };
    eval{ $params{PORT} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/port" ],
                   COUNTER  => [ 0 ]) };
    eval{ $params{USER} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/user" ],
                   COUNTER  => [ 0 ]) };
    eval{ $params{PASSWD} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/passwd" ],
                   COUNTER  => [ 0 ]) };
    eval{ $params{NAMESPACE} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/namespace" ],
                   COUNTER  => [ 0 ]) };

    # special handling for SQLite databases
    if ($params{TYPE} eq "SQLite") {
	if (defined $args->{PURPOSE} && ($args->{PURPOSE} ne "")) {
	    $params{NAME} .= "._" . $args->{PURPOSE} . "_";
	}
    }

    return OpenXPKI::Server::DBI->new (%params);
}

sub get_log
{
    ##! 1: "start"
    my $config = CTX('xml_config');

    $config = $config->get_xpath (
                  XPATH    => [ 'common/log_config' ],
                  COUNTER  => [ 0 ]);

    ## init logging
    ##! 64: 'before Log->new'

    my $log = OpenXPKI::Server::Log->new (CONFIG => $config);

    ##! 64: 'log during get_log: ' . $log

    return $log;
}

sub redirect_stderr
{
    ##! 1: "start"
    my $config = CTX('xml_config');

    my $stderr = $config->get_xpath (XPATH => "common/server/stderr");
    if (not $stderr)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_REDIRECT_STDERR_MISSING_STDERR");
    }
    ##! 2: "redirecting STDERR to $stderr"
    if (not open STDERR, '>>', $stderr)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_REDIRECT_STDERR_FAILED");
    }
    binmode STDERR, ":utf8";
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Init - daemon initialization

=head1 Description

This class is used to initialize all the objects which are required. The
code is not in the server class itself to get a clean interface for the
initialization and to avoid any "magic" stuff. We hope that this makes
the customization of the code more easier.

=head1 Functions

=head2 Basic Initialization

=head3 init

Initialization must be done ONCE by the server process.
Expects the XML configuration file via the named parameter CONFIG.

Usage:

  use OpenXPKI::Server::Init;

  OpenXPKI::Server::Init::init({
         CONFIG => 't/config.xml',
     });

If called this way, the init code processes all initialization steps.
You may split the initialization sequence in order to do stuff in
between steps by providing an array reference TASKS as a named argument:

  OpenXPKI::Server::Init::init({
         CONFIG => 't/config.xml',
         TASKS  => [ 'xml_config', 'i18n', 'log' ],
     });

and later simply call

  OpenXPKI::Server::Init::init({
         CONFIG => 't/config.xml',
     });

to initialize the remaining tasks.

If called without the TASKS argument the function will perform all steps
that were not already executed before.

If called with the named argument SILENT set to a true value the 
init method does not log successful initialization steps.

=head3 get_remaining_init_tasks

Returns an array of all remaining initialization task names (i. e. all
tasks that have not yet been executed) in the order they would normally 
be processed.

=head3 get_xml_config

expects as only parameter the option CONFIG. This must be a filename
of an XML configuration file which is compliant with OpenXPKI's schema
definition in openxpki.xsd. We support local xinclude so please do not
be surprised if you habe a configuration file which looks a little bit
small. It returns an instance of OpenXPKI::XML::Config.

=head3 init_i18n

Initializes the code for internationalization. It requires an instance
of OpenXPKI::XML::Config in the parameter CONFIG.

=head2 Cryptographic Initialization

=head3 get_crypto_layer

Return an instance of the TokenManager class which handles all
configured cryptographic tokens.

=head3 get_pki_realms

Prepares a hash which has the following structure.

If the named parameter LIGHT is true, it does not try to initialize
the CA certificate, which is particularly useful if it has not been
imported/aliased yet and openxpkiadm uses Server::Init.

$hash{PKI_REALM_NAME}->{"crypto"}->{"default"}

Requires 'xml_config', 'log' and 'crypto_layer' in the Server Context.

The hash also includes validity information as defined in the configuration
in the following sample format:

  $hash{PKI_REALM_NAME} = {
      endentity => {
          id => {
              'User' => {
                  validity => {
                      notafter => {
                          format => 'relativedate',
                          validity => '+0006',
                      },
                  },
              },
          },
      },
      selfsignedca => {
          id => {
              'INTERNAL_CA_1' => {
                  validity => {
                      notbefore => {
                          format => 'absolutedate',
                          validity => '20060101',
                      },
                      notafter => {
                          format => 'relativedate',
                          validity => '+02',
                      },
                  },
              },
          },
      },
      crl => {
          id => {
              'default' => {
                  validity => {
                      notafter => {
                          format => 'relativedate',
                          validity => '+000014',
                      },
                  },
              },
          },
      },
      ca => {
          id => {
              CA1 => {
                  status = 1,    # (0: unavailable, 1: available)
                  identifier => 'ABCDEFGHIJK',
                  crypto => OpenXPKI::Crypto::TokenManager->new(...),
                  cacert => OpenXPKI::Crypto::X509->new(...),
                  notbefore => DateTime->new(),
                  notafter => DateTime->new(),
              },
          },
      },
  };

See OpenXPKI::DateTime for more information about the various time formats
used here.
Undefined 'notbefore' dates are interpreted as 'now' during issuance.
Relative notafter dates relate to the corresponding notbefore date.

Three sections are contained in the hash: 'endentity', 'selfsignedca'
and 'crl'. 
The ID of endentity validities is the corresponding role (profile). 
The ID of self-signed CA or CRL validities is the internal CA name.


=head2 Non-Cryptographic Object Initialization

=head3 get_dbi

Initializes the database interface and returns the database object reference.

Requires 'log' and 'xml_config' in the Server Context.

If database type is SQLite and the named parameter 'PURPOSE' exists,
this parameter is appended to the SQLite database name.
This is necessary because of a limitation in SQLite that prevents multiple
open transactions on the same database.

=head3 get_log

Returns an instance of the module OpenXPKI::Log.

Requires 'xml_config' in the Server Context.

=head3 get_log

requires no arguments.
It returns an instance of the module OpenXPKI::Server::Authentication.
The context must be already established because OpenXPKI::XML::Config is
loaded from the context.

=head3 redirect_stderr

requires no arguments and is a simple function to send STDERR to
configured file. This is useful to track all warnings and errors.
