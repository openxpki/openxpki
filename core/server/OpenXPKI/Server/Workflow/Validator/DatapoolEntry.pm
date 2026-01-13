package OpenXPKI::Server::Workflow::Validator::DatapoolEntry;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Validator );

use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( validation_error configuration_error );


sub _validate {

    my ( $self, $wf, $value ) = @_;

    return unless ($value);

    my $invert = $self->param('invert');

    my $params = {
        namespace => $self->param('namespace'),
        key => $value,
    };

    if (!$params->{namespace}) {
        configuration_error('Validator::DatapoolEntry requires the namespace parameter');
    }

    ##! 32: $params

    my $msg = CTX('api2')->get_data_pool_entry(%$params);

    if ($msg) {
        return validation_error( $self->param('error') || 'I18N_OPENXPKI_UI_VALIDATOR_DATAPOOL_ENTRY_EXIST' ) if ($invert);
    } else {
        return validation_error( $self->param('error') || 'I18N_OPENXPKI_UI_VALIDATOR_DATAPOOL_ENTRY_DOES_NOT_EXIST' ) unless ($invert);
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::DatapoolEntry

=head1 SYNOPSIS

    is_known_transaction_id:
        class: OpenXPKI::Server::Workflow::Validator::DatapoolEntry
        param:
            namespace: transaction_id
            error: No such transaction id
        arg:
          - $transaction_id

=head1 DESCRIPTION

Checks if the datapool namespace contains an item with the given value as key.

Raises a validation error if the entry does not exist. Set I<invert> to a true
value for the opposite check.

=head2 Parameters

=over

=item namespace

check entries in this namespace (required)

=item invert

Set to true to invert the condition.

=back