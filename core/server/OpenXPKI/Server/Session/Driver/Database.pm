package OpenXPKI::Server::Session::Driver::Database;
use Moose;
use utf8;
with "OpenXPKI::Server::Session::DriverRole";

=head1 NAME

OpenXPKI::Server::Session::Driver::Database - Session implementation that
persists to the database

=head1 SYNOPSIS

To use the global database handle (C<CTX('dbi')>:

    my $session = OpenXPKI::Server::Session->new(
        type => "Database",
    );

To specify a different database (i.e. use a separate database handle):

    my $session = OpenXPKI::Server::Session->new(
        type => "Database",
        config => {
            driver => "SQLite",
            name => "/tmp/mydb.sqlite",
        },
    );

=head1 DESCRIPTION

The methods in this class do not execute C<COMMIT>s on the database if it's
configured to reuse the global database handle. This is to make sure
transcations started in the core application logic are not disturbed.

If an own database handle is created, it's configured to do C<AUTOCOMMIT>s.

=head1 METHODS

Please see L<OpenXPKI::Server::Session::DriverRole> for a description of the
available methods.

=cut

# Project modules
use OpenXPKI::Server::Init;
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Database;

################################################################################
# Attributes
#

has dbi => (
    is => 'rw',
    isa => 'OpenXPKI::Server::Database',
    lazy => 1,
    default => sub {
        my $self = shift;
        if ($self->dbi_params) {
            return OpenXPKI::Server::Database->new(
                db_params => $self->dbi_params,
                autocommit => 1,
                log => $self->log,
            );
        }
        OpenXPKI::Exception->throw(message => "Cannot set default for attribute 'dbi' because CTX('dbi') is not available")
            unless OpenXPKI::Server::Context::hascontext('dbi');
        return CTX('dbi');
    },
);

has dbi_params => (
    is => 'rw',
    isa => 'HashRef',
);

has table => (
    is => 'ro',
    isa => 'Str',
    default => "session",
);

################################################################################
# Methods
#
around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;

    # inject constructor argument "dbi_param" if "driver" and others are given
    if ($args{driver}) {
        $args{dbi_params} = {};
        $args{dbi_params}->{type} = delete $args{driver};
        for (qw( name namespace host port user passwd )) {
            $args{dbi_params}->{$_} = delete $args{$_} if $args{$_};
        }
    }
    return $class->$orig(%args);
};


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
        into => $self->table,
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
        from => $self->table,
        columns => [ '*' ],
        where => {
            session_id => $id,
        },
    ) or return;
    ##! 8: "loaded raw session #$id: ".join(", ", map { "$_ = ".$db->{$_} } sort keys %$db)

    return
        $self->data_factory->(
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
        from => $self->table,
        where => {
            session_id  => $id,
        },
    )
    or OpenXPKI::Exception->throw(message => "Failed to delete session from database");
}

sub delete_all_before {
    my ($self, $epoch) = @_;

    ##! 8: "deleting all sessions where modified < $epoch"

    # There is a problem with deadlocks on (at least) mysql if we use a
    # table wide delete query so we first load all to-be-expired sessions
    # and delete them one by one

    my $sth = $self->dbi->select(
        from => $self->table,
        columns => ['session_id'],
        where => {
            modified => { '<' => $epoch },
        },
    );
    $self->dbi->start_txn();
    while (my $row = $sth->fetchrow_arrayref) {
        $self->dbi->delete(
            from => $self->table,
            where => { session_id => $row->[0] }
        );
    }
    $self->dbi->commit();
    return 1;
}

__PACKAGE__->meta->make_immutable;
