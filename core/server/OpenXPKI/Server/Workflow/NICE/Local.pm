## OpenXPKI::Server::Workflow::NICE::Local.pm
## NICE Backends using the local crypto backend
##
## Written 2012 by Oliver Welter <openxpki@oliwel.de>
## for the OpenXPKI project
## (C) Copyright 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::NICE::Local;

use Data::Dumper;

use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI::Crypto::Profile::CRL;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Crypto::CRL;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::WFObject::WFArray;

use Moose;
#use namespace::autoclean; # Conflicts with Debugger
extends 'OpenXPKI::Server::Workflow::NICE';

sub issueCertificate {

    my $self = shift;
    my $csr = shift;

    ##! 1: 'Starting '
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $realm = CTX('session')->data->pki_realm;
    my $config = CTX('config');

    my $csr_serial = $csr->{CSR_SERIAL};

    ##! 8: 'csr serial  ' . $csr_serial

    my $cert_profile = $csr->{PROFILE};
    ##! 64: 'certificate profile: ' . $cert_profile

    # Determine the expected validity of the certificate to find the right ca
    # Requries that we load the CSR attributes
    my ($notbefore, $notafter);
    my @subject_alt_names;
    my @extension;

    my $cert_attr = CTX('dbi')->select(
        columns => [ qw(
            attribute_contentkey
            attribute_value
        ) ],
        from => 'csr_attributes',
        where => { req_key => $csr_serial },
    );

    while (my $attr = $cert_attr->fetchrow_hashref) {
        my $key = $attr->{attribute_contentkey};
        my $val = $attr->{attribute_value};

        if ($key eq 'subject_alt_name') {
            push @subject_alt_names,  $serializer->deserialize($val);
        } elsif ($key eq 'x509v3_extension') {
            push @extension, $serializer->deserialize($val);
        } elsif ($key eq 'notbefore') {
            $notbefore = OpenXPKI::DateTime::get_validity({
                VALIDITYFORMAT => 'detect',
                VALIDITY        => $val,
            });
        } elsif ($key eq 'notafter') {
            $notafter = OpenXPKI::DateTime::get_validity({
                VALIDITYFORMAT => 'detect',
                VALIDITY        => $val,
            });
        }


    }

    # Set notbefore/notafter according to profile settings if it was not set in csr

    my $validity_path = "profile.$cert_profile.validity";
    if (!$config->exists($validity_path)) {
        $validity_path = "profile.default.validity";
    }

    if (not $notbefore) {
        my $profile_notbefore = $config->get("$validity_path.notbefore");
        if ($profile_notbefore) {
            $notbefore = OpenXPKI::DateTime::get_validity({
                VALIDITY => $profile_notbefore,
                VALIDITYFORMAT => 'detect',
            });
        } else {
            # assign default (current timestamp) if notbefore is not specified
            $notbefore = DateTime->now( time_zone => 'UTC' );
        }
    }
    if (not $notafter) {
        my $profile_notafter = $config->get("$validity_path.notafter");
        ##! 32: 'Notafter ' . Dumper $profile_notafter
        if (not $profile_notafter) {
           OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_NICE_LOCAL_ISSUE_NOT_AFTER_NOT_SET",
            params  => {
                PROFILE => $cert_profile,
                CSR => $csr_serial
            });
        }
        $notafter = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE => $notbefore,
            VALIDITY => $profile_notafter,
            VALIDITYFORMAT => 'detect',
        });
    }

    # Determine issuing ca
    my $issuing_ca = CTX('api')->get_token_alias_by_type( {
        TYPE => 'certsign',
        VALIDITY => {
            NOTBEFORE => $notbefore,
            NOTAFTER => $notafter,
        },
    });

    ##! 32: 'issuing ca: ' . $issuing_ca

    CTX('log')->application()->debug("try to issue csr $csr_serial using token $issuing_ca");


    my $default_token = CTX('api')->get_default_token();
    my $ca_token = CTX('crypto_layer')->get_token({
        TYPE => 'certsign',
        NAME => $issuing_ca
    });

    if (!defined $ca_token) {
        OpenXPKI::Exception->throw(
           message => 'I18N_OPENXPKI_SERVER_NICE_LOCAL_CA_TOKEN_UNAVAILABLE',
        );
    }

    my $profile = OpenXPKI::Crypto::Profile::Certificate->new (
        CA        => $issuing_ca,
        ID        => $cert_profile,
        TYPE      => 'ENDENTITY', # FIXME - should be useless
    );

    ##! 64: 'propagating cert subject: ' . $csr->{SUBJECT}
    $profile->set_subject( $csr->{SUBJECT} );

    ##! 51: 'SAN List ' . Dumper ( @subject_alt_names )
    if (scalar @subject_alt_names) {
        ##! 64: 'propagating subject alternative names: ' . Dumper @subject_alt_names
       $profile->set_subject_alt_name(\@subject_alt_names);
    }

    ## 64: 'Extensions ' . Dumper \@extension
    if (scalar @extension) {
        foreach my $ext (@extension) {
            # we only support oids for the moment
            my $oid = $ext->{oid};
            if (!$oid || $oid !~ /\A(\d+\.)+\d+\z/) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_NICE_LOCAL_UNSUPPORTED_EXTENSION',
                    param => { NAME => $oid }
                );
            }

            # We dont want those to be set from external
            # (might be used to overwrite essential settings like CA:true )
            if ($oid =~ /^0?2\.0?5\.0?29\./) {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_NICE_LOCAL_EXTENSION_NOT_ALLOWED",
                    params => { NAME => $oid }
                );
            }

            # scalar case
            if ($ext->{value}) {
                $profile->set_extension(
                    NAME     => $oid,
                    CRITICAL => $ext->{critical} ? 'true' : 'false',
                    VALUES   => $ext->{value},
                );
            } elsif ($ext->{section}) {
                $profile->set_oid_extension_sequence(
                    NAME     => $oid,
                    CRITICAL => $ext->{critical} ? 'true' : 'false',
                    VALUES   => $ext->{section},
                );
            }
        }
    }


    my $rand_length = $profile->get_randomized_serial_bytes();
    my $increasing  = $profile->get_increasing_serials();

    # determine serial number (atomically)
    my $serial = $profile->create_random_serial(
        $increasing
            ? (PREFIX => CTX('dbi')->next_id('certificate'))
            : (),
        RANDOM_LENGTH => $profile->get_randomized_serial_bytes(),
    );
    ##! 32: 'propagating serial number: ' . $serial
    $profile->set_serial($serial);

    if (defined $notbefore) {
        ##! 64: 'propagating notbefore date: ' . $notbefore
        $profile->set_notbefore($notbefore);
    }

    if (defined $notafter) {
        ##! 32: 'propagating notafter date: ' . $notafter
        $profile->set_notafter($notafter);
    }

    ##! 16: 'performing key online test'
    if (! $ca_token->key_usable()) {
        CTX('log')->application()->warn("Token for $issuing_ca not usable");
        $self->_get_activity()->pause('I18N_OPENXPKI_UI_PAUSED_CERTSIGN_TOKEN_NOT_USABLE');
    }


    ##! 32: 'issuing certificate'
    ##! 64: 'certificate profile '. Dumper( $profile )
    my $certificate = $ca_token->command({
        COMMAND => "issue_cert",
        PROFILE => $profile,
        CSR     => $csr->{DATA},
    });

    # SPKAC Requests return binary format - so we need to convert that
    if ($certificate !~ m{\A -----BEGIN }xms) {
        ##! 32: 'Certificate seems to be binary - conveting it'
        $certificate = $default_token->command({
            COMMAND => "convert_cert",
            DATA    => $certificate,
            OUT     => "PEM",
            IN      => "DER",
        });
    }
    ##! 64: 'cert: ' . $certificate

    my $msg = sprintf("Certificate %s (%s) issued by %s", $profile->get_subject(), $serial, $issuing_ca);
    CTX('log')->application()->info($msg);

    my $cert_identifier = $self->__persistCertificateInformation(
        {
            certificate => $certificate,
            ca_identifier => $ca_token->get_instance()->get_cert_identifier(),
            csr_serial  => $csr_serial
        },
        {}
    );

    ##! 16: 'cert_identifier: ' . $cert_identifier

    return { 'cert_identifier' => $cert_identifier };
}


