package OpenXPKI::Server::Session::Driver::Database;
use Moose;
use utf8;
with "OpenXPKI::Server::Session::DriverRole";

=head1 NAME

OpenXPKI::Server::Session::Driver::Database - Session implementation that
persists to the database

=head1 DESCRIPTION

Please see L<OpenXPKI::Server::Session::DriverRole> for a description of the
available methods.

=cut

# Project modules
use OpenXPKI::Server::Init;
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Server::Session::Data;

################################################################################
# Attributes
#

has dbi => (
    is => 'rw',
    isa => 'OpenXPKI::Server::Database',
    required => 1,
);

################################################################################
# Methods required by OpenXPKI::Server::Session::DriverRole
#

# DBI compliant driver name
sub save {
    my ($self, $data) = @_;
    ##! 8: "saving session #".$data->id

    my $id          = $data->id         or OpenXPKI::Exception->throw(message => "Cannot persist session: value 'id' is not set");
    my $created     = $data->created    or OpenXPKI::Exception->throw(message => "Cannot persist session: value 'created' is not set");
    my $modified    = $data->modified   or OpenXPKI::Exception->throw(message => "Cannot persist session: value 'modified' is not set");
    my $ip_address  = $data->ip_address; # undef allowed

    $self->dbi->merge_and_commit(
        into => 'session',
        set => {
            modified    => $modified,
            ip_address  => $ip_address,
            data        => $data->freeze(except => [ "id", "created", "modified", "ip_address" ]),
        },
        set_once => {
            created     => $created,
        },
        where => {
            session_id  => $id,
        },
    )
    or OpenXPKI::Exception->throw(message => "Failed to write session to database");
}

sub load {
    my ($self, $id) = @_;

    my $db = $self->dbi->select_one(
        from => 'session',
        columns => [ '*' ],
        where => {
            session_id => $id,
        },
    ) or return;
    ##! 8: "loaded raw session #$id: ".join(", ", map { "$_ = ".$db->{$_} } sort keys %$db)

    return
        OpenXPKI::Server::Session::Data
        ->new(
            id         => $db->{session_id},
            created    => $db->{created},
            modified   => $db->{modified},
            $db->{ip_address} ? (ip_address => $db->{ip_address}) : (),
        )
        ->thaw($db->{data});
}

sub delete {
    my ($self, $data) = @_;
    ##! 8: "deleting session #".$data->id

    my $id = $data->id or OpenXPKI::Exception->throw(message => "Cannot delete session: value 'id' is not set");

    $self->dbi->delete(
        from => 'session',
        where => {
            session_id  => $id,
        },
    )
    or OpenXPKI::Exception->throw(message => "Failed to delete session from database");
}

sub delete_all_before {
    my ($self, $epoch) = @_;
    ##! 8: "deleting all sessions where modified < $epoch"
    return $self->dbi->delete_and_commit(
        from => 'session',
        where => {
            modified => { '<' => $epoch },
        },
    );
}

__PACKAGE__->meta->make_immutable;
