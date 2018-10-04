# OpenXPKI::Server::Workflow::Activity::Tools::GetCertificateIdentifier
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::GetCertificateIdentifier;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

my @parameters = qw(
    cert_attrmap
    certificate
);

__PACKAGE__->mk_accessors(@parameters);


sub execute {
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $default_token = CTX('api')->get_default_token();

    ##! 16: 'ParseCert'
    my %contextentry_of = (
        certificatein => 'certificate',
        certidentifierout => 'cert_identifier',
    );

    foreach my $contextkey (keys %contextentry_of) {
        if (defined $self->param($contextkey . 'contextkey')) {
            $contextentry_of{$contextkey} = $self->param($contextkey . 'contextkey');
        }
    }

    my $certificate = $context->param($contextentry_of{'certificatein'});

    my $x509 = OpenXPKI::Crypto::X509->new(
        TOKEN => $default_token,
        DATA  => $certificate,
    );
    my $cert_identifier  = $x509->get_identifier();

    CTX('log')->application()->debug('Identifier of certificate is ' . $cert_identifier);

    $context->param($contextentry_of{'certidentifierout'} => $cert_identifier );

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::GetCertificateIdentifier

=head1 Description

Calculate the certificate's identifier

=head1 Parameters


=head2 certificateincontextkey

Context parameter to use for input certificate (default: certificate)

=head2 certidentifieroutcontextkey

Context parameter to use for certificate identifier output
(default: cert_identifier)

