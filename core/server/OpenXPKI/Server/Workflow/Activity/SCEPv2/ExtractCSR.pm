# OpenXPKI::Server::Workflow::Activity::SCEPv2::ExtractCSR
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::ExtractCSR;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $pki_realm  = CTX('session')->get_pki_realm();
    my $cfg_id     = $self->config_id();


    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $context   = $workflow->context();
    my $config = CTX('config'); 
    
    my $server    = $context->param('server');

    my $pkcs10 = $context->param('pkcs10');
     
    my $default_token = CTX('api')->get_default_token();

    # extract subject from CSR and add a context entry for it
    my $csr_obj = OpenXPKI::Crypto::CSR->new(
        DATA  => $pkcs10,
        TOKEN => $default_token
    );
        
    my $csr_body = $csr_obj->get_parsed_ref()->{BODY};
    ##! 32: 'csr_parsed: ' . Dumper $csr_body
    
    
    my $csr_subject = $csr_body->{'SUBJECT'};
    my $csr_key_size = $csr_body->{KEYSIZE};
    $context->param('cert_subject' => $csr_subject);
    $context->param('csr_type'    => 'pkcs10');
    $context->param('csr_key_size' => $csr_key_size );
    
    # Check the key size against allowed ones
    
    my @key_size = $config->get_scalar_as_list("scep.$server.key_size");
    if ($key_size[0]) {
        if (grep /^$csr_key_size$/, @key_size ) {
        	##! 16: 'keysize ok'               
            $context->param('csr_key_size_ok' => 1 );        	
        } else {
	    	##! 16: 'wrong keysize'
	        $context->param('csr_key_size_ok' => 0 );
	        CTX('log')->log(
	            MESSAGE => "SCEP csr has wrong key size", 
	            PRIORITY => 'info',
	            FACILITY => 'system',
	        );
        }        	    
    } else {
        ##! 16: 'keysize definition missing'    	
    	CTX('log')->log(
            MESSAGE => "SCEP csr key size check - keysize not defined", 
            PRIORITY => 'error',
            FACILITY => 'system',
        );
    }
    
    
    # Extract the SAN from the PKCS#10       
    my @subject_alt_names = $csr_obj->get_subject_alt_names();
    ##! 64: 'subject_alt_names: ' . Dumper(\@subject_alt_names)    
    $context->param('cert_subject_alt_name' =>
                    $serializer->serialize(\@subject_alt_names));

    # Fetch the sources hash from the context and extend it 
    my $sources = $serializer->deserialize( $context->param('sources') );
    $sources->{'cert_subject'} = 'SCEP';
    $sources->{'cert_subject_alt_name_parts'}  = 'SCEP';   
    $context->param('sources' => $serializer->serialize($sources));

    # Test for the embeded Profile name at OID 1.3.6.1.4.1.311.20.2 
    
    # This is either empty or an array ref with the BitString
    my $csr_extensions = $csr_body->{OPENSSL_EXTENSIONS}->{'1.3.6.1.4.1.311.20.2'};    
    
    ##! 32: ' Ext  ' . Dumper $csr_extensions
    
    if ($csr_extensions && ref $csr_extensions eq 'ARRAY') {
        my $cert_extension_name = $csr_extensions->[0];
        # it looks like as the XS Parser already converts the the BMPString to 
        # a readable representation, so we just parse the chars out        
        $cert_extension_name =~ s/^\.\.//; # Leading Byte
        # FIXME - I dont have any idea what chars are possible within parsed bmpstring 
        # so this probably chokes on some strings! 
        $cert_extension_name =~ s/(\.(.))/$2/g;
        $context->param('cert_extension_name' => $cert_extension_name);

        # Check if the extension has a profile mapping, defined in scep.<server>.profile_map        
        my $profile = $config->get("scep.$server.profile_map.$cert_extension_name");
        if ($profile) {
  	        # Move old profile name for reference
            $context->param('cert_profile_default' => $context->param('cert_profile') );       
            $context->param('cert_profile' => $profile );            
            CTX('log')->log(
	            MESSAGE => "SCEP found Microsoft Certificate Name Extension: $cert_extension_name, mapped to $profile", 
	            PRIORITY => 'info',
	            FACILITY => 'system',
	        );        
        } else {
        	CTX('log')->log(
                MESSAGE => "SCEP found Microsoft Certificate Name Extension: $cert_extension_name, ignored - no matching profile", 
                PRIORITY => 'error',
                FACILITY => 'system',
            );
        }
    }


   
   
    my $challenge = $csr_body->{'CHALLENGEPASSWORD'};
    if ($challenge) {
        ##! 32: 'challenge: ' . Dumper $challenge
        $context->param('_challenge_password' => $challenge);
        CTX('log')->log(
            MESSAGE => "SCEP challenge password present on CSR subject: " . $context->param('cert_subject'),
            PRIORITY => 'info',
            FACILITY => ['audit','system'],
        );       
    }   

    my $signer_cert = $context->param('signer_cert'); 
    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA  => $signer_cert,        
        TOKEN => $default_token
    );

    ##! 32: 'signer x509: ' . Dumper $x509    
    my $now = DateTime->now();
    my $notbefore = $x509->get_parsed('BODY', 'NOTBEFORE');
    my $notafter = $x509->get_parsed('BODY', 'NOTAFTER');
        
    if ( ( DateTime->compare( $notbefore, $now ) <= 0)  && ( DateTime->compare( $now,  $notafter) < 0) ) {
        $context->param('signer_validity_ok' => '1');
    } else {
        $context->param('signer_validity_ok' => '0');
    }
    
    
    ##! 32: 'signer cert_identifier: ' . $x509->get_identifier()
    
    my $signer_subject = $x509->get_parsed('BODY', 'SUBJECT');
    my $signer_issuer = $x509->get_parsed('BODY', 'ISSUER');
    my $signer_identifier = $x509->get_identifier();
               
    # Check if revoked in the database                
    
    my $signer_hash = CTX('dbi_backend')->first (
        TABLE => 'CERTIFICATE',
        DYNAMIC => {
            IDENTIFIER => $signer_identifier,
        },
        'COLUMNS' => ['STATUS','NOTAFTER']
    );    
    if ($signer_hash) {                
        if ($signer_hash->{STATUS} eq 'REVOKED') {
            $context->param('signer_status_revoked' => '1');
             CTX('log')->log(
                MESSAGE => "SCEP signer certificate revoked; CSR subject: " . $context->param('cert_subject') .", Signer $signer_subject",
                PRIORITY => 'info',
                FACILITY => 'audit',
            );
        } else {
            $context->param('signer_status_revoked' => '0');
            CTX('log')->log(
                MESSAGE => "SCEP signer certificate valid; CSR subject: " . $context->param('cert_subject') .", Signer $signer_subject",
                PRIORITY => 'info',
                FACILITY => 'audit',
            );            
        }
        $context->param('signer_cert_identifier' => $signer_hash->{IDENTIFIER});
    } else {
        $context->param('signer_status_revoked' => '0');
    }
    
    ##! 64: 'signer issuer: ' . $signer_issuer
    ##! 64: 'signer subject: ' . $signer_subject 
    ##! 64: 'csr subject: ' . $csr_subject
     
    $context->param('signer_sn_matches_csr' => ($signer_subject eq $csr_subject) ? 1 : 0);
                    
    # Validate the signature    
    # TODO-SCEPv2 - use old token api
    my $pkcs7_token = CTX('crypto_layer')->get_system_token({ TYPE => 'PKCS7' });
    my $pkcs7 = $context->param('_pkcs7');
    
