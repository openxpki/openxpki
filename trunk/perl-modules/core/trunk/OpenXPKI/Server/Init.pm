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
use OpenXPKI qw(debug set_language set_locale_prefix);
use OpenXPKI::Exception;

use OpenXPKI::XML::Config;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Server::DBI;
use OpenXPKI::Server::Log;
use OpenXPKI::Server::ACL;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Authentication;

use OpenXPKI::Server::Context qw( CTX );

## we operate in static mode

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
                DEBUG     => 0,
               };

    bless $self, $class;

    my $keys         = shift;
    $self->{DEBUG}   = $keys->{DEBUG} if ($keys->{DEBUG});

    ### getting xml config...
    my $xml_config = $self->get_xml_config(CONFIG => $keys->{"CONFIG"});
    $self->init_i18n(CONFIG => $xml_config);

    ### getting crypto layer...
    my $crypto_layer = $self->get_crypto_layer(CONFIG => $xml_config);

    ### record these for later use...
    OpenXPKI::Server::Context::setcontext({
        xml_config   => $xml_config,
        crypto_layer => $crypto_layer,
        debug        => $keys->{DEBUG},
    });
    $self->redirect_stderr();

    ### getting pki_realm...
    my $pki_realm    = $self->get_pki_realms(CONFIG => $xml_config,
					     CRYPTO => $crypto_layer);

    ### getting logger...
    my $log          = $self->get_log(CONFIG => $xml_config);

    ### getting backend database...
    my $dbi_backend  = $self->get_dbi(CONFIG => $xml_config,
				      LOG    => $log);

    ### getting workflow database...
    my $dbi_workflow = $self->get_dbi(CONFIG => $xml_config,
				      LOG    => $log);

    OpenXPKI::Server::Context::setcontext({
        pki_realm      => $pki_realm,
        log            => $log,
        dbi_backend    => $dbi_backend,
        dbi_workflow   => $dbi_workflow,
        acl            => OpenXPKI::Server::ACL->new(),
        api            => OpenXPKI::Server::API->new(),
        authentication => OpenXPKI::Server::Authentication->new (),
    });

    ## FIXME: why do we need a reference to our daemon?
    ## FIXME: this sounds like a backdoor for me (bellmich)
    ## FIXME: nevertheless I'm sure that I introduced  this :(
    if (exists $keys->{SERVER})
    {
        OpenXPKI::Server::Context::setcontext({
            server         => $keys->{SERVER},
        });
    }

    return $self;
}

sub get_xml_config
{
    my $self = shift;
    my $keys = { @_ };

    ## this is a hack to support testing without a full initialization
    my $debug = 0;
       $debug = $self->{DEBUG} if (ref $self);

    $self->debug ("start");

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

    return OpenXPKI::XML::Config->new (DEBUG  => $debug,
                                       CONFIG => $keys->{"CONFIG"});
}

sub init_i18n
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

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
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_CRYPTO_LAYER_MISSING_CONFIG");
    }

    return OpenXPKI::Crypto::TokenManager->new (DEBUG  => $self->{DEBUG});
}



sub get_pki_realms
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_PKI_REALMS_LAYER_MISSING_CONFIG");
    }
    if (not $keys->{CRYPTO})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_PKI_REALMS_LAYER_MISSING_CRYPTO");
    }

    ### get all PKI realms

    my %realms = ();
    my $count = $keys->{CONFIG}->get_xpath_count (XPATH => "pki_realm");
    for (my $i = 0 ; $i < $count ; $i++)
    {
        ## prepare crypto stuff for every PKI realm

        my $name = $keys->{CONFIG}->get_xpath (
                       XPATH    => [ 'pki_realm', 'name' ],
                       COUNTER  => [ $i, 0 ]);

	my $defaulttoken = $self->__get_default_crypto_token (
	    CONFIG => $keys->{CONFIG},
	    CRYPTO => $keys->{CRYPTO},
	    PKI_REALM => $name);

        $realms{$name}->{crypto}->{default} = $defaulttoken;

	my @xpath   = ( 'pki_realm', 'common', 'profiles' );
	my @counter = ( $i,         0,        0 );
	
	foreach my $entrytype (qw( endentity selfsignedca crl )) {
	    ### entrytype: $entrytype

	    my $nr_of_entries = $keys->{CONFIG}->get_xpath_count(
		XPATH   => [ @xpath,   $entrytype, 'profile' ],
		COUNTER => [ @counter, 0 ]);
	    
	    ### entries: $nr_of_entries
	    foreach (my $jj = 0; $jj < $nr_of_entries; $jj++) {
		my $entryid = $keys->{CONFIG}->get_xpath(
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
			$format = $keys->{CONFIG}->get_xpath(
			    XPATH   => [ @xpath,   $entrytype, 'profile', 'validity', $validitytype, 'format' ],
			    COUNTER => [ @counter, 0,          $jj,       0,          0,             0 ],
			    );

			$validity = $keys->{CONFIG}->get_xpath(
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
		    }
		}
	    }
	}

	### %realms
	
	# get all CA certificates for PKI realm
	# $realms{$name}->{ca}->{$ca}->{certificate} =
	# get end entity validities
	my $nr_of_ca_entries
	    = $keys->{CONFIG}->get_xpath_count(
	    XPATH   => ['pki_realm', 'ca'],
	    COUNTER => [$i]);

	for (my $jj = 0; $jj < $nr_of_ca_entries; $jj++) {
	    my $ca_id = $keys->{CONFIG}->get_xpath(
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
	    

	    my $token = 
		$keys->{CRYPTO}->get_token (DEBUG     => $self->{DEBUG},
					    TYPE      => "CA",
					    ID        => $ca_id,
					    PKI_REALM => $name);
	    
	    $realms{$name}->{ca}->{id}->{$ca_id}->{crypto} = $token;

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
		
	    my $cacertdata = OpenXPKI->read_file($cacertfile);
	    if (! defined $cacertdata) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_INIT_GET_PKI_REALMS_NO_CA_CERT",
		    params  => {
			PKI_REALM => $name,
			CA_ID     => $ca_id,
			CA_CERT_FILE => $cacertfile,
		    },
		    );
	    }

	    
	    my $cacert
		= OpenXPKI::Crypto::X509->new(TOKEN => $defaulttoken,
					      DATA  => $cacertdata);
	    
	    if (! defined $cacert) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_INIT_GET_PKI_REALMS_CA_CERT_PARSING_ERROR",
		    params  => {
			PKI_REALM => $name,
			CA_ID     => $ca_id,
			CA_CERT_FILE => $cacertfile,
		    },
		    );
	    }
	    
	    $realms{$name}->{ca}->{id}->{$ca_id}->{cacert} = $cacert;

	    # for convenience and quicker accesss
	    $realms{$name}->{ca}->{id}->{$ca_id}->{notbefore} = 
		$cacert->get_parsed("BODY", "NOTBEFORE");
	    $realms{$name}->{ca}->{id}->{$ca_id}->{notafter} = 
		$cacert->get_parsed("BODY", "NOTAFTER");
	}
	    
    }

    ### realms: %realms
    return \%realms;
}

