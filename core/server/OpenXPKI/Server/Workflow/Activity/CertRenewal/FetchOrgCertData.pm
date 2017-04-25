# OpenXPKI::Server::Workflow::Activity::CertRenewal::FetchOrgCertData
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CertRenewal::FetchOrgCertData;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;

    my $context = $workflow->context();
    ##! 32: 'context: ' . Dumper($context)
    my $dbi       = CTX('dbi');
    my $pki_realm = CTX('api')->get_pki_realm();

    my $cert_identifier = $context->param('org_cert_identifier');

    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $certificate = $dbi->select_one(
        from_join => 'certificate req_key=req_key csr',
        columns => [ 'certificate.subject', 'csr.profile' ],
        where => {
            'certificate.identifier' => $cert_identifier,
            'certificate.pki_realm'  => $pki_realm,
        }
    );

    $context->param( 'cert_profile' => $certificate->{'profile'} );
    $context->param( 'cert_subject' => $certificate->{'subject'} );

    my @subj_alt_names;
    my $cert_info = {};

    my $sth = $dbi->select(
        from => 'certificate_attributes',
        columns => [ 'attribute_key', 'attribute_contentkey' ],
        where => {
            'identifier' => $cert_identifier,
        },
    );

    while (my $metadata = $sth->fetchrow_hashref) {
        my $key   = $metadata->{attribute_contentkey};
        my $value = $metadata->{attribute_value};
        if ( $key eq 'subject_alt_name' ) {
            ##! 16: 'Adding SAN ' . $value
            # Type:Value
            my @t = split ":", $value;
            push @subj_alt_names, \@t;
        } else {
            ##! 16: 'Unknown certificate attribute ' . $key
        }
    }

    $context->param(
        'cert_subject_alt_name' => $serializer->serialize( \@subj_alt_names ),
    );

    my $source_ref;
    # PersistCertificate checks for the SAN Source, so we need to set this
    if (defined $context->param('sources')) { # deserialize if present
        ##! 32: 'sources defined'
        $source_ref = $serializer->deserialize(
            $context->param('sources')
        );
    }
    $source_ref->{'cert_subject_alt_name'} = 'renewal';

    $context->param( 'sources' => $serializer->serialize($source_ref) );

    ##! 32: 'context: ' . Dumper($context)
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CertRenewal::FetchOrgCertData

=head1 Description

Load data from the original certificate and populate context

=head2 Context parameters

=over

=item org_cert_identifier

The certificate identifier of the certificate to be renewed

=back

Writes the following context parameters:

=over 12

=item cert_profile

=item cert_subject

=item cert_subject_alt_name

=back

=head1 Functions

=head2 execute

Executes the action.
