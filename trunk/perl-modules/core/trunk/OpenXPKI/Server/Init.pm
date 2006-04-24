## OpenXPKI::Server::Init.pm 
##
## Written by Michael Bell for the OpenXPKI project 2005
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::Init;

## used modules

# use Smart::Comments;

use English;
use OpenXPKI::Debug 'OpenXPKI::Server::Init';
use OpenXPKI qw(set_language set_locale_prefix);
use OpenXPKI::Exception;

use OpenXPKI::XML::Config;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Server::DBI;
use OpenXPKI::Server::Log;
use OpenXPKI::Server::ACL;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Authentication;

use OpenXPKI::Server::Context qw( CTX );

# define an array of hash refs mapping the task id to the corresponding
# init code. the order of the array elements is also the default execution
# order.
my @init_tasks = qw(
  xml_config
  i18n
  log
  crypto_layer
  redirect_stderr
  pki_realm
  dbi_backend
  dbi_workflow
  acl
  api
  authentication
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
	if (! exists $is_initialized{$task}) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_INIT_TASK_ILLEGAL_TASK_ACTION",
		params  => {
		    task => $task,
		});
	}
	next TASK if $is_initialized{$task};

	eval "__do_init_$task(\$keys);";
	$is_initialized{$task}++;

	if ($is_initialized{'log'}) {
	    CTX('log')->log(
		MESSAGE  => "Initialization task '$task' finished",
		PRIORITY => "info",
		FACILITY => "system");
	}
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
    ### init xml config...
    my $xml_config = get_xml_config(CONFIG => $keys->{"CONFIG"});
    OpenXPKI::Server::Context::setcontext(
	{
	    xml_config => $xml_config,
	});
}

sub __do_init_i18n {
    ### init i18n...
    init_i18n(CONFIG => CTX('xml_config'));
};

sub __do_init_log {
    ### init log...
    my $log          = get_log();
    ### $log
    OpenXPKI::Server::Context::setcontext(
	{
	    log => $log,
	});
};

sub __do_init_crypto_layer {
    ### init crypto...
    OpenXPKI::Server::Context::setcontext(
	{
	    crypto_layer => get_crypto_layer(),
	});
};

sub __do_init_redirect_stderr {
    ### redirect stderr...
    redirect_stderr();
};


sub __do_init_pki_realm {
    ### init pki_realm...
    my $pki_realm    = get_pki_realms();
    
    OpenXPKI::Server::Context::setcontext(
	{
	    pki_realm => $pki_realm,
	});
};

sub __do_init_dbi_backend {
    ### init backend dbi...
    my $dbi = get_dbi(CONFIG => CTX('xml_config'),
		      LOG    => CTX('log'));
    
    OpenXPKI::Server::Context::setcontext(
	{
	    dbi_backend => $dbi,
	});
};

sub __do_init_dbi_workflow {
    ### init backend dbi...
    my $dbi = get_dbi(CONFIG => CTX('xml_config'),
		      LOG    => CTX('log'));
    
    OpenXPKI::Server::Context::setcontext(
	{
	    dbi_workflow => $dbi,
	});
};

sub __do_init_acl {
    ### init acl...
    OpenXPKI::Server::Context::setcontext(
	{
	    acl => OpenXPKI::Server::ACL->new(),
	});
};

sub __do_init_api {
    ### init api...
    OpenXPKI::Server::Context::setcontext(
	{
	    api => OpenXPKI::Server::API->new(),
	});
};

sub __do_init_authentication {
    ### init authentication...
    OpenXPKI::Server::Context::setcontext(
	{
	    authentication => OpenXPKI::Server::Authentication->new(),
	});
};

