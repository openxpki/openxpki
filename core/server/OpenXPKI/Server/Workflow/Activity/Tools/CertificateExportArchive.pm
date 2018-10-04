package OpenXPKI::Server::Workflow::Activity::Tools::CertificateExportArchive;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use MIME::Base64 qw(encode_base64);
use Workflow::Exception qw(configuration_error);

sub execute {

    ##! 1: 'start'

    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();

    my $cert_identifier = $self->param('cert_identifier');
    my $key_password = $self->param('key_password');

    my $target_key = $self->param('target_key') || 'certificate_export';

    my $chain = CTX('api')->get_chain({ START_IDENTIFIER => $cert_identifier, OUTFORMAT => 'PEM'});
    my @certs = @{$chain->{CERTIFICATES}};

    my $zip = Archive::Zip->new();

    my $crt_file = $self->param('crt_file') || 'cert.pem';
    my $key_file = $self->param('key_file') || 'key.pem';
    my $chain_file = $self->param('chain_file') || 'chain.pem';

    my $privkey;
    eval {

        my $p = {
            IDENTIFIER =>  $cert_identifier,
            FORMAT => 'OPENSSL_PRIVKEY',
            PASSWORD => $key_password,
        };

        my $export_password = $self->param('export_password');
        if (defined $export_password) {
            if ($export_password ne '') {
                $p->{PASSOUT} = $export_password;
            } elsif ($self->param('unencrypted')) {
                $p->{PASSOUT} = '';
                $p->{NOPASSWD} = 1;
            }
        }
        $privkey = CTX('api')->get_private_key_for_cert($p);
    };
    if (!$privkey) {

        CTX('log')->application()->error("Export of private key failed for $cert_identifier");

        if ($self->param('die_on_error')) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_UI_EXPORT_CERTIFICATE_FAILED_TO_LOAD_PRIVATE_KEY'
            );
        }

        $context->param( $target_key => '');
        return;

    }

    CTX('log')->application()->info("Export of private key to archive for $cert_identifier");


    CTX('log')->audit('key')->info("private key export to archive", {
        certid => $cert_identifier
    });

    $zip->addString( $privkey->{PRIVATE_KEY}, $key_file )
        ->desiredCompressionMethod( COMPRESSION_DEFLATED );

    my $chain = CTX('api')->get_chain({ START_IDENTIFIER => $cert_identifier, OUTFORMAT => 'PEM'});
    my @certs = @{$chain->{CERTIFICATES}};

    $zip->addString( shift @certs, $crt_file )
        ->desiredCompressionMethod( COMPRESSION_DEFLATED );

    $zip->addString( join("\n", @certs), $chain_file )
        ->desiredCompressionMethod( COMPRESSION_DEFLATED );

    # create in memory file handle
    my $buffer;
    open( my $fh, '>', \$buffer);
    if ( !$fh || ( $zip->writeToFileHandle( $fh ) != AZ_OK ) ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_ERROR_WRITING_IN_MEMORY_ARCHIVE'
        );
    }

    if ($self->param('base64') || ($target_key !~ /\A_/)) {
        $buffer = encode_base64( $buffer );
    }

    $context->param( $target_key => $buffer );

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CertificateExportArchive

=head1 Description

Create a zip archive holding certifcate, key (openssl native format) and
all chain certificates including the root, all certs are PEM encoded.
The archive is written to the context at the given target_key. If the
target_key does not start with an underscore, the archive data is encoded
using base64.

=head1 Configuration

=head2 Activity parameters

=over

=item cert_identifier

The cert to be exported.

=item key_password

The password which was used to persist the key, also used for encrypting
the exported key if export_password is not set.

=item key_file, optional

The filename used inside the archive for the key, default is key.pem

=item crt_file, optional

The filename used inside the archive for the certificate, default is cert.pem

=item chain_file, optional

The filename used inside the archive for the ca/chain, default is chain.pem

=item export_password, optional

Encrypt the key with this password instead of the input password. Ignored
if empty, to export unencrypted, you must also set the I<unencrypted> flag.

=item unencrypted, optional

Set this to a boolean true value AND set I<export_password> to the empty
string to export the key unencrypted.

=item die_on_error, optional

Boolean, if true the activity will throw an exception if the private key
could not be restored (which usually means that the wrong password was
provided). If false/not set, the target_key is just empty on error.

=item target_key, optional

The context key to write the result to, default is I<certificate_export>.
Note: If you use a persisted workflow, this will leave the (password
protected) key readable in the context forever.

=back

