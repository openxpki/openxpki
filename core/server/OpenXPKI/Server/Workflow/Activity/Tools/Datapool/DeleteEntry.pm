package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::DeleteEntry;
use OpenXPKI;

use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::DateTime;
use DateTime;
use Template;
use Workflow::Exception qw(configuration_error);


sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $params     = { PKI_REALM => CTX('api2')->get_pki_realm(), };

    configuration_error('Mandatory parameter key missing or empty') unless($self->param('key'));
    configuration_error('Mandatory parameter namespace missing or empty') unless($self->param('namespace'));

    CTX('api2')->delete_data_pool_entry(
        namespace => $self->param('namespace'),
        key => $self->param('key')
    );

    CTX('log')->application()->info('Remove datapool entry for key '.$self->param('key').' in namespace '.$self->param('namespace'));



    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::DeleteEntry

=head1 Description

Delete an entry from the Datapool, defined by C<namespace> and C<key>.

=head1 Configuration

=head2 Activity Paramaters

=over

=item namespace

=item key

=back
