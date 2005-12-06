# OpenXPKI::Crypto::TokenManager.pm 
# Copyright (C) 2003-2005 Michael Bell
# $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::TokenManager;

use OpenXPKI qw (debug);
use OpenXPKI::Exception;

use Data::Dumper;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
                DEBUG => 0,
               };

    bless $self, $class;

    my $keys = { @_ };
    $self->{DEBUG}  = 1               if ($keys->{DEBUG});
    $self->{config} = $keys->{CONFIG} if ($keys->{CONFIG});

    if (not $self->{config})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_NEW_MISSING_XML_CONFIG");
    }

    $self->debug ("token manager is ready");
    return $self;
}

sub set_ui
{
    my $self    = shift;
    $self->{UI} = shift;
    return 1;
}

######################################################################
##                     slot management                              ##
######################################################################

sub get_token
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("entering function");

    my $type  = $keys->{TYPE};
    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};

    if (not $type)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_TYPE");
    }
    if (not $name)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_NAME");
    }
    if (not $realm)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_PKI_REALM");
    }
    $self->debug ("$realm: $type -> $name");

    $self->__add_token (TYPE => $type, NAME => $name, PKI_REALM => $realm)
        if (not $self->{TOKEN}->{$realm}->{$type}->{$name});
    $self->debug ("token added");

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_EXIST")
        if (not $self->{TOKEN}->{$realm}->{$type}->{$name});
    $self->debug ("token is present");

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_USABLE")
        if (not $self->__use_token (TYPE => $type, NAME => $name, PKI_REALM => $realm));
    $self->debug ("token is usable");

    return $self->{TOKEN}->{$realm}->{$type}->{$name};
}

sub __add_token
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("entering function");

    my $type  = $keys->{TYPE};
    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};

    ## build path from token type

    my $type_path = "";
    if ($type eq "CA")
    {
        $type_path = "ca";
    }
    elsif ($type eq "DEFAULT")
    {
        $type_path = "common";
    } else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_INCORRECT_TYPE",
            params  => {"TYPE" => $type});
    }

    ## get matching pki_realm

    my $realm_count = $self->{config}->get_xpath_count (
                          XPATH => 'pki_realm');
    my $realm_index;
    for (my $i=0; $i<$realm_count; $i++)
    {
        $self->debug ("checking pki_realm");
        next if ($realm ne $self->{config}->get_xpath (
                              XPATH    => [ 'pki_realm', 'name' ],
                              COUNTER  => [ $i, 0 ]));
        $self->debug ("pki_realm ok");
        $realm_index = $i;
        last;
    }
    if (! defined $realm_index)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_PKI_REALM_NOT_FOUND",
            params  => {"PKI_REALM" => $realm});
    }
 
    ## get matching type
    my $type_count = $self->{config}->get_xpath_count (
                          XPATH   => [ 'pki_realm', $type_path ],
                          COUNTER => [ $realm_index ]);
    my $type_index;
    for (my $i=0; $i<$type_count; $i++)
    {
        $self->debug ("checking name of type");
        next if ($name ne $self->{config}->get_xpath (
                              XPATH    => [ 'pki_realm', $type_path, 'name' ],
                              COUNTER  => [ $realm_index, $i, 0 ]));
        $self->debug ("pki_realm and name ok");
        $type_index = $i;
        last;
    }
    if (! defined $type_index)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_INCORRECT_NAME_OR_TYPE",
            params  => {"NAME" => $name, "TYPE" => $type});
    }



    # build token parameters
    my %token_args = ( NAME   => $name,
		       PARENT => $self,
	);

    # any existing key in this hash is considered optional in %token_args
    my %is_optional = ();

    # default tokens don't need key, cert etc...
    if ($type eq "DEFAULT") {
	foreach (qw(key cert internal_chain passwd passwd_parts)) {
	    $is_optional{uc($_)}++;
	}
    }

    # FIXME: currently unused attributes:
    # openca-sv
    foreach my $key (qw(debug      backend       mode 
                        engine     shell         wrapper 
                        tmpdir     randfile
                        config
                        key        cert          internal_chain
                        passwd     passwd_parts 
                       )) {

	my $attribute_count;
	eval {
	    $attribute_count = $self->{config}->get_xpath_count (
		XPATH    => [ 'pki_realm', $type_path, 'token', $key ],
		COUNTER  => [ $realm_index, $type_index, 0 ]);
	};

	if (my $exc = OpenXPKI::Exception->caught())
	{
	    $self->debug ("caught exception while reading config attribute $key");
	    # only pass exception if attribute is not optional
	    if (! $is_optional{uc($key)}) {
		$self->debug ("argument $key is not optional, escalating");
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_INCOMPLETE_CONFIGURATION",
		    child   => $exc,
		    params  => {"NAME" => $name, 
				"TYPE" => $type, 
				"ATTRIBUTE" => $key,
		    },
		    )
	    }
	    $attribute_count = 0;
	}

	# multivalue attributes are not desired/supported
	if ($attribute_count > 1) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_DUPLICATE_ATTRIBUTE",
		params  => {"NAME" => $name, 
			    "TYPE" => $type, 
			    "ATTRIBUTE" => $key,
		});
	}

	if ($attribute_count == 1) {
	    my $value = $self->{config}->get_xpath (
		XPATH    => [ 'pki_realm', $type_path, 'token', $key ],
		COUNTER  => [ $realm_index, $type_index, 0, 0 ]);
	    
	    $token_args{uc($key)} = $value;
	}
    }
    

    ## init token
    my $backend = $token_args{BACKEND};
    delete $token_args{BACKEND};

    if (! defined $backend) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_BACKEND_UNDEFINED",
	    params  => {"NAME" => $name, 
			"TYPE" => $type, 
	    });
    }

    $self->debug ("try to setup $backend token");
    eval {
        $self->{TOKEN}->{$realm}->{$type}->{$name} = $self->__new_token ($backend, %token_args);
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        delete $self->{TOKEN}->{$realm}->{$type}->{$name}
            if (exists $self->{TOKEN}->{$realm}->{$type}->{$name});
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_CREATE_FAILED",
            child   => $exc);
    }

    if (! defined $self->{TOKEN}->{$realm}->{$type}->{$name}) {
        delete $self->{TOKEN}->{$realm}->{$type}->{$name}
            if (exists $self->{TOKEN}->{$realm}->{$type}->{$name});
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_INIT_FAILED",
	    );
    }

    $self->debug ("$type token $name for $realm successfully added");
    return $self->{TOKEN}->{$realm}->{$type}->{$name};
}

