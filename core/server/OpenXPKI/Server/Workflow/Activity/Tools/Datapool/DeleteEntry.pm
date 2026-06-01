package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::DeleteEntry;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::DateTime;
use DateTime;
use Template;
use Workflow::Exception qw(configuration_error workflow_error);


sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    configuration_error('Mandatory parameter key missing or empty') unless($self->param('key'));
    configuration_error('Mandatory parameter namespace missing or empty') unless($self->param('namespace'));

    my $params = {
        namespace => $self->param('namespace'),
        key => $self->param('key')
    };

    if ($self->param('pki_realm')) {
        if ($self->param('pki_realm') eq '_global') {
            $params->{pki_realm} = '_global';
        } elsif($self->param('pki_realm') ne CTX('session')->data->pki_realm) {
            workflow_error( 'Access to foreign realm is not allowed' );
        }
    }

    CTX('api2')->delete_data_pool_entry(%$params);

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
