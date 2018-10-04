## OpenXPKI::Server::Authentication::Connector
##
## Written 2013 by Oliver Welter, based on
## OpenXPKI::Server::Authentication::Password
## (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Server::Authentication::Connector;

use strict;
use warnings;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Moose;


has source => (
    is => 'ro',
    isa => 'ArrayRef',
);

has role => (
    is => 'ro',
    isa => 'Str|Undef',
);

has name => (
    is => 'ro',
    isa => 'Str',
    default => 'Connector',
);

has description => (
    is => 'ro',
    isa => 'Str',
    default => '',
);


around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;

    # path is passed as single argument
    my $path = shift;
    my $config = CTX('config');

    my @source = split /\./, $path;
    push @source, 'source';

    ##! 2: "load name and description for handler"
    return $class->$orig({
        description => $config->get("$path.description"),
        name => $config->get("$path.label"),
        role => $config->get("$path.role"),
        source => \@source,
    });

};


sub login_step {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $name    = $arg_ref->{HANDLER};
    my $msg     = $arg_ref->{MESSAGE};

    if (! exists $msg->{PARAMS}->{LOGIN} ||
        ! exists $msg->{PARAMS}->{PASSWD}) {
        ##! 4: 'no login data received (yet)'
        return (undef, undef,
            {
        SERVICE_MSG => "GET_PASSWD_LOGIN",
        PARAMS      => {
                    NAME        => $self->name(),
                    DESCRIPTION => $self->description(),
            },
            },
        );
    }


    ##! 2: 'login data received'
    my $account = $msg->{PARAMS}->{LOGIN};
    my $passwd  = $msg->{PARAMS}->{PASSWD};

    ##! 2: "account ... $account"

    # check account - password checking is done using an authentication
    # connector with password binding.

    my $result = CTX('config')->get( [ @{$self->source()}, $account ], { password =>  $passwd } );

    if (defined $result && ref $result ne '') {
        # this usually means a wrong connector definition
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_CONNECTOR_RETURN_NOT_SCALAR",
            params  => {
              SOURCE => $self->source(),
              ACCOUNT => $account,
            },
        );
    }

    if ($result) {
        # result ok - return user, role, service ready message
        CTX('log')->auth()->info("Login successful for user $account with role " . $self->role());

        return ($account, $self->role(), { SERVICE_MSG => 'SERVICE_READY', });
    }

    ##! 4: "Login failed for $account with result $result"
    CTX('log')->auth()->error("Login FAILED for user $account with role " . $self->role());
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED",
        params  => {
            USER => $account,
        },
    );
}


1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::Connector - passphrase based authentication
using connector backend.

=head1 Description

Replacement for OpenXPKI::Server::Authentication::Password which checks the
password aganist a connector backend using the password as bind parameter.

=head1 Configuration

Requires name, description as all other connectors. The connector just checks
the password, the role is static for all users and given as key I<role>.
The key I<source> must be a connector reference that supports the password
bind query syntax.
Suited connectors are e.g. Connector::Builtin::Authentication::*

    User Password:
        type: Connector
        label: User Password
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_PASSWORD
        role: User
        source@: connector:auth.connector.localuser


returns a pair of (user, role, response_message) for a given login
step. If user and role are undefined, the login is not yet finished.

