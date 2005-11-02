# OpenXPKI::Crypto::TokenManager.pm 
# Copyright (C) 2003-2005 Michael Bell
# $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::TokenManager;

use OpenXPKI qw (debug);
use OpenXPKI::Exception;

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

    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};

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
    $self->debug ("$realm: $name");

    $self->__add_token (NAME => $name, PKI_REALM => $realm)
        if (not $self->{TOKEN}->{$realm}->{$name});
    $self->debug ("token added");

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_EXIST")
        if (not $self->{TOKEN}->{$realm}->{$name});
    $self->debug ("token is present");

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_USABLE")
        if (not $self->__use_token (NAME => $name, PKI_REALM => $realm));
    $self->debug ("token is usable");

    return $self->{TOKEN}->{$realm}->{$name};
}

sub __add_token
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("entering function");

    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};

    ## get matching config
    my $token_count = $self->{config}->get_xpath_count (
                          XPATH    => 'token_config/token');
    if (not defined $token_count)
    {
        OpenXPKI::Exception->throw (
            errno   => $self->{config}->errno(),
            message => $self->{config}->errval());
    }
    for (my $i=0; $i<$token_count; $i++)
    {
        $self->debug ("checking pki realm");
        next if ($realm ne $self->{config}->get_xpath (
                              XPATH    => [ 'token_config/token', 'pki_realm' ],
                              COUNTER  => [ $i, 0 ]));
        $self->debug ("checking name");
        next if ($name ne $self->{config}->get_xpath (
                              XPATH    => [ 'token_config/token', 'name' ],
                              COUNTER  => [ $i, 0 ]));
        $self->debug ("pki realm and name ok");
        my @args = (NAME => $name, PARENT => $self);

        ## load CRYPTO, GETTEXT, NAME and MODE to array
        $self->debug ("loading mode");
        my $help = $self->{config}->get_xpath (
                               XPATH    => [ 'token_config/token', 'mode' ],
                               COUNTER  => [ $i, 0 ]);
        push @args, "MODE", $help;

        ## load complete config in array
        $self->debug ("loading options");
        my $option_count = $self->{config}->get_xpath_count (
                               XPATH    => [ 'token_config/token', 'option' ],
                               COUNTER  => [ $i ]);
        for (my $k=0; $k<$option_count; $k++)
        {
            $help = $self->{config}->get_xpath (
                               XPATH    => [ 'token_config/token', 'option', 'name' ],
                               COUNTER  => [ $i, $k, 0 ]),
            $self->debug ("option name: $help");
            push @args, $help;
            $help = $self->{config}->get_xpath (
                               XPATH    => [ 'token_config/token', 'option', 'value' ],
                               COUNTER  => [ $i, $k, 0 ]);
            if (defined $help)
            {
                $self->debug ("option value: $help");
            } else {
                ## empty tag
                $self->debug ("option value: <empty/>");
            }
            push @args, $help;
        }
        $self->debug ("loaded options");

        ## handle multivalued parameters

        my $count = scalar @args / 2;
        my %hargs = ();
        for (my $i=0; $i<$count; $i++)
        {
            my $name  = $args[2*$i];
            my $value = $args[2*$i+1];
            ## if global debug then local debug too
            $value = $self->{DEBUG} if ($name =~ /DEBUG/i and not $value and $self->{DEBUG});
            if (exists $hargs{$name})
            {
                $hargs{$name} = [ @{$hargs{$name}}, $value ];
            } else
            {
                $hargs{$name} = [ $value ];
            }
            ## activate crypto layer debugging if a single token is in debug mode
            $self->{DEBUG} = $value if ($name =~ /DEBUG/i and $value);
        }
        @args = ();
        foreach my $key (keys %hargs)
        {
            $self->debug ("argument: name: $key");
            push @args, $key;
            if (scalar @{$hargs{$key}} > 1)
            {
                push @args, $hargs{$key};
            } else
            {
                push @args, $hargs{$key}->[0];
            }
        }
        $self->debug ("fixed multivalued options");

        ## init token
        my $type = $self->{config}->get_xpath (
                               XPATH    => [ 'token_config/token', 'type' ],
                               COUNTER  => [ $i, 0 ]);
        $self->debug ("try to setup $type token");
        eval {
            $self->{TOKEN}->{$realm}->{$name} = $self->__new_token ($type, @args);
        };
        if (my $exc = OpenXPKI::Exception->caught())
        {
            delete $self->{TOKEN}->{$realm}->{$name}
                if (exists $self->{TOKEN}->{$realm}->{$name});
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_CREATE_FAILED",
                child   => $exc);
        }
        $self->debug ("token $name for $realm successfully added");
        return $self->{TOKEN}->{$realm}->{$name};
    }
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_NOT_CONFIGURED",
        params  => {"NAME" => $name, "PKI_REALM" => $realm});
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
    ## my $token = eval {$name->new ($self, @_)};
    my $token = eval {$name->new (@_)};

    if (my $exc = OpenXPKI::Exception->caught())
    {
        ## really stupid dummy exception handling
        $self->debug ("cannot get new instance of driver $name");
        $exc->rethrow();
    }
    $self->debug ("no error during new, new token present");

    return $token;
}

