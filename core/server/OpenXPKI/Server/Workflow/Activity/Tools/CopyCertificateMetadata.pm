package OpenXPKI::Server::Workflow::Activity::Tools::CopyCertificateMetadata;

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

    my $source_cert_identifier = $self->param('source_cert_identifier');
    my $cert_identifier = $self->param('cert_identifier') || $context->param('cert_identifier');

    ##! 16: ' cert_identifier' . $cert_identifier

    # one of error, overwrite, merge, skip
    my $mode = $self->param('mode') || 'error';

    if ($mode !~ /(error|overwrite|skip)/) {
        configuration_error('Invalid mode ' . $mode);
    }

    ##! 16: ' parameters: ' . Dumper $params

    my @attribute;
    if (my $attribute = $self->param('attribute')) {
        if (ref $attribute) {
            @attribute = map { 'meta_'.$_ } @{$attribute};
        } else {
            @attribute = map { 'meta_'.$_ } split /\s+/, $attribute;
        }
    } else {
        @attribute = ('meta_%');
    }

    ##! 16: 'Attributes: ' . Dumper \@attribute

    my $dbi = CTX('dbi');
    my $sth_attrib = $dbi->select(
        from => 'certificate_attributes',
        columns => [ 'attribute_contentkey', 'attribute_value' ],
        where => {
            identifier => $source_cert_identifier,
            attribute_contentkey => { -like => \@attribute }
        }
    );

    while (my $item = $sth_attrib->fetchrow_hashref) {
        ##! 32: 'Value ' . Dumper $item
        $dbi->insert(
            into => 'certificate_attributes',
            values => {
                attribute_key        => AUTO_ID,
                identifier           => $cert_identifier,
                attribute_contentkey => $item->{attribute_contentkey},
                attribute_value      => $item->{attribute_value},
            }
        );
    }



}

1;


__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CopyCertificateMetadata

=head1 Description

Copy certificate meta_ attributes from one certificate to another. The
target is NOT checked for any existing data.

=head2 Configuration

    class: OpenXPKI::Server::Workflow::Activity::Tools::CopyCertificateMetadata
    param:
       source_cert_identifier: 2DLIufyJvo0yJDLIuf346
       cert_identifier: 0utS7yqMTAy2DLIufyJvoc2GSCs
       attribute: email requestor

Load the metadata attributes named by I<attribute> from the certificate
given as I<source_cert_identifier> and write them to I<cert_identifier>.

The meta_ prefix is added internally and must not ne provided, if attributes
is omited all attributes with the meta_ prefixed are copied. Attributes can
be stated as a space separated list or directly as array ref.


