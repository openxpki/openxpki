package OpenXPKI::Server::Workflow::Activity::Tools::EvaluateSignerTrust;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypt::X509;

sub execute {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context = $workflow->context();
    my $config = CTX('config');

    # reset the context flags
    $context->param('signer_trusted' => 0);
    $context->param('signer_authorized' => undef);
    $context->param('signer_revoked' => 0);
    $context->param('signer_validity_ok' => 0);
    $context->param('signer_chain_ok' => undef);
    $context->param('signer_in_current_realm' => 0);
    $context->param('signer_cert_identifier' => undef );

    my $current_realm = CTX('session')->data->pki_realm;

    my $signer_cert = $context->param('signer_cert');

    if (!$signer_cert) {
        ##! 16: 'No signer certificate in context'
        CTX('log')->application()->debug("Trusted Signer validation skipped, no certificate found");
        return 1;
    }

    my $x509 = OpenXPKI::Crypt::X509->new( $signer_cert );

    my $signer_identifier = $x509->get_cert_identifier();
    ##! 32: 'Signer identifier ' .$signer_identifier

    # Get realm and issuer for signer certificate
    my $cert_hash = CTX('dbi')->select_one(
        from    => 'certificate',
        columns => ['pki_realm', 'issuer_identifier', 'req_key', 'status' ],
        where   => { identifier => $signer_identifier },
    );

    if (!$cert_hash && $x509->is_selfsigned() && $self->param('allow_surrogate_certificate')) {
        my $db_results = CTX('dbi')->select_hashes(
            from    => 'certificate',
            columns => ['pki_realm', 'identifier', 'issuer_identifier', 'req_key', 'status', 'data' ],
            where   => {
                subject_key_identifier => $x509->get_subject_key_id(),
                req_key => { "!=" => undef }
            },
            limit => 2,
        );

        if ($db_results && scalar @{$db_results}) {
            if (scalar @{$db_results} > 1) {
                CTX('log')->application()->warn("Use of surrogate requested but result is not unique!");
            } else {
                $cert_hash = $db_results->[0];
                $signer_identifier = $cert_hash->{identifier};
                CTX('log')->application()->info("Using surrogate certificate");
                ##! 32: 'Got surrogate ' . $signer_identifier
                $x509 = OpenXPKI::Crypt::X509->new( $cert_hash->{data} );
            }
        }

    }

    # Check if the certificate is valid
    my $now = DateTime->now();
    my $notbefore = $x509->get_notbefore();
    my $notafter = $x509->get_notafter();

    if ( ( DateTime->compare( $notbefore, $now ) <= 0)  && ( DateTime->compare( $now,  $notafter) < 0) ) {
        $context->param('signer_validity_ok' => '1');
    } else {
        $context->param('signer_validity_ok' => '0');
    }

    # populate some details on the cert if requested
    my $signer_subject = $x509->get_subject();
    if ($self->param('export_subject')) {
        $context->param( 'signer_subject' => $signer_subject );
    }

    if ($self->param('export_key_identifier')) {
        if ($self->param('export_key_identifier') eq 'hash') {
            $context->param( 'signer_subject_key_identifier' => $x509->get_public_key_hash() );
        } elsif ($self->param('export_key_identifier') eq 'both') {
            $context->param( 'signer_public_key_hash' => $x509->get_public_key_hash());
            $context->param( 'signer_subject_key_identifier' => $x509->get_subject_key_id() );
        } else {
            $context->param( 'signer_subject_key_identifier' => $x509->get_subject_key_id() );
        }
    }

    # Check the chain
    # set from either db query or from chain validation
    my ($signer_issuer, $signer_root, $signer_revoked);
    my $signer_realm = 'unknown';
    my $signer_profile = 'unknown';
    my $validate_chain;

    # certificate identifier was found in the internal database
    if ($cert_hash) {
        ##! 16: 'certificate found in database'
        # certificate was found in local database
        $context->param('signer_cert_identifier' => $signer_identifier);
        $signer_realm = $cert_hash->{pki_realm} || '_global';
        $signer_issuer = $cert_hash->{issuer_identifier};
        $signer_revoked = ($cert_hash->{status} ne 'ISSUED');

        # Get the profile of the certificate, if it was issued from this CA
        if ($cert_hash->{req_key}) {
            my $profile = CTX('api2')->get_profile_for_cert( identifier => $signer_identifier );
            $signer_profile = $profile if ($profile);
            if ( $current_realm eq $signer_realm ) {
                $context->param('signer_in_current_realm' => 1 );
            }
        }

        # do chain validation via database - this is prone to possible
        # collision attacks against the sha1 based certificate identifier
        # unless the signer_cert was properly validated against a trusted chain
        if ($signer_issuer && $self->param('skip_chain_validation')) {
            CTX('log')->application()->info("Do chain validation against database");
            my $signer_chain = CTX('api2')->get_chain( start_with => $signer_issuer );
            if ($signer_chain->{complete}) {
                $signer_root = pop $signer_chain->{identifiers}->@*;
            }
        } else {
            # marker for chain validation
            $validate_chain = 1;
        }

    # certificate neither "local" nor otherwise "known"
    # external signer is allowed so proceed here
    } elsif (!$x509->is_selfsigned() && $self->param('allow_external_signer')) {

        ##! 16: 'external certificate - try to validate'
        $signer_realm = 'external';

        # marker for chain validation
        $validate_chain = 1;

    }

    # perform chain validation
    if ($validate_chain) {
        ##! 16: 'perform chain validation'

        my $crl_check = $self->param('crl_check') || 'none';
        CTX('log')->application()->info("Do external chain validation with CRL check $crl_check");

        my $chain_validate = CTX('api2')->validate_certificate(
            pem => $signer_cert,
            crl_check => $crl_check,
        );

        my $cert_status = $chain_validate->{status};
        ##! 32: 'chain validation status ' . $cert_status
        if ($cert_status =~ m{(VALID|REVOKED|NOROOT)}) {

            my @signer_chain = $chain_validate->{chain}->@*;
            # remove the entity from the chain
            shift @signer_chain;
            if (scalar @signer_chain) {
                $signer_issuer = CTX('api2')->get_cert_identifier( cert => $signer_chain[0] );
            }

            if ($cert_status ne 'NOROOT') {
                my $signer_root_pem = pop @signer_chain;
                $signer_root = CTX('api2')->get_cert_identifier( cert => $signer_root_pem );
                $context->param('signer_chain_ok' => 1);
            }
            # not implemented for remote certificates yet!
            $signer_revoked = ($cert_status eq 'REVOKED');

            CTX('log')->application()->debug("Chain validation result is $cert_status");

        }  else {

            ##! 32: 'chain broken or untrusted'
            $context->param('signer_chain_ok' => 0);
            CTX('log')->application()->warn("Chain validation was not successful");
        }

    }

    ##! 32: 'Signer profile ' .$signer_profile
    ##! 32: 'Signer realm ' .  $signer_realm
    ##! 32: 'Signer issuer ' . ($signer_issuer || 'unknown')
    ##! 32: 'Signer root ' . ($signer_root || 'unknown')

    if ($signer_revoked) {
        ##! 64: 'Signer is revoked'
        CTX('log')->application()->warn("Trusted Signer certificate is revoked");
        $context->param('signer_revoked' => 1);

    } elsif ($signer_root) {
        ##! 64: 'Signer is trusted'
        $context->param('signer_trusted' => 1);
        CTX('log')->application()->info("Trusted Signer chain validated - trusted root is $signer_root");

    } elsif ($x509->is_selfsigned()) {
        ##! 64: 'Signer is selfsigned'
        $context->param('signer_cert_identifier' => '');
        CTX('log')->application()->info("Trusted Signer chain - certificate is self signed");

    # something went really wrong, the certificate might be forged or is
    # not from a trusted source so it does - usually - not make sense to
    # continue but sometimes you might want to....
    } elsif ($self->param('allow_untrusted_signer')) {
        ##! 64: 'continue with untrusted signer'
        CTX('log')->application()->info("Chain validation failed but allow_untrusted_signer is set");

    } else {
        ##! 64: 'untrusted signer, aborting'
        CTX('log')->application()->warn("Trusted Signer chain validation FAILED - aborting");
        return;
    }

    # End chain validation, now check the authorization

    ##! 32: 'Check signer '.$signer_subject.' against trustlist'
    my $rules = $self->param('rules');
    # explicit declaration as action parameter
    my @rules;
    if (ref $rules eq 'HASH') {
        ##! 128: $rules
        @rules = sort keys %{$rules};
        CTX('log')->application()->debug("SignerTrust explicit rules: ". join(",", @rules));
    } else {
        @rules = $config->get_keys( $rules );
        CTX('log')->application()->debug("SignerTrust loading rules from $rules");
    }

    if (!@rules) {
        CTX('log')->application()->info("No rules were found - skip signer authorization check.");
        return 1;
    }

    CTX('log')->application()->debug("Trusted Signer Authorization $signer_profile / $signer_realm / $signer_subject / $signer_identifier");

    TRUST_RULE:
    foreach my $rule (@rules) {
        ##! 32: 'Testing rule ' . $rule
        my $trustrule = (ref $rules eq 'HASH') ? $rules->{$rule}
            : $config->get_hash("$rules.$rule");

        # as we expect the idenifier to be uniq we do not need a realm
        $trustrule->{realm} = $current_realm
            if (!$trustrule->{realm} && !$trustrule->{identifier});

        ##! 64: $trustrule
        my $matched = CTX('api2')->evaluate_trust_rule(
            signer_subject  => $signer_subject,
            signer_identifier   => $signer_identifier,
            signer_realm    => $signer_realm,
            ($signer_profile ? (signer_profile  => $signer_profile) : ()),
            ($signer_issuer  ? (signer_issuer   => $signer_issuer) : ()),
            ($signer_root    ? (signer_root     => $signer_root) : ()),
            rule            => $trustrule,
        );

        if ($matched) {
            ##! 16: 'Passed validation rule #'.$rule,
            CTX('log')->application()->info("Trusted Signer Authorization matched rule $rule");
            $context->param('signer_authorized' => 1);
            return 1;
        }
    }

    CTX('log')->application()->info("Trusted Signer not found in trust list ($signer_subject).");

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

Evaluate if the signer certificate can be trusted and is authorized.
Populates several context items with the results of the validation.

Checks are by default done based on the contents of the certificate
database and work only for certificates found there. If you want to
validate certificates from an external CA you must import the full
issuer chain and either set the C<allow_external_signer> parameter or
import the used signer certificates themselves.

=head2 Context Parameters

=head3 Output

=over

=item signer_trusted (Bool)

True if the complete chain is available and certificate status is not
revoked. Does B<NOT> check for expiration.

=item signer_authorized (Bool)

True if the signer matches one of the given rules. This does B<NOT>
depend on the trust status of the certificate, so you need to check
both flags or delegate the chain validation to another component
(e.g. TLS configuration of a webserver). Will be C<undef> if the
certificate chain could not be validated at all or no trust rules
were found.

=item signer_validity_ok (Bool)

True if the current date is within the notbefore/notafter window.

=item signer_revoked (Bool)

True if the certificate is marked as revoked.

=item signer_chain_ok (Bool)

Only available with external signers. True if the certificate chain
was successfully built, false otherwise.

=item signer_cert_identifier (Str)

The identifier of the signer certificate. Empty string if the
certificate is self-signed and not found in the database.

=item signer_subject (Str)

The subject of the signer certificate. Only exported if the
C<export_subject> parameter is set.

=item signer_subject_key_identifier (Str)

The subject key identifier or public key hash of the signer
certificate. See C<export_key_identifier> parameter for details.

=item signer_public_key_hash (Str)

The SHA1 hash of the public key (only when C<export_key_identifier>
is set to C<both>).

=item signer_in_current_realm (Bool)

Whether the signer is an entity in the current realm.

=back

=head1 CONFIGURATION

The check for authorization uses a list of rules. Those can be either
given explicitly to the C<rules> parameter or as a pointer to the
realm config. A common pattern used in OpenXPKI is to build the path
for the rules from the server properties, e.g. the SCEP workflow uses
C<scep.[% context.server %].authorized_signer>.

If C<rules> is a scalar, it is considered to be a config path. If it
is a hash it is taken as an explicitly defined ruleset.

The ruleset structure is a hash of hashes, where each entry is a
combination of one or more matching rules. The name of the rule is
used for logging purposes only:

  rule1:
    subject: CN=scep-signer.*,dc=OpenXPKI,dc=org
    identifier: AhElV5GzgFhKalmF_yQq-b1TnWg
    profile: client_scep
    realm: democa

=head2 Rules

The rules within one entry are ANDed together. Values are full string
matches, except the subject rule which is a regexp. If you want to
provide alternatives, add multiple list items.

=over

=item subject

Evaluated as a regexp against the signer's full subject. Characters
with special meaning in Perl regexps must be escaped.

=item profile

Matches the name of the internal OpenXPKI profile assigned to this
certificate. This implies that the certificate was issued by this CA.

=item realm

The name of the realm where the certificate originates from. Also
works for certificates imported into a realm. If not set, the default
is the current realm. Pass the special value C<_any> to ignore the
realm during rule evaluation.

Special rules apply when matching on C<identifier> or C<issuer_alias>.

=item identifier

The identifier of the certificate. Also works with externally issued
or self-signed certificates. C<realm> is only matched if set
explicitly, so C<realm: _any> is the default.

=item issuer_alias

The name of an alias group as registered in the C<aliases> table.
Matches if the certificate issuer has an active alias in the given
group. The alias is searched in the given realm and the global realm.
Setting C<realm: _any> is ignored (search is done in the global
realm only).

Note: The query is done at once for the given and global realm. This
might cause unexpected behaviour when the same alias exists in both
with different validity dates (there will be a positive match if
either the local or the global realm lists the item as valid).

=item root_alias

Same as C<issuer_alias> but queries for the root certificate.

=item meta_*

Load the metadata attributes assigned to the certificate and match
against the given value.

=back

=head2 Activity Parameters

=over

=item rules

Usually a scalar value, taken as config path to read the rules from.
Can also be a hash that represents an explicit ruleset (see L</Rules>).

=item export_subject

Boolean. If set, the signer subject is exported to the context
parameter C<signer_subject>.

=item export_key_identifier

Export information about the signer's subject key identifier. The
behaviour depends on the value:

=over

=item C<hash>

Write the SHA1 hash of the public key (as defined in RFC 5280) to
C<signer_subject_key_identifier>.

=item C<both>

Write the subject key identifier to C<signer_subject_key_identifier>
and the SHA1 hash to C<signer_public_key_hash>.

=item I<(any true value)>

Write the key identifier read from the certificate to
C<signer_subject_key_identifier>.

=back

B<Note>: If a certificate does not contain an explicit subject key
identifier, this always falls back to the SHA1 hash.

=item allow_external_signer

Boolean. If set and the signer is not found in the local database,
the activity tries to verify the certificate chain using the
C<validate_certificate> API method.

=item allow_untrusted_signer

Boolean. If true, the rulesets are processed even if the certificate
chain could not be built or validated. Only useful with external
signers.

=item skip_chain_validation

Boolean. If true, the signer certificate chain validation is done against the
database only and not using a cryptographic operation. This should only be
activated if you have otherwise validated the certificate.

=item crl_check

Only used with external signers. Valid values are C<leaf> or C<all>.
Tries to use CRLs when validating the certificate for either the
leaf certificate or the full chain. See C<validate_certificate> API method.

=item allow_surrogate_certificate

Boolean. If set and the signer is not found in the local database
B<and> is self-signed, the database is searched for an entity
certificate with the same subject key ID. This is used e.g. in the
proof-of-possession renewal via EST/RPC.

=back
