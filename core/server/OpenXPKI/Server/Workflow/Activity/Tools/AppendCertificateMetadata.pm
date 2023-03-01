package OpenXPKI::Server::Workflow::Activity::Tools::AppendCertificateMetadata;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Database; # to get AUTO_ID
use Workflow::Exception qw(configuration_error workflow_error);

sub execute {
    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $params = $self->param();

    my $ser  = OpenXPKI::Serialization::Simple->new();

    my $cert_identifier = $self->param('cert_identifier');
    ##! 16: ' cert_identifier' . $cert_identifier

    return unless ($cert_identifier);

    # one of error, overwrite, merge, skip
    my $mode = $self->param('mode') || 'error';

    if ($mode !~ /(error|overwrite|skip|merge)/) {
        configuration_error('Invalid mode ' . $mode);
    }


    my $attr;
    foreach my $key (keys %{$params}) {
        next unless($key =~ /^meta_(.*)/);
        $attr->{$1} = $params->{$key};
    }

    CTX('api2')->set_cert_metadata(
        identifier => $cert_identifier,
        attribute => $attr,
        mode => $mode
    );

    return 1;

}

1;


__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::AppendCertificateMetadata

=head1 Description

Add arbitrary key/value items as certificate metadata.

The activitiy will exit silently if cert_identifier is not set.

=head2 Configuration

    class: OpenXPKI::Server::Workflow::Activity::Tools::AppendCertificateMetadata
    param:
       cert_identifier: 0utS7yqMTAy2DLIufyJvoc2GSCs
       mode: overwrite
       meta_new_attribute: my_value

This will attach a new metadata item with the key meta_new_attribute and
value my_value for the given identifier. This information does not depend
on any metadata settings in the certificates profile!

You can pass multiple attributes prefixed with I<meta_>, the value can
either be a scalar value or an array. The value hash and the mode will
passed to I<set_cert_metadata>, check there for the modes and their
prerequisites.