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

use English;
use OpenXPKI qw(debug set_language set_locale_prefix);
use OpenXPKI::Exception;

use OpenXPKI::XML::Config;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Server::DBI;
use OpenXPKI::Server::Log;

## we operate in static mode

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
                DEBUG     => 0,
               };

    bless $self, $class;

    my $keys = { @_ };
    $self->{DEBUG} = $keys->{DEBUG} if ($keys->{DEBUG});

    return $self;
}

sub get_xml_config
{
    my $self = shift;
    my $keys = { @_ };
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

    return OpenXPKI::XML::Config->new (DEBUG  => $self->{"DEBUG"},
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

sub redirect_stderr
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_REDIRECT_STDERR_MISSING_CONFIG");
    }

    my $stderr = $keys->{CONFIG}->get_xpath (XPATH => "common/server/stderr");
    if (not $stderr)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_REDIRECT_STDERR_MISSING_STDERR");
    }
    $self->debug ("switching stderr to $stderr");
    if (not open STDERR, '>>', $stderr)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_REDIRECT_STDERR_FAILED");
    }
    binmode STDERR, ":utf8";
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

    return OpenXPKI::Crypto::TokenManager->new (DEBUG  => $self->{DEBUG},
                                                CONFIG => $keys->{CONFIG});
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

    ## get all PKI realms

    my %realms = ();
    my $count = $keys->{CONFIG}->get_xpath_count (XPATH => "pki_realm");
    for (my $i = 0 ; $i < $count ; $i++)
    {
        ## prepare crypto stuff for every PKI realm

        my $name = $keys->{CONFIG}->get_xpath (
                       XPATH    => [ 'pki_realm', 'name' ],
                       COUNTER  => [ $i, 0 ]);

        $realms{$name}->{crypto}->{default} = $self->__get_default_crypto_token (
                                                 CONFIG => $keys->{CONFIG},
                                                 CRYPTO => $keys->{CRYPTO},
                                                 PKI_REALM => $name);
    }

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
                                       NAME      => "default",
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

sub get_user_interfaces
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_UI_MISSING_CONFIG");
    }

    my $count = $keys->{CONFIG}->get_xpath_count (XPATH => "common/server/interface");
    my %ui    = ();
    for (my $i=0; $i < $count; $i++)
    {
        ## load interface class
        my $class = $keys->{CONFIG}->get_xpath (
                        XPATH   => "common/server/interface",
                        COUNTER => $i);
           $class = "OpenXPKI::UI::".$class;
        eval "use $class;";
        if ($EVAL_ERROR)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_INIT_GET_USER_INTERFACE_USE_FAILED",
                params  => {EVAL_ERROR => $EVAL_ERROR,
                            MODULE     => $class});
        }

        ## initialize interface class
        $ui{$class} = eval { $class->new (API => $self->{api}) };
        $EVAL_ERROR->rethrow() if ($EVAL_ERROR);
    }

    return %ui;
}

sub get_server_config
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("start");

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_CRYPTO_LAYER_MISSING_CONFIG");
    }

    my %params = ();
    $params{proto}      = "unix";
    $params{background} = 1;
    $params{user}       = $keys->{CONFIG}->get_xpath (XPATH => "common/server/user");
    $params{group}      = $keys->{CONFIG}->get_xpath (XPATH => "common/server/group");
    $params{port}       = $keys->{CONFIG}->get_xpath (XPATH => "common/server/socket_file")."|unix";
    $params{pid_file}   = $keys->{CONFIG}->get_xpath (XPATH => "common/server/pid_file");

    ## check daemon user

    my ($pw_name,$pw_passwd,$pw_uid,$pw_gid,
        $pw_quota,$pw_comment,$pw_gcos,$pw_dir,$pw_shell,$pw_expire) =
        getpwnam ($params{"user"});
    ($pw_name,$pw_passwd,$pw_uid,$pw_gid,
     $pw_quota,$pw_comment,$pw_gcos,$pw_dir,$pw_shell,$pw_expire) =
        getpwuid ($params{"user"}) if (not $pw_uid);
    if (not defined $pw_name or length $pw_name < 1)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_SERVER_CONFIG_WRONG_USER",
            params  => {"USER" => $params{"user"}});
    }

    ## check daemon group

    my ($gr_name,$gr_passwd,$gr_gid,$gr_members) =
        getgrnam ($params{"group"});
    ($gr_name,$gr_passwd,$gr_gid,$gr_members) =
        getgrgid ($params{"group"});
    if (not defined $gr_name or length $gr_name < 1)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_SERVER_CONFIG_WRONG_DAEMON_GROUP",
            params  => {"GROUP" => $params{"group"}});
    }

    return %params;
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

is the constructor and exists only to support the class with a debugging
feature. If you need to debug the class then simply specify a true value
for the parameter DEBUG.

=head3 get_xml_config

expects as only parameter the option CONFIG. This must be a filename
of an XML configuration file which is compliant with OpenXPKI's schema
definition in openxpki.xsd. We support local xinclude so please do not
be surprised if you habe a configuration file which looks a little bit
small. It returns an instance of OpenXPKI::XML::Config.

=head3 init_i18n

initializes the code for internationalization. It requires an instance
of OpenXPKI::XML::Config in the parameter CONFIG.

=head3 redirect_stderr

send all messages to STDERR directly to a file. The file is specified in
the XML configuration. The function requires an instance
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

=head2 Non-Cryptographic Object Initialization

=head3 get_dbi

initializes the database interface. It needs an instance of OpenXPKI::XML::Config
(parameter CONFIG) and an instance of OpenXPKI::Server::Log (parameter LOG). 
The log parameter is needed to guarantee a correct logging behaviour of
the database interface.

=head3 get_log

requires only the usual instance of OpenXPKI::XML::Config in the parameter CONFIG.
It returns an instance of the module OpenXPKI::Log.

=head2 Server Configuration

=head3 get_user_interfaces

needs the usual CONFIG parameter with an instance of OpenXPKI::XML::Config
and returns a hash with the supported user interfaces. The value
of each hash element is an instance of the user interface class.

=head3 get_server_config

prepares the complete server configuration to startup a socket
based server with Net::Server::Fork. It returns a hash which can be
directly passed to the module. The only required parameter is an
instance of OpenXPKI::XML::Config.
