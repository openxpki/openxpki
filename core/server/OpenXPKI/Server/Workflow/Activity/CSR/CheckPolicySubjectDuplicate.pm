
package OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicySubjectDuplicate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::DN;
use OpenXPKI::DateTime;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $target_key = $self->param('target_key') || 'check_policy_subject_duplicate';

    my $cert_subject = $self->param('cert_subject');
    $cert_subject = $context->param('cert_subject') unless(defined $cert_subject);

    # prevent creating havoc (subject is empty = no where query!)
    if (!$cert_subject) {
        $context->param( { $target_key => undef } );
         CTX('log')->application()->debug("Policy subject duplicate check skipped due to empty subject");

        return 1;
    }

    my $query = {
        STATUS => 'ISSUED',
        ENTITY_ONLY => 1,
    };

    if ($self->param('any_realm')) {
        ##! 32: 'Any realm requested'
        $query->{PKI_REALM} = '_ANY';
    }

    if ($self->param('cn_only')) {
        ##! 32: 'match cn only'
        my $dn = new OpenXPKI::DN( $cert_subject );
        my %hash = $dn->get_hashed_content();
        $query->{SUBJECT} = 'CN='.$hash{CN}[0].',%';
    } else {
        $query->{SUBJECT} = $cert_subject.'%';
    }

    if (my $renewal = $self->param('allow_renewal_period')) {
        ##! 16: 'Renewal allowed in period ' . $renewal
        my $notafter = OpenXPKI::DateTime::get_validity({
            VALIDITY => $renewal,
            VALIDITYFORMAT => 'detect',
        });

        $query->{NOTAFTER} = $notafter->epoch();
    } else {
        $query->{NOTAFTER} = time();
    }

    if (my $profile = $self->param('profile')) {
        $query->{PROFILE} = $profile;
    }

    ##! 32: 'Search duplicate with query ' . Dumper $query

    my $result = CTX('api')->search_cert($query);

    ##! 16: 'Search returned ' . Dumper $result
    my @identifier = map {  $_->{IDENTIFIER} } @{$result};

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

=back
