
package OpenXPKI::Server::Workflow::Activity::Tools::SearchCertificates;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DN;
use OpenXPKI::DateTime;
use OpenXPKI::Serialization::Simple;
use Workflow::Exception qw( configuration_error );


sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    ##! 1: 'Start'
    my $cert_subject = $self->param('cert_subject');
    my $realm = $self->param('realm');
    my $profile = $self->param('profile');
    my $issuer = $self->param('issuer');
    my $order = $self->param('order');
    my $limit = $self->param('limit');
    my $include_revoked = $self->param('include_revoked');
    my $include_expired = $self->param('include_expired');
    my $cutoff_notbefore = $self->param('cutoff_notbefore');
    my $cutoff_notafter = $self->param('cutoff_notafter');
    my $entity_only = $self->param('entity_only');
    my $cert_serial = $self->param('cert_serial');
    my $identifier = $self->param('cert_identifier');

    my @param = $self->param();

    my $query = {
        entity_only => 0,
        cert_attributes => {},
        return_columns => 'identifier',
    };

    if (defined $self->param('tenant')) {
        $query->{tenant} = $self->param('tenant');
    } elsif ($workflow->attrib('tenant')) {
        $query->{tenant} = $workflow->attrib('tenant');
    }

    if (!$include_revoked) {
        $query->{status} = 'ISSUED';
    };

    if ($entity_only) {
        $query->{entity_only} = 1;
    }

    my $valid_at;
    if (my $v_at = $self->param('valid_at')) {
        ##! 16: 'valid_At ' . $v_at
       $valid_at = OpenXPKI::DateTime::get_validity({
            VALIDITY =>  $v_at,
            VALIDITYFORMAT => 'detect',
        });
    } else {
       $valid_at = DateTime->now();
    }

    my $epoch = $valid_at->epoch();

    # if cutoff is set, we filter on notbefore between valid_at and cutoff
    if ($cutoff_notbefore) {
        my $cutoff = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE => $valid_at,
            VALIDITY => $cutoff_notbefore,
            VALIDITYFORMAT => 'detect',
        })->epoch();

        if ($epoch > $cutoff) {
            $query->{valid_after} = $cutoff;
            $query->{valid_before} = $epoch;
        } else {
            $query->{valid_after} = $epoch;
            $query->{valid_before} = $cutoff;
        }
    } else {
        $query->{valid_before} = $epoch + 1;
    }

    my $expiry_cutoff = 0;
    # if expired certs should be included, we just move the notafter limit
    if (!$include_expired) {
        $expiry_cutoff = $epoch;
    } elsif (!($include_expired eq '1' || $include_expired =~ /[a-z]/)) {
        $expiry_cutoff = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE => $valid_at,
            VALIDITY => $include_expired,
            VALIDITYFORMAT => 'detect',
        })->epoch();
    }

    # if notafter cutoff is set, we use it as upper limit
    # we always expect this to be a positive offset
    if ($cutoff_notafter) {
        my $cutoff = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE => $valid_at,
            VALIDITY => $cutoff_notafter,
            VALIDITYFORMAT => 'detect',
        })->epoch();
        $query->{expires_after} = $expiry_cutoff;
        $query->{expires_before} = $cutoff;
    } elsif($expiry_cutoff) {
        $query->{expires_after} = $expiry_cutoff;

    # catch include_expired "_any"
    } elsif (!$include_expired) {
        $query->{expires_after} = $epoch - 1;
    }

    if ($identifier) {
        ##! 16: 'Adding identifier ' . $identifier
        $query->{identifier} = $identifier;
    }

    if ($cert_subject) {
        ##! 16: 'Adding subject ' . $cert_subject
        $query->{subject} = $cert_subject;
    }

    if ($realm) {
        ##! 16: 'Adding realm ' . $realm
        $query->{pki_realm} = $realm;
    }

    if ($profile) {
        ##! 16: 'Adding profile ' . $profile
        $query->{profile} = $profile;
    }

    if ($issuer) {
        ##! 16: 'Adding issuer ' . $issuer
        $query->{issuer_identifier} = $issuer;
    }

    if ($order && ($order =~ /\A ([a-z0-9]+)(\s+(asc|desc))? \z/xms)) {
        my $col = uc($1);
        my $reverse = lc($3) || '';
        $query->{order} = $col;
        $query->{reverse} = ($reverse eq 'desc') ? 1 : 0;
    }

    if ($limit) {
        if ($limit =~ /\A\d+\z/) {
            $query->{limit} = $limit;
        } elsif ($limit eq 'single') {
            $query->{limit} = 1;
        }
    }


    foreach my $key (@param) {
        ##! 16: 'Checking key ' . $key
        if ($key =~ /^(meta_|system_|subject_alt_name)/) {
            my $value = $self->param($key);
            next unless (defined $value && $value ne '');
            ##! 16: 'Add key with value ' . $value
            if ($value eq '<undef>') {
                $query->{cert_attributes}->{$key} = undef;
            } else {
                $query->{cert_attributes}->{$key} = { '=', $value };
            }
        }
    }

    if ($self->param('subject_key_identifier')) {
        # uppercase the value to match the database format
        $query->{'subject_key_identifier'} = uc($self->param('subject_key_identifier'));
    }

    if ($cert_serial) {
        $cert_serial =~ s/[\s:]//g;
        if ($cert_serial =~ /[a-f]/i && substr($cert_serial,0,2) ne '0x') {
            $cert_serial = '0x' . $cert_serial;
        }
        $query->{cert_serial} = $cert_serial;
    }

    if (scalar (keys %{$query}) == 3 && !$query->{cert_attributes}) {
        configuration_error('I18N_OPENXPKI_UI_SEARCH_CERTIFICATES_QUERY_IS_EMPTY');
    }

    ##! 32: 'Full query ' . Dumper $query;
    my $result = CTX('api2')->search_cert(%$query);
    ##! 64: 'Search returned ' . Dumper $result

    my $target_key = $self->param('target_key') || 'cert_identifier_list';

    my $ignore = $self->param('cert_identifier_ignore') || '';
    ##! 32: $ignore
    my @identifier = map {  ($_->{identifier} eq $ignore) ? () : $_->{identifier} } @{$result};

    if (@identifier) {
        if ($limit && $limit eq 'single') {
            $target_key = $self->param('target_key') || 'cert_identifier';
            $context->param( $target_key => $identifier[0] );
            CTX('log')->application()->trace("SearchCertificates result (single)" . $result->[0]->{identifier});
        } else {
            $context->param( $target_key => \@identifier );
            CTX('log')->application()->trace("SearchCertificates result " . Dumper \@identifier);
        }

    } else {

        $context->param( { $target_key => undef } );

    }

    return 1;
}

