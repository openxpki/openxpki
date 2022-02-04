package OpenXPKI::Server::Workflow::Activity::Tools::GetIdentifierForAlias;

use warnings;
use strict;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw(configuration_error workflow_error);

use base qw( OpenXPKI::Server::Workflow::Activity );

sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    my $target_key = $self->param('target_key') || 'cert_identifier';

    my $res;
    if (my $alias = $self->param('alias')) {
        $res = CTX('api2')->get_certificate_for_alias( alias => $alias );
    } else {
        my %args;
        # get group name from type
        if ($self->param('token')) {
            $args{type} = $self->param('token');

        # explicit group name
        } elsif ($self->param('alias_group')) {
            $args{group} = $self->param('alias_group');

        # oops
        } else {
            configuration_error 'Neither group nor token type nor alias was given';
        }
        my $token_list = CTX('api2')->list_active_aliases( %args );
        $res = $token_list->[0]->{identifier} if ($token_list->[0]);
    }

    if (!$res && !$self->param('empty_ok')) {
        workflow_error "No active tokens found";
    }

    $context->param( $target_key => $res );
}

1;

__END__;


=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::GetIdentifierForAlias

=head1 Description

Use the named  I<alias> or find the "best" token for the given alias
definition (either by I<token> type or the I<alias_group> name) and
return its certificate identifier.

The class will throw an exception if no matching item is found
unless I<empty_ok> is set to a true value.

=head1 Configuration

=head2 Activity parameters

=over

=item alias

The full alias, e.g. ca-signer-1

=item token

Name of the token type to look up, e.g. certsign

=item alias_group

Name of the group to look up, e.g. ca-signer

token and group are mutually exclusive, token has precedence.

=item target_key

Context item to write the result to, default I<cert_identifier>.

=item empty_ok

Boolean, if true does not throw an error if the result is empty.

=back
