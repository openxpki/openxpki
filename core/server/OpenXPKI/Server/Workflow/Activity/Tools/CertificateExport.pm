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
    my $private_key = $self->param('private_key') || '';

    my $target_key = $self->param('target_key') || 'certificate_export';

    my $key;

    # no template, no key, just export the plain certificate
    if (!$template && !defined $key_password) {

        my $cert = CTX('api2')->get_cert( identifier => $cert_identifier, format => 'PEM' );
        $context->param( $target_key  => $cert );

    } elsif (defined $key_password) {
        my $privkey;
        eval {

            my $key_format = $self->param('key_format') || 'OPENSSL_PRIVKEY';
            my $alias = $self->param('alias') || '';

            my $p = {
                identifier =>  $cert_identifier,
                format => $key_format,
                password => $key_password,
                alias => $alias,
            };

            my $export_password = $self->param('export_password');
            if (defined $export_password) {
                if ($export_password ne '') {
                    $p->{passout} = $export_password;
                } elsif ($self->param('unencrypted')) {
                    $p->{passout} = '';
                    $p->{nopassword} = 1;
                }
            }

            if ( $self->param('include_root_cert') ) {
                $p->{keeproot} = 1;
            }

            # In case the private key is not stored in the default location e.g. using a
            # remote backend or other secure storage we get the private key from the activity
            if (!$private_key) {
                ##! 64: 'Do export from local datapool'
                $privkey = CTX('api2')->get_private_key_for_cert(%$p);
            } else {
                ##! 64: 'Do export with key from context'
                $p->{private_key} = $private_key;
                $privkey = CTX('api2')->convert_private_key(%$p);
            }

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
                $context->param( $target_key  => $privkey );
            } else {
                $key = $privkey
            }
        }
    }

    # the "no template" case was already handled above
    if ($template) {

        my $chain = CTX('api2')->get_chain( start_with => $cert_identifier, format => 'PEM' );
        my @certs = @{$chain->{certificates}};

        ##! 64: 'chain ' . Dumper $chain
        ##! 64: 'key' . $key

        my $tt = OpenXPKI::Template->new();

        my $ca = pop @certs if ($chain->{complete});

        my $ttargs = {
            cert_identifier => $cert_identifier,
            subject => ($chain->{subject}->[0]),
            certificate => shift @certs,
            ca => $ca,
            chain => \@certs,
            key =>  $key,
        };
        ##! 32: $ttargs

        # shift/pop of the entity and ca from the ends of the list
        my $export;
        if (my $template_dir = $self->param('template_dir')) {
            $template =~ s{[^\w\-\.]}{}g;
            ##! 64: "Render from file $template_dir/$template"
            $export = $tt->render_from_file( "$template_dir/$template", $ttargs );
        } else {
            ##! 128: $template
            $export = $tt->render( $template, $ttargs );
        }
        $context->param( $target_key , $export );
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

=item private_key

The PEM encoded private key, protected by the given key_password.
Mandatory if the private key can not be found in the datapool.

=item template

A template toolkit string or, in conjunction with I<template_dir>, the name of
a template file to be used to render the output.

The parser is called with six parameters. Certificates are PEM encoded, keys
might be in binary format, depending on the key_format parameter!

=over

=item cert_identifier

The cert_identifier

=item certificate

The PEM encoded certificate.

=item subject

The subject of the certificate

=item ca

The PEM encoded root certificate, might be empty if the chain can not
be completed.

=item key

The private key, requires the key_password to be set to the correct
value. Obviously, keys are only available if created or imported.

=item chain

An ARRAY of PEM encoded intermediates, might be empty.

=back

=item template_dir

Optional, if set then I<template> is considered to be a filename in
I<template_dir> that contains the template string.

=item key_password

The password which was used to persist the key, also used for encrypting
the exported key if export_password is not set.

=item key_format, optional

@see OpenXPKI::Server::API2::Plugin::Cert::private_key

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
