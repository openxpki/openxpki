## OpenXPKI::Server::Authentication::X509.pm 
##
## Written 2006 by Michael Bell
## Rewritten 2007 by Alexander Klink for the OpenXPKI Project
## (C) Copyright 2006, 2007 by The OpenXPKI Project
package OpenXPKI::Server::Authentication::X509;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::X509;
use MIME::Base64;

use Moose;

use Data::Dumper;

has path => (
    is => 'ro',
    isa => 'Str',
);

has trust_certs => (
    is => 'rw',
    isa => 'ArrayRef',
);

has trust_realms => (
    is => 'rw',
    isa => 'ArrayRef',
);

has trust_anchors => (
    is => 'rw',
    isa => 'ArrayRef',
    builder => '_load_anchors',
    lazy => 1
);


## constructor and destructor stuff

around BUILDARGS => sub {
     
    my $orig = shift;
    my $class = shift;
    
    my $path = shift;
    
    return $class->$orig({ path => $path });
    
};


sub BUILD {
    
    my $self = shift;
      
    my $path = $self->path();
    ##! 2: "load name and description for handler"
    
    my $config = CTX('config');

    my @trust_certs =  $config->get_scalar_as_list("$path.cacert");
    my @trust_realms = $config->get_scalar_as_list("$path.realm");
    
    ##! 8: 'Config Path: ' . $path
    ##! 8: 'Trusted Certs ' . Dumper @trust_certs
    ##! 8: 'Trusted Realm ' . Dumper @trust_realms
       
    $self->trust_certs ( \@trust_certs );
    $self->trust_realms ( \@trust_realms );

    $self->{DESC} = $config->get("$path.description");
    $self->{NAME} = $config->get("$path.label"); 
    $self->{CHALLENGE_LENGTH} = $config->get("$path.challenge_length");
    
    $self->{ROLE} = $config->get("$path.role.default");    
    $self->{ROLEARG} = $config->get("$path.role.argument");
    
    if ($config->get("$path.role.handler")) {        
        my @path = split /\./, "$path.role.handler";
        $self->{ROLEHANDLER} = \@path;     
    }
         
    if (!$self->{CHALLENGE_LENGTH}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_MISSING_CHALLENGE_LENGTH_CONFIGURATION',            
        );
    }

}

sub _load_anchors {
	
	my $self = shift;
	
    my $trusted_realms = $self->trust_realms();
    my $trusted_certs = $self->trust_certs();

    ##! 8: 'Trusted Certs ' . Dumper $trusted_certs
    ##! 8: 'Trusted Realm ' . Dumper $trusted_realms

    my @trust_anchors;   
    
    @trust_anchors = @{$trusted_certs} if ($trusted_certs);

    foreach my $trust_realm (@{$trusted_realms}) {
        # Look up the group name used for the ca certificates in the given realm
        ##! 16: 'Load ca signers from realm ' . $trust_realm
        my $ca_group_name = CTX('config')->get("realm.$trust_realm.crypto.type.certsign");      
        if (!$ca_group_name) { next; } # Realm is not setup as CA   
        ##! 16: 'ca group name is ' . $ca_group_name 
        my $ca_certs = CTX('api')->list_active_aliases({ GROUP => $ca_group_name, REALM => $trust_realm });
        ##! 16: 'ca cert in realm ' . Dumper $ca_certs
        if (!$ca_certs) { next; }        
        push @trust_anchors, map { $_->{IDENTIFIER} } @{$ca_certs};
    }
    
    if (! scalar @trust_anchors ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_MISSING_TRUST_ANCHOR_CONFIGURATION',
            params => {
                PKI_REALM => CTX('session')->get_pki_realm() 
            }
        );
   }
        
    ##! 16: 'trust_anchors: ' . Dumper \@trust_anchors
    return \@trust_anchors;
    	
}

