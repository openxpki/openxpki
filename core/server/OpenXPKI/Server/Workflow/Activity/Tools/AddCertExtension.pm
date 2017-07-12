package OpenXPKI::Server::Workflow::Activity::Tools::AddCertExtension;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use English;
use Workflow::Exception qw( configuration_error );

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    ##! 1: 'start'

    my $value = $self->param('value');
    if (!$value) {
        return;
    }

    my $oid = $self->param('oid');
    my $format = $self->param('format') || '';
    my $encoding = $self->param('encoding') || '';
    my $critical = $self->param('critical') || 0;

    my $ext = { oid => $oid, critical => $critical };
    if ($encoding eq 'SEQUENCE') {
        ##! 16: 'sequence mode'
        $ext->{section} = $value;
    } else {
        ##! 16: 'scalar mode'
        if ($encoding) {
            $value = $encoding.':'.$value;
        }
        if ($format) {
            $value = $format.':'.$value;
        }
        $ext->{value} = $value;
    }

    ##! 32: 'Setting extension ' . Dumper $ext

    my $cert_extension = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
        { workflow => $workflow, context_key => 'cert_extension' } );

    $cert_extension ->push( $ext );

    return 1;

}


1;

__END__;


=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::AddCertExtension

=head1 Description

Add a new item to the cert_extension list. The items get persisted and
added to the certificate on issue. Running this activity is equal to
adding the data to the profiles OID section. See the profile documentation
for details on the parameters.

=head1 Configuration

=head2 Parameters

=over

=item oid

oid of the extension (numeric notation, named oids are not accepted).

=item format, optional

the format of the item, usually ASN1 or DER.

=item encoding, optional

encoding of the item

=item value

value to set, in case you set encoding to SEQUENCE, the value must be
a valid string to be added as section in the openssl config file. If
the value is empty, nothing is added.

=item critical

Set to 1 to mark this extension as critical

=back

=head1 Example

To get the extension data in the context you must add the oid names to
the PCSK10 parser activity:

    class: OpenXPKI::Server::Workflow::Activity::Tools::ParsePKCS10
    param:
       req_extensions: certificateTemplate certificateTemplateName

=head2 Single value

Add the certificateTemplateName extension using the value extracted from
the PKCS10 request by the parser.

    class: OpenXPKI::Server::Workflow::Activity::Tools::AddCertExtension
    param:
        oid: 1.3.6.1.4.1.311.20.2
        format: ASN1
        encoding: UTF8String
        _map_value: "[% context.req_extensions.certificateTemplateName %]"

=head2 Example - Nested Sequence

    class: OpenXPKI::Server::Workflow::Activity::Tools::AddCertExtension
    param:
        oid: 1.3.6.1.4.1.311.21.7
        format: ASN1
        encoding: SEQUENCE
        _map_value: |
            [% IF context.req_extensions.certificateTemplate %]
            field1=OID:[% context.req_extensions.certificateTemplate.templateID %]
            field2=INT:[% context.req_extensions.certificateTemplate.templateMajorVersion %]
            field3=INT:[% context.req_extensions.certificateTemplate.templateMinorVersion %]
            [% END %]