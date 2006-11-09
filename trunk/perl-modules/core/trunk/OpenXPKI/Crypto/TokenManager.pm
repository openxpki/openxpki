# OpenXPKI::Crypto::TokenManager.pm 
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2003-2006 by The OpenXPKI Project
# $Revision$
package OpenXPKI::Crypto::TokenManager;

use strict;
use warnings;

use OpenXPKI::Debug 'OpenXPKI::Crypto::TokenManager';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;
use English;
use OpenXPKI::Crypto::Backend::API;
use OpenXPKI::Crypto::Tool::SCEP::API;
use OpenXPKI::Crypto::Tool::PKCS7::API;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };
    $self->{tmp} = $keys->{TMPDIR} if ($keys->{TMPDIR});

    ##! 1: "end - token manager is ready"
    return $self;
}

######################################################################
##                     slot management                              ##
######################################################################

sub get_token
{
    my $self = shift;
    my $keys = { @_ };
    ##! 1: "start"

    my $type  = $keys->{TYPE};
    my $name  = $keys->{ID};
    my $realm = $keys->{PKI_REALM};
    my $cert  = $keys->{CERTIFICATE};

    if (not $type)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_TYPE");
    }
    $name = "default" if ($type  eq "DEFAULT");
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
    ##! 2: "$realm: $type -> $name"

    if (not $self->{TOKEN}->{$realm}->{$type}->{$name}) {
        $self->__add_token(
            TYPE        => $type,
            NAME        => $name,
            PKI_REALM   => $realm,
            CERTIFICATE => $cert,
        );
    }
    ##! 2: "token added"

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_EXIST")
        if (not $self->{TOKEN}->{$realm}->{$type}->{$name});
    ##! 2: "token is present"

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_USABLE")
        if (not $self->__use_token (TYPE => $type, NAME => $name, PKI_REALM => $realm));
    ##! 2: "token is usable"

    return $self->{TOKEN}->{$realm}->{$type}->{$name};
}

sub __add_token
{
    my $self = shift;
    my $keys = { @_ };
    ##! 1: "start"

    my $type  = $keys->{TYPE};
    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};
    my $cert  = $keys->{CERTIFICATE};

    ## build path from token type

    my $type_path = "";
    if ($type eq "CA")
    {
        $type_path = "ca";
    }
    elsif ($type eq 'SCEP')
    {
        $type_path = 'scep';
    }
    elsif ($type eq 'PKCS7')
    {
        $type_path = 'pkcs7';
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

    my $realm_count = CTX('xml_config')->get_xpath_count (
                          XPATH => 'pki_realm');
    my $realm_index;
    for (my $i=0; $i<$realm_count; $i++)
    {
        ##! 4: "checking pki_realm"
        next if ($realm ne CTX('xml_config')->get_xpath (
                              XPATH    => [ 'pki_realm', 'name' ],
                              COUNTER  => [ $i, 0 ]));
        ##! 4: "pki_realm ok"
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
    my $type_count = CTX('xml_config')->get_xpath_count (
                          XPATH   => [ 'pki_realm', $type_path ],
                          COUNTER => [ $realm_index ]);
    my $type_index;
    for (my $i=0; $i<$type_count; $i++)
    {
        ##! 4: "checking name of type"
        next if ($name ne CTX('xml_config')->get_xpath (
                              XPATH    => [ 'pki_realm', $type_path, 'id' ],
                              COUNTER  => [ $realm_index, $i, 0 ]));
        ##! 4: "pki_realm and name ok"
        $type_index = $i;
        last;
    }
    if (! defined $type_index)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_INCORRECT_NAME_OR_TYPE",
            params  => {"NAME" => $name, "TYPE" => $type});
    }

    my $backend = CTX('xml_config')->get_xpath (
		XPATH    => [ 'pki_realm', $type_path, 'token', 'backend' ],
		COUNTER  => [ $realm_index, $type_index, 0, 0 ]);

    if (! defined $backend) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_BACKEND_UNDEFINED",
	    params  => {"NAME" => $name, 
			"TYPE" => $type, 
	    });
    }

    ##! 2: "try to setup $backend token"
    eval {
        my $backend_api_class;
        if ($type eq 'SCEP') { # SCEP uses its own API
            $backend_api_class = 'OpenXPKI::Crypto::Tool::SCEP::API';
        }
        elsif ($type eq 'PKCS7') { # so does PKCS#7
            $backend_api_class = 'OpenXPKI::Crypto::Tool::PKCS7::API';
        }
        else { # use the 'default' backend
            $backend_api_class = 'OpenXPKI::Crypto::Backend::API';
        }
        ##! 16: 'instantiating token, API class: ' . $backend_api_class
        $self->{TOKEN}->{$realm}->{$type}->{$name} =
                $backend_api_class->new ({
                    CLASS => $backend,
                    TMP   => $self->{tmp},
                    NAME  => $name,
                    PKI_REALM_INDEX => $realm_index,
                    TOKEN_TYPE      => $type_path,
                    TOKEN_INDEX     => $type_index,
                    CERTIFICATE     => $cert,
                });
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        delete $self->{TOKEN}->{$realm}->{$type}->{$name}
            if (exists $self->{TOKEN}->{$realm}->{$type}->{$name});
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_CREATE_FAILED",
            children => [ $exc ]);
    }
    elsif ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_EVAL_ERROR',
            params => {
                'EVAL_ERROR' => $EVAL_ERROR,
            }
        );
    }

    if (! defined $self->{TOKEN}->{$realm}->{$type}->{$name}) {
        delete $self->{TOKEN}->{$realm}->{$type}->{$name}
            if (exists $self->{TOKEN}->{$realm}->{$type}->{$name});
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_INIT_FAILED",
	    );
    }

    ##! 2: "$type token $name for $realm successfully added"
    return $self->{TOKEN}->{$realm}->{$type}->{$name};
}

sub __use_token
{
    ##! 16: 'start'
    my $self = shift;
    my $keys = { @_ };

    my $type  = $keys->{TYPE};
    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};

    ## the token must be present

    if (! defined $self->{TOKEN}->{$realm}->{$type}->{$name}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_USE_TOKEN_NOT_PRESENT");
    } 

    my $instance = $self->{TOKEN}->{$realm}->{$type}->{$name};
    
    return $instance->login()
        if (not $instance->online());

    return 1;
    ##! 16: 'end'
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

=head1 Name

OpenXPKI::Crypto::TokenManager

=head1 Description

This modules manages all cryptographic tokens. You can use it to simply
get tokens and to manage the state of a token.

=head1 Functions

=head2 new

If you want to
use an explicit temporary directory then you must specifiy this
directory in the variable TMPDIR.

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
