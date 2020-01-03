package OpenXPKI::Server::NICE::Local;

use Data::Dumper;

use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI::Crypto::Profile::CRL;
use OpenXPKI::Crypt::X509;
use OpenXPKI::Crypt::PubKey;
use OpenXPKI::Crypt::CRL;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use MIME::Base64;

use Moose;
#use namespace::autoclean; # Conflicts with Debugger
extends 'OpenXPKI::Server::NICE';

sub issueCertificate {

    my $self = shift;
    my $csr = shift;
    my $issuing_ca = shift || '';

    ##! 1: 'Starting '
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $realm = CTX('session')->data->pki_realm;
    my $config = CTX('config');

    my $csr_serial = $csr->{req_key};

    ##! 8: 'csr serial  ' . $csr_serial

    my $cert_profile = $csr->{profile};
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
            }) if ($val);
        } elsif ($key eq 'notafter') {
            $notafter = OpenXPKI::DateTime::get_validity({
                VALIDITYFORMAT => 'detect',
                VALIDITY        => $val,
            }) if ($val);
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

    # $issuing_ca set by user, check if the validity is ok
    if ($issuing_ca) {

        CTX('log')->application()->debug("Use ca set by user $issuing_ca to issue $csr_serial");

        # check if this is a certsign alias
        my $group = $config->get([ 'crypto', 'type', 'certsign']);
        $issuing_ca =~ / \A (.+)-(\d+) \z/x;
        if ($1 ne $group) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVER_NICE_LOCAL_ISSUER_NOT_IN_CERTSIGN_GROUP",
                params  => {
                    CA_ALIAS => $issuing_ca,
                    GROUP => $group,
            });
        }

        my $cert = CTX('api2')->get_certificate_for_alias( alias => $issuing_ca );

        if ($notafter->epoch() > $cert->{notafter}) {
            $notafter = DateTime->from_epoch( epoch => $cert->{notafter} );
            CTX('log')->application()->warn("Validity exceeds selected issuing ca - truncating notafter");

        } elsif ($notafter->epoch() < $cert->{notbefore}) {
            CTX('log')->application()->error("Expected notafter is before CA lifetime!");
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_NICE_LOCAL_CA_NOTAFTER_BEFORE_CA_LIFETIME',
            );
        }

        if ($notbefore->epoch() < $cert->{notbefore}) {
            $notbefore = DateTime->from_epoch( epoch => $cert->{notbefore} );
            CTX('log')->application()->warn("Validity exceeds selected issuing ca - truncating notbefore");

        } elsif ($notbefore->epoch() > $cert->{notafter}) {
            CTX('log')->application()->error("Expected notbefore is after CA lifetime!");
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_NICE_LOCAL_CA_NOTBEFORE_AFTER_CA_LIFETIME',
            );
        }


    } else {
        # Determine issuing ca
        $issuing_ca = CTX('api2')->get_token_alias_by_type(
            type => 'certsign',
            validity => {
                notbefore => $notbefore,
                notafter => $notafter,
            },
        );

        CTX('log')->application()->debug("Found $issuing_ca to issue $csr_serial");

    }

    ##! 32: 'issuing ca: ' . $issuing_ca

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
    );

    ##! 64: 'propagating cert subject: ' . $csr->{subject}
    $profile->set_subject( $csr->{subject} );

    ##! 64: 'SAN List ' . Dumper ( @subject_alt_names )
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
    if (!$ca_token->key_usable()) {
        CTX('log')->application()->warn("Token for $issuing_ca not usable");
        $self->last_error('I18N_OPENXPKI_UI_PAUSED_CERTSIGN_TOKEN_NOT_USABLE');
        return undef;
    }

    ##! 32: 'issuing certificate'
    ##! 64: 'certificate profile '. Dumper( $profile )
    my $certificate = $ca_token->command({
        COMMAND => "issue_cert",
        PROFILE => $profile,
        CSR     => $csr->{data},
    });

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

    my $self = shift;
    my $cert_identifier = shift;

    CTX('dbi')->update(
        table => 'certificate',
        set => { status => 'CRL_ISSUANCE_PENDING' },
        where => {
           identifier => $cert_identifier,
        },
    );

    return 1;

}

sub checkForRevocation {

    my $self = shift;
    my $cert_identifier  = shift;

    # As the local crl issuance process will set the state in the certificate
    # table directly, we get the certificate status from the local table

    ##! 16: 'Checking revocation status'
    my $cert = CTX('dbi')->select_one(
        from => 'certificate',
        columns => ['status'],
        where => { identifier => $cert_identifier },
    );

    CTX('log')->application()->debug("Check for revocation of $cert_identifier, result: " . $cert->{status});

    ##! 32: 'certificate status ' . $cert->{status}
    return ($cert->{status} eq 'REVOKED');

}