sub __new_token {

    my $self = shift;
    my $name = shift;
    $self->debug ("entering function");
    foreach my $item (@_)
    {
        next if (not defined $item); ## happens on empty arrays
        $self->debug ("argument: $item");
    }

    ## get the token class    
    eval "require $name";
    if ($@)
    {
        my $text = $@;
        $self->debug ("compilation of driver $name failed\n$text");
        OpenXPKI::Exception->throw (message => $text);
    }
    $self->debug ("class: $name");

    ## get the token
    ## FIXME: why I send $self to the child!?
    my $token;
    eval { 
	$token = $name->new (@_) 
    };

    if (my $exc = OpenXPKI::Exception->caught())
    {
        ## really stupid dummy exception handling
        $self->debug ("cannot get new instance of driver $name");
        $exc->rethrow();
    }
    $self->debug ("no exception during new()");

    if (! defined $token) {
	$self->debug ("initialization error (constructor returned undef)");
	return;
    }
    $self->debug ("no error during new, new token present");

    return $token;
}

sub __use_token
{
    my $self = shift;
    my $keys = { @_ };

    my $type  = $keys->{TYPE};
    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};

    ## the token must be present
    OpenXPKI::Excepion->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_USE_TOKEN_NOT_PRESENT")
        if (not $self->{TOKEN}->{$realm}->{$type}->{$name});

    return $self->{TOKEN}->{$realm}->{$type}->{$name}->login()
        if (not $self->{TOKEN}->{$realm}->{$type}->{$name}->online());

    return 1;
}

## functions to handle token which can operate as daemons

sub stop_session
{
    my $self = shift;
    my $error = 0;

    foreach my $realm (keys %{$self->{TOKEN}})
    {
        foreach my $type (keys %{$self->{TOKEN}->{$realm}})
        {
            foreach my $name (keys %{$self->{TOKEN}->{$realm}->{$type}})
            {
                next if (not $self->{TOKEN}->{$realm}->{$type}->{$name}->get_mode() !~ /^session$/i);
                $error = 1 if (not $self->{TOKEN}->{$realm}->{$type}->{$name}->logout());
            }
        }
    }
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_STOP_SESSION_FAILED")
        if ($error);
    return 1;
}

## logout all tokens except sessions and daemons
sub DESTROY {
    my $self = shift;

    my $error = 0;
    foreach my $realm (keys %{$self->{TOKEN}})
    {
        next if (not defined $realm or not length $realm);
        foreach my $type (keys %{$self->{TOKEN}->{$realm}})
        {
            next if (not defined $type or not length $type);
            foreach my $name (keys %{$self->{TOKEN}->{$realm}->{$type}})
            {
                next if (not $self->{TOKEN}->{$realm}->{$type}->{$name});
                if ($self->{TOKEN}->{$realm}->{$type}->{$name}->get_mode() eq "standby")
                {
                    $error = 1 if (not $self->{TOKEN}->{$realm}->{$type}->{$name}->logout());
                }
                ## init destruction of token
                delete $self->{TOKEN}->{$realm}->{$type}->{$name};
            }
        }
    }

    OpenXPKI::Exception->throw (
        message => "I18N_OPENPKI_CRYPTO_TOKENMANAGER_DESTROY_TOKEN_FAILED")
        if ($error);
    return 1;
}

1;
__END__

=head1 Description

This modules manages all cryptographic tokens. You can use it to simply
get tokens and to manage the state of a token.

=head1 Functions

=head2 new

The constructor only need an instance of the XML configuration. The
parameter for this is called CONFIG. If you want to debug the module
then must specify a true value for the parameter DEBUG.

=head2 set_ui

is used to set the user interface. This is required to enter the passpharse
for a software token.

=head2 get_token

needs TYPE, NAME and PKI_REALM of a token and will return a token which is ready to
use. Please remember that all tokens inside of one PKI realm need
distinguished names. The TYPE describes the use case of the token. This is required
to find the token configuration. TYPE can be today only CA and DEFAULT.

=head2 stop_session

stops all tokens which operate in session mode.

=head2 start_daemon

start all tokens which operate in daemon mode. NOT IMPLEMENTED ACTUALLY.

=head2 stop_daemon

stop all tokens which operate in daemon mode. NOT IMPLEMENTED ACTUALLY.
