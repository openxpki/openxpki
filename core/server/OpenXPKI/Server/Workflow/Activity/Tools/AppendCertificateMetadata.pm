package OpenXPKI::Server::Workflow::Activity::Tools::AppendCertificateMetadata;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Database; # to get AUTO_ID
use Data::Dumper;
use Workflow::Exception qw(configuration_error workflow_error);

sub execute {
    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $params = $self->param();

    my $ser  = OpenXPKI::Serialization::Simple->new();

    my $cert_identifier = $self->param('cert_identifier');
    ##! 16: ' cert_identifier' . $cert_identifier

    # one of error, overwrite, merge, skip
    my $mode = $self->param('mode') || 'error';

    if ($mode !~ /(error|overwrite|skip)/) {
        configuration_error('Invalid mode ' . $mode);
    }

    ##! 16: ' parameters: ' . Dumper $params


    my $dbi = CTX('dbi');

  KEY:
    foreach my $key (keys %{$params}) {

        if ($key !~ /^meta_/) {
            next KEY;
        }

        ##! 16: 'Key ' . $key
        my $value = $self->param($key);

        if (! defined $value || $value eq '') {
            $self->log->debug('Skipping $key as value is empty');
            next KEY;
        }

         my $dbi_cert_metadata = $dbi->select(
            from => 'certificate_attributes',
            columns => ['*'],
            where => {
                identifier => $cert_identifier,
                attribute_contentkey => $key,
            },
        );
        my $item = $dbi_cert_metadata->fetchrow_hashref;

        if (!$item) {
            $dbi->insert(
                into => 'certificate_attributes',
                values => {
                    attribute_key        => AUTO_ID,
                    identifier           => $cert_identifier,
                    attribute_contentkey => $key,
                    attribute_value      => $value,
                }
            );
            CTX('log')->application()->info("Append certificate metadata $key with $value");

        } elsif ($mode eq 'skip') {
            CTX('log')->application()->info("Key already exists, skip certificate metadata with $key with $value");

        } elsif ($mode eq 'overwrite') {
            $dbi->update(
                into => 'certificate_attributes',
                set => {
                    attribute_value  => $value,
                },
                where => {
                    attribute_key    => $item->{attribute_key},
                }
            );
            CTX('log')->application()->info("Overwrite certificate metadata $key with $value");

        } else {
            OpenXPKI::Exception->throw (
                message => "Append Certificate Metadata item exists",
                params => { KEY => $key }
            );
        }

    }
    return 1;

}

1;


__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::AppendCertificateMetadata

=head1 Description

Add arbitrary key/value items as certificate metadata

=head2 Configuration

    class: OpenXPKI::Server::Workflow::Activity::Tools::AppendCertificateMetadata
    param:
       cert_identifier: 0utS7yqMTAy2DLIufyJvoc2GSCs
       mode: overwrite
       meta_new_attribute: my_value

This will attach a new metadata item with the key meta_new_attribute and
value my_value for the given identifier. This information does not depend
on any metadata settings in the certificates profile!

Metadata is assumed to have a scalar value and each key only exists once
per certificate. The behaviour if the key already exists is controlled by
the I<mode> parameter.

=head2 Mode

=over

=item error

If the used key is already present, an exception is thrown.

=item skip

The new value is discarded, the old one will remain in the table.

=item overwrite

The old value is replaced by the new one.

=back

