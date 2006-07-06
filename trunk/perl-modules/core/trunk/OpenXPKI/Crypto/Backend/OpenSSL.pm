## OpenXPKI::Crypto::Backend::OpenSSL
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$
	
use strict;
use warnings;
use utf8; ## pack/unpack is too slow

package OpenXPKI::Crypto::Backend::OpenSSL;

use OpenXPKI::Crypto::Backend::OpenSSL::CLI;
use OpenXPKI::Crypto::Backend::OpenSSL::Command;
use OpenXPKI::Crypto::Backend::OpenSSL::Config;
use OpenXPKI::Crypto::Backend::OpenSSL::XS;
use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Debug 'OpenXPKI::Crypto::Backend::OpenSSL';
use OpenXPKI::Exception;
use English;

use File::Spec;
use Date::Parse;
use DateTime;

# use Smart::Comments;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};
    bless $self, $class;

    my $keys = shift;

    # determine temporary directory to use:
    # if a temporary directoy is specified, use it
    # else try /var/tmp (because potentially large files may be written that
    # are better left in the /var file system)
    # if /var/tmp does not exist fallback to /tmp

    ## removed FileSpec because it returns relative paths!!!

    my $requestedtmp = $keys->{TMP};
    delete $keys->{TMP};
    $self->{TOKEN_TYPE} = $keys->{TOKEN_TYPE};
  CHECKTMPDIRS:
    for my $path ($requestedtmp,    # user's preference
		  File::Spec->catfile('', 'var', 'tmp'), # suitable for large files
		  File::Spec->catfile('', 'tmp'),        # present on all UNIXes
	) {

	# directory must be readable & writable to be usable as tmp
	if (defined $path &&
	    (-d $path) &&
	    (-r $path) &&
	    (-w $path)) {
	    $self->{TMP} = $path;
	    last CHECKTMPDIRS;
	}
    }

    if (! (exists $self->{TMP} && -d $self->{TMP}))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_TEMPORARY_DIRECTORY_UNAVAILABLE");
    }

    $self->{XS} = OpenXPKI::Crypto::Backend::OpenSSL::XS->new();

    $self->__load_config  ($keys);
    $self->__init_config ();
    $self->__init_engine  ();
    $self->__init_shell   ();
    $self->__init_command ();

    return $self;
}

sub __load_config
{
    my $self = shift;
    my $keys = shift;

    my $name        = $keys->{NAME};
    my $realm_index = $keys->{PKI_REALM_INDEX};
    my $type_path   = $keys->{TOKEN_TYPE};
    my $type_index  = $keys->{TOKEN_INDEX};

    $self->{PARAMS}->{TMP} = $self->{TMP};

    # any existing key in this hash is considered optional in %token_args
    my %is_optional = ();

    # default tokens don't need key, cert etc...
    if ($type_path eq "common") {
	foreach (qw(key cert internal_chain passwd passwd_parts)) {
	    $is_optional{uc($_)}++;
	}
    }

    # FIXME: currently unused attributes:
    # openca-sv
    foreach my $key (qw(backend       mode 
                        engine     shell         wrapper 
                        randfile
                        key        cert          internal_chain
                        passwd     passwd_parts
                        engine_section
                        key_store  engine_usage
                       )) {

	my $attribute_count;
	eval {
	    ##! 8: "try to get attribute_count"
	    $attribute_count = CTX('xml_config')->get_xpath_count (
		XPATH    => [ 'pki_realm', $type_path, 'token', $key ],
		COUNTER  => [ $realm_index, $type_index, 0 ]);
	    ##! 8: "attribute_count ::= ".$attribute_count
	};

	if (my $exc = OpenXPKI::Exception->caught())
	{
	    ##! 8: "caught exception while reading config attribute $key"
	    # only pass exception if attribute is not optional
	    if (! $is_optional{uc($key)}) {
		##! 16: "argument $key is not optional, escalating"
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_INCOMPLETE_CONFIGURATION",
		    child   => $exc,
		    params  => {"NAME" => $name, 
				"TYPE" => $type_path, 
				"ATTRIBUTE" => $key,
		    },
		    );
	    }
	    $attribute_count = 0;
	}
        elsif ($EVAL_ERROR)
        {
	    ##! 8: "caught system exception while reading config attribute $key"
	    # FIXME: should we really throw an OpenXPKI exception here?
            OpenXPKI::Exception->throw (message => $EVAL_ERROR);
        }

	# multivalue attributes are not desired/supported
	if ($attribute_count > 1) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_BACKEND_OPENSSL_LOAD_CONFIG_DUPLICATE_ATTRIBUTE",
		params  => {"NAME" => $name, 
			    "TYPE" => $type_path, 
			    "ATTRIBUTE" => $key,
		});
	}

	if ($attribute_count == 1) {
	    my $value = CTX('xml_config')->get_xpath (
		XPATH    => [ 'pki_realm', $type_path, 'token', $key ],
		COUNTER  => [ $realm_index, $type_index, 0, 0 ]);

	    $self->{PARAMS}->{uc($key)} = $value;
	}
    }
    return 1;
}

