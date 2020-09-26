package OpenXPKI::Server::Workflow::Activity::User::PersistUserData;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $params = $self->param();
    my $set={};
    foreach my $key (keys %{$params}) {
        $set->{$key}=$self->param($key) if ($key ne 'username');
    }
    CTX('dbi')->update(
        table => 'users',
        set => $set,
        where => {
           username => $self->param('username'),
           pki_realm=> CTX('api2')->get_pki_realm()
        },
    );
    return 1;
}

1;


=head1 Name

OpenXPKI::Server::Workflow::Activity::User::PersistUserData;

=head1 Description

Updates user attributes in the database. The username (as primary key) and all attributes 
to be updated must be provided as params.

