package OpenXPKI::Server::Workflow::Activity::CertRenewal::DetermineSubjectStyle;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;


sub execute {

    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $pki_realm  = CTX('session')->data->pki_realm;
    my $context    = $workflow->context();

    my $cert_identifier = $self->param('cert_identifier') // $context->param('cert_identifier');
    my $cert_profile    = $self->param('cert_profile') // $context->param('cert_profile');

    my $prefix = $self->param('target_prefix') || '';

    if (!$cert_identifier || !$cert_profile) {
        CTX('log')->application()->warn("cert_identifier and/or cert_profile not set");
        $context->param( $prefix.'cert_subject_style' => undef );
        return;
    }

    my $dbi = CTX('dbi');

    # try to grab cert_subject_style from the old workflow
    # works only with standard workflows but fails silenty
    my $csr_wf_id = $dbi->select_one(
        from   => 'certificate_attributes',
        columns => [ 'attribute_value' ],
        where => {
            attribute_contentkey => 'system_workflow_csr',
            identifier           => $cert_identifier,
        },
    );

    ##! 16: 'CSR Workflow ' . Dumper $csr_wf_id

    my $cert_subject_style;
    if ($csr_wf_id) {

        CTX('log')->application()->debug("Searching in workflow " . $csr_wf_id->{attribute_value});

        my $res = $dbi->select_one(
            from   => 'workflow_context',
            columns => [ 'workflow_context_value' ],
            where => {
                workflow_context_key => 'cert_subject_style',
                workflow_id          => $csr_wf_id->{attribute_value},
            },
        );
        $cert_subject_style = $res->{'workflow_context_value'};
        CTX('log')->application()->debug("Subject style $cert_subject_style found in workflow");

    }

    ##! 16: 'Workflow Context ' . Dumper $cert_subject_style

    if ($cert_subject_style) {
        if (!CTX('config')->exists(['profile', $cert_profile, 'style', $cert_subject_style, 'ui' ])) {
            CTX('log')->application()->warn("Subject style $cert_subject_style was removed as it does not exist in profile $cert_profile");
            $cert_subject_style = undef;
        }
    }

    my $fallback_policy = $self->param('fallback_policy') || '';

    if ($cert_subject_style) {
        CTX('log')->application()->debug("Subject style $cert_subject_style validated in profile");

    } elsif ($fallback_policy eq 'none') {

        CTX('log')->application()->warn("No subject style found, fallback policy is none.");

    } else {
        my @styles = CTX('config')->get_keys(['profile', $cert_profile, 'style' ]);
        my @uistyles;
        foreach my $style (sort @styles) {
            if (CTX('config')->exists(['profile', $cert_profile, 'style', $style, 'ui' ])) {
                push @uistyles, $style;
                if ($fallback_policy ne 'unique') {
                    last;
                }
            }
        }

        if (!scalar @uistyles) {
            CTX('log')->application()->warn("No usable subject style found in profile $cert_profile.");
        } elsif (scalar @uistyles == 1) {
            $cert_subject_style = shift @uistyles;
            CTX('log')->application()->warn("Subject style $cert_subject_style was autodetected for profile $cert_profile");
        } else {
            CTX('log')->application()->warn("Ambigous result for subject style in profile $cert_profile.");
        }

    }

    $context->param( $prefix.'cert_subject_style' => $cert_subject_style );

    return 1;
}


1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::DetermineSubjectStyle

=head1 Description

Determine a subject style to use during renewal of a certificate. The
activity first tries to find the initial CSR workflow of the given
certificate and to load the value of I<cert_subject_style> from the context.
If found, it checks if this value exists and has a "UI" section in the given
profile.

If no subject style can be found this way, it takes the first subject style
from the given profile that has an UI section. See I<fallback_policy> to
fine tune this behaviour.

=head2 Parameters

=over

=item cert_identifier

=item cert_profile

=item target_prefix (optional)

If set, the key cert_subject_style is prepended by this prefix,
default is empty.

=item fallback_policy (optional)

Set to I<unique> if you only want to accept a "guessed" result if it is
uambigous, which means there is only one style with an UI section in the
profile so it is the only possible option.

Set to I<none> if you dont want any "guessing" in case the original
subject style is not found.

=back


=head2 Context Values

=over

=item cert_identifier

Used as fallback if activity parameter is not set

=item cert_profile

Used as fallback if activity parameter is not set

=back

=head2 Context Values Written

=over

=item cert_subject_style

Contains the used cert_subject_style, if found.

=back
