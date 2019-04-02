package OpenXPKI::Server::Workflow::Activity::Tools::ParseCertificateBundle;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::DN;
use OpenXPKI::Crypt::X509;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;
use Template;
use Digest::SHA qw(sha1_hex);

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;

    my $context   = $workflow->context();

    my $config = CTX('config');

    my $pem = $self->param('pem');

    my $target_key =  $self->param('target_key ') || 'certificate_list';

    OpenXPKI::Exception->throw(
        message => 'No certificate data received'
    ) unless ($pem);

    my $certs = [ $pem =~ m{ ( -----BEGIN\ [\w\s]*CERTIFICATE----- [^-]+ -----END\ [\w\s]*CERTIFICATE----- ) }gmsx ];

    if (!$certs->[0] && $pem =~ m{-----BEGIN PKCS7----}) {
         $certs = CTX('api2')->get_default_token()->command({
            COMMAND  => 'pkcs7_get_chain',
            NOSORT   => 1,
            PKCS7    => $pem,
        });
    }

    OpenXPKI::Exception->throw(
        message => 'Unable to extract any certs from provided PEM'
    ) unless (ref $certs && $certs->[0]);

    my @res;
    foreach my $data (@$certs) {
        my $x509 = OpenXPKI::Crypt::X509->new($data);

        push @res, {
            cert_subject    => $x509->get_subject(),
            serial          => $x509->get_serial(),
            cert_issuer     => $x509->get_issuer(),
            cert_identifier => $x509->get_cert_identifier(),
        };
    };

    $context->param( { $target_key => \@res });

    return 1;
}

1;

__END__


=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ParseCertificateBundle

=head1 Description

Takes a list of concatenated PEM blocks or a PKCS7 bundle and returns a
summary of the certificate properties included in the bundle.

The result is an array where each item is a hash with the keys

    cert_subject, serial, cert_issuer, cert_identifier

=head1 Configuration

=head2 Activity Parameters

=over

=item pem

The PEM formatted certificate bundle, either concatenated certificates or
a PKCS7 bundle.

=item target_key

Context key to write the result to, the default is I<certificate_list>.

=back