sub renewCertificate {
    return issueCertificate( @_ );
}

sub revokeCertificate {

   my $self       = shift;
   my $crr  = shift;

   # We need the cert_identifier to check for revocation later
   # usually it is already there
   # TODO Context parameters should be returned and set by calling method just like issueCertificate() does
   $self->_set_context_param('cert_identifier', $crr->{IDENTIFIER}) if (!$self->_get_context_param('cert_identifier'));

   return;
}

sub checkForRevocation {
    my $self = shift;

    # As the local crl issuance process will set the state in the certificate
    # table directly, we get the certificate status from the local table

    ##! 16: 'Checking revocation status'
    my $id = $self->_get_context_param('cert_identifier');
    my $cert = CTX('dbi')->select_one(
        from => 'certificate',
        columns => ['status'],
        where => { identifier => $id },
    );

    CTX('log')->application()->debug("Check for revocation of $id, result: " . $cert->{status});

    if ($cert->{status} eq 'REVOKED') {
       ##! 32: 'certificate revoked'
       return 1;
    }

    # If the certificate is not revoked, trigger pause
    ##! 32: 'Revocation is pending - going to pause'
    $self->_get_activity()->pause('I18N_OPENXPKI_UI_PAUSED_LOCAL_REVOCATION_PENDING');

    return;
}


