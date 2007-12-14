## OpenXPKI::Server::Authentication::ClientX509
##
## Written in 2007 by Alexander Klink
## (C) Copyright 2007 by The OpenXPKI Project

package OpenXPKI::Server::Authentication::ClientX509;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::X509;

use DateTime;
use Data::Dumper;

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

    ##! 2: "load allowed roles"
    my $nr_of_roles = $config->get_xpath_count(
        XPATH     => [ @{ $keys->{XPATH} }, 'allowed_role' ],
        COUNTER   => [ @{ $keys->{COUNTER} } ],
        CONFIG_ID => $keys->{CONFIG_ID},
    );
    ##! 16: 'nr_of_roles: ' . $nr_of_roles
    $self->{ROLES} = [];
    for (my $i = 0; $i < $nr_of_roles; $i++) {
        $self->{ROLES}->[$i] = $config->get_xpath(
            XPATH     => [ @{ $keys->{XPATH} }  , 'allowed_role' ],
            COUNTER   => [ @{ $keys->{COUNTER} }, $i             ],
            CONFIG_ID => $keys->{CONFIG_ID},
        );
        ##! 16: 'allowed role: ' . $self->{ROLES}->[$i]
    }
    ##! 2: "finished"

    return $self;
}

sub login_step {
    ##! 1: 'start' 
    my $self    = shift;
    my $arg_ref = shift;
 
    my $name    = $arg_ref->{HANDLER};
    my $msg     = $arg_ref->{MESSAGE};
    my $answer  = $msg->{PARAMS};

    if (! exists $msg->{PARAMS}->{LOGIN}) {
        ##! 4: 'no login data received (yet)' 
        return (undef, undef, 
            {
		SERVICE_MSG => "GET_CLIENT_X509_LOGIN",
		PARAMS      => {
                    NAME        => $self->{NAME},
                    DESCRIPTION => $self->{DESC},
	        },
            },
        );
    }

    my ($username, $certificate) = ($answer->{LOGIN}, $answer->{CERTIFICATE});

    ##! 2: "credentials ... present"
    ##! 2: "username: $username"
    ##! 2: "certificate: $certificate"

    my $realm = CTX('session')->get_pki_realm();

    my $x509;
    eval {
        $x509 = OpenXPKI::Crypto::X509->new(
            DATA  => $certificate,
            TOKEN => CTX('pki_realm')->{$realm}->{crypto}->{default},
        );
    };
    if (! defined $x509) {
        ##! 16: 'x509 not defined'
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_CLIENT_X509_LOGIN_FAILED",
            params  => {
                USER => $username,
            },
        );
    }
    my $identifier = $x509->get_identifier();
    ##! 16: 'identifier: ' . $identifier

    my $cert_info = CTX('api')->get_cert({
        IDENTIFIER => $identifier,
    });
    ##! 16: 'cert_info: ' . Dumper $cert_info
    if (! defined $cert_info) {
        ##! 16: 'get_cert failed'
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_CLIENT_X509_LOGIN_FAILED",
            params  => {
                USER => $username,
            },
        );
    }
    if ($cert_info->{STATUS} ne 'ISSUED') {
        ##! 16: 'status is not ISSUED'
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_CLIENT_X509_LOGIN_FAILED",
            params  => {
                USER => $username,
            },
        );
    }
    my $notbefore = $cert_info->{BODY}->{NOTBEFORE};
    my $notafter  = $cert_info->{BODY}->{NOTAFTER};
    my $now = DateTime->now();
    if (DateTime->compare($now, $notbefore) == -1) {
        ##! 16: 'certificate is not yet valid'
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_CLIENT_X509_LOGIN_FAILED",
            params  => {
                USER => $username,
            },
        );
    }
    if (DateTime->compare($now, $notafter) == 1) {
        ##! 16: 'certificate is no longer valid'
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_CLIENT_X509_LOGIN_FAILED",
            params  => {
                USER => $username,
            },
        );
    }

    my $role = $cert_info->{ROLE};
    ##! 16: 'role: ' . $role
    if (! grep {$_ eq $role} @{ $self->{ROLES} }) {
        ##! 16: 'certificate role is not acceptable'
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_CLIENT_X509_LOGIN_FAILED",
            params  => {
                USER => $username,
            },
        );
    }
    $self->{ROLE} = $role;
    $self->{USER} = $username;

    return (
        $self->{USER},
        $self->{ROLE},
        {
            SERVICE_MSG => 'SERVICE_READY',
        },
    );
}

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::ClientX509 - support for client based X509 authentication.

=head1 Description


=head1 Functions

=head2 new

the constructor reads the acceptable roles from the configuration

=head2 login_step

returns (user, role, service ready message) triple if login was
successful, (undef, undef, {}) otherwise. The message which
is supplied as a parameter to the function should contain both a
LOGIN and a CERTIFICATE parameter.
The certificate should be the PEM-encoded client certificate.
In a typical Apache setting, this is $ENV{'SSL_CLIENT_CERT'} if
the +ExportCertData SSLOption is set.
The certificate is checked for validity at login, the certificate
role is read from the database and compared to the list of acceptable
roles from the configuration.
