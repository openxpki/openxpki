package OpenXPKI::Server::Workflow::Condition::CertificateHasSuccessor;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Condition );

use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );


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
        columns => [ 'identifier' ],
        where => {
            attribute_value => $cert_identifier,
            attribute_contentkey => 'system_renewal_cert_identifier',
        }
    );

    if (!defined $res) {
        ##! 16: 'owner is not defined'
        CTX('log')->application()->debug("CertificateHasSuccessor condition failed - no successor found");
        condition_error('certificate has successor failed');
    }

    CTX('log')->application()->debug("CertificateHasSuccessor condition passed:" . $res->{identifier});

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
