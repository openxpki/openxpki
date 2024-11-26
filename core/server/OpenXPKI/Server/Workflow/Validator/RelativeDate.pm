package OpenXPKI::Server::Workflow::Validator::RelativeDate;
use OpenXPKI;

use parent qw( Workflow::Validator );

use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );

__PACKAGE__->mk_accessors( qw( emptyok ) );

sub init {

    my ( $self, $params ) = @_;

    $self->SUPER::init( $params );

    $self->emptyok( exists $params->{'emptyok'} ? $params->{'emptyok'} : 0 );

}


sub validate {

    my ( $self, $wf, $timespec ) = @_;

    if ($self->emptyok && !$timespec) {
        return 1;
    }

    if ($timespec !~ /^[+-](\d{2}){1,6}$/) {
        ##! 16: 'invalid timespec: ' . $timespec
        validation_error("I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_RELATIVEDATE_WRONG_TIMESPEC");
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::RelativeDate

=head1 DESCRIPTION

Checks if the given date is parseable as a relativedate by
OpenXPKI::DateTime

=head2 Parameters

=over 8

=item emptyok

=back

