package OpenXPKI::Server::Workflow::Activity::Tools::CertificateExport;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Template;
use OpenXPKI::Debug;
use Data::Dumper;
use File::Temp;

sub execute {

    ##! 1: 'start'

    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();

    my $cert_identifier = $self->param('cert_identifier');
    my $key_password = $self->param('key_password');
    my $template = $self->param('template');

    my $target_key = $self->param('target_key') || 'certificate_export';

    my $key;

    # no template, no key, just export the plain certificate
    if (!$template && !defined $key_password) {

        my $cert = CTX('api')->get_cert({ IDENTIFIER => $cert_identifier, FORMAT => 'PEM'});
        $context->param( $target_key  => $cert );

    } elsif (defined $key_password) {
        my $privkey;
        eval {

            my $key_format = $self->param('key_format') || 'OPENSSL_PRIVKEY';
            my $alias = $self->param('alias') || '';

            my $p = {
                IDENTIFIER =>  $cert_identifier,
                FORMAT => $key_format,
                PASSWORD => $key_password,
                ALIAS => $alias,
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

            if ( $self->param('include_root_cert') ) {
                $p->{KEEPROOT} = 1;
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
            $context->param( $target_key  => '');

        } else {

            CTX('log')->application()->info("Export of private key to context for $cert_identifier");

            CTX('log')->audit('key')->info("private key export to context", {
                certid => $cert_identifier
            });

            # If no template is given, we export only the private key
            if (!$template) {
                $context->param( $target_key  => $privkey->{PRIVATE_KEY} );
            } else {
                $key = $privkey->{PRIVATE_KEY};
            }
        }
    }

    # the "no template" case was already handled above
    if ($template) {

        my $chain = CTX('api')->get_chain({ START_IDENTIFIER => $cert_identifier, OUTFORMAT => 'PEM'});
        my @certs = @{$chain->{CERTIFICATES}};

        ##! 64: 'chain ' . Dumper $chain
        ##! 64: 'key' . $key

        my $tt = OpenXPKI::Template->new();

        my $ca = pop @certs if ($chain->{COMPLETE});

        my $ttargs = {
            subject => ($chain->{SUBJECT}->[0]),
            certificate => shift @certs,
            ca => $ca,
            chain => \@certs,
            key =>  $key,
        };
        ##! 32: 'values ' . Dumper $ttargs

        # shift/pop of the entity and ca from the ends of the list
        my $config = $tt->render( $template, $ttargs );

        $context->param( $target_key , $config);
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CertificateExport

=head1 Description

Create a text export for a certificate using a template. The export file
can contain the chain and private key.

=head1 Configuration

=head2 Activity parameters

=over

=item cert_identifier

The cert to be exported.

=item template

A template toolkit string to be used to render the output. The parser is
called with five parameters. Certificates are PEM encoded, keys might be
in binary format, depending on the key_format parameter!

=over

=item certificate

The PEM encoded certificate.

=item subject

The subject of the certificate

=item ca

The PEM encoded ca certificate, might be empty if the chain can not
be completed.

=item key

The private key, requires the key_password to be set to the correct
value. Obviously, keys are only available if created or imported.

=item chain

An ARRAY of PEM encoded intermediates, might be empty.

=back

=item key_password

The password which was used to persist the key, also used for encrypting
the exported key if export_password is not set.

=item key_format, optional

 @see OpenXPKI::Server::API::Object::get_private_key_for_cert

=item export_password, optional

Encrypt the key with this password instead of the input password. Ignored
if empty, to export unencrypted, you must also set the I<unencrypted> flag.

=item unencrypted, optional

Set this to a boolean true value AND set I<export_password> to the empty
string to export the key unencrypted.

=item alias, optional

For PKCS12 sets the so called "friendly name" for the certificate.
For Java Keystore sets the keystore alias.
Parameter is ignored for any other key types.

=item include_root_cert, optional

Only valid with PKCS12 or JavaKeyStore format.
If set to a true value, the root certificate will be included in the file.
B<Warning>: Root certificates should be distributed and validated with a
defined process and not as a "drive-by"! Enable this only if you are sure
about the implications.

=item die_on_error

Boolean, if true the activity will throw an exception if the private key
could not be restored (which usually means that the wrong password was
provided). If false/not set, the target_key is just empty on error.

=item target_key, optional

The context key to write the result to, default is I<certificate_export>.
Note: If you export a key and use a persisted workflow, this will leave the
(password protected) key readable in the context forever.

=back

