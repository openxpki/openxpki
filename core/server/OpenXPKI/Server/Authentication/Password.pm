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

    ## check account - the handler config has a connector at .user
    # that returns password and role for a requested username

    my $user_info = CTX('config')->get_hash( [ @{$self->{PREFIX}}, $account ] );

    if (!$user_info) {
        ##! 4: "No such user: $account"
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED",
            params  => {
              USER => $account,
            },
        );
    }


    my $encrypted;
    my $scheme;

    # digest specified in RFC 2307 userPassword notation?
    if ($user_info->{digest} =~ m{ \{ (\w+) \} (.*) }xms) {
        ##! 8: "database uses RFC2307 password syntax"
        $scheme = lc($1);
        $encrypted = $2;
    }

    if (! defined $scheme) {
        OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_NEW_MISSING_SCHEME_SPECIFICATION",
        params  => {
            USER => $account,
        },
        log => {
            priority => 'fatal',
            facility => 'system',
        },
        )
    }

    if ($scheme !~ /^(sha|ssha|md5|smd5|crypt)$/) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_UNSUPPORTED_SCHEME",
            params  => {
                USER => $name,
                SCHEME => $scheme,
            },
            log => {
                priority => 'fatal',
                facility => 'system',
        });
    }

    my ($computed_secret, $salt);
    if ($scheme eq 'sha') {
         my $ctx = Digest::SHA->new();
         $ctx->add($passwd);
        $computed_secret = $ctx->b64digest();
    }
    if ($scheme eq 'ssha') {
        $salt = substr(decode_base64($encrypted), 20);
         my $ctx = Digest::SHA->new();
         $ctx->add($passwd);
        $ctx->add($salt);
        $computed_secret = encode_base64($ctx->digest() . $salt, '');
    }
    if ($scheme eq 'md5') {
         my $ctx = Digest::MD5->new();
         $ctx->add($passwd);
        $computed_secret = $ctx->b64digest();
    }
    if ($scheme eq 'smd5') {
        $salt = substr(decode_base64($encrypted), 16);
         my $ctx = Digest::MD5->new();
         $ctx->add($passwd);
        $ctx->add($salt);
        $computed_secret = encode_base64($ctx->digest() . $salt, '');
    }
    if ($scheme eq 'crypt') {
        $computed_secret = crypt($passwd, $encrypted);
    }

    if (! defined $computed_secret) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_UNSUPPORTED_SCHEME",
            params  => {
              USER => $account,
            },
        );
    }

    ##! 2: "ident user ::= $account and digest ::= $computed_secret"
    $computed_secret =~ s{ =+ \z }{}xms;
    $encrypted       =~ s{ =+ \z }{}xms;

    ## compare passphrases
    if ($computed_secret ne $encrypted) {
        ##! 4: "mismatch with digest in database ($encrypted, $salt)"
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED",
            params  => {
              USER => $account,
            },
        );
    }
    else { # hash is fine, return user, role, service ready message
        return ($account, $user_info->{role},
            {
                SERVICE_MSG => 'SERVICE_READY',
            },
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
Every user block in the configuration must include a name, digest and role.
The digest must have the format

{SCHEME}encrypted_string

SCHEME is one of sha (SHA1), md5 (MD5), crypt (Unix crypt), smd5 (salted
MD5) or ssha (salted SHA1).

=head2 login_step

returns a pair of (user, role, response_message) for a given login
step. If user and role are undefined, the login is not yet finished.