sub issueCRL {

    my $self = shift;
    my $ca_alias = shift;

    my $pki_realm = CTX('session')->data->pki_realm;
    my $dbi = CTX('dbi');

    # FIXME - we want to have a context free api....
    my $crl_validity = $self->_get_context_param('crl_validity');
    my $delta_crl = $self->_get_context_param('delta_crl');

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_SERVER_NICE_LOCAL_CRL_NO_DELTA_CRL_SUPPORT",
    ) if $delta_crl;

    my $serializer = OpenXPKI::Serialization::Simple->new();

    # Load meta data of CA from the database
    my $ca_info = CTX('api')->get_certificate_for_alias( { ALIAS => $ca_alias } );

    # Get the certificate identifier to filter in the database
    my $ca_identifier = $ca_info->{IDENTIFIER};

    # Build Profile (from ..Workflow::Activity::CRLIssuance::GetCRLProfile)
    my $crl_profile = OpenXPKI::Crypto::Profile::CRL->new(
        CA  => $ca_alias,
        $crl_validity
         ? (VALIDITY => { VALIDITYFORMAT => 'relativedate', VALIDITY => $crl_validity }) : (),
        # We need the validity to check for the necessity of a "End of Life" CRL
        CA_VALIDITY => { VALIDITYFORMAT => 'epoch', VALIDITY => $ca_info->{NOTAFTER} }
    );
    ##! 16: 'profile: ' . Dumper( $crl_profile )

    my $ca_token = CTX('crypto_layer')->get_token({
        TYPE => 'certsign',
        NAME => $ca_alias
    });

    OpenXPKI::Exception->throw(
       message => 'I18N_OPENXPKI_SERVER_NICE_LOCAL_CA_TOKEN_UNAVAILABLE',
    ) unless defined $ca_token;

    # we want all identifiers and data for certificates that are
    # already in the certificate database with status 'REVOKED'

    # We need to select three different classes of certificates
    # for the CRL:
    # - those that are in the certificate DB with status 'REVOKED'
    #   and have a corresponding CRR entry, for those we also need
    #   the smallest approval date (works optimal using SQL MIN(), tbd)
    # - those that are in the certificate DB with status 'REVOKED'
    #   and for some reason DON't have a CRR entry. For those, the
    #   date is set to epoch 0
    # - those that are in the certificate DB with status
    #   'CRL_ISSUANCE_PENDING' and their smallest CRR approval date

    my @cert_timestamps; # array with certificate data and timestamp

    # fetch certificates that are already revoked or to be revoked, must
    # use LEFT JOIN as there can be revoked certificates without CRR items!
    my $certs = $dbi->select(
        from_join => 'certificate =>certificate.identifier=crr.identifier crr',
        columns => [ 'cert_key', 'certificate.identifier identifier', 'revocation_time', 'reason_code', 'invalidity_time', 'status' ],
        where => {
            'certificate.pki_realm' => $pki_realm,
            issuer_identifier => $ca_identifier,
            status => [ 'REVOKED', 'CRL_ISSUANCE_PENDING' ],
        },
        order_by => [ 'cert_key', 'revocation_time desc' ]
    );

    push @cert_timestamps, $self->__prepare_crl_data($certs);

    ##! 32: 'cert_timestamps: ' . join(", ", map { join "/", @$_ } @cert_timestamps)

    my $serial = $dbi->next_id('crl');

    ##! 2: "id: $serial"

    $crl_profile->set_serial($serial);
    #
    ##! 16: 'performing key online test'
    if (! $ca_token->key_usable()) {
        CTX('log')->application()->warn("Token for $ca_identifier not usable");
        $self->_get_activity()->pause('I18N_OPENXPKI_UI_PAUSED_CRL_TOKEN_NOT_USABLE');
    }
    #
    my $crl = $ca_token->command({
        COMMAND => 'issue_crl',
        REVOKED => \@cert_timestamps,
        PROFILE => $crl_profile,
    });
    #
    my $crl_obj = OpenXPKI::Crypto::CRL->new(
            TOKEN => CTX('api')->get_default_token(),
            DATA  => $crl,
    );
    ##! 128: 'crl: ' . Dumper($crl)
    #
    CTX('log')->application()->info('CRL issued for CA ' . $ca_alias . ' in realm ' . $pki_realm);

    #
    # publish_crl can then publish all those with a PUBLICATION_DATE of 0
    # and set it accordingly
    my $data = { $crl_obj->to_db_hash() };

    CTX('log')->audit('cakey')->info('crl issued', {
        cakey     => $data->{authority_key_identifier},
        token     => $ca_alias,
        pki_realm => $pki_realm,
    });

    $data = {
        # FIXME #legacydb Change upper to lower case in OpenXPKI::Crypto::CRL->to_db_hash(), not here
        ( map { lc($_) => $data->{$_} } keys %$data ),
        pki_realm         => $pki_realm,
        issuer_identifier => $ca_identifier,
        crl_key           => $serial,
        publication_date  => 0,
    };
    $dbi->insert( into => 'crl', values => $data );

    return { crl_serial => $serial };
}

