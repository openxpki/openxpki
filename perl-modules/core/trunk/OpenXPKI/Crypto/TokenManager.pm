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
    $self->{DEBUG}      = 1                   if ($keys->{DEBUG});
    $self->{cache}      = $keys->{CACHE}      if ($keys->{CACHE});

    if (not $self->{cache})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_NEW_MISSING_XML_CACHE");
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
    my $group = $keys->{CA_GROUP};

    if (not $name)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_NAME");
    }
    if (not $group)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_MISSING_CA_GROUP");
    }
    $self->debug ("$group: $name");

    $self->add_token (NAME => $name, CA_GROUP => $group)
        if (not $self->{TOKEN}->{$group}->{$name});
    $self->debug ("token added");

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_EXIST")
        if (not $self->{TOKEN}->{$group}->{$name});
    $self->debug ("token is present");

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_GET_TOKEN_NOT_USABLE")
        if (not $self->use_token (NAME => $name, CA_GROUP => $group));
    $self->debug ("token is usable");

    return $self->{TOKEN}->{$group}->{$name};
}

sub add_token
{
    my $self = shift;
    my $keys = { @_ };
    $self->debug ("entering function");

    my $name  = $keys->{NAME};
    my $group = $keys->{CA_GROUP};

    ## get matching config
    my $token_count = $self->{cache}->get_xpath_count (
                          XPATH    => 'token_config/token');
    if (not defined $token_count)
    {
        OpenXPKI::Exception->throw (
            errno   => $self->{cache}->errno(),
            message => $self->{cache}->errval());
    }
    for (my $i=0; $i<$token_count; $i++)
    {
        $self->debug ("checking ca group");
        next if ($group ne $self->{cache}->get_xpath (
                              XPATH    => [ 'token_config/token', 'ca_group' ],
                              COUNTER  => [ $i, 0 ]));
        $self->debug ("checking name");
        next if ($name ne $self->{cache}->get_xpath (
                              XPATH    => [ 'token_config/token', 'name' ],
                              COUNTER  => [ $i, 0 ]));
        $self->debug ("group and name ok");
        my @args = ();

        ## load CRYPTO, GETTEXT, NAME and MODE to array
        $self->debug ("loading mode");
        my $help = $self->{cache}->get_xpath (
                               XPATH    => [ 'token_config/token', 'mode' ],
                               COUNTER  => [ $i, 0 ]);
        push @args, "TOKEN_MODE", $help;

        ## load complete config in array
        $self->debug ("loading options");
        my $option_count = $self->{cache}->get_xpath_count (
                               XPATH    => [ 'token_config/token', 'option' ],
                               COUNTER  => [ $i ]);
        for (my $k=0; $k<$option_count; $k++)
        {
            $help = $self->{cache}->get_xpath (
                               XPATH    => [ 'token_config/token', 'option', 'name' ],
                               COUNTER  => [ $i, $k, 0 ]),
            $self->debug ("option name: $help");
            push @args, $help;
            $help = $self->{cache}->get_xpath (
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
        my $type = $self->{cache}->get_xpath (
                               XPATH    => [ 'token_config/token', 'type' ],
                               COUNTER  => [ $i, 0 ]);
        $self->debug ("try to setup $type token");
        eval {
            $self->{TOKEN}->{$group}->{$name} = $self->new_token ($type, @args);
        };
        if (my $exc = OpenXPKI::Exception->caught())
        {
            delete $self->{TOKEN}->{$group}->{$name}
                if (exists $self->{TOKEN}->{$group}->{$name});
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_CREATE_FAILED",
                child   => $exc);
        }
        $self->debug ("token $name for $group successfully added");
        return $self->{TOKEN}->{$group}->{$name};
    }
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_ADD_TOKEN_NOT_CONFIGURED",
        params  => {"NAME" => $name, "GROUP" => $group});
}

sub new_token {

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
        $self->debug ("cannot get new instance of driver OpenCA::Token::$name");
        $exc->rethrow();
    }
    $self->debug ("no error during new, new token present");

    return $token;
}

sub use_token
{
    my $self = shift;
    my $keys = { @_ };

    my $name  = $keys->{NAME};
    my $group = $keys->{CA_GROUP};

    ## the token must be present
    OpenXPKI::Excepion->throw (
        message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_USE_TOKEN_NOT_PRESENT")
        if (not $self->{TOKEN}->{$group}->{$name});

    return $self->{TOKEN}->{$group}->{$name}->login()
        if (not $self->{TOKEN}->{$group}->{$name}->online());

    return 1;
}

## functions to handle token which can operate as daemons

sub stop_session
{
    my $self = shift;
    my $error = 0;

    foreach my $group (keys %{$self->{TOKEN}})
    {
        foreach my $name (keys %{$self->{TOKEN}->{$group}})
        {
            next if (not $self->{TOKEN}->{$group}->{$name}->get_mode() !~ /^session$/i);
            $error = 1 if (not $self->{TOKEN}->{$group}->{$name}->logout());
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
    my $token_count = $self->{cache}->get_xpath_count (
                          XPATH    => 'token_config/token');
    for (my $i=0; $i<$token_count; $i++)
    {
        next if ($self->{cache}->get_xpath (
                      XPATH    => [ 'token_config/token', 'mode' ],
                      COUNTER  => [ $i, 0 ]) !~ /^daemon$/i);
        my $name = $self->{cache}->get_xpath (
                      XPATH    => [ 'token_config/token', 'name' ],
                      COUNTER  => [ $i, 0 ]);
        my $group = $self->{cache}->get_xpath (
                      XPATH    => [ 'token_config/token', 'ca_group' ],
                      COUNTER  => [ $i, 0 ]);
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_START_DAEMON_GET_TOKEN_FAILED",
            params  => {"NAME" => $name, "CA_GROUP" => $group})
            if (not $self->get_token(NAME => $name, CA_GROUP => $group));
    }
    return 1;
}

sub stop_daemon
{
    my $self = shift;
    my $error = 0;
    my $token_count = $self->{cache}->get_xpath_count (
                          XPATH    => 'token_config/token');
    for (my $i=0; $i<$token_count; $i++)
    {
        next if ($self->{cache}->get_xpath (
                      XPATH    => [ 'token_config/token', 'mode' ],
                      COUNTER  => [ $i, 0 ]) !~ /^daemon$/i);
        my $name = $self->{cache}->get_xpath (
                      XPATH    => [ 'token_config/token', 'name' ],
                      COUNTER  => [ $i, 0 ]);
        my $group = $self->{cache}->get_xpath (
                      XPATH    => [ 'token_config/token', 'ca_group' ],
                      COUNTER  => [ $i, 0 ]);
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_TOKENMANAGER_START_DAEMON_ADD_TOKEN_FAILED",
            params  => {"NAME" => $name, "CA_GROUP" => $group})
            if (not $self->add_token(NAME => $name, CA_GROUP => $group));
        $error = 1 if (not $self->{TOKEN}->{$group}->{$name}->logout());
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
    foreach my $group (keys %{$self->{TOKEN}})
    {
        next if (not defined $group or not length $group);
        foreach my $name (keys %{$self->{TOKEN}->{$group}})
        {
            next if (not $self->{TOKEN}->{$group}->{$name});
            next if (not $self->{TOKEN}->{$group}->{$name}->get_mode() =~ /^(session|daemon)$/i);
            $error = 1 if (not $self->{TOKEN}->{$group}->{$name}->logout());
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

=head1 Functions
