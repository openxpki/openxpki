package OpenXPKI::Server::Workflow::Activity::Tools::ParseCertificateBundle;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Crypt::X509;
use OpenXPKI::Crypt::PKCS7;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;

    my $context   = $workflow->context();

    my $config = CTX('config');

    my $pem = $self->param('pem');
    ##! 64: $pem
    my $target_key =  $self->param('target_key ') || 'certificate_list';

    OpenXPKI::Exception->throw(
        message => 'No certificate data received'
    ) unless ($pem);

    my $certs;
    if (my @certs = $pem =~ m{ ( -----BEGIN\ [\w\s]*CERTIFICATE----- [^-]+ -----END\ [\w\s]*CERTIFICATE----- ) }gmsx) {
        ##! 16: 'smells like a PEM bundle'
        $certs = [ map { OpenXPKI::Crypt::X509->new($_) } @certs ]
    } elsif ($pem =~ m{-----BEGIN PKCS7----}) {
        ##! 16: 'Looks like a PKCS7 container'
        $certs = OpenXPKI::Crypt::PKCS7->new($pem)->certificates();
    }

    OpenXPKI::Exception->throw(
        message => 'Unable to extract any certs from provided PEM'
    ) unless (ref $certs && $certs->[0]);

    ##! 64: $certs
    my @res;
    foreach my $x509 (@$certs) {
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