1;

=head1 NAME

OpenXPKI::Server::Workflow::Activity::Tools::SearchCertificates

=head1 DESCRIPTION

Search for certificates based on several criteria, useful as prestage for
duplicate/renewal check or for bulk actions. The result is a list of
identifiers written to context defined by target_key.

See the parameter section for available filters.

=head1 Configuration

=head2 Example

 class: OpenXPKI::Server::Workflow::Activity::Tools::SearchCertificates
    param:
        profile: tls_server
        realm: democa
        issuer: YHkkLxEKtqbopNbcFwdBcHqKWPE
        target_key: other_key

=head2 Configuration parameters

=over

=item realm

The realm to search in, default is the current realm, I<_any> searches globally

=item tenant

The tenant to search for, the default is to use the tenant of the
current workflow.

=item profile

The profile of the certificate, default is all profiles.

=item entity_only

Boolean, find only certificates issued within this realm. Default is no.

=item cert_subject

Searches the full DN for an exact match! The '*' as wildcard is supported.

=item subject_alt_name

Searches in the SAN section, you must prefix the value with the SAN type,
e.g. DNS:www.openxpki.org or IP:1.2.3.4. There might be some difficulties
with non-ascii strings/encodings.

=item issuer

The certificate identifier of the issuer

=item subject_key_identifier

The certificate subject_key_identifier (hex notation with colon)

=item cert_serial

The certificate serial number (as hex with 0x prefix or integer, separator
and casing is handled internally)

=item cert_identifier

Returns the certificate for this cert_identifier. Allows you to easily check
if a given identifier exists or matches other attributes queries.

=item meta_*, system_*

Lets you search for any certificate attribute having a listed prefix.
You can set the special value I<<undef>> (including the angle brackets)
to search for rows without a certain attribute.

=item target_key

Name of the context value to write the result to, the default is
I<cert_identifier_list> resp. I<cert_identifier> when C<limit: single>
is used.

=item order

Sort the result, accepts a single column name, optionally
prefixed by "asc" (default) or "desc" (reversed sorting)

=item limit

Limit the size of the result set. If you pass the special word I<single>
the result is a scalar with the first identifier matching the query.
In case I<target_key> is not set, the value is written to I<cert_identifier>.

=item cert_identifier_ignore

Pass a single certificate identifier that is removed from the list in case
it was found. This is useful to exclude the certificate in the current
workflow when looking for e.g. duplicates.

=item include_expired

Parseable OpenXPKI::Datetime value (autodetected), certificates which are
expired after the given date are included in the report. Set to I<_any> to
include all expired certificates. Default is not to include expired
certificates.

=item include_revoked

If set to a true value, certificates which are not in ISSUED state
(revoked, crl pending, on hold) are also included in the report. Default
is to show only issued certificates.

=item valid_at

Parseable OpenXPKI::Datetime value (autodetected) used as base for validity
calculation. Default is now.

=item cutoff_notbefore

Parseable OpenXPKI::Datetime value (autodetected), show only certificates
where notebefore is between valid_at and this value. Relative intervals
are calculated against the given valid_at date!

=item cutoff_notafter

Parseable OpenXPKI::Datetime value (autodetected), show certificates where
notafter is less than value.  Relative intervals are calculated
against the given valid_at date!

=back