sub __get_default_crypto_token
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    if (not $keys->{CRYPTO})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DEFAULT_CRYPTO_TOKEN_MISSING_CRYPTO");
    }
    if (not $keys->{PKI_REALM})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DEFAULT_CRYPTO_TOKEN_MISSING_PKI_REALM");
    }

    return $keys->{CRYPTO}->get_token (DEBUG     => $self->{DEBUG},
                                       TYPE      => "DEFAULT",
                                       ID        => "default",
                                       PKI_REALM => $keys->{PKI_REALM});
}

sub get_dbi
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    ## check logging module

    if (not $keys->{LOG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DBI_MISSING_LOG");
    }
    my %params = (LOG => $keys->{LOG});

    ## check config

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DBI_MISSING_CONFIG");
    }
    my $config = $keys->{CONFIG};

    ## setup debugging

    $params{DEBUG} = $config->get_xpath (
                    XPATH    => [ 'common/database/debug' ],
                    COUNTER  => [ 0 ]);
    $params{DEBUG} = $self->{"DEBUG"} if (not $params{DEBUG});

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
        $vendor_envs = $config->get_xpath_count (
                            XPATH    => [ 'common/database/environment/vendor', 'option' ],
                            COUNTER  => [ $k ]);
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
        $self->debug ("NUMBER: $i\n".
                      "OPTION: $env_name\n".
                      "VALUE:  $env_value\n");
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
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    ## check parameters

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_LOG_MISSING_CONFIG");
    }
    my $config = $keys->{CONFIG};

    $config = $config->get_xpath (
                  XPATH    => [ 'common/log_config' ],
                  COUNTER  => [ 0 ]);

    ## init logging

    my $log = OpenXPKI::Server::Log->new (
                  DEBUG  => $self->{DEBUG},
                  CONFIG => $config);

    return $log;
}

sub redirect_stderr
{
    my $self = shift;
    $self->debug ("start");

    my $config = CTX('xml_config');

    my $stderr = $config->get_xpath (XPATH => "common/server/stderr");
    if (not $stderr)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_REDIRECT_STDERR_MISSING_STDERR");
    }
    $self->debug ("switching stderr to $stderr");
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

=head3 new

Initialization must be done ONCE by the server process.
Expects the XML configuration file via the named parameter CONFIG.
The named parameter DEBUG may be set to a true value to enable debugging.

Usage:

  use OpenXPKI::Server::Init;

  OpenXPKI::Server::Init::new({
         CONFIG => 't/config.xml',
         DEBUG => 0,
     });


=head3 get_xml_config

expects as only parameter the option CONFIG. This must be a filename
of an XML configuration file which is compliant with OpenXPKI's schema
definition in openxpki.xsd. We support local xinclude so please do not
be surprised if you habe a configuration file which looks a little bit
small. It returns an instance of OpenXPKI::XML::Config.

=head3 init_i18n

initializes the code for internationalization. It requires an instance
of OpenXPKI::XML::Config in the parameter CONFIG.

=head2 Cryptographic Initialization

=head3 get_crypto_layer

needs only an instance of the XML configuration in the parameter CONFIG.
It return an instance of the TokenManager class which handles all
configured cryptographic tokens.

=head3 get_pki_realms

prepares a hash which has the following structure:

$hash{PKI_REALM_NAME}->{"crypto"}->{"default"}

The values are the default cryptographic token for each PKI realm.
The parameters CONFIG and CRYPTO are required. The first parameter
is the XML configuration object and the second parameter must
be an instance of the TokenManager.

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

initializes the database interface. It needs an instance of OpenXPKI::XML::Config
(parameter CONFIG) and an instance of OpenXPKI::Server::Log (parameter LOG). 
The log parameter is needed to guarantee a correct logging behaviour of
the database interface.

=head3 get_log

requires only the usual instance of OpenXPKI::XML::Config in the parameter CONFIG.
It returns an instance of the module OpenXPKI::Log.

=head3 get_log

requires no arguments.
It returns an instance of the module OpenXPKI::Server::Authentication.
The context must be already established because OpenXPKI::XML::Config is
loaded from the context.

=head3 redirect_stderr

requires no arguments and is a simple function to send STDERR to
configured file. This is useful to track all warnings and errors.