sub issueCRL {

    my $self = shift;
    my $ca_alias = shift;
    my $param = shift || {};

    ##! 8: "ca_alias $ca_alias"
    ##! 64: 'Params ' . Dumper $param

    my $pki_realm = CTX('session')->data->pki_realm;
    my $dbi = CTX('dbi');

    my $crl_validity = $param->{validity};
    my $delta_crl = $param->{validity};

    my $profile = $param->{crl_profile}; 

    my $remove_expired = $param->{remove_expired};
    my $reason_code = $param->{reason_code};

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_SERVER_NICE_LOCAL_CRL_NO_DELTA_CRL_SUPPORT",
    ) if $delta_crl;

    my $serializer = OpenXPKI::Serialization::Simple->new();

    # Load meta data of CA from the database
    my $ca_info = CTX('api2')->get_certificate_for_alias( alias => $ca_alias );

    # Get the certificate identifier to filter in the database
    my $ca_identifier = $ca_info->{identifier};

    # Build Profile (from ..Workflow::Activity::CRLIssuance::GetCRLProfile)
    my $crl_profile = OpenXPKI::Crypto::Profile::CRL->new(
        CA  => $ca_alias,
        ID => $profile,
        $crl_validity
         ? (VALIDITY => { VALIDITYFORMAT => 'relativedate', VALIDITY => $crl_validity }) : (),
        # We need the validity to check for the necessity of a "End of Life" CRL
        CA_VALIDITY => { VALIDITYFORMAT => 'epoch', VALIDITY => $ca_info->{notafter} }
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

    my %extra_where;
    if ($remove_expired) {
        $extra_where{notafter} = { '>', time()},
    }

    if ($reason_code) {
        $extra_where{reason_code} = $param->{reason_code};
    }

    my $certs = $dbi->select(
        from => 'certificate',
        columns => [ 'cert_key', 'identifier',
            'revocation_time', 'reason_code', 'invalidity_time',
            'status' ],
        where => {
            'certificate.pki_realm' => $pki_realm,
            issuer_identifier => $ca_identifier,
            status => [ 'REVOKED', 'CRL_ISSUANCE_PENDING' ],
            %extra_where
        },
        order_by => [ 'notbefore', 'req_key' ]
    );

    push @cert_timestamps, $self->__prepare_crl_data($certs);

    ##! 32: 'cert_timestamps: ' . join(", ", map { join "/", @$_ } @cert_timestamps)

    my $serial = $dbi->next_id('crl');

    ##! 2: "id: $serial"

    $crl_profile->set_serial($serial);

    ##! 16: 'performing key online test'
    if (!$ca_token->key_usable()) {
        CTX('log')->application()->warn("Token for $ca_alias not usable");
        $self->last_error('I18N_OPENXPKI_UI_PAUSED_CERTSIGN_TOKEN_NOT_USABLE');
        return undef;
    }

    my $crl = $ca_token->command({
        COMMAND => 'issue_crl',
        CERTLIST => \@cert_timestamps,
        PROFILE => $crl_profile,
    });

    my $crl_obj = OpenXPKI::Crypt::CRL->new( $crl );
    ##! 128: 'crl: ' . Dumper($crl)

    CTX('log')->application()->info('CRL issued for CA ' . $ca_alias . ' in realm ' . $pki_realm);

    CTX('log')->audit('cakey')->info('crl issued', {
        cakey     => $ca_identifier,
        token     => $ca_alias,
        pki_realm => $pki_realm,
    });

    my $data = {
        pki_realm         => $pki_realm,
        issuer_identifier => $ca_identifier,
        crl_key           => $serial,
        crl_number        => $serial,
        items             => scalar @cert_timestamps,
        last_update       => $crl_obj->last_update,
        next_update       => $crl_obj->next_update,
        publication_date  => 0,
        data              => $crl_obj->pem(),
    };
    
    if ($profile) {
        $data->{profile} = $profile;
    }
    
    $dbi->insert( into => 'crl', values => $data );

    return { crl_serial => $serial };
}

sub __prepare_crl_data {
    my $self = shift;
    my $sth_certs = shift;

    my @cert_timestamps = ();
    my $dbi       = CTX('dbi');
    my $pki_realm = CTX('session')->data->pki_realm;

    while (my $cert = $sth_certs->fetchrow_hashref) {
        ##! 32: 'cert to be revoked: ' . Data::Dumper->new([$cert])->Indent(0)->Terse(1)->Sortkeys(1)->Dump
        my $serial      = $cert->{cert_key};

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

        # as this is done inside the same database transaction as the
        # final insert of the generated CRL it is safe to set the status
        # before the CRL is actually created
        $dbi->update(
            table => 'certificate',
            set   => { status => $status },
            where => { identifier => $identifier },
        ) if ($status ne $cert->{status});
    }
    return @cert_timestamps;
}

