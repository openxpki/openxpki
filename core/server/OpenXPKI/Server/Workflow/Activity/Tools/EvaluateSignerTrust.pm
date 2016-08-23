package OpenXPKI::Server::Workflow::Activity::Tools::EvaluateSignerTrust;

use strict;
use warnings;

use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use English;

sub execute {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context = $workflow->context();
    my $config = CTX('config');
    #my $server = $context->param('server');
    
    # reset the context flags    
    $context->param('signer_trusted' => 0);    
    $context->param('signer_authorized' => 0);
    $context->param('signer_revoked' => 0);
    $context->param('signer_validity_ok' => 0);
    
    my $signer_cert = $context->param('signer_cert');
    
    if (!$signer_cert) {
        CTX('log')->log(
            MESSAGE => "Trusted Signer validation skipped, no certificate found", 
            PRIORITY => 'debug',
            FACILITY => ['application']
        );
        return 1;
    }

    my $default_token = CTX('api')->get_default_token();
    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA  => $signer_cert,        
        TOKEN => $default_token
    );       

    # Check if the certificate is valid       
    my $now = DateTime->now();
    my $notbefore = $x509->get_parsed('BODY', 'NOTBEFORE');
    my $notafter = $x509->get_parsed('BODY', 'NOTAFTER');

    if ( ( DateTime->compare( $notbefore, $now ) <= 0)  && ( DateTime->compare( $now,  $notafter) < 0) ) {
        $context->param('signer_validity_ok' => '1');
    } else {
        $context->param('signer_validity_ok' => '0');
    }
       
    # Check the chain
    my $signer_identifier = $x509->get_identifier();

    $context->param('signer_cert_identifier' => $signer_identifier);

    # Get realm and issuer for signer certificate
    my $cert_hash = CTX('dbi_backend')->first(
        TABLE    => 'CERTIFICATE',
        COLUMNS  => ['PKI_REALM', 'ISSUER_IDENTIFIER', 'CSR_SERIAL', 'STATUS' ],
        DYNAMIC  => { 'IDENTIFIER' => {VALUE => $signer_identifier }, }                            
    );
    
    my $signer_realm = $cert_hash->{'PKI_REALM'} || 'global';
    my $signer_issuer = $cert_hash->{'ISSUER_IDENTIFIER'};
    
    my $signer_req_key = $cert_hash->{'CSR_SERIAL'};
    
    # Get the profile of the certificate, if it was issued from this CA
    my $signer_profile = 'unknown';    
    if ($signer_req_key) { 
        my $csr_hash = CTX('dbi_backend')->first(
            TABLE    => 'CSR',        
            COLUMNS  => 'PROFILE',
            DYNAMIC  => { 'CSR_SERIAL' => {VALUE => $signer_req_key } }                            
        );
        $signer_profile = $csr_hash->{'PROFILE'} if ($csr_hash->{'PROFILE'});
    }
    
    ##! 32: 'Signer profile ' .$signer_profile
    ##! 32: 'Signer realm ' .  $signer_realm 
    ##! 32: 'Signer issuer ' . $signer_issuer   

    my $signer_root = '';
    if ($signer_issuer) {      
        my $signer_chain = CTX('api')->get_chain({
            'START_IDENTIFIER' => $signer_issuer,        
        });                                    
        if ($signer_chain->{COMPLETE}) {                        
            $signer_root = pop @{$signer_chain->{IDENTIFIERS}};             
        }
    }
    
    if ($cert_hash->{'STATUS'} ne 'ISSUED') {        
        CTX('log')->log(
            MESSAGE => "Trusted Signer certificate is revoked", 
            PRIORITY => 'info',
            FACILITY => ['application','audit']
        );
        $context->param('signer_revoked' => 1);
        
    } elsif ($signer_root) {
        
        $context->param('signer_trusted' => 1);
        
        CTX('log')->log(
            MESSAGE => "Trusted Signer chain validated - trusted root is $signer_root", 
            PRIORITY => 'info',
            FACILITY => ['application','audit']
        );
                
    } else {
        CTX('log')->log(
            MESSAGE => "Trusted Signer chain validation FAILED", 
            PRIORITY => 'info',
            FACILITY => ['application']
        );
    }

    # End chain validation, now check the authorization

    my $signer_subject = $x509->get_parsed('BODY', 'SUBJECT');
    ##! 32: 'Check signer '.$signer_subject.' against trustlist' 
    
    my $rules_prefix = $self->param('rules');    
    my @rules = $config->get_keys( $rules_prefix );
    
    my $matched = 0;
    my $current_realm = CTX('session')->get_pki_realm();
    
    CTX('log')->log(
        MESSAGE => "Trusted Signer Authorization $signer_profile / $signer_realm / $signer_subject / $signer_identifier",        
        PRIORITY => 'trace',
        FACILITY => 'application',
    );            
    
    TRUST_RULE:
    foreach my $rule (@rules) {
        ##! 32: 'Testing rule ' . $rule
        my $trustrule = $config->get_hash("$rules_prefix.$rule");
        $trustrule->{realm} = $current_realm if (!$trustrule->{realm});
        
        $matched = 0;
        foreach my $key (keys %{$trustrule}) {
            my $match = $trustrule->{$key};
            ##! 64: 'expected match ' . $key . '/' . $match
            if ($key eq 'subject') {            
                $matched = ($signer_subject =~ /^$match$/i);
                
            } elsif ($key eq 'identifier') {
                $matched = ($signer_identifier eq $match);
                  
            } elsif ($key eq 'realm') {
                $matched = ($signer_realm eq $match);
                
            } elsif ($key eq 'profile') {                                    
                $matched = ($signer_profile eq $match);
                                
            } else {                
                CTX('log')->log(
                    MESSAGE => "Trusted Signer Authorization unknown ruleset $key:$match",
                    PRIORITY => 'error',
                    FACILITY => 'system',
                );
                $matched = 0;
            }
            next TRUST_RULE if (!$matched);

            CTX('log')->log(
                MESSAGE => "Trusted Signer Authorization matched subrule $rule/$match",
                PRIORITY => 'debug',
                FACILITY => 'application',
            );            
            ##! 32: 'Matched ' . $match
        }
        
        if ($matched) {
            ##! 16: 'Passed validation rule #'.$rule,
            CTX('log')->log(
                MESSAGE => "Trusted Signer Authorization matched rule $rule",
                PRIORITY => 'info',
                FACILITY => 'application',
            );            
            $context->param('signer_authorized' => 1);
            return 1;
        }       
    }
     
    CTX('log')->log(
        MESSAGE => "Trusted Signer not found in trust list ($signer_subject).",
        PRIORITY => 'info',
        FACILITY => ['application','audit']
    );

    $context->param('signer_authorized' => 0);
    return 1;
}