sub __prepare_crl_data {
    my $self = shift;
    my $sth_certs = shift;

    my @cert_timestamps = ();
    my $dbi       = CTX('dbi');
    my $pki_realm = CTX('session')->data->pki_realm;

    my $last_serial = '';
    while (my $cert = $sth_certs->fetchrow_hashref) {
        ##! 32: 'cert to be revoked: ' . Data::Dumper->new([$cert])->Indent(0)->Terse(1)->Sortkeys(1)->Dump
        my $serial      = $cert->{cert_key};
        if ($last_serial eq $serial) {
            ##! 16: 'Skipping duplicate crr for serial ' . $serial
            next;
        }
        $last_serial = $serial;
        my $identifier  = $cert->{identifier};
        my $reason_code = $cert->{reason_code}  || '';
        my $revocation_time = $cert->{revocation_time};
        my $invalidity_time = $cert->{invalidity_time};

        # there might be certificates set to revoked that do not have a CRR item
        if ($reason_code) {
            ##! 32: 'approved crr present: ' . Dumper $cert
            push @cert_timestamps, [ $serial, $revocation_time, $reason_code, $invalidity_time ];
        } else {
            push @cert_timestamps, [ $serial ];
        }

        # update certificate database:
        my $status = 'REVOKED';
        $status = 'HOLD'   if $reason_code eq 'certificateHold';
        $status = 'ISSUED' if $reason_code eq 'removeFromCRL';

        $dbi->update(
            table => 'certificate',
            set   => { status => $status },
            where => { identifier => $identifier },
        ) if ($status ne $cert->{status});
    }
    return @cert_timestamps;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::NICE::Local

=head1 Description

This module implements the OpenXPKI NICE Interface using the local crypto backend

=head1 Configuration

The module does not require nor accept any configuration options.

=head1 API Functions

=head2 issueCertificate

Issues a certitficate, will autodetect the most current ca for the requested
profile.

Takes only the key information from the pkcs10 and requires subject, SAN and
validity to be given as context parameters. Also supports SPKAC request format.

=head2 renewCertificate

Currently only an alias for issueCertificate

=head2 revokeCertificate

This sub will just put cert_identifier and reason_code from the CRR to the
context, so it is quickly available in the checkForRevocation step.

=head2 checkForRevocation

Queries the certifictes status from the local certificate datasbase.

=head2 issueCRL

Creates a crl for the given ca and pushes it into the database for publication.
Incremental CRLs are not supported.