sub generateKey {

    my $self = shift;

    my $mode = shift; # not used
    my $key_alg = shift;
    my $key_params = shift;
    my $key_transport = shift;
    my $extra = shift || {};

    my $params = {
        key_alg => $key_alg,
        password => $key_transport->{password},
        enc_alg => $key_transport->{algorithm},
    };

    # password check
    if (not $params->{password}) {
        $self->last_error('I18N_OPENXPKI_UI_NICE_GENERATE_KEY_NO_PASSWORD');
        return;
    }

    foreach my $key (keys %{$key_params}) {
        my $value = $key_params->{$key};
        if ( defined $value && $value ne '' ) {
            if ($key =~ /curve_name/i) {
                $params->{curve} = $value;
            } elsif ($key =~ /key_length/i) {
                $params->{key_length} = $value;
            }
        }
    }

    # command definition
    my $res;
    CTX('log')->audit('key')->info("generating private key via NICE");

    eval {
        my $pkcs8 = CTX('api2')->generate_key(%$params);

        my $pubkey = CTX('api2')->get_default_token()->command({
            COMMAND => "get_pubkey",
            DATA => $pkcs8,
            PASSWD => $params->{password},
        });

        my $pub = OpenXPKI::Crypt::PubKey->new($pubkey);

        $res = {
            pkey => $pkcs8,
            pubkey => encode_base64($pub->data),
            key_id => $pub->get_subject_key_id,
        };
    };
    if ($EVAL_ERROR) {
        CTX('log')->application()->error('Error generating private key: ' . $EVAL_ERROR);
    }
    return $res;

}

sub fetchKey {

    my $self = shift;

    my $key_identifier = shift;
    my $password = shift || '';
    my $key_transport = {
        password => $password,
        algorithm => 'aes256',
        %{shift || {}}
    };
    my $params = shift;

    # password check
    if (not $password) {
        OpenXPKI::Exception->throw(
            message => 'No password set for key encryption'
        );
    }

    my $pkey;
    my $datapool = CTX('api2')->get_data_pool_entry(
        namespace =>  'certificate.privatekey',
        key       =>  $key_identifier
    );

    if (!$datapool) {
        $self->last_error('I18N_OPENXPKI_UI_NICE_FETCH_KEY_NO_SUCH_KEY');
        CTX('log')->application()->error('No key found for this key_id');
        return;
    }

    eval {
        $pkey = CTX('api2')->convert_private_key(
            private_key => $datapool->{value},
            format     => 'OPENSSL_PRIVKEY',
            password   => $password,
            # fallback to password is done in API, Algo is always aes256
            passout => $key_transport->{password} || '',
        );
    };
    if ($EVAL_ERROR || !$pkey) {
        $self->last_error('I18N_OPENXPKI_UI_NICE_FETCH_KEY_DECRYPT_FAILED');
        CTX('log')->application()->error('Unable to export private key: ' . ($EVAL_ERROR || 'unknown error'));
    }

    return $pkey;

}

1;
__END__

=head1 Name

OpenXPKI::Server::NICE::Local

=head1 Description

This module implements the OpenXPKI NICE Interface using the local crypto backend

=head1 Configuration

The module does not require nor accept any configuration options.

=head1 API Functions

=head2 issueCertificate

Issues a certitficate, will autodetect the most current ca for the requested
profile. Issuer can be enforced by passing the issuer alias as second
parameter, the certificates validity will be tailored to fit into the CA
validity window.

Takes only the key information from the pkcs10 and requires subject, SAN and
validity to be given as context parameters.

=head2 renewCertificate

Currently only an alias for issueCertificate

=head2 revokeCertificate

Set the status field of the certificate table to "CRL_ISSUANCE_PENDING".

=head2 checkForRevocation

Queries the certifictes status from the local certificate datasbase.

=head2 issueCRL

Creates a crl for the given ca and pushes it into the database for publication.
Incremental CRLs are not supported.

The first parameter must be the ca-alias, the second parameter is as hash
with options:

=over

=item crl_profile (optional)

the profile definition to use 

=item crl_validity

OpenXPKI::DateTime relative date, overrides the profile validity.

=item delta_crl

not supported yet.

=item reason_code

List of reason codes to be included in the CRL (CRL Scope), default is to
include all reason codes.

=item remove_expired

Boolean, if set, only certifcates with a notafter greater than now are
included in the CRL, by default the CRL also lists expired certificates.

=back

=head2 generateKey

Calls the local API method generate_key, input parameters are "drop in"
compatible to the Tools::GenerateKey activity. The return value is a hash:

=over

=item pkey

The PEM encoded private key, including header/footer lines

=item pubkey

The base64 encoded public key (no line breaks or headers)

=item key_id

The key identifier, sha1 hash (uppercase hex) of pubkey, same format
as subject_key_id of PKCS10 and x509 classes.

=back

=head2 fetchKey

Loads the private key from the datapool based on the used key_id.

