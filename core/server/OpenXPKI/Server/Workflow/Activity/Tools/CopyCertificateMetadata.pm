package OpenXPKI::Server::Workflow::Activity::Tools::CopyCertificateMetadata;
use OpenXPKI -base => 'OpenXPKI::Server::Workflow::Activity';

use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw(configuration_error);

sub execute {
    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $params = $self->param();

    my $source_cert_identifier = $self->param('source_cert_identifier');
    my $cert_identifier = $self->param('cert_identifier') || $context->param('cert_identifier');

    ##! 16: ' cert_identifier' . $cert_identifier

    # one of error, overwrite, merge, skip
    my $mode = $self->param('mode') || 'merge';

    if ($mode !~ /(error|overwrite|update|skip|merge)/) {
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

    my %attrib;
    while (my $item = $sth_attrib->fetchrow_hashref) {
        ##! 32: 'Value ' . Dumper $item
        my $key = $item->{attribute_contentkey};
        $key =~ s/\Ameta_//;
        my $val = $item->{attribute_value};
        if (exists $attrib{$key}) {
            $attrib{$key} = [ $attrib{$key} ] unless ref $attrib{$key};
            push @{$attrib{$key}}, $val;
        } else {
            $attrib{$key} = $val;
        }
    }

    ##! 16: 'Attributes to copy: ' . Dumper \%attrib
    return unless %attrib;

    CTX('api2')->set_cert_metadata(
        identifier => $cert_identifier,
        attribute  => \%attrib,
        mode       => $mode,
    );

}

1;


__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CopyCertificateMetadata

=head1 Description

Copy certificate metadata from one certificate to another, uses the set_cert_me

=head2 Configuration

    class: OpenXPKI::Server::Workflow::Activity::Tools::CopyCertificateMetadata
    param:
       source_cert_identifier: 2DLIufyJvo0yJDLIuf346
       cert_identifier: 0utS7yqMTAy2DLIufyJvoc2GSCs
       attribute: email requestor
       mode: merge

=head2 Parameters

=over

=item * C<source_cert_identifier> I<Str> - identifier of the certificate to copy attributes from

=item * C<cert_identifier> I<Str> - target certificate identifier; falls back to the workflow context value

=item * C<attribute> I<Str|ArrayRef> - space-separated list or array ref of attribute names to copy.
The C<meta_> prefix is added internally and must not be provided.
If omitted, all C<meta_*> attributes are copied.

=item * C<mode> I<Str> - conflict handling mode passed to C<set_cert_metadata>, default is C<merge>.

=back