=begin    
     
    my $pki_realm = CTX('session')->get_pki_realm(); 
    my $cfg_id = CTX('api')->get_config_id({ ID => $workflow->id() });
          
    my $pkcs7_token = CTX('crypto_layer')->get_token(
        TYPE      => 'PKCS7',
        ID        => $pkcs7tool,
        PKI_REALM => $pki_realm,
        CONFIG_ID => $config_id,
    );
    my $sig_subject = $pkcs7_token->command({
        COMMAND => 'get_subject',
        PKCS7   => $pkcs7,
    });
=cut 
    
    ##! 64: 'PKCS7: ' . $pkcs7
    my $sig_valid;
    eval {
        $pkcs7_token->command({
            COMMAND => 'verify',
            PKCS7   => $pkcs7,
        });
    };
    if ($EVAL_ERROR) {
        ##! 4: 'signature invalid: ' . $EVAL_ERROR                
        CTX('log')->log(
            MESSAGE => "Invalid SCEP signature; CSR subject: " . $context->param('cert_subject'),
            PRIORITY => 'info',
            FACILITY => 'audit',
        );
        $context->param('signer_signature_valid' => 0);                        
    } else {
        CTX('log')->log(
            MESSAGE => "SCEP signature verified; CSR subject: " . $context->param('cert_subject') .", Signer $signer_subject",
            PRIORITY => 'info',
            FACILITY => 'audit',
        );
        $context->param('signer_signature_valid' => 1);
    }
    # unset pkcs7 
    $context->param('_pkcs7' => undef);    
    
    # copy the extra params (if present) - as they are passed internally we do NOT serialize them
    my $url_params = $context->param('_url_params');
    
    ##! 16: 'Url Params: ' . Dumper $url_params  
    if ($url_params) {               
        foreach my $param (keys %{$url_params}) {
            my $val = $url_params->{$param};
            if (ref $val ne "") { next; } # Scalars only                       
            $param =~ s/[\W]//g; # Strip any non word chars
            ##! 32: "Add extra parameter $param with value $val"
            $context->param("url_$param" => $val);        
        }        
    }     
    $context->param('_url_params' => undef);

    # We do this search under the assumption, that a renewal request always has the correct subject
    # If we have an initial request with a subject that needs preprocessing, we wont find any 
    # certificate with eiter subject. 
    # If we have an initial enrollment on an already used subject (replacement device)
    # you need to revoke the old certificate manually before you can issue a new one!  
    my $certs = CTX('api')->search_cert({
        VALID_AT => time(), 
        STATUS => 'ISSUED',
        SUBJECT => $csr_subject
    });


    # Find number of active certs - certs with exeeded lifteime but within
    my $cert_count = scalar(@{$certs}); 

    # If no active certs are found, check if we have a renewal and check if 
    # the signer certificate is in the grace period
    if (!$cert_count && $signer_subject eq $csr_subject && $signer_hash) {
    
        my $grace = $config->get("scep.$server.grace_period") || 0;
        ##! 32: 'Checking certs in the grace period: ' . $grace
        if ($grace) {
            my $grace_expiry = OpenXPKI::DateTime::get_validity({                   
                VALIDITY       => '-' . $grace,
                VALIDITYFORMAT => 'relativedate',
            })->epoch(); 
        
            if ($signer_hash->{NOTAFTER} > $grace_expiry) {
                ##! 32: 'Signer cert is in grace period'
                $cert_count = 1;
                CTX('log')->log(
                    MESSAGE => "SCEP Signer $signer_identifier is in grace period",
                    PRIORITY => 'info',
                    FACILITY => 'audit',
                );
            }
        }        
    }
        
    $context->param('num_active_certs' => $cert_count );
  
    # Check if the request was received within the renewal window
    # We use the earliest expiry date from the list of valid certificate 
    my $renewal = $config->get("scep.$server.renewal_period") || 0;
    
    $context->param('in_renew_window' => 0);
    if ($renewal) {
        
        # Reverse calculation ;) 
        my $renewal_time = OpenXPKI::DateTime::get_validity({   
            VALIDITY       => '+' . $renewal,
            VALIDITYFORMAT => 'relativedate',
        })->epoch();

        ##! 32: 'Renewal period is '.$renewal.'  and includes certs expiring before ' . $renewal_time        
        # Check if at least one of the exisiting certs is within the renwal window
        foreach my $cert (@{$certs}) {
            ##! 64 ' Testing '.$cert->{IDENTIFIER}.' with notafter ' . $cert->{NOTAFTER}
            if ($cert->{NOTAFTER} <= $renewal_time ) {
                ##! 32: 'Certificate '.$cert->{IDENTIFIER}.' is within renewal period'
                $context->param('in_renew_window' => 1);
                 CTX('log')->log(
                    MESSAGE => 'Certificate '.$cert->{IDENTIFIER}.' is within renewal period',
                    PRIORITY => 'info',
                    FACILITY => 'audit',
                );
                last;
            }
        }              
    }
    
  
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEPv2::ExtractCSR

=head1 Description

This activity extracts the PKCS#10 CSR and the subject from the
SCEP message and saves it in the workflow context.
