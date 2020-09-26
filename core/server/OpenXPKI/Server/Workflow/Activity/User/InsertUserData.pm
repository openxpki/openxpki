package OpenXPKI::Server::Workflow::Activity::User::InsertUserData;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;

sub execute {

    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $params = $self->param();

    # make sure that users can only be inserted in the current realm
    my $values = {
        pki_realm => CTX('api2')->get_pki_realm()
    };

    # add additional parameters from params, workflow designer must provide all required params
    foreach my $key (keys %{$params}) {
        $values->{$key} = $self->param($key);
    }

    # perform simple insert
    CTX('dbi')->insert(
        into => 'users',
        values => $values
    );
    return 1;
}

1;


=head1 Name

OpenXPKI::Server::Workflow::Activity::User::InsertUserData;

=head1 Description

Inserts a new user in the database

=head1 Configuration

All required user attributes must be provided as parameters:

  class: OpenXPKI::Server::Workflow::Activity::User::InsertUserData;
  param:
      _map_username: $username
      _map_role: $role
      ...
