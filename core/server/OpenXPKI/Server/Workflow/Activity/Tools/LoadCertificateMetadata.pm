package OpenXPKI::Server::Workflow::Activity::Tools::LoadCertificateMetadata;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $params = $self->param();

    my $ser  = OpenXPKI::Serialization::Simple->new();

    my $cert_identifier = $self->param( 'cert_identifier' )
        || $context->param( 'cert_identifier' );

    if (! defined $cert_identifier) {
        OpenXPKI::Exception->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_LOADCERTIFICATEMETADATA_CERT_IDENTIFIER_NOT_DEFINED',
        );
    }

    ##! 16: 'cert_identifier ' . $cert_identifier
    my $sth = CTX('dbi')->select(
        from => 'certificate_attributes',
        columns => [ 'attribute_contentkey', 'attribute_value' ],
        where => {
            identifier => $cert_identifier,
            attribute_contentkey => { -like => 'meta_%' },
        },
    );

    my $prefix = $self->param('prefix') || 'meta';
    ##! 16: 'Prefix ' . $prefix

    my $context_data;
    ##! 16: ' Size of cert_metadata '. scalar( @{$cert_metadata} )
    while (my $metadata = $sth->fetchrow_hashref) {
        ##! 32: 'Examine Key ' . $metadata->{ATTRIBUTE_KEY}
        my $key = $metadata->{attribute_contentkey};
        my $value = $metadata->{attribute_value};
        if (OpenXPKI::Serialization::Simple::is_serialized($value)) {
            ##! 32: 'Deserialize '
            $value = $ser->deserialize( $value );
        }

        # find multivalues
        if ($context_data->{$key}) {
            ##! 32: 'set multivalue context for ' . $key
            # on second element, create array with first one
            if (!ref $context_data->{$key}) {
                $context_data->{$key} = [ $context_data->{$key} ];
            }
            push @{$context_data->{$key}}, $value;
        } else {
            ##! 32: 'set scalar context for ' . $key
            $context_data->{$key} = $value;
        }
    }

    # write to the context, serialize non-scalars and add []
    foreach my $key (keys %{$context_data}) {
        my $val = $context_data->{$key};
        my $tkey = $key;
        if ($prefix ne 'meta') {
            $tkey =~ s/^meta/$prefix/;
        }

        if (ref $context_data->{$key}) {
            ##! 64: 'Set key ' . $tkey . ' to array ' . Dumper $val
            $context->param( $tkey.'[]' => $ser->serialize( $val  ) );
        } else {
            ##! 64: 'Set key ' . $key . ' to ' . $val
            $context->param( $tkey => $val  );
        }
    }

    CTX('log')->application()->debug('Found metadata keys '. join(", ", keys %{$context_data}) .' for ' . $cert_identifier);


    return 1;
}

1;


=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::LoadCertificateMetadata;

=head1 Description

Load the metadata assigned to a given certificate into the context.

Set the expected prefix for the keys using the parameter I<prefix>. If
no prefix value is given, the default I<meta> is used. Note: the prefix
must not end with the underscore, it is appended by the class.


=head1 Configuration

Minimum configuration does not require any parameter and will read the
certificate identifier to load from the context value I<cert_identifier>.
This given snippet behaves the same as a call without any parameters.

  class: OpenXPKI::Server::Workflow::Activity::Tools::LoadCertificateMetadata
  param:
      _map_cert_identifier: $cert_identifier
      prefix: meta

=head2 Activity parameters

=over

=item prefix

A custom prefix to write the metadata to. Note that the activity will
not take care of any existing data if the key already exists!

=item cert_identifier

The identifier of the cert to load, default is the value of the context
key cert_identifier.

=back

