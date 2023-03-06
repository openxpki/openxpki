package OpenXPKI::Server::Workflow::Activity::User::LoadUserData;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

sub execute {
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();

    my $where={
        pki_realm => CTX('api2')->get_pki_realm()
    };
    $where->{username} = $self->param('username') if $self->param('username');
    $where->{mail} = $self->param('mail') if $self->param('mail');

    if(!$self->param('username') && !$self->param('mail')){
        OpenXPKI::Exception->throw (
            message => 'LoadUserData expects at least one search parameter out of username and mail',
        );
    }

    # fetch all attributes of the user identified by either username or mail
    my $user = CTX('dbi')->select_one(
        from => 'users',
        columns => ['*'],
        where => $where,
    );
    # insert user values into context
    foreach my $key (keys %{$user}) {
        $context->param( $key => $user->{$key} );
    }

    return 1;
}

1;


=head1 Name

OpenXPKI::Server::Workflow::Activity::User::LoadUserData

=head1 Description

Load the user data identified by either username or email (at least one
of them must be provided as param). All user attributes are then stored
in the workflow context
