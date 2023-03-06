package OpenXPKI::Server::Workflow::Activity::Tools::LoadCertificateMetadata;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

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
    my $attr = CTX('api2')->get_cert_attributes(
        identifier => $cert_identifier,
        attribute => 'meta_%'
    );
    ##! 128: $attr

    my $prefix = $self->param('prefix');
    my $target_key = $self->param('target_key');

    ##! 16: 'Prefix ' . $prefix
    ##! 16: $target_key

    my $context_data;
    foreach my $key (keys %{$attr}) {
        ##! 16: $key
        my $value = $attr->{$key};
        ##! 64: $value

        # replace the prefix if requested
        if ($prefix) {
            $key =~ s/^meta/$prefix/;

        # default is to set hash in target_key without prefix
        } elsif ($target_key) {
            $key = substr($key,5);

        }

        # collapse single value items
        if (@{$value} == 1) {
            ##! 32: 'collapse to scalar'
            $value = $value->[0];
            # legacy support - mutlivalues are now stored as individual lines
            if (OpenXPKI::Serialization::Simple::is_serialized($value)) {
                ##! 32: 'Deserialize '
                $value = $ser->deserialize( $value );
            }
        }

        $context_data->{$key} = $value;

    }

    CTX('log')->application()->debug('Found metadata keys '. join(", ", keys %{$context_data}) .' for ' . $cert_identifier);

    if ($target_key) {
        $context->param( $target_key => $context_data );
    } else {
        $context->param( $context_data );
    }

    return 1;
}

1;


=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::LoadCertificateMetadata

=head1 Description

Load the metadata assigned to a given certificate into the context.

Set the expected prefix for the keys using the parameter I<prefix>. If
no prefix value is given, the default I<meta> is used. Note: the prefix
must not end with the underscore, it is appended by the class.

If you set I<target_key>, the metadata is added to the context as a single
hash item to this context key. The default is to strip the prefix I<meta>
in this case but you can set an explicit prefix using I<prefix>.

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

=item target_key

Place the collected metadata into a single context item with this key.

=back

