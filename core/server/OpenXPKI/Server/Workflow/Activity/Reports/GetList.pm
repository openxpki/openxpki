package OpenXPKI::Server::Workflow::Activity::Reports::GetList;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;
use OpenXPKI::Template;
use DateTime;
use Workflow::Exception qw(configuration_error);

sub execute {

    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();

    # where to write the output
    my $target_key = $self->param('target_key') || 'report_list';

    my $items = CTX('api2')->get_report_list( columns => [ 'report_name', 'created', 'description' ] );

    $context->param({ $target_key => $items });

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Reports::GetList

=head1 Description


=head1 Configuration

=head2 Activity parameters

=over

=item target_key

Write the report data into the workflow context using this key. The
filesystem is not used in this case, so all file related settings are
ignored.


=back