sub __use_token
{
    my $self = shift;
    my $keys = { @_ };

    my $name  = $keys->{NAME};
    my $realm = $keys->{PKI_REALM};

    ## the token must be present
    OpenXPKI::Excepion->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_USE_TOKEN_NOT_PRESENT")
        if (not $self->{TOKEN}->{$realm}->{$name});

    return $self->{TOKEN}->{$realm}->{$name}->login()
        if (not $self->{TOKEN}->{$realm}->{$name}->online());

    return 1;
}

## functions to handle token which can operate as daemons

sub stop_session
{
    my $self = shift;
    my $error = 0;

    foreach my $realm (keys %{$self->{TOKEN}})
    {
        foreach my $name (keys %{$self->{TOKEN}->{$realm}})
        {
            next if (not $self->{TOKEN}->{$realm}->{$name}->get_mode() !~ /^session$/i);
            $error = 1 if (not $self->{TOKEN}->{$realm}->{$name}->logout());
        }
    }
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_STOP_SESSION_FAILED")
        if ($error);
    return 1;
}

sub start_daemon
{
    my $self = shift;
    my $error = 0;
    my $token_count = $self->{config}->get_xpath_count (
                          XPATH    => 'token_config/token');
    for (my $i=0; $i<$token_count; $i++)
    {
        next if ($self->{config}->get_xpath (
                      XPATH    => [ 'token_config/token', 'mode' ],
                      COUNTER  => [ $i, 0 ]) !~ /^daemon$/i);
        my $name = $self->{config}->get_xpath (
                      XPATH    => [ 'token_config/token', 'name' ],
                      COUNTER  => [ $i, 0 ]);
        my $realm = $self->{config}->get_xpath (
                      XPATH    => [ 'token_config/token', 'pki_realm' ],
                      COUNTER  => [ $i, 0 ]);
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_START_DAEMON_GET_TOKEN_FAILED",
            params  => {"NAME" => $name, "PKI_REALM" => $realm})
            if (not $self->get_token(NAME => $name, PKI_REALM => $realm));
    }
    return 1;
}

sub stop_daemon
{
    my $self = shift;
    my $error = 0;
    my $token_count = $self->{config}->get_xpath_count (
                          XPATH    => 'token_config/token');
    for (my $i=0; $i<$token_count; $i++)
    {
        next if ($self->{config}->get_xpath (
                      XPATH    => [ 'token_config/token', 'mode' ],
                      COUNTER  => [ $i, 0 ]) !~ /^daemon$/i);
        my $name = $self->{config}->get_xpath (
                      XPATH    => [ 'token_config/token', 'name' ],
                      COUNTER  => [ $i, 0 ]);
        my $realm = $self->{config}->get_xpath (
                      XPATH    => [ 'token_config/token', 'pki_realm' ],
                      COUNTER  => [ $i, 0 ]);
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_START_DAEMON_ADD_TOKEN_FAILED",
            params  => {"NAME" => $name, "PKI_REALM" => $realm})
            if (not $self->__add_token(NAME => $name, PKI_REALM => $realm));
        $error = 1 if (not $self->{TOKEN}->{$realm}->{$name}->logout());
    }
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_STOP_DAEMON_TOKEN_FAILED")
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
        foreach my $name (keys %{$self->{TOKEN}->{$realm}})
        {
            next if (not $self->{TOKEN}->{$realm}->{$name});
            if ($self->{TOKEN}->{$realm}->{$name}->get_mode() eq "standby")
            {
                $error = 1 if (not $self->{TOKEN}->{$realm}->{$name}->logout());
            }
            ## init destruction of token
            delete $self->{TOKEN}->{$realm}->{$name};
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

needs NAME and PKI_REALM of a token and will return a token which is ready to
use. Please remember that all tokens inside of one PKI realm need
distinguished names.

=head2 stop_session

stops all tokens which operate in session mode.

=head2 start_daemon

start all tokens which operate in daemon mode.

=head2 stop_daemon

stop all tokens which operate in daemon mode.
