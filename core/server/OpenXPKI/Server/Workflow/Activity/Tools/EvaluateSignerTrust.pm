package OpenXPKI::Server::Workflow::Activity::Tools::EvaluateSignerTrust;

use strict;
use warnings;

use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Crypt::X509;
use Data::Dumper;
use English;

sub execute {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context = $workflow->context();
    my $config = CTX('config');

    # reset the context flags
    $context->param('signer_trusted' => 0);
    $context->param('signer_authorized' => 0);
    $context->param('signer_revoked' => 0);
    $context->param('signer_validity_ok' => 0);
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
        my $db_results = CTX('dbi')->select(
            from    => 'certificate',
            columns => ['pki_realm', 'identifier', 'issuer_identifier', 'req_key', 'status', 'data' ],
            where   => {
                subject_key_identifier => $x509->get_subject_key_id(),
                req_key => { "!=" => undef }
            },
            limit => 2,
        )->fetchall_arrayref({});

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

    # Check the chain
    # set from either db query or from chain validation
    my ($signer_issuer, $signer_req_key, $signer_root, $signer_revoked, @signer_chain);
    my $signer_realm = 'unknown';
    my $signer_profile = 'unknown';


    if ($cert_hash) {
        ##! 16: 'certificate found in database'
        # certificate was found in local database
        $context->param('signer_cert_identifier' => $signer_identifier);
        $signer_realm = $cert_hash->{pki_realm} || '_global';
        $signer_issuer = $cert_hash->{issuer_identifier};
        $signer_req_key = $cert_hash->{req_key};
        $signer_revoked = ($cert_hash->{status} ne 'ISSUED');

        # Get the profile of the certificate, if it was issued from this CA

        if ($signer_req_key) {
            my $csr_hash = CTX('dbi')->select_one(
                from    => 'csr',
                columns => [ 'profile' ],
                where   => { req_key => $signer_req_key },
            );
            $signer_profile = $csr_hash->{profile} if $csr_hash->{profile};

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

        my $chain_validate = CTX('api2')->validate_certificate(
            pem => $signer_cert,
        );

        my $cert_status = $chain_validate->{status} || '';
        if (!$cert_status ) {
            ##! 32: 'chain validation died'
            CTX('log')->application()->warn("Unable to build chain for external certificate");
        } else {
            ##! 32: 'chain validation status ' . $chain_validate->{status}
            @signer_chain = @{$chain_validate->{chain}};
            # remove the entity from the chain
            shift @signer_chain;
            if ($signer_chain[0]) {
                $signer_issuer = CTX('api2')->get_cert_identifier( cert => $signer_chain[0] );
            }

            if ($cert_status ne 'NOROOT') {
                my $signer_root_pem = pop @{$chain_validate->{chain}};
                $signer_root = CTX('api2')->get_cert_identifier( cert => $signer_root_pem );
            }
            # not implemented for remote certificates yet!
            $signer_revoked = ($cert_status eq 'REVOKED');

            CTX('log')->application()->debug("Chain validation result is $cert_status");
        }
    }

    ##! 32: 'Signer profile ' .$signer_profile
    ##! 32: 'Signer realm ' .  $signer_realm
    ##! 32: 'Signer issuer ' . ($signer_issuer || 'unknown')
    ##! 32: 'Signer root ' . ($signer_root || 'unknown')

    if ($signer_revoked) {
        CTX('log')->application()->warn("Trusted Signer certificate is revoked");
        $context->param('signer_revoked' => 1);

    } elsif ($signer_root) {

        $context->param('signer_trusted' => 1);

        CTX('log')->application()->info("Trusted Signer chain validated - trusted root is $signer_root");

    } elsif ($x509->is_selfsigned()) {

        $context->param('signer_cert_identifier' => '');

        CTX('log')->application()->info("Trusted Signer chain - certificate is self signed");

    } else {
        CTX('log')->application()->warn("Trusted Signer chain validation FAILED");

    }

    # End chain validation, now check the authorization

    my $signer_subject = $x509->get_subject();
    ##! 32: 'Check signer '.$signer_subject.' against trustlist'

    if ($self->param('export_subject')) {
        $context->param( 'signer_subject' => $signer_subject );
    }

    if ($self->param('export_key_identifier')) {
        $context->param( 'signer_subject_key_identifier' => $x509->get_subject_key_id() );
    }

    my $rules_prefix = $self->param('rules');
    my @rules = $config->get_keys( $rules_prefix );

    my $matched = 0;

    CTX('log')->application()->debug("Trusted Signer Authorization $signer_profile / $signer_realm / $signer_subject / $signer_identifier");

    my $meta;

    TRUST_RULE:
    foreach my $rule (@rules) {
        ##! 32: 'Testing rule ' . $rule
        my $trustrule = $config->get_hash("$rules_prefix.$rule");

        # as we expect the idenifier to be uniq we do not need a realm
        $trustrule->{realm} = $current_realm
            if (!$trustrule->{realm} && !$trustrule->{identifier});

        $matched = 0;
        foreach my $key (keys %{$trustrule}) {
            my $match = $trustrule->{$key};
            ##! 64: 'expected match ' . $key . '/' . $match
            if ($key eq 'subject') {
                $matched = ($signer_subject =~ /^$match$/i);

            } elsif ($key eq 'identifier') {
                $matched = ($signer_identifier eq $match);

            } elsif ($key eq 'realm') {
                # if issuer_alias is used the realm check is done on the alias
                $matched = ($trustrule->{issuer_alias}) ? 1 :
                    ($signer_realm eq $match);

            } elsif ($key eq 'profile') {
                $matched = ($signer_profile eq $match || $match eq '_any');

            } elsif ($key eq 'issuer_alias' || $key eq 'root_alias') {

                my $identifier = ($key eq 'issuer_alias') ? $signer_issuer : $signer_root;
                my $alias = CTX('dbi')->select_one(
                    from    => 'aliases',
                    columns => [ 'alias' ],
                    where   => {
                        group_id => $match,
                        identifier => $identifier,
                        notbefore => { '<' => time },
                        notafter  => { '>' => time },
                        pki_realm => [ $trustrule->{realm}, '_global' ],
                    },
                );
                ##! 64: "Result for $key ($identifier) in $match: " . ($alias->{alias} || 'no result')
                $matched = (defined $alias->{alias});

            } elsif ($key =~ m{meta_}) {
                # reset the matched state!
                $matched = 0;
                if (!defined $meta->{$key}) {
                    my $attr = CTX('api2')->get_cert_attributes(
                        identifier => $signer_identifier,
                        attribute => $key
                    );
                    $meta->{$key} = $attr->{$key} || [];
                    ##! 64: 'Loaded attr ' . Dumper $meta->{$key}
                }
                foreach my $aa (@{$meta->{$key}}) {
                    ##! 64: "Attr $aa"
                    next unless ($aa eq $match);
                    $matched = 1;
                    last;
                }

            } else {
                CTX('log')->system()->error("Trusted Signer Authorization unknown ruleset $key/$match");

                $matched = 0;
            }
            next TRUST_RULE if (!$matched);

            CTX('log')->application()->debug("Trusted Signer Authorization matched subrule $rule/$match");

            ##! 32: 'Matched ' . $match
        }

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
into several context items, all values are boolean. Checks are based on
the contents of the certificate database, so if you want to use external
certificates with this class you need to import them first.

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

=item signer_subject

the subject of the signer certificate,
only exported if export_subject parameter is set

=item signer_subject_key_identifier

the signer_key_identifier of the signer certificate,
only exported if export_key_identifier parameter is set

=item signer_in_current_realm

Boolean, weather the signer is an entity in the current realm

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

=item export_subject

Boolean, if set the signer_subject is exported to the context.

=item export_key_identifier

Boolean, if set the signer_subject_key_identifier is exported to the context.

=item allow_external_signer

Boolean, if set and the signer is not found in the local database the activity
tries to verify the certificate chain using the validate_certificate API
method.

=item allow_surrogate_certificate

Boolean, if set and the signer is not found in the local database B<and> is
self-signed the database is searched for an entity certificate with the same
subject key id. This is used e.g. in the PoP renewal via EST/RPC.

=back
