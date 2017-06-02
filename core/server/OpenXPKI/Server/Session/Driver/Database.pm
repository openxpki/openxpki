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

    my $data_hash = $data->get_attributes; # HashRef
    ##! 8: "saving session #".$data->{id}.": ".join(", ", map { "$_ = ".$data->{$_} } sort keys %$data)
    delete $data_hash->{created};
    delete $data_hash->{modified};
    delete $data_hash->{ip_address};
    delete $data_hash->{id};

    $self->dbi->merge_and_commit(
        into => 'session',
        set => {
            modified    => $data->modified,
            ip_address  => $data->ip_address,
            data        => $self->freeze($data_hash),
        },
        set_once => {
            created     => $data->created,
        },
        where => {
            session_id  => $data->id,
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

    my $data_hash = {
        id          => $db->{session_id},
        created     => $db->{created},
        modified    => $db->{modified},
        ip_address  => $db->{ip_address},
        % { $self->thaw($db->{data}) },
    };
    # Make sure all attributes are correct
    $self->check_attributes($data_hash, 1);

    return OpenXPKI::Server::Session::Data->new( %{ $data_hash } );
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
