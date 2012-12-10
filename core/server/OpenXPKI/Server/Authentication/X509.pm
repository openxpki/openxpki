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
use MIME::Base64;

use Data::Dumper;

## constructor and destructor stuff

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $path = shift;
    my $config = CTX('config');

    ##! 2: "load name and description for handler"

    $self->{DESC} = $config->get("$path.description");
    $self->{NAME} = $config->get("$path.label"); 
    $self->{CHALLENGE_LENGTH} = $config->get("$path.challenge_length");
    
    $self->{ROLE} = $config->get("$path.role.default");    
    $self->{ROLEARG} = $config->get("$path.role.argument");
    
    if ($config->get("$path.role.handler")) {        
        my @path = split /\./, "$path.role.handler";
        $self->{ROLEHANDLER} = \@path;     
    }
    

    my @trusted_realms = $config->get_scalar_as_list("$path.realm");
    my @trusted_certs = $config->get_scalar_as_list("$path.cacert");

    my @trust_anchors;   
    if (@trusted_certs) {
        @trust_anchors = @trusted_certs;
    }     
    
    foreach my $trust_realm (@trusted_realms) {
        ## FIXME-MIG - find all ca certs in that realm and add them        
        # Look up the group name used for the ca certificates in the given realm
        my $ca_group_name = CTX('config')->get("realm.$trust_realm.type.certsign");      
        if (!$ca_group_name) { next; }    
        my $ca_certs = CTX('api')->list_active_aliases({ GROUP => $ca_group_name, REALM => $trust_realm });        
        push @trust_anchors, map { $_->{IDENTIFIER} } $ca_certs;
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

    $self->{TRUST_ANCHORS} = \@trust_anchors;
       
    if (!$self->{CHALLENGE_LENGTH}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_MISSING_CHALLENGE_LENGTH_CONFIGURATION',            
        );
    }

    return $self;
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
        my $signer_subject;
        eval {
            $signer_subject = $pkcs7_token->command({
                COMMAND => 'get_subject',
                PKCS7   => $pkcs7,
                DATA    => $challenge,
            });
        };
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_COULD_NOT_DETERMINE_SIGNER_SUBJECT',
            );
        }
        ##! 16: 'signer subject: ' . $signer_subject
        my $default_token = CTX('api')->get_default_token();
        my @signer_chain = $default_token->command({
            COMMAND        => 'pkcs7_get_chain',
            PKCS7          => $pkcs7,
            SIGNER_SUBJECT => $signer_subject,
        });
        ##! 64: 'signer_chain: ' . Dumper \@signer_chain

        my $x509_signer = OpenXPKI::Crypto::X509->new(
            TOKEN => $default_token,
            DATA  => $signer_chain[0],
        );
        my $sig_identifier = $x509_signer->get_identifier();
                
        if (! defined $sig_identifier || $sig_identifier eq '') {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_COULD_NOT_DETERMINE_SIGNATURE_CERTIFICATE_IDENTIFIER',
            );
        }
        ##! 64: 'sig identifier: ' . $sig_identifier

        my @signer_chain_server;
        eval {
            @signer_chain_server = @{ CTX('api')->get_chain({
                START_IDENTIFIER => $sig_identifier,
            })->{IDENTIFIERS} };
        };
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_COULD_NOT_DETERMINE_SIGNATURE_CHAIN_FROM_SERVER',
                params  => {
                    EVAL_ERROR => $EVAL_ERROR,
                },
            );
        }
        ##! 64: 'signer_chain_server: ' . Dumper \@signer_chain_server
        my $anchor_found;
        my @trust_anchors = @{ $self->{TRUST_ANCHORS} };
      CHECK_CHAIN:
        foreach my $identifier (@signer_chain_server) {
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
                    'IDENTIFIER' => $sig_identifier,
                },
            );
        }

        # Get the signer cert from the DB (and check that it is valid now)
        my $cert_db = CTX('dbi_backend')->first(
            TABLE    => 'CERTIFICATE',
            DYNAMIC  => {
                'IDENTIFIER' => {VALUE => $sig_identifier},
                'STATUS'     => {VALUE => 'ISSUED'},
            },
            VALID_AT => time(),
        );
        if (! defined $cert_db) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_CERT_NOT_FOUND_IN_DB_OR_INVALID',
                params  => {
                    'IDENTIFIER' => $sig_identifier,
                },
            );
        } 
        my $user = $signer_subject;
            
        # Assign default role            
        my $role;    
        # Ask connector    
        if ($self->{ROLEHANDLER}) {               
            if ($self->{ROLEARG} eq "cn") {
                # FIXME - how to get that fastest?
            } elsif ($self->{ROLEARG} eq "subject") {    
                $role = CTX('config')->get( [ $self->{ROLEHANDLER},  $x509_signer->{PARSED}->{BODY}->{SUBJECT} ]);                    
            } elsif ($self->{ROLEARG} eq "serial") {
                $role = CTX('config')->get( [ $self->{ROLEHANDLER},  $x509_signer->{PARSED}->{BODY}->{SERIAL} ]);            
            }
        }    
        
        $role = $self->{ROLE} unless($role);
        
        ##! 16: 'role: ' . $role
        if (!defined $role) {
            ##! 16: 'no certificate role found'
            return (undef, undef, {}); 
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