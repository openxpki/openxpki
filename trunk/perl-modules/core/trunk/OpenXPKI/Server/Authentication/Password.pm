## OpenXPKI::Server::Authentication::Password.pm 
##
## Written 2006 by Michael Bell
## Updated to use new Service::Default semantics 2007 by Alexander Klink
## (C) Copyright 2006, 2007 by The OpenXPKI Project
## $Revision$

package OpenXPKI::Server::Authentication::Password;

use strict;
use warnings;

use OpenXPKI::Debug 'OpenXPKI::Server::Authentication::Password';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Digest::SHA1;
use Digest::MD5;

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = shift;
    ##! 1: "start"

    my $config = CTX('xml_config');

    ##! 2: "load name and description for handler"

    $self->{DESC} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "description" ],
                                        COUNTER => [ @{$keys->{COUNTER}}, 0 ]);
    $self->{NAME} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "name" ],
                                        COUNTER => [ @{$keys->{COUNTER}}, 0 ]);

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
        ##! 4: "scanned user ... "
        ##! 4: "    (name, digest, algorithm, role) => "
        ##! 4: "    ($name, $digest, $algorithm, $role)"
        if ($algorithm !~ /^(sha1|md5|crypt)$/)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_NEW_UNSUPPORTED_ALGORITHM",
                params  => {
		    USER => $name, 
		    ALGORITHM => $algorithm,
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => 'system',
		},
		);
        }
    }

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
    else {
        ##! 2: 'login data received'
        my $account = $msg->{PARAMS}->{LOGIN};
        my $passwd  = $msg->{PARAMS}->{PASSWD};

        ##! 2: "account ... $account"

        ## check account

        if (not exists $self->{DATABASE}->{$account}) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED",
                params  => {
		    USER => $account,
		},
		);
        }
        my $digest    = $self->{DATABASE}->{$account}->{DIGEST};
        my $algorithm = $self->{DATABASE}->{$account}->{ALGORITHM};
        my $role      = $self->{DATABASE}->{$account}->{ROLE};
    
        ## create comparable value
        my $hash = "";
        if ($algorithm eq "sha1") {
             my $sha1 = Digest::SHA1->new();
             $sha1->add($passwd);
             $hash = $sha1->b64digest();
             ## normalize digests
             $hash   =~ s/=*$//;
             $digest =~ s/=*$//;
        } elsif ($algorithm eq"md5") {
             my $md5 = Digest::MD5->new();
             $md5->add($passwd);
             $hash = $md5->b64digest();
        } elsif ($algorithm eq "crypt") {
             $hash = crypt ($passwd, $digest);
        }
    
        ##! 2: "ident user ::= $account and digest ::= $hash"
    
        ## compare passphrases
        if ($hash ne $digest) {
            ##! 4: "mismatch with digest in database ($digest)"
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED",
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
            ); 
        } 
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

is the constructor. The supported parameters are XPATH and COUNTER.
This is the minimum parameter set for any authentication class.
Every user block in the configuration must include a name, algorithm, digest and role.

=head2 login_step

returns a pair of (user, role, response_message) for a given login
step. If user and role are undefined, the login is not yet finished.