1;

=head1 NAME

OpenXPKI::Server::Workflow::Activity::Tools::EvaluateSignerTrust

=head1 SYNOPSIS

    class: OpenXPKI::Server::Workflow::Activity::Tools::EvaluateSignerTrust
    param:
      _map_rules: scep.[% context.server %].authorized_signer_on_behalf

=head1 DESCRIPTION

Evaluate if the signer certificate can be trusted. Populates the result 
into several context items, all values are boolean.

=over

=item signer_trusted

true if the complete chain is available and certificate status is not 
revoked. Does B<NOT> check for expiration.

=item signer_authorized

true if the signer matches one of the given rules. This does B<NOT> depend
on the trust status of the certificate, so you need to check both flags or 
delegate the chain validation to another component (e.g. tls config of 
webserver). 

=item signer_validity_ok

true if the current date is within the notbefore/notafter window

=item signer_revoked

true if the certificate is marked revoked. 

=item signer_cert_identifier

the identifier of the signer certificate

=back 

=head1 Configuration

The check for authorization uses a list of rules below the path defined
by the rules parameter. E.g. for the SCEP workflow this is   
I<scep.[% context.server ].authorized_signer_on_behalf>. 
The list is a hash of hashes, were each entry is a combination of one or more 
matching rules. The name of the rule is just used for logging purpose:

  rule1:
    subject: CN=scep-signer.*,dc=OpenXPKI,dc=org
    identifier: AhElV5GzgFhKalmF_yQq-b1TnWg
    profile: I18N_OPENXPKI_PROFILE_SCEP_SIGNER
    realm: ca-one

The subject is evaluated as a regexp, therefore any characters with a 
special meaning in perl regexp need to be escaped! Identifier, profile and
realm are matched as is, realm is always the session realm if not set. 
The rules in one entry are ANDed together. If you want to provide 
alternatives, add multiple list items.