sub __do_init_server {
    my $keys = shift;
    ### init server ref...
    if (defined $keys->{SERVER}) {
	OpenXPKI::Server::Context::setcontext(
	    {
		server => $keys->{SERVER},
	    });
    }
};

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
            message => "I18N_OPENXPKI_SERVER_INIT_XML_CONFIG_FILE_IS_NOT_READABLE",
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
    my $keys = { @_ };
    ##! 1: "start"

    my $config = CTX('xml_config');
    my $log    = CTX('log');
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
	$log->log(
	    MESSAGE  => "Attached default token for PKI realm '$name'",
	    PRIORITY => "info",
	    FACILITY => "system");
	
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
		    } elsif ($EVAL_ERROR && (ref $EVAL_ERROR)) {
			$EVAL_ERROR->rethrow();
		    }
		    
		    ### got format: $format
		    ### got validity: $validity

		    if (defined $validity) {
			$realms{$name}->{$entrytype}->{id}->{$entryid}->{validity}->{$validitytype} = 
			{
			    'format' => $format,
			    'validity' => $validity,
			};

			$log->log(
			    MESSAGE  => "Accepted $entrytype $validitytype validity ($format:$validity) for PKI realm '$name'",
			    PRIORITY => "info",
			    FACILITY => "system");
			
			
		    }
		}
	    }
	}

	### %realms
	
	# get all CA certificates for PKI realm
	# $realms{$name}->{ca}->{$ca}->{certificate} =
	# get end entity validities
	my $nr_of_ca_entries
	    = $config->get_xpath_count(
	    XPATH   => ['pki_realm', 'ca'],
	    COUNTER => [$i]);

	my $issuing_ca_count = 0;

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
	    
	    
	    my $token = $crypto->get_token (TYPE      => "CA",
					    ID        => $ca_id,
					    PKI_REALM => $name);
	    
	    # attach CA certificate
	    my $cacertfile = $token->get_certfile();

	    if ((! defined $cacertfile) 
		|| ($cacertfile eq "")) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_INIT_GET_PKI_REALMS_NO_CA_CERTFILE",
		    params  => {
			PKI_REALM => $name,
			CA_ID     => $ca_id,
		    },
		    );
	    }


	    my $cacertdata;
	    eval {
		$cacertdata = OpenXPKI->read_file($cacertfile);
	    };
	    if (my $exc = OpenXPKI::Exception->caught()) {
		# ignore exception for missing 'notbefore' entry
		if ($exc->message() 
		    eq "I18N_OPENXPKI_READ_FILE_DOES_NOT_EXIST") {
		    $log->log(
			MESSAGE  => "Could not read issuing CA certificate '$cacertfile' for CA '$ca_id' (PKI realm $name)",
			PRIORITY => "warn",
			FACILITY => "system");

		    $log->log(
			MESSAGE  => "Issuing CA '$ca_id' (PKI realm $name) is unavailable",
			PRIORITY => "warn",
			FACILITY => "monitor");
		    
		    next ISSUINGCA;
		}
		else
		{
		    $exc->rethrow();
		}
	    } elsif ($EVAL_ERROR && (ref $EVAL_ERROR)) {
		$EVAL_ERROR->rethrow();
	    }

	    
	    if (! defined $cacertdata) {
		$log->log(
		    MESSAGE  => "Could not read issuing CA certificate '$cacertfile' for CA '$ca_id' (PKI realm $name)",
		    PRIORITY => "warn",
		    FACILITY => "system");
		
		$log->log(
		    MESSAGE  => "Issuing CA '$ca_id' (PKI realm $name) is unavailable",
		    PRIORITY => "warn",
		    FACILITY => "monitor");
		
		next ISSUINGCA;
	    }

	    my $cacert
		= OpenXPKI::Crypto::X509->new(TOKEN => $defaulttoken,
					      DATA  => $cacertdata);
	    
	    if (! defined $cacert) {
		$log->log(
		    MESSAGE  => "Could not parse issuing CA certificate '$cacertfile' for CA '$ca_id' (PKI realm $name)",
		    PRIORITY => "warn",
		    FACILITY => "system");
		
		$log->log(
		    MESSAGE  => "Issuing CA '$ca_id' (PKI realm $name) is unavailable",
		    PRIORITY => "warn",
		    FACILITY => "monitor");
		
		next ISSUINGCA;
	    }


	    $realms{$name}->{ca}->{id}->{$ca_id}->{crypto} = $token;
	    $realms{$name}->{ca}->{id}->{$ca_id}->{cacert} = $cacert;
	    $log->log(
		MESSAGE  => "Attached CA token for issuing CA '$ca_id' of PKI realm '$name'",
		PRIORITY => "info",
		FACILITY => "system");
	    
	    # for convenience and quicker accesss
	    $realms{$name}->{ca}->{id}->{$ca_id}->{notbefore} = 
		$cacert->get_parsed("BODY", "NOTBEFORE");
	    $realms{$name}->{ca}->{id}->{$ca_id}->{notafter} = 
		$cacert->get_parsed("BODY", "NOTAFTER");

	    $issuing_ca_count++;

	    $log->log(
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
		FACILITY => "system");
	}
	    
	$log->log(
	    MESSAGE  => "Identified $issuing_ca_count issuing CAs for PKI realm '$name'",
	    PRIORITY => "info",
	    FACILITY => "system");

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
    ##! 1: "start"

    my $config = CTX('xml_config');

    my %params = (LOG => CTX('log'));

    ## setup of the environment

    ## determine database vendor
    $params{TYPE} = $config->get_xpath (
                   XPATH    => [ 'common/database/type' ],
                   COUNTER  => [ 0 ]);

    ## determine configuration for infrastructure
    $params{SERVER_ID} = $config->get_xpath (
                   XPATH    => [ 'common/database/server_id' ],
                   COUNTER  => [ 0 ]);
    $params{SERVER_SHIFT} = $config->get_xpath (
                   XPATH    => [ 'common/database/server_shift' ],
                   COUNTER  => [ 0 ]);

    ## find configuration and detect number of options
    my ($vendor_name, $vendor_number, $vendor_envs) = ("", -1, 0);
    my $vendor_count = $config->get_xpath_count (
                            XPATH    => [ 'common/database/environment/vendor' ],
                            COUNTER  => []);
    for (my $k = 0; $k<$vendor_count; $k++)
    {
        $vendor_name = $config->get_xpath (
                            XPATH    => [ 'common/database/environment/vendor', 'type' ],
                            COUNTER  => [ $k, 0 ]);
        next if ($vendor_name ne $params{TYPE});
        $vendor_number = $k;
        eval { $vendor_envs = $config->get_xpath_count (
		   XPATH    => [ 'common/database/environment/vendor', 'option' ],
		   COUNTER  => [ $k ]);
	};
    }

    ## load environment
    for (my $i = 0; $i<$vendor_envs; $i++)
    {
        my $env_name = $config->get_xpath (
                           XPATH    => [ 'common/database/environment/vendor', 'option', 'name' ],
                           COUNTER  => [ $vendor_number, $i, 0 ]);
        my $env_value = $config->get_xpath (
                           XPATH    => [ 'common/database/environment/vendor', 'option', 'value' ],
                           COUNTER  => [ $vendor_number, $i, 0 ]);
        $ENV{$env_name} = $env_value;
        ##! 4: "NUMBER: $i"
        ##! 4: "OPTION: $env_name"
        ##! 4: "VALUE:  $env_value"
    }

    ## load database config
    $params{NAME} = $config->get_xpath (
                   XPATH    => [ 'common/database/name' ],
                   COUNTER  => [ 0 ]);
    eval{ $params{HOST} = $config->get_xpath (
                   XPATH    => [ 'common/database/host' ],
                   COUNTER  => [ 0 ]) };
    eval{ $params{PORT} = $config->get_xpath (
                   XPATH    => [ 'common/database/port' ],
                   COUNTER  => [ 0 ]) };
    eval{ $params{USER} = $config->get_xpath (
                   XPATH    => [ 'common/database/user' ],
                   COUNTER  => [ 0 ]) };
    eval{ $params{PASSWD} = $config->get_xpath (
                   XPATH    => [ 'common/database/passwd' ],
                   COUNTER  => [ 0 ]) };
    eval{ $params{NAMESPACE} = $config->get_xpath (
                   XPATH    => [ 'common/database/namespace' ],
                   COUNTER  => [ 0 ]) };

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
    my $log = OpenXPKI::Server::Log->new (CONFIG => $config);

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
    ##! 2: "switching stderr to $stderr"
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

Prepares a hash which has the following structure:

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
