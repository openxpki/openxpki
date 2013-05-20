## OpenXPKI::Server::Authentication::ClientX509
##
## Written in 2007 by Alexander Klink
## (C) Copyright 2007 by The OpenXPKI Project

#FIXME-MIG: Need testing

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

    ##! 1: "start"
    
    my $path = shift;
    my $config = CTX('config');

    ##! 2: "load name and description for handler"
    $self->{DESC} = $config->get("$path.description");
    $self->{NAME} = $config->get("$path.label");
    
    $self->{ROLE} = $config->get("$path.role.default");    
    $self->{ROLEARG} = $config->get("$path.role.argument");
    
    if ($config->get("$path.role.handler")) {        
        my @path = split /\./, "$path.role.handler";
        $self->{ROLEHANDLER} = \@path;     
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

    my $x509;
    eval {
        $x509 = OpenXPKI::Crypto::X509->new(
            DATA  => $certificate,
            TOKEN => CTX('api')->get_default_token(),
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
    
    # FIXME - this makes only sense with known certificates, 
    # but we might want to use external cas as well
    
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
    if (DateTime->compare($now, OpenXPKI::DateTime::_parse_date_utc($notbefore)) == -1) {
        ##! 16: 'certificate is not yet valid'
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_CLIENT_X509_LOGIN_FAILED",
            params  => {
                USER => $username,
            },
        );
    }
    if (DateTime->compare($now, OpenXPKI::DateTime::_parse_date_utc($notafter)) == 1) {
        ##! 16: 'certificate is no longer valid'
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_CLIENT_X509_LOGIN_FAILED",
            params  => {
                USER => $username,
            },
        );
    }
          
            
    # Assign default role            
    my $role;    
    # Ask connector    
    if ($self->{ROLEHANDLER}) {               
        if ($self->{ROLEARG} eq "username") {
            $role = CTX('config')->get( [ $self->{ROLEHANDLER}, $username ]);
        } elsif ($self->{ROLEARG} eq "subject") {    
            $role = CTX('config')->get( [ $self->{ROLEHANDLER},  $x509->{PARSED}->{BODY}->{SUBJECT} ]);                    
        } elsif ($self->{ROLEARG} eq "serial") {
            $role = CTX('config')->get( [ $self->{ROLEHANDLER},  $x509->{PARSED}->{BODY}->{SERIAL} ]);            
        }
    }    
      
    $role = $self->{ROLE} unless($role);

    ##! 16: 'role: ' . $role
    if (!$role) {
        ##! 16: 'no certificate role found'
        return (undef, undef, {}); 
    }
    
    return ( $username, $role,
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

=head1 configuration
    
Signature:
    type: ClientX509
    label: External X509
    description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_SIGNATURE
    role:             
        handler: @auth.roledb
        argument: dn
        default: ''

=head2 parameters

=over

=item role.handler

A connector that returns a role for the given role argument. 

=item role.argument

Argument to use with hander to query for a role. Supported values are I<username> (as passed by the client), I<subject>, I<serial>

=item role.default

The default role to assign to a user if no result is found using the handler.
If you do not specify a handler but a default role, you get a static role assignment for any matching certificate.  

=back