sub __init_config
{
    my $self = shift;
    $self->{CONFIG} = OpenXPKI::Crypto::Backend::OpenSSL::Config->new(
                      {
                          TMP => $self->{TMP},
                          XS  => $self->{XS}
                      });
}

sub __init_engine
{
    ##! 8: "start"
    my $self = shift;
    my $keys = shift;

    if (!exists $self->{PARAMS}->{ENGINE} || $self->{PARAMS}->{ENGINE} eq "") {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_ENGINE_UNDEFINED",
	    );
    }

    my $engine = "OpenXPKI::Crypto::Backend::OpenSSL::Engine::".$self->{PARAMS}->{ENGINE};
    eval "use $engine;";
    if ($@)
    {
        my $msg = $@;
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_INIT_ENGINE_USE_FAILED",
            params  => {"ERRVAL" => $msg});
    }
    delete $self->{PARAMS}->{ENGINE};
    $self->{ENGINE} = eval {$engine->new (%{$self->{PARAMS}}, XS => $self->{XS})};
    if (my $exc = OpenXPKI::Exception->caught())
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_INIT_ENGINE_NEW_FAILED",
            child   => $exc);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }
    ##! 16: "configure engine (ENGINE_USAGE and KEY_STORE)"
    ##! 16: "why do we store these informations in OpenSSL and not in the engine?"
    ##! 16: "why do we store the same information in two places (engine and openssl)?"
    $self->{ENGINE_USAGE} = $self->{PARAMS}->{ENGINE_USAGE};
    $self->{KEY_STORE} = $self->{PARAMS}->{KEY_STORE};
    delete $self->{PARAMS}->{ENGINE_USAGE};
    delete $self->{PARAMS}->{KEY_STORE};

    ##! 16: "update profile"
    $self->{CONFIG}->set_engine($self->{ENGINE});

    ##! 8: "end"
    return 1;
}

sub __init_shell
{
    ##! 8: "start"
    my $self = shift;

    if (not -x $self->{PARAMS}->{SHELL})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_BINARY_NOT_FOUND",
	    params => {
		SHELL => $self->{PARAMS}->{SHELL},
	    });
    } else {
        $self->{OPENSSL} = $self->{PARAMS}->{SHELL};
        $self->{SHELL}   = $self->{PARAMS}->{SHELL};
	if (not -e $self->{SHELL})
	{
	    OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_DOES_NOT_EXIST",
	        params  => {"SHELL" => $self->{SHELL}});
	}
    }
    my $wrapper = $self->{ENGINE}->get_wrapper();
    if ($wrapper)
    {
        $self->{SHELL} = $wrapper . " " . $self->{OPENSSL};
    }

    eval
    {
        $self->{CLI} = OpenXPKI::Crypto::Backend::OpenSSL::CLI->new
                         ({
                             ENGINE => $self->{ENGINE},
                             SHELL  => $self->{SHELL},
                             TMP    => $self->{TMP},
                             CONFIG => $self->{CONFIG}
                         });
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_INIT_CLI_FAILED",
            child   => $exc);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }

    ##! 8: "end"
    return 1;
}

sub __init_command
{
    my $self = shift;

    foreach my $key (["TMP", "TMP"], ["RANDFILE", "RANDOM_FILE"])
    {
        if (not exists $self->{PARAMS}->{$key->[0]})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_MISSING_COMMAND_PARAM",
                params  => {"PARAM" => $key->[0]});
        }
        $self->{COMMAND_PARAMS}->{$key->[1]} = $self->{PARAMS}->{$key->[0]};
    }
    $self->{COMMAND_PARAMS}->{ENGINE} = $self->{ENGINE};
    $self->{COMMAND_PARAMS}->{CONFIG} = $self->{CONFIG};
    $self->{COMMAND_PARAMS}->{XS}     = $self->{XS};

    return 1;
}