sub login_step {
    ##! 1: 'start' 
    my $self    = shift;
    my $arg_ref = shift;
 
    my $name    = $arg_ref->{HANDLER};
    my $msg     = $arg_ref->{MESSAGE};

    if (! exists $msg->{PARAMS}->{CHALLENGE} ||
        ! exists $msg->{PARAMS}->{SIGNATURE}) {
        ##! 4: 'no login data received (yet)' 
        # The challenge is just the session ID, so we do not have to
        # remember the challenge (which could only be done in the
        # session anyways as people might talk to different servers
        # in different login steps) ...
        my $challenge = CTX('session')->get_id();
        ##! 64: 'challenge: ' . $challenge
        # save the pending challenge to check later that we
        # received a valid challenge

        return (undef, undef, 
            {
		SERVICE_MSG => "GET_X509_LOGIN",
		PARAMS      => {
                    NAME        => $self->{NAME},
                    DESCRIPTION => $self->{DESC},
                    CHALLENGE   => $challenge,
	        },
            },
        );
    }
    else {
        ##! 2: 'login data / signature received'
        my $challenge = $msg->{PARAMS}->{CHALLENGE};
        my $signature = $msg->{PARAMS}->{SIGNATURE};
        my $pki_realm = CTX('session')->get_pki_realm();

        if ($signature !~ m{ \A .* \n \z }xms) {
            # signature does not end with \n, add it
            $signature .= "\n";
        }
        ##! 64: 'challenge: ' . $challenge
        ##! 64: 'signature: ' . $signature

        if ($challenge ne CTX('session')->get_id()) {
            # the sent challenge is not for this session ID
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_CHALLENGE_DOES_NOT_MATCH_SESSION_ID',
                params  => {
                    CHALLENGE  => $challenge,
                    SESSION_ID => CTX('session')->get_id(),
                },
            );
        }
        if (! $signature =~ m{ \A [a-zA-Z\+/=]+ \z }xms) {
            # the sent signature is not in Base64 format
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_SIGNATURE_IS_NOT_BASE64',
            );
        }
        my $pkcs7 =
              '-----BEGIN PKCS7-----' . "\n"
            . $signature
            . '-----END PKCS7-----';
        my $pkcs7_token = CTX('crypto_layer')->get_system_token({ TYPE => "PKCS7" });
          
        ##! 64: ' Signature blob: ' . $pkcs7
        ##! 64: ' Challenge: ' . $challenge          
            
        eval {
            $pkcs7_token->command({
                COMMAND => 'verify',
                PKCS7   => $pkcs7,
                DATA    => $challenge,
            });
        };
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_INVALID_SIGNATURE',
            );
        }
        ##! 16: 'signature valid'
        
        my $default_token = CTX('api')->get_default_token();
        
        # Looks like firefox adds \r to the p7
        $pkcs7 =~ s/\r//g;
        my $validate = CTX('api')->validate_certificate({
        	PKCS7 => $pkcs7,        	        	
        });
        
        ##! 32: 'validation result ' . Dumper $validate
        if ($validate->{STATUS}  ne 'VALID') {
        	OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_SIGNER_CERT_NOT_VALID',
                params  => {
                    'STATUS' => $validate->{STATUS}
                },
            );
        } 
        
        my $x509_signer = OpenXPKI::Crypto::X509->new( DATA => $validate->{CHAIN}->[0], TOKEN => $default_token );         
        my $signer_subject = $x509_signer->get_parsed('BODY','SUBJECT');
               
        ##! 32: 'signer cert pem: ' . $signer_subject 
        
        
        ##! 64: 'signer_chain_server: ' . Dumper $validate->{CHAIN}
        my $anchor_found;
        my @trust_anchors = @{$self->trust_anchors()};
        my @signer_chain_server = @{$validate->{CHAIN}};
        
      CHECK_CHAIN:
        foreach my $pem (@signer_chain_server) {
        	
        	my $x509 = OpenXPKI::Crypto::X509->new( DATA => $pem, TOKEN => $default_token ); 
        	my $identifier = $x509->get_identifier();        	
            ##! 16: 'identifier: ' . $identifier
            if (grep {$identifier eq $_} @trust_anchors) {
                $anchor_found = 1;
                last CHECK_CHAIN;
            }
        }
        if (! defined $anchor_found) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_UNTRUSTED_CERTIFICATE',
                params  => {
                    'IDENTIFIER' => $x509_signer->get_identifier(),
                },
            );
        }
        
        ##! 16: ' Signer Subject ' . $signer_subject  
        my $dn = OpenXPKI::DN->new( $signer_subject );

        ##! 32: 'dn hash ' . Dumper $dn;
        my %dn_hash = $dn->get_hashed_content();
        ##! 16: 'dn hash ' . Dumper %dn_hash;
                        
        # in the unusual case that there is no dn we use the full subject
        my $user = $signer_subject;
        $user = $dn_hash{'CN'}[0] if ($dn_hash{'CN'});
            
        # Assign default role            
        my $role;    
        # Ask connector    
        ##! 16: 'Rolehandler ' . Dumper $self->{ROLEHANDLER} 
        if ($self->{ROLEHANDLER}) {               
            if ($self->{ROLEARG} eq "cn") {
            	$role = CTX('config')->get( [ $self->{ROLEHANDLER},  $user ]); 
            } elsif ($self->{ROLEARG} eq "subject") {    
                $role = CTX('config')->get( [ $self->{ROLEHANDLER},  $x509_signer->{PARSED}->{BODY}->{SUBJECT} ]);                    
            } elsif ($self->{ROLEARG} eq "serial") {
                $role = CTX('config')->get( [ $self->{ROLEHANDLER},  $x509_signer->{PARSED}->{BODY}->{SERIAL} ]);            
            } else {
            	OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_CERT_UNKNOWN_ROLE_HANDLER_ARGUMENT',
                    params  => {
                        'ARGUMENT' => $self->{ROLEARG},
                    },
                    log => {
                        PRIORTITY => 'error',
                        FACILITY => 'system',                        
                    }
                );
            }
        }    
        
        $role = $self->{ROLE} unless($role);
        
        ##! 16: 'role: ' . $role
        if (!$role) {
            ##! 16: 'no certificate role found'
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_LOGIN_FAILED",
                params  => {
                    USER => $signer_subject,
                    REASON => 'no role'
            });            
        }
              

        return ($user, $role,
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

OpenXPKI::Server::Authentication::X509 - certificate based authentication.

=head1 Description

This is the class which supports OpenXPKI with a signature based
authentication method. The parameters are passed as a hash reference.

=head1 Functions

=head2 new

is the constructor. It requires the config prefix as single argument.
This is the minimum parameter set for any authentication class.

=head2 login_step

returns a pair of (user, role, response_message) for a given login
step. If user and role are undefined, the login is not yet finished.

=head1 configuration
    
Signature:
    type: X509
    label: Signature
    description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_SIGNATURE
    challenge_length: 256
    role:             
        handler: @auth.roledb
        argument: dn
        default: ''
    # trust anchors
    realm:
    - my_client_auth_realm
    cacert:
    - cert_identifier of external ca cert

=head2 parameters

=over

=item challenge_length

Length of the random challenge in bytes

=item role.handler

A connector that returns a role for a give user 

=item role.argument

Argument to use with hander to query for a role. Supported values are I<cn> (common name), I<subject>, I<serial>

=item role.default

The default role to assign to a user if no result is found using the handler.
If you do not specify a handler but a default role, you get a static role assignment for any matching certificate.  

=item cacert

A list of certificate identifiers to be used as trust anchors

=item realm

A list of realm names to be used as trust anchors (this loads all ca certificates from the given realm into the list of trusted ca certs).

=back