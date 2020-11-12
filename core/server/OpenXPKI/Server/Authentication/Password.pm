## OpenXPKI::Server::Authentication::Password.pm
##
## Written 2006 by Michael Bell
## Updated to use new Service::Default semantics 2007 by Alexander Klink
## Updated to support seeded SHA1 and RFC 2307 password notatation
##   2007 by Martin Bartosch
# Refactored for connector syntax 2012 by Oliver Welter
## (C) Copyright 2006 to 2012 by The OpenXPKI Project

package OpenXPKI::Server::Authentication::Password;

use strict;
use warnings;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Password;

use Digest::SHA;
use Digest::MD5;
use MIME::Base64;

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $path = shift;
    my $config = CTX('config');

    ##! 2: "load name and description for handler"

    my @path = split /\./, $path;
    push @path, 'user';
    $self->{PREFIX} = \@path;
    $self->{DESC} = $config->get("$path.description");
    $self->{NAME} = $config->get("$path.label");
    $self->{ROLE} = $config->get("$path.role");

    return $self;
}

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
                    NAME        => $self->{NAME},
                    DESCRIPTION => $self->{DESC},
            },
            },
        );
    }


    ##! 2: 'login data received'
    my $account = $msg->{PARAMS}->{LOGIN};
    my $passwd  = $msg->{PARAMS}->{PASSWD};

    ##! 2: "account ... $account"

    my ($digest, $role);

    # check account - the handler config has a connector at .user
    # that returns password or password and role for a requested username

    my $userinfo;
    if (!$self->{ROLE}) {
        $userinfo = CTX('config')->get_hash( [ @{$self->{PREFIX}}, $account ] );
        $digest = $userinfo->{digest} || '';
        delete $userinfo->{digest};
        $role = $userinfo->{role} || '';
        delete $userinfo->{role};
    } else {
        $digest = CTX('config')->get( [ @{$self->{PREFIX}}, $account ] );
        $role =  $self->{ROLE};
    }

    OpenXPKI::Exception->throw (
        message => "User not found",
        params  => {
          USER => $account,
        },
    ) unless($digest);

    OpenXPKI::Exception->throw (
        message => "No role returned for user",
        params  => {
          USER => $account,
        }
    ) unless($role);




    ## compare passphrases
    if (!OpenXPKI::Password::check($passwd,$digest)) {
        ##! 4: "mismatch with digest in database ($encrypted, $salt)"
        OpenXPKI::Exception->throw (
            message => "Provided password does not match",
            params  => {
              USER => $account,
            },
        );
    }
    else { # hash is fine, return user, role, service ready message
        return ($account, $role,
            {
                SERVICE_MSG => 'SERVICE_READY',
            },
            $userinfo
        );

    }
    return (undef, undef, {});
}


1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::Password - passphrase based authentication.

=head1 Description

This is the class which supports OpenXPKI with an internal passphrase based
authentication method. The parameters are passed as a hash reference.

=head1 Functions

=head2 new

is the constructor. It requires the config prefix as single argument.
This is the minimum parameter set for any authentication class.

When no I<role> is set in the configuration, the configuration must return
a hash for each user holding I<digest> and I<role>, any additonal fields of
the hash are returned as I<userinfo>.

The digest must have the format: C<{SCHEME}encrypted_string>

SCHEME is one of sha (SHA1), md5 (MD5), crypt (Unix crypt), smd5 (salted
MD5) or ssha (salted SHA1).

If you add the I<role> parameter to the config, the configuration must return
a scalar value for each username representing the digest.

=head2 login_step

returns a pair of (user, role, response_message) for a given login
step. If user and role are undefined, the login is not yet finished.