sub command
{
    ##! 1: "start"
    my $self = shift;
    my $keys = shift;

    my $cmd  = "OpenXPKI::Crypto::Backend::OpenSSL::Command::".$keys->{COMMAND};
    delete $keys->{COMMAND};
    ##! 2: "Command: $cmd"

    my $ret = eval
    ##! 2: "FIXME: do we need an eval here?"
    {
        my $cmdref = $cmd->new ({%{$self->{COMMAND_PARAMS}}, %{$keys}, TOKEN_TYPE => $self->{TOKEN_TYPE}});
        my $cmds = $cmdref->get_command();

	if (ref $cmds ne 'HASH') {
	    # standard invocation
	    $self->{CLI}->prepare (
		{
		    COMMAND => $cmds, 
		    CONFIG => $self->{CONFIG},
		});
	    $self->{CLI}->execute();
	} else {
	    # command returned a hash instead of a arrayref, this means
	    # that we need to extract parameters for execute
	    
	    if (! exists $cmds->{COMMAND}) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_MISSING_SUBPARAMETER_COMMAND");
	    }
	    if (! exists $cmds->{PARAMS}) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_MISSING_SUBPARAMETER_PARAMS");
	    }

	    $self->{CLI}->prepare (
		{
		    COMMAND => $cmds->{COMMAND}, 
		    CONFIG => $self->{CONFIG},
		});
	    $self->{CLI}->execute(
		{
		    PARAMS => $cmds->{PARAMS},
		});
	}

        my $result = $self->{CLI}->get_result();
        $result = $cmdref->get_result ($result);

        if ($cmdref->hide_output())
        {
            ##! 8: "successfully completed"
        } else {
            ##! 8: "successfully completed: $result"
        }

        $cmdref->cleanup();
        return $result;
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        $self->{CLI}->cleanup(); ## this is safe
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_FAILED",
            params  => {"COMMAND" => $cmd},
            child   => $exc);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    } else {
        ##! 4: "end"
        return $ret;
    }
}

###########################
##     BEGIN XS code     ##
###########################

sub get_object
{
    ##! 1: "start"
    my $self = shift;
    return $self->{XS}->get_object(@_);
}

sub get_object_function
{
    ##! 1: "start"
    my $self   = shift;
    return $self->{XS}->get_object_function(@_);
}

sub free_object
{
    ##! 1: "start"
    my $self   = shift;
    return $self->{XS}->free_object(@_);
}

#########################
##     END XS code     ##
#########################

###############################
##     BEGIN engine code     ##
###############################

sub get_mode
{
    ##! 1: "start"
    my $self   = shift;
    return $self->{ENGINE}->get_mode(@_);
}

sub online
{
    ##! 1: "start"
    my $self   = shift;
    return $self->{ENGINE}->online(@_);
}

sub key_online
{
    ##! 1: "start"
    my $self   = shift;
    return $self->{ENGINE}->key_online(@_);
}

sub login
{
    ##! 1: "start"
    my $self   = shift;
    return $self->{ENGINE}->login(@_);
}

sub logout
{
    ##! 1: "start"
    my $self   = shift;
    return $self->{ENGINE}->logout(@_);
}

sub get_certfile
{
    ##! 1: "start"
    my $self   = shift;
    return $self->{ENGINE}->get_certfile(@_);
}

sub get_chainfile
{
    ##! 1: "start"
    my $self   = shift;
    return $self->{ENGINE}->get_chainfile(@_);
}

#############################
##     END engine code     ##
#############################

sub DESTROY
{
    ##! 1: "start"
    my $self = shift;
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL - OpenSSL cryptographic backend

=head1 Description

This is the basic class to provide OpenXPKI with an OpenSSL based
cryptographic token. Beside the documented function all functions
in the class OpenXPKI::Crypto::Backend::OpenSSL::Engine are
available here too because we map these engine specific functions
directly to the engine (via AUTOLOAD).

=head1 Functions

=head2 new

is the constructor. It requires five basic parameters which are
described here. The other parameters are engine specific and
are described in the related engine documentation. Please see
OpenXPKI::Crypto::Backend::OpenSSL::Engine for more details.

=over

=item * RANDFILE (file to store the random informations)

=item * SHELL (the OpenSSL binary)

=item * TMP (the used temporary directory which must be private)

=back

=head2 command

execute an OpenSSL command. You must specify the name of the command
as first parameter followed by a hash with parameter. Example:

  $token->command ({COMMAND => "create_key", TYPE => "RSA", ...});

=head1 XS functions

We support some library functions via our XS module. Please see
our XS module for more informations.

=over

=item * get_object

=item * get_object_function

=item * free_object

=back

=head1 Engine functions

The OpenSSL engines which are supported provide some functions to
get more detailed infos about the used security token. Please see
our engine module for more informations.

=over

=item * get_mode

=item * online

=item * key_online

=item * login

=item * logout

=item * get_certfile

=item * get_chainfile

=back

=head1 See Also

OpenXPKI::Crypto::Backend::OpenSSL::XS and OpenXPKI::Crypto::Backend::OpenSSL::Engine
