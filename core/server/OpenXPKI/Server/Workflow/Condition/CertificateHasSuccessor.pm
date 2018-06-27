
package OpenXPKI::Server::Workflow::Condition::CertificateHasSuccessor;

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

    my $cert_identifier = $self->param('cert_identifier');
    $cert_identifier = $context->param('cert_identifier') unless($cert_identifier);

    if (!defined $cert_identifier ) {
        configuration_error('You need to have cert_identifier in context or set it via the parameters');
    }

    my $res = CTX('dbi')->select_one(
        from => 'certificate_attributes',
        columns => [ 'attribute_value' ],
        where => {
            identifier => $cert_identifier,
            attribute_contentkey => 'system_renewal_cert_identifier',
        }
    );

    if (!defined $res) {
        ##! 16: 'owner is not defined'
        CTX('log')->application()->info("CertificateHasSuccessor condition failed - no successor found");
        condition_error('I18N_OPENXPKI_UI_CERTIFICATE_HAS_SUCCESSOR_FAILED');
    }

    CTX('log')->application()->debug("CertificateHasSuccessor condition passed:" . $res->{attribute_value});

    return 1;
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CertificateHasSuccessor

=head1 SYNOPSIS


=head1 DESCRIPTION

This condition checks whether the given certificate has (at least one)
successor certificate (via certificate_attributes / system_renewal_cert_identifier)
