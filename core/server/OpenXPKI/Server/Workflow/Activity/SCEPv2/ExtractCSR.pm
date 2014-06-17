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
use OpenXPKI::DN;
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $pki_realm  = CTX('session')->get_pki_realm();

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
    # Explicit check for empty subject - should never happen but if it crashes the logic
    if (!$csr_subject) {
        CTX('log')->log(
            MESSAGE => "SCEP csr has no subject",
            PRIORITY => 'error',
            FACILITY => 'application',
        );
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_ACTIVITY_SCEP_EXTRACT_CSR_NO_SUBJECT'
        );
    }


    my $csr_key_size = $csr_body->{KEYSIZE};
    my $csr_key_type = $csr_body->{PUBKEY_ALGORITHM};
    my ($csr_hash_type) = lc($csr_body->{PUBKEY_HASH}) =~ m{ \A ([^:]+) : }x;

    $context->param('csr_subject' => $csr_subject);
    $context->param('csr_type'    => 'pkcs10');
    $context->param('csr_key_size' => $csr_key_size );
    $context->param('csr_key_type' => $csr_key_type );
    $context->param('csr_hash_type' => $csr_hash_type );

    # Check the key size against allowed ones
    my $key_size_allowed = $config->get_hash("scep.$server.key_size");
    $context->param('csr_key_size_ok' => 0 );
    $context->param('csr_key_type_ok' => 0 );

    if (!$key_size_allowed->{$csr_key_type}) {
        CTX('log')->log(
            MESSAGE => "SCEP csr key type not known ($csr_key_type)",
            PRIORITY => 'warn',
            FACILITY => 'application',
        );
    } else {
        $key_size_allowed->{$csr_key_type} =~ m{ (\d+)(\s*\-\s*(\d+))? }x;
        my $min = $1; my $max = $3 ? $3 : undef;
        $context->param('csr_key_type_ok' => 1 );
        if ($csr_key_size < $min) {
            CTX('log')->log(
                MESSAGE => "SCEP csr key size is too small ($csr_key_type / $csr_key_size < $min)",
                PRIORITY => 'warn',
                FACILITY => 'application',
            );
        } elsif($max && $csr_key_size > $max)  {
            CTX('log')->log(
                MESSAGE => "SCEP csr key size is too long ($csr_key_type / $csr_key_size > $max)",
                PRIORITY => 'warn',
                FACILITY => 'application',
            );
        } else {
            $context->param('csr_key_size_ok' => 1 );
            CTX('log')->log(
                MESSAGE => "SCEP csr key size is ok ($csr_key_type / $csr_key_size)",
                PRIORITY => 'warn',
                FACILITY => 'application',
            );
        }
    }

    # Test hash type
    my @hash_allowed = $config->get_scalar_as_list("scep.$server.hash_type");
    my %hash_allowed = map { lc($_) => 1 } @hash_allowed;
    if ($hash_allowed{$csr_hash_type}) {
        $context->param('csr_hash_type_ok' => 1 );
        CTX('log')->log(
            MESSAGE => "SCEP csr hash type is ok ($csr_hash_type)",
            PRIORITY => 'info',
            FACILITY => 'application',
        );
    } else {
        $context->param('csr_hash_type_ok' => 0 );
        CTX('log')->log(
            MESSAGE => "SCEP csr hash type not in allowed list ($csr_hash_type)",
            PRIORITY => 'warn',
            FACILITY => 'application',
        );
    }


    # Test for the embeded Profile name at OID 1.3.6.1.4.1.311.20.2

    # This is either empty or an array ref with the BitString
    my $csr_extensions = $csr_body->{OPENSSL_EXTENSIONS}->{'1.3.6.1.4.1.311.20.2'};

    ##! 32: ' Ext  ' . Dumper $csr_extensions

    if ($csr_extensions && ref $csr_extensions eq 'ARRAY') {
        my $cert_extension_name = $csr_extensions->[0];
        # it looks like as the XS Parser already converts the the BMPString to
        # a readable representation, so we just parse the chars out
        $cert_extension_name =~ s/^..//; # Leading Byte
        # FIXME - I dont have any idea what chars are possible within parsed bmpstring
        # so this probably chokes on some strings!
        $cert_extension_name =~ s/.(.)/$1/g;
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
	            FACILITY => 'application',
	        );
        } else {
        	CTX('log')->log(
                MESSAGE => "SCEP found Microsoft Certificate Name Extension: $cert_extension_name, ignored - no matching profile",
                PRIORITY => 'warn',
                FACILITY => 'application',
            );
        }
    }

    my %hashed_dn = OpenXPKI::DN->new( $csr_subject )->get_hashed_content();
    ##! 16: 'DN ' . Dumper \%dn
    $context->param('cert_subject_parts' => $serializer->serialize( \%hashed_dn ) );

    # Fetch the sources hash from the context and extend it
    my $sources = $serializer->deserialize( $context->param('sources') );
    $sources->{'cert_subject'} = 'SCEP';
    $sources->{'cert_subject_alt_name_parts'}  = 'SCEP';
    $context->param('sources' => $serializer->serialize($sources));

    my $cert_subject = $csr_subject;
    # Check if there is a subject style to enable subject rendering
    # NOTE - this needs to be done after the csr extension block as this can change the profile
    my $subject_style = $config->get("scep.$server.subject_style");
    my @subject_alt_names;
    if ($subject_style) {

        my $profile = $context->param('cert_profile');

        $context->param('cert_subject_style' => $subject_style);
        CTX('log')->log(
            MESSAGE => "SCEP subject rendering enabled ( $profile / $subject_style ) ",
            PRIORITY => 'info',
            FACILITY => ['application'],
        );

        my %subject_vars = %hashed_dn;

        # slurp url params if any and add them to the request
        # FIXME - is there a security problem with shell chars or the like?
        my $url_params = $context->param('_url_params');
        $subject_vars{URL_PARAM} = $url_params if($url_params);

        $cert_subject = CTX('api')->render_subject_from_template({
            PROFILE => $profile,
            STYLE   => $subject_style,
            VARS    => \%subject_vars
        });

        if (!$cert_subject) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_ACTIVITY_SCEP_EXTRACT_CSR_RENDER_SUBJECT_FAILED',
                params => { PROFILE => $profile, STYLE   => $subject_style }
            );
        }

        my @san_template_keys = $config->get_keys("profile.$profile.style.$subject_style.subject.san");
        if (scalar @san_template_keys > 0) {

            CTX('log')->log(
                MESSAGE => "SCEP san rendering enabled ( $profile / $subject_style ) ",
                PRIORITY => 'info',
                FACILITY => ['application'],
            );

            my $csr_info = $csr_obj->get_subject_alt_names({ FORMAT => 'HASH' });
            @subject_alt_names = @{CTX('api')->render_san_from_template({
                PROFILE => $profile,
                STYLE   => $subject_style,
                VARS    => \%subject_vars,
                ADDITIONAL => $csr_info || {},
            })};
        }
    }

    # in case no san rendering has been done, just copy them from the pkcs10
    @subject_alt_names = $csr_obj->get_subject_alt_names() unless (@subject_alt_names);


    ##! 64: 'subject : ' . $cert_subject
    ##! 64: 'subject_alt_names: ' . Dumper(\@subject_alt_names)

    $context->param('cert_subject' => $cert_subject);
    $context->param('cert_subject_alt_name' => $serializer->serialize( \@subject_alt_names )) if (@subject_alt_names);

    my $challenge = $csr_body->{'CHALLENGEPASSWORD'};
    if ($challenge) {
        ##! 32: 'challenge: ' . Dumper $challenge
        $context->param('_challenge_password' => $challenge);
        CTX('log')->log(
            MESSAGE => "SCEP challenge password present on CSR subject: " . $context->param('cert_subject'),
            PRIORITY => 'info',
            FACILITY => ['audit','application'],
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
    my $signer_subject = $x509->get_parsed('BODY', 'SUBJECT');
    my $signer_issuer = $x509->get_parsed('BODY', 'ISSUER');
    my $signer_identifier = $x509->get_identifier();

    ##! 16: 'signer cert_identifier: ' . $x509->get_identifier()

    if ( ( DateTime->compare( $notbefore, $now ) <= 0)  && ( DateTime->compare( $now,  $notafter) < 0) ) {
        $context->param('signer_validity_ok' => '1');
    } else {
        $context->param('signer_validity_ok' => '0');
    }

    # check if the csr is self signed (based on the pubkey)
    my $csr_pubkey_hash = $csr_body->{'PUBKEY_HASH'};
    my $x509_pubkey_hash = $x509->get_parsed('BODY', 'PUBKEY_HASH');
    ##! 32: 'csr pubkey ' . $csr_pubkey_hash
    ##! 32: 'signer pubkey ' . $x509_pubkey_hash

    my $is_self_signed = ($csr_pubkey_hash eq $x509_pubkey_hash ? 1 : 0);
    $context->param('signer_is_self_signed' => $is_self_signed);

    CTX('log')->log(
        MESSAGE => "SCEP signer subject: " . $signer_subject . ($is_self_signed ? ' - is selfsign' : ''),
        PRIORITY => 'info',
        FACILITY => 'application',
    );

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
                FACILITY => ['audit','monitor','application']
            );
        } else {
            $context->param('signer_status_revoked' => '0');
            CTX('log')->log(
                MESSAGE => "SCEP signer certificate valid; CSR subject: " . $context->param('cert_subject') .", Signer $signer_subject",
                PRIORITY => 'info',
                FACILITY => [ 'audit', 'application'],
            );
        }
        $context->param('signer_cert_identifier' => $signer_hash->{IDENTIFIER});
        $context->param('signer_cert_subject' => $signer_hash->{SUBJECT});
    } else {
        $context->param('signer_status_revoked' => '0');
    }

    ##! 64: 'signer issuer: ' . $signer_issuer
    ##! 64: 'signer subject: ' . $signer_subject
    ##! 64: 'csr subject: ' . $csr_subject

    $context->param('signer_sn_matches_csr' => ($signer_subject eq $csr_subject) ? 1 : 0);

    # Validate the signature
    my $pkcs7 = $context->param('_pkcs7');

    ##! 64: 'PKCS7: ' . $pkcs7
    my $sig_valid;
    eval {
        $default_token->command({
            COMMAND => 'pkcs7_verify',
            NO_CHAIN => 1,
            PKCS7   => $pkcs7,
        });
    };
    if ($EVAL_ERROR) {
        ##! 4: 'signature invalid: ' . $EVAL_ERROR
        CTX('log')->log(
            MESSAGE => "Invalid SCEP signature; CSR subject: " . $context->param('cert_subject'),
            PRIORITY => 'warn',
            FACILITY => ['audit','application'],
        );
        CTX('log')->log(
            MESSAGE => "SCEP signature failed, reason $EVAL_ERROR",
            PRIORITY => 'debug',
            FACILITY => ['application'],
        );
        $context->param('signer_signature_valid' => 0);
    } else {
        CTX('log')->log(
            MESSAGE => "SCEP signature verified; CSR subject: " . $context->param('cert_subject') .", Signer $signer_subject",
            PRIORITY => 'info',
            FACILITY => ['audit','application'],
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

    # number of active certs
    my $cert_count = scalar(@{$certs});
    $context->param('num_active_certs' => $cert_count );

    # Check if the request was received within the renewal window
    # We check the validity of the signer certificate against the renewal window
    # Note - the in_renew_window flag will become misslieading if we are not in an
    # renewal case as we check the wrong certificate
    my $renewal = $config->get("scep.$server.renewal_period") || 0;
    $context->param('in_renew_window' => 0);

    if ($renewal && $signer_hash) {
        # Reverse calculation - the date wich must not be exceeded by notafter
        my $renewal_time = OpenXPKI::DateTime::get_validity({
            VALIDITY       => '+' . $renewal,
            VALIDITYFORMAT => 'relativedate',
        })->epoch();

        if ($signer_hash->{NOTAFTER} <= $renewal_time) {
            CTX('log')->log(
                MESSAGE => "SCEP Signer $signer_identifier is in renewal period",
                PRIORITY => 'info',
                FACILITY => ['audit','application'],
            );
            $context->param('in_renew_window' => 1);
        }
    }

    # Do the same for the replace window
    my $replace = $config->get("scep.$server.replace_period") || 0;
    $context->param('in_replace_window' => 0);

    if ($replace && $signer_hash) {
        # Reverse calculation - the date wich must not be exceeded by notafter
        my $replace_time = OpenXPKI::DateTime::get_validity({
            VALIDITY       => '+' . $replace,
            VALIDITYFORMAT => 'relativedate',
        })->epoch();

        if ($signer_hash->{NOTAFTER} <= $replace_time) {
            CTX('log')->log(
                MESSAGE => "SCEP Signer $signer_identifier is in replace period",
                PRIORITY => 'info',
                FACILITY => ['audit','application'],
            );
            $context->param('in_replace_window' => 1);
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
