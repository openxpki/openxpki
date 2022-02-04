package OpenXPKI::Server::Workflow::Activity::Tools::PrepareRenewal;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;


sub execute {

    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $context    = $workflow->context();

    my $cert_identifier = $self->param('cert_identifier');

    my $dbi = CTX('dbi');

    # select current certificate from database
    my $cert = $dbi->select_one(
        from => 'certificate',
        columns => [ 'subject', 'req_key', 'notbefore', 'notafter', 'identifier' ],
        where => {
            identifier => $cert_identifier,
            status    => 'ISSUED',
        },
    );

    if (!$cert) {
        CTX('log')->application()->error("certificate renewal identifier not found");
        OpenXPKI::Exception->throw(
            message => 'Prepare renewal certificate identifier not found ' . $cert_identifier ,
        );
    }

    my $prefix = $self->param('target_prefix') || '';

    $context->param( $prefix.'cert_subject' => $cert->{subject});

    # select subject alt names from database
    my $sth = $dbi->select(
        from   => 'certificate_attributes',
        columns => [ 'attribute_value' ],
        where => {
            attribute_contentkey => 'subject_alt_name',
            identifier           => $cert_identifier,
        },
    );

    my @subject_alt_names;
    while (my $san = $sth->fetchrow_hashref) {
        # If the value is serialized, deserialize it. If it's not, assume
        # that it is stored in the old colon-separated form and parse
        # it manually.
        if (OpenXPKI::Serialization::Simple::is_serialized($san->{attribute_value})) {
            push @subject_alt_names, $serializer->deserialize($san->{attribute_value});
        } else {
            my @split = split q{:}, $san->{attribute_value}, 2;
            push @subject_alt_names, \@split;
        }
    }
    ##! 64: 'subject_alt_names: ' . Dumper(\@subject_alt_names)
    $context->param(  $prefix.'cert_subject_alt_name' =>
                    $serializer->serialize(\@subject_alt_names));

    # look up the certificate profile via the csr table
    ##! 32: ' Look for old csr: ' . $cert->{req_key}
    my $old_profile = CTX('api2')->get_profile_for_cert( identifier => $cert_identifier );

    ##! 32: 'Found profile ' . $old_profile
    $context->param(  $prefix.'cert_profile' =>  $old_profile );

    $context->param( 'in_renewal_window' => 0 );
    $context->param( 'in_renewal_grace_period' => undef );

    # if certificate is expired already check for grace period setting

    if ($cert->{notafter} >= time) {
        my $renewal_notbefore = $self->param('renewal_period') || '000060';
        # Reverse calculation - the date wich must not be exceeded by notafter
        my $renewal_time = OpenXPKI::DateTime::get_validity({
            VALIDITY       => '+' . $renewal_notbefore,
            VALIDITYFORMAT => 'relativedate',
        })->epoch();

        if ($cert->{notafter} <= $renewal_time) {
            CTX('log')->application()->debug("renewal request for ".$cert->{subject}." is in renewal period ($cert_identifier)");
            $context->param('in_renewal_window' => 1);
        }

    } elsif ($self->param('renewal_grace_period')) {

        my $grace_period_time = OpenXPKI::DateTime::get_validity({
            VALIDITY       => '-' . $self->param('renewal_grace_period'),
            VALIDITYFORMAT => 'relativedate',
        })->epoch();
        CTX('log')->application()->debug("evaluated grace period for expired signer ($cert_identifier)");
        if ($cert->{notafter} > $grace_period_time) {
            $context->param( 'in_renewal_grace_period' => $grace_period_time );
            $context->param( 'in_renewal_window' => 1 );
        }

    }

    my $sources = $context->param('sources') ? $serializer->deserialize( $context->param('sources') ) : {};
    $sources->{'cert_profile'} = 'RENEWAL';
    $sources->{'cert_subject'} = 'RENEWAL';
    $sources->{'cert_subject_alt_name_parts'}  = 'RENEWAL';
    $context->param('sources' => $serializer->serialize($sources));

    return 1;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PrepareRenewal

=head1 Description

This activity sets the relevant context fields used for certificate renwal.

=head2 Parameters

=over

=item cert_identifier

Load information from this certificate.

=item renewal_period

A OpenXPKI::Datetime specification for the renewal period. Used to set the
I<in_renewal_window> return value. The default is 60 days.

=item renewal_grace_period

A OpenXPKI::Datetime specification for the renewal grace period. The grace
period allows the original certificate to be expired for the given period.

If the grace period was used, the I<in_renewal_grace_period> is set to a
true value.

=item target_prefix

If set, the keys cert_profile, cert_subject and cert_subject_alt_name are
prepended by this prefix. Optional, default is empty.

=back

=head2 Context Values

=over

=item in_renewal_window

Boolean, 1 if the notafter date of the renewal certificate is inside the
given validity window or 0 if not.

=item in_renewal_grace_period

Boolean, 1 if the renewal certificate was already expired but the notafter
date was within the given grace_period.

=item cert_profile

The profile of the renewal certiticate.

=item cert_subject

The subject of the renewal certiticate.

=item cert_subject_alt_name

Subject alternative names in array format as required by PersistCSR.

=back
