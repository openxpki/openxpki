
package OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicySubjectDuplicate;
use OpenXPKI;

use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DN;
use OpenXPKI::DateTime;
use OpenXPKI::Serialization::Simple;


sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $target_key = $self->param('target_key') || 'check_policy_subject_duplicate';

    my $cert_subject = $self->param('cert_subject');
    $cert_subject = $context->param('cert_subject') unless(defined $cert_subject);

    # prevent creating havoc (subject is empty = no WHERE clause!)
    if (!$cert_subject) {
        $context->param( { $target_key => undef } );
        CTX('log')->application()->debug("Policy subject duplicate check skipped due to empty subject");
        return 1;
    }

    my $query = {
        status => 'ISSUED',
        entity_only => 1,
        return_columns => 'identifier',
        tenant => '',
    };

    if ($self->param('any_realm')) {
        ##! 32: 'Any realm requested'
        $query->{pki_realm} = '_any';
    }

    if ($self->param('cn_only')) {
        ##! 32: 'match cn only'
        my $dn = OpenXPKI::DN->new( $cert_subject );
        my %hash = $dn->get_hashed_content();
        $query->{subject} = 'CN='.$hash{CN}[0].',%';
    } else {
        $query->{subject} = $cert_subject.'%';
    }

    if (my $renewal = $self->param('allow_renewal_period')) {
        ##! 16: 'Renewal allowed in period ' . $renewal
        my $notafter = OpenXPKI::DateTime::get_validity({
            VALIDITY => $renewal,
            VALIDITYFORMAT => 'detect',
        });

        $query->{expires_after} = $notafter->epoch();
    } else {
        $query->{expires_after} = time();
    }

    if (my $profile = $self->param('profile')) {
        $query->{profile} = $profile;
    }

    ##! 32: 'Search duplicate with query ' . Dumper $query

    my $result = CTX('api2')->search_cert(%{$query});

    ##! 16: 'Search returned ' . Dumper $result

    my $ignore = $self->param('cert_identifier_ignore') || '';

    my @identifier = map {  ($_->{identifier} eq $ignore) ? () : $_->{identifier} } @{$result};

    if (@identifier) {

        my $ser = OpenXPKI::Serialization::Simple->new();
        $context->param( $target_key , $ser->serialize(\@identifier) );

        CTX('log')->application()->info("Policy subject duplicate check failed, found certs " . (join ", ", @identifier));


    } else {

        $context->param( { $target_key => undef } );

    }

    return 1;
}

1;

=head1 NAME

OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicySubjectDuplicate

=head1 DESCRIPTION

Check if another certificate with the same subject already exists. The
default is to check against entity certificates in the same realm which
are not expired and not revoked. This includes certificates with a
notbefore date in the future!
See the parameters section for other search options.

=head1 Configuration

=head2 Activity Parameters

=over

=item target_key

Default is check_policy_subject_duplicate, holds list of identifiers found.

=item any_realm

Boolean, search certificates globally.

=item profile

Only search for certificates with this profile. Hint: Use the _map_syntax
to grab the profile from the workflow.

=item cn_only

Check only on the common name of the certificate.

=item allow_renewal_period

Set to a OpenXPKI::DateTime validity specification (eg. +0003 for three
month) to allow renewals within a defined period. Certificates which expire
within the given period are not considered to trigger a duplicate error.

=item cert_identifier_ignore

Pass a single certificate identifier that is removed from the list in case
it was found. This is useful when running this check on a renewal/replace
workflow where you already know there is one matching certificate.

=back
