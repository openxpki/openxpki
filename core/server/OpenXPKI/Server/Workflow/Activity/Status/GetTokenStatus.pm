package OpenXPKI::Server::Workflow::Activity::Status::GetTokenStatus;
use OpenXPKI;

use parent qw(OpenXPKI::Server::Workflow::Activity);

use List::Util 'uniq';
use OpenXPKI::Server::Context qw(CTX);
use OpenXPKI::Serialization::Simple;


sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $node = CTX('config')->hostname;
    my $target_key = $self->param('target_key') || 'token_status';

    my $groups = CTX('api2')->list_token_groups();
    my @groups = sort { $a cmp $b } uniq values $groups->%*;
    my @token;
    foreach my $group ( @groups ) {
        my $entries = CTX('api2')->list_active_aliases(
            group => $group,
            check_online => 1
        );
        ##! 64: $entries
        foreach my $entry ($entries->@*) {
            push @token, {
                node => $node,
                alias => $entry->{alias},
                status => lc($entry->{status}),
                last_update => time(),
            };
        }
    }

    $context->param( $target_key  => \@token );

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Status::GetTokenStatus

=head1 Description

Iterate over all active aliases in all token groups and test their
availability. Writes the test result to the given I<target_key>.

The result is a list of hashes, sorted by group name.

    [{
        node => 'node1',
        alias => 'ca-signer-1',
        status => 'online',
        last_update => 1775546540
    },
    {
        node => 'node1',
        alias => 'ratoken-1',
        status => 'online',
        last_update => 1775546542
    }]

=head1 Configuration

=head2 Parameters

=over

=item target_key (default: token_status)

Name of the context key under which the result is stored.

=back
