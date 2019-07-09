package OpenXPKI::Server::Workflow::Condition::CertificateAttribute;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use Data::Dumper;

sub _evaluate {

    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    my $context  = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)


    my $attribute = $self->param('attribute');

    if (!$attribute || $attribute =~ m{\W}) {
        configuration_error('Attribute name must be given and must not contain any non-word characters');
    }

    my $cert_identifier = $self->param('cert_identifier');
    $cert_identifier = $context->param('cert_identifier') unless($cert_identifier);

    if (!defined $cert_identifier ) {
        configuration_error('You need to have cert_identifier in context or set it via the parameters');
    }

    my $res =  CTX('api2')->get_cert_attributes( identifier => $cert_identifier, attribute => $attribute );

    if (!defined $res) {
        ##! 16: 'not defined'
        CTX('log')->application()->info("CertificateAttribute condition failed - no values found");
        condition_error('CertificateAttribute condition failed');
    }

    CTX('log')->application()->debug("CertificateAttribute condition passed:" . Dumper $res);

    return 1;
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CertificateAttribute

=head1 SYNOPSIS

=head1 DESCRIPTION

This condition checks whether the given certificate has (at least one)
value for the certificate_attribute given.

=head2 Activity Parameters

=over

=item attribute

Name of the attribute to look up, wildcards are not allowed!

=item cert_identifier

Certificate to look up, if not given uses the value from the context.

=back
