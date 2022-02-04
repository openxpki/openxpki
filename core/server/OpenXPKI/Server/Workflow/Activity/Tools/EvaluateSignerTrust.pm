package OpenXPKI::Server::Workflow::Activity::Tools::EvaluateSignerTrust;

use strict;
use warnings;

use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Crypt::X509;
use English;

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
    my ($signer_issuer, $signer_root, $signer_revoked, @signer_chain);
    my $signer_realm = 'unknown';
    my $signer_profile = 'unknown';

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

        if ($signer_issuer) {
            my $signer_chain = CTX('api2')->get_chain( start_with => $signer_issuer );
            @signer_chain = @{$signer_chain->{identifiers}};
            if ($signer_chain->{complete}) {
                $signer_root = pop @{$signer_chain->{identifiers}};
            }
        }
    } elsif (!$x509->is_selfsigned() && $self->param('allow_external_signer')) {
        ##! 16: 'external certificate - try to validate'
        # use validate to build the chain
        $signer_realm = 'external';

        my $crl_check = $self->param('crl_check') || 'none';

        my $chain_validate = CTX('api2')->validate_certificate(
            pem => $signer_cert,
            crl_check => $crl_check,
        );

        my $cert_status = $chain_validate->{status};
        ##! 32: 'chain validation status ' . $cert_status
        if ($cert_status =~ m{(VALID|REVOKED|NOROOT)}) {

            @signer_chain = @{$chain_validate->{chain}};
            # remove the entity from the chain
            shift @signer_chain;
            if ($signer_chain[0]) {
                $signer_issuer = CTX('api2')->get_cert_identifier( cert => $signer_chain[0] );
            }

            if ($cert_status ne 'NOROOT') {
                my $signer_root_pem = pop @{$chain_validate->{chain}};
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

    my $matched = 0;

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

Evaluate if the signer certificate can be trusted. Populates the result
into several context items, all values are boolean. Checks are by default
done based on the contents of the certificate database and work only for
certificates which are found there. If you want to validate certificates
from an external CA you must import the full issuer chain and either set
the I<allow_external_signer> flag or import the used signer certificates
themselves.

=over

=item signer_trusted

true if the complete chain is available and certificate status is not
revoked. Does B<NOT> check for expiration.

=item signer_authorized

true if the signer matches one of the given rules. This does B<NOT> depend
on the trust status of the certificate, so you need to check both flags or
delegate the chain validation to another component (e.g. tls config of
webserver). Will be I<undef> in case the certificate chain could not be
validated at all or no trust rules have been found.

=item signer_validity_ok

true if the current date is within the notbefore/notafter window

=item signer_revoked

true if the certificate is marked revoked.

=item signer_chain_ok

only available with external signers, true if the certificate chain
was successfully build, false otherwise.

=item signer_cert_identifier

the identifier of the signer certificate

=item signer_subject

the subject of the signer certificate,
only exported if export_subject parameter is set

=item signer_subject_key_identifier, signer_public_key_hash

the signer_key_identifier / public_key_hash of the signer
certificate, see export_key_identifier parameter for details.

=item signer_in_current_realm

Boolean, weather the signer is an entity in the current realm

=back

=head1 Configuration

The check for authorization uses a list of rules. Those can be either
given explicitly to the I<rules> parameter or as a pointer to the realm
config. A common pattern used in OpenXPKI is to build the path for the
rules from the server properties, e.g. the SCEP workflow uses
I<scep.[% context.server ].authorized_signer>..

If I<rules> is a scalar, it is considered to be a config path, if it is
a hash it is taken as explicitly defined ruleset.

The ruleset structure is a hash of hashes, were each entry is a combination
of one or more matching rules. The name of the rule is just used for logging
purpose:

  rule1:
    subject: CN=scep-signer.*,dc=OpenXPKI,dc=org
    identifier: AhElV5GzgFhKalmF_yQq-b1TnWg
    profile: client_scep
    realm: democa

=head2 Rules

The rules in one entry are ANDed together, values are full string match,
except the subject rule. If you want to provide alternatives, add multiple
list items.

=over

=item subject

Evaluated as a regexp against the signers full subject, therefore any
characters with a special meaning in perl regexp need to be escaped!

=item profile

Matches the name of the internal OpenXPKI profile assigned to this
certificate. This implies that the certificate was issued by us.

=item realm

The name of the realm where the certificate originates from, works also
for certificates imported into a realm. If not set, the default is the
current realm. Pass the special value I<_any> to ignore the realm during
rule evaluation.

Special rules apply when matching on "identifier" or "issuer_alias".

=item identifier

The identifier of the certificate. This works also with external issued or
self signed certificates. I<realm> is only matched if set explicit, so
I<realm: _any> is the default.

=item issuer_alias

The name of an alias group as registered in the I<aliases> table. Matches
if the certificate issuer has an active alias in the given group. The alias
item is searched in the given realm and the global realm, setting
I<realm: _any> is ignored (search is done in the global realm only).

Note: The query is done at once for the given and global realm, this might
cause unexepcted behaviour when the same alias exists in both with different
validity dates (there will be a positive match if either the local or the
global realm lists the item as valid).

=item root_alias

Same as issuer_alias but queries for the root certificate

=item meta_*

Load the metadata attributes assigned to the certificate and match against
the given value.

=back

=head2 Parameters

=over

=item rules

Usually a scalar value, taken as config path to read the rules from. Can
also be a hash that represents an explicit ruleset (see Rules).

=item export_subject

Boolean, if set the signer_subject is exported to the context.

=item export_key_identifier

Export information about the signers subject_key_identifier. As there is
an ambiguity on this term, you can switch the behaviour.

The default behaviour on any true value is to write the key identifier
read from the certificate to  I<signer_subject_key_identifier>. If you
pass I<hash>, you get the value of the SHA1 hash of the public key as
defined in RFC5280 in this field. If you pass I<both>, the SHA1 has will
be written as an additional field to I<signer_public_key_hash>.

B<Note>: If a certificate does not contain an explicit subject key
identifier, this always falls back to the SHA1 hash.

=item allow_external_signer

Boolean, if set and the signer is not found in the local database the activity
tries to verify the certificate chain using the validate_certificate API
method.

=item allow_untrusted_signer

Boolean, if true, the rulesets are processed even if the certificate chain
could not be built or validated. This is only useful with external signers.

=item crl_check

Only used when the certificate is an external signer. Valid values are
I<leaf> or I<all>, tries to use CRLs when validating the certificate for
either the lead certificate or the full chain. The required CRLs must
exist in the CRL table.


=item allow_surrogate_certificate

Boolean, if set and the signer is not found in the local database B<and> is
self-signed the database is searched for an entity certificate with the same
subject key id. This is used e.g. in the PoP renewal via EST/RPC.

=back
