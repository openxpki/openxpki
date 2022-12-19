package OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Database; # to get AUTO_ID
use Log::Log4perl;

sub execute {
    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $ser  = OpenXPKI::Serialization::Simple->new();
    my $dbi = CTX('dbi');

    my $cert_identifier = $context->param('cert_identifier');
    ##! 16: 'cert_identifier: ' . $cert_identifier

    my $param = $context->param();
    ##! 32: 'Update request: ' . Dumper $param

    my $metadata = {};
    for my $key (keys %{$param}) {
        next if ($key !~ m{ \A meta_ }xms);

        # deprecated - context key with extra brackets
        if ($key =~ m{ \A (\w+)\[\] }xms) {
            $key = $1;
            CTX('log')->deprecated->error("Deprecated usage of square brackets in field name ($key)");
        }

        my @new_values;
        if (ref $param->{$key} eq 'ARRAY') {
            ##! 32: "attribute $key treated as ARRAY"
            @new_values = @{ $param->{$key} };
        } elsif (OpenXPKI::Serialization::Simple::is_serialized($param->{$key})) {
            ##! 32: "attribute $key treated as ARRAY (serialized)"
            @new_values = @{$ser->deserialize( $param->{$key} )};
        } elsif ($param->{$key}//'' ne '') {
            ##! 32: "attribute $key treated as SCALAR"
            @new_values = ($param->{$key});
        }

        # strip the meta_ prefix from the key
        $key = substr($key,5);
        $metadata->{$key} = \@new_values;

    }

    ##! 32: 'Metadata is ' . Dumper $metadata
    CTX('api2')->set_cert_metadata(
        identifier => $cert_identifier,
        attribute  => $metadata,
        mode  => 'overwrite',
    );

    return 1;
}

1;

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata

=head1 Description

Update the metadata stored in certificate_attributes with information
taken from the current workflow context.

=head2 Context Items

=over

=item cert_identifier

The identifier of the certificate to update

=item meta_*

Any key in the context starting with I<meta_*> is considered to contain
the expected information, set a key to an empty empty value to remove
the original data from the system. Existing metadata items that do not
have a matching key in the context are not modified.

=back