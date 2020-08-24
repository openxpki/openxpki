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

    return unless ($cert_identifier);

    # one of error, overwrite, merge, skip
    my $mode = $self->param('mode') || 'error';

    if ($mode !~ /(error|overwrite|skip|merge)/) {
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

        my $attr = CTX('api2')->get_cert_attributes(
            identifier => $cert_identifier,
            attribute => $key
        );
        my $item = $attr->{$key};

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
            CTX('log')->application()->info("Append (set) certificate metadata $key with $value");

        } elsif ($mode eq 'skip') {
            CTX('log')->application()->info("Key already exists, skip certificate metadata with $key with $value");

        } elsif ($mode eq 'overwrite') {

            if (scalar @{$item} > 1) {
                OpenXPKI::Exception->throw (
                    message => "Append Certificate Metadata item is not scalar but overwrite expected",
                    params => { KEY => $key }
                );
            }

            $dbi->update(
                table => 'certificate_attributes',
                set => {
                    attribute_value  => $value,
                },
                where => {
                    attribute_contentkey => $key,
                    identifier           => $cert_identifier,
                }
            );
            CTX('log')->application()->info("Overwrite certificate metadata $key with $value");

        } elsif ($mode eq 'merge') {

            if ((grep { $_ eq $value } @{$item}) == 0) {
                $dbi->insert(
                    into => 'certificate_attributes',
                    values => {
                        attribute_key        => AUTO_ID,
                        identifier           => $cert_identifier,
                        attribute_contentkey => $key,
                        attribute_value      => $value,
                    }
                );
                CTX('log')->application()->info("Append (merge) certificate metadata $key with $value");
            } else {

                CTX('log')->application()->info("Value already exists, skip certificate metadata with $key with $value");
            }

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

=head2 Mode

=over

=item error

If the used key is already present, an exception is thrown. This is the default.

=item skip

The new value is discarded, the old one will remain in the table.

=item overwrite

The old value is replaced by the new one, expects that only one value exists.
If multiple values have been found, an exception is thrown.

=item merge

Add the new value if it does not already exists, will also work if the key
is defined more than once.

=back
