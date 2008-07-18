## OpenXPKI::Server::Authentication::Password.pm 
##
## Written 2006 by Michael Bell
## Updated to use new Service::Default semantics 2007 by Alexander Klink
## Updated to support seeded SHA1 and RFC 2307 password notatation 
##   2007 by Martin Bartosch
## (C) Copyright 2006, 2007 by The OpenXPKI Project

package OpenXPKI::Server::Authentication::Password;

use strict;
use warnings;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use Digest::SHA1;
use Digest::MD5;
use MIME::Base64;

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
                                        COUNTER => [ @{$keys->{COUNTER}}, 0 ],
                                        CONFIG_ID => $keys->{CONFIG_ID},
    );
    $self->{NAME} = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "name" ],
                                        COUNTER => [ @{$keys->{COUNTER}}, 0 ],
                                        CONFIG_ID => $keys->{CONFIG_ID},
    );

    ## load user database

    my $count = $config->get_xpath_count (XPATH   => [@{$keys->{XPATH}}, "user"],
                                          COUNTER => $keys->{COUNTER},
                                          CONFIG_ID => $keys->{CONFIG_ID},
    );
    for (my $i=0; $i<$count; $i++)
    {
        my $name      = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "user", "name" ],
                                            COUNTER => [ @{$keys->{COUNTER}}, $i, 0 ],
                                            CONFIG_ID => $keys->{CONFIG_ID},
        );
        my $encrypted = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "user", "digest" ],
                                            COUNTER => [ @{$keys->{COUNTER}}, $i, 0 ],
                                            CONFIG_ID => $keys->{CONFIG_ID},
        );
        my $role      = $config->get_xpath (XPATH   => [ @{$keys->{XPATH}},   "user", "role" ],
                                            COUNTER => [ @{$keys->{COUNTER}}, $i, 0 ],
                                            CONFIG_ID => $keys->{CONFIG_ID},
        );

	my $scheme;
	# digest specified in RFC 2307 userPassword notation?
	if ($encrypted =~ m{ \{ (\w+) \} (.*) }xms) {
	    ##! 8: "database uses RFC2307 password syntax"
	    $scheme = lc($1);
	    $encrypted = $2;
	}

	if (! defined $scheme) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_NEW_MISSING_SCHEME_SPECIFICATION",
		params  => {
		    USER => $name, 
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => 'system',
		},
		)
	}
	

        $self->{DATABASE}->{$name}->{ENCRYPTED} = $encrypted;
        $self->{DATABASE}->{$name}->{SCHEME}    = $scheme;
        $self->{DATABASE}->{$name}->{ROLE}      = $role;
        ##! 4: "scanned user ... "
        ##! 4: "    (name, encrypted, scheme, role) => "
        ##! 4: "    ($name, $encrypted, $scheme, $role)"

        if ($scheme !~ /^(sha1|sha|ssha|md5|smd5|crypt)$/)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_NEW_UNSUPPORTED_SCHEME",
                params  => {
		    USER => $name, 
		    SCHEME => $scheme,
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

        if (! exists $self->{DATABASE}->{$account}) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_PASSWORD_LOGIN_FAILED",
                params  => {
		    USER => $account,
		},
		);
        }
        my $encrypted = $self->{DATABASE}->{$account}->{ENCRYPTED};
        my $scheme    = $self->{DATABASE}->{$account}->{SCHEME};
        my $role      = $self->{DATABASE}->{$account}->{ROLE};
    
	my $computed_secret;
	if ($scheme eq 'sha') {
 	    my $ctx = Digest::SHA1->new();
 	    $ctx->add($passwd);
	    $computed_secret = $ctx->b64digest();
	}
	if ($scheme eq 'ssha') {
	    my $salt = substr(decode_base64($encrypted), 20);
 	    my $ctx = Digest::SHA1->new();
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
	    my $salt = substr(decode_base64($encrypted), 16);
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
            ##! 4: "mismatch with digest in database ($encrypted)"
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
Every user block in the configuration must include a name, digest and role.
The digest must have the format

{SCHEME}encrypted_string

SCHEME is one of sha (SHA1), md5 (MD5), crypt (Unix crypt(3)) or 
ssha (seeded SHA1).

=head2 login_step

returns a pair of (user, role, response_message) for a given login
step. If user and role are undefined, the login is not yet finished.

