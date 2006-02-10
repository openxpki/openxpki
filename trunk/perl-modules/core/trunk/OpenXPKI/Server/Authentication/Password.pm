## OpenXPKI::Server::Authentication::Password.pm 
##
## Written by Michael Bell 2006
## Copyright (C) 2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;

package OpenXPKI::Server::Authentication::Password;

use OpenXPKI qw(debug);
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Digest::SHA1;
use Digest::MD5;

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
                DEBUG     => 0,
               };

    bless $self, $class;

    my $keys = shift;
    $self->{DEBUG} = 1 if ($keys->{DEBUG});
    $self->debug ("start");

    my $config = CTX('xml_config');

    ## load user database

    my $count = $config->get_xpath_count (XPATH   => [@{$keys->{XPATH}}, "user"],
                                          COUNTER => $keys->{COUNTER});
    for (my $i=0; $i<$count; $i++)
    {
        my $name      = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "user", "name" ],
                                            COUNTER => [ @{$keys->{COUNTER}}, $i, 0 ]);
        my $digest    = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "user", "digest" ],
                                            COUNTER => [ @{$keys->{COUNTER}}, $i, 0 ]);
        my $algorithm = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "user", "algorithm" ],
                                            COUNTER => [ @{$keys->{COUNTER}}, $i, 0 ]);
        my $role      = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "user", "role" ],
                                            COUNTER => [ @{$keys->{COUNTER}}, $i, 0 ]);
        $self->{DATABASE}->{$name}->{DIGEST}    = $digest;
        $self->{DATABASE}->{$name}->{ALGORITHM} = lc $algorithm;
        $self->{DATABASE}->{$name}->{ROLE}      = $role;
        $self->debug ("scanned user ... ".
                      "(name, digest, algorithm, role) => ".
                      "($name, $digest, $algorithm, $role)");
        if ($algorithm !~ /^(sha1|md5|crypt)$/)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_NEW_UNSUPPORTED_ALGORITHM",
                params  => {USER => $name, ALGORITHM => $algorithm});
        }
    }

    return $self;
}

sub login
{
    my $self = shift;
    $self->debug ("start");
    my $name = shift;
    my $gui  = CTX('gui');

    my ($account, $passwd) = $gui->get_passwd_login ($name);

    $self->debug ("credentials ... present");
    $self->debug ("account ... $account");

    ## check account

    if (not exists $self->{DATABASE}->{$account})
    {
        CTX('log')->log (FACILITY => "auth",
                         PRIORITY => "warn",
                         MESSAGE  => "Login to internal database failed (unknown user).\n".
                                     "user::=$account\n".
                                     "logintype::=Password");
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED",
            params  => {USER => $account});
    }
    my $digest    = $self->{DATABASE}->{$account}->{DIGEST};
    my $algorithm = $self->{DATABASE}->{$account}->{ALGORITHM};
    my $role      = $self->{DATABASE}->{$account}->{ROLE};

    ## create comparable value
    my $hash = "";
    if ($algorithm eq "sha1")
    {
         my $ref = Digest::SHA1->new();
         $ref->add($passwd);
         $hash = $ref->b64digest();
         ## normalize digests
         $hash   =~ s/=*$//;
         $digest =~ s/=*$//;
    } elsif ($algorithm eq"md5") {
         my $ref = Digest::MD5->new();
         $ref->add($passwd);
         $hash = $ref->b64digest();
    } elsif ($algorithm eq "crypt") {
         $hash = crypt ($passwd, $digest);
    }

    $self->debug ("ident user ::= $account and digest ::= $hash");

    ## compare passphrases
    if ($hash ne $digest) {
        $self->debug ("mismatch with digest in database ($digest)");
        CTX('log')->log (FACILITY => "auth",
                         PRIORITY => "warn",
                         MESSAGE  => "Login to internal database failed (wrong passphrase).\n".
                                     "user::=$account\n".
                                     "logintype::=Password");
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED",
            params  => {USER => $account});
    }

    ## accept login
    $self->{USER} = $account;

    return 1;
}

sub get_user
{
    my $self = shift;
    $self->debug ("start");
    return $self->{USER};
}

sub get_role
{
    my $self = shift;
    $self->debug ("start");
    return $self->{DATABASE}->{$self->{USER}}->{ROLE};
}

1;
__END__

=head1 Description

This is the class which supports OpenXPKI with an internal passphrase based
authentication method. The parameters are passed as a hash reference.

=head1 Functions

=head2 new

is the constructor. The supported parameters are DEBUG, XPATH and COUNTER.
This is the minimum parameter set for any authentication class.
Every user block in the configuration must include a name, algorithm, digest and role.

=head2 login

returns true if the login was successful.

=head2 get_user

returns the user which logged in successful.

=head2 get_role

returns the role from the user database.
