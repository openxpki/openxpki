package OpenXPKI::Server::Workflow::Activity::Tools::BuildPKCS7CertList;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use MIME::Base64;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Crypt::PKCS7::CertificateList;
use Workflow::Exception qw(configuration_error);


sub execute {

    ##! 1: 'start'

    my $self = shift;
    my $workflow = shift;
    my $context = $workflow->context();

    my $certificate = $self->param('certificate');
    my $cert_identifier_list = $self->param('cert_identifier_list') || [];

    my $target_key = $self->param('target_key') || 'pkcs7';

    my $p7 = OpenXPKI::Crypt::PKCS7::CertificateList->new();

    $p7->keep_duplicates(1) if ($self->param('keep_duplicates'));

    # support array or concatenated PEM
    my @certs;
    if (ref $certificate eq 'ARRAY') {
        ##! 32: 'Adding from certificate array'
        ##! 64: $certificate
        @certs = @$certificate;
    } elsif ($certificate) {
        ##! 32: 'Adding from certificate pem bundle'
        @certs = ($certificate =~ m{ ( -----BEGIN\ [\w\s]*CERTIFICATE----- [^-]+ -----END\ [\w\s]*CERTIFICATE----- ) }gmsx );
        ##! 64: \@certs
    }
    # the add_cert method can also handle PEM blocks
    map { $p7->add_cert( $_ ) } @certs;

    foreach my $cert_identifier (@$cert_identifier_list) {
        ##! 32: 'Adding from identifier ' . $cert_identifier
        $p7->add_cert( CTX('api2')->get_cert( identifier => $cert_identifier, format => 'DER' ) );
    }

    my $format = $self->param('format') || 'PEM';
    if ($format eq 'PEM') {
        $context->param( $target_key => $p7->pem() );

    } elsif ($format ne 'DER') {
        configuration_error('Invalid format string given');

    } elsif ($self->param('base64')) {
        $context->param( $target_key => encode_base64($p7->data(),'') );

    } else {
        $context->param( $target_key => $p7->data() );

    }

    return 1;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::BuildPKCS7CertList

=head1 Description

Convert a list of certificates into a PKCS7 certificates-only structure.

Certificates can be given directly as PEM blocks or as a list of
cert_identifiers. The order of the given lists is preserved, if both
parameters are set the PEM blocks will be added to the list first.

=head1 Configuration

=head2 Activity parameters

=over

=item certificate

A list of PEM blocks to be contained in the PKCS7 structure. can be
either an array of strings holding the individual PEM blocks or a single
string with the PEM blocks concatenated.

=item cert_identifier_list

The list of certificate identifiers to be contained in the PKCS7
structure.

=item format, optional

=over

=item PEM

Export the PKCS7 structure in PEM encoding to the given I<target_key>

=item DER

Export the PKCS7 structure as binary data (DER) to the given
I<target_key>. Do not export binary data to non-volatile context keys!

=back

=item target_key, optional

The context key to write the result to, default is I<certificate_export>.
Note: If you export a key and use a persisted workflow, this will leave the
(password protected) key readable in the context forever.

=item base64, optional

Boolean, if set the output is wrapped by a base64 encoding to avoid raw
binary data in context. Only available with format DER or PKCS7DER.
Ineffective when a template is set, use the template definition instead.

=item keep_duplicates, optional

Boolean, while the order of certificates in the input is preserved, any
duplicates found will be removed from the list after their first
occurence. If you set this to true, duplicates will appear repeatedly
in the output structure.

=back

