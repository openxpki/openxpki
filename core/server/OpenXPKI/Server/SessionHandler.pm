package OpenXPKI::Server::SessionHandler;
use Moose;
use utf8;

# Core modules
use Scalar::Util qw( blessed );

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Server::Session::Data;
use OpenXPKI::Debug;

=head1 NAME

OpenXPKI::Server::SessionHandler - Create, persist and resume sessions

=head1 SYNOPSIS

To start a new session:

    my $session = OpenXPKI::Server::SessionHandler->new(
        type => "Database",
        config => { dbi => $dbi },
        log => OpenXPKI::Server::Log->new,
    );
    $session->data->pki_realm("ca-one");
    ...
    $session->persist;

To resume an existing session:

    my $session = OpenXPKI::Server::SessionHandler->new(
        type => "Database",
        config => { dbi => $dbi },
        log => OpenXPKI::Server::Log->new,
    );
    $session->resume($id);

=cut

################################################################################
# Attributes
#

has log => (
    is => 'ro',
    isa => 'Object',
    required => 1,
);

# storage driver name (= last part of any package in the OpenXPKI::Server::Session::Driver::* namespace)
has type => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

# Additional configuration options for the driver
has driver_config => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

# session lifetime
has lifetime => (
    is => 'ro',
    isa => 'Int',
    default => 1800, # 30 minutes
);

# storage driver
has driver => (
    is => 'ro',
    does => 'OpenXPKI::Server::Session::DriverRole',
    lazy => 1,
    builder => '_build_driver',
    init_arg => undef,
);

has data => (
    is => 'rw',
    isa => 'OpenXPKI::Server::Session::Data',
    lazy => 1,
    default => sub { OpenXPKI::Server::Session::Data->new },
    handles => {
        id => "id",
        data_as_hashref => "get_attributes",
    },
    predicate => "is_initialized",
);

sub _build_driver {
    my $self = shift;

    my $class = "OpenXPKI::Server::Session::Driver::".$self->type;

    eval { use Module::Load 0.32; autoload($class) };
    OpenXPKI::Exception->throw (
        message => "Unable to require() session driver package",
        params => { class_name => $class, message => $@ }
    ) if $@;

    my $instance;
    eval { $instance = $class->new($self->driver_config) };
    OpenXPKI::Exception->throw (
        message => "Unable to instantiate session driver class",
        params => { class_name => $class, message => $@ }
    ) if $@;

    OpenXPKI::Exception->throw (
        message => "Session driver class does not seem to be a Moose class",
        params => { class_name => $class }
    ) unless $instance->can('does');

    OpenXPKI::Exception->throw (
        message => "Session driver class does not consume role OpenXPKI::Server::Session::DriverRole",
        params => { class_name => $class }
    ) unless $instance->does('OpenXPKI::Server::Session::DriverRole');

    return $instance;
}

################################################################################
# Methods
#

=head1 METHODS

=cut

## POD for methods that come from Moose attributes ("handles")

=head2 id

Shortcut for C<$session-E<gt>data-E<gt>id>

=head2 data_as_hashref

Returns a HashRef containing session attribute names and their value (which
might be undef).

B<Parameters>

=over

=item * @attrs - optional: list of attribute names if only a subset shall be returned.

=back

=head2 is_initialized

Returns 1 if the session is initialized, i.e. either data has been set or a
persisted session was resumed.

=cut

#######################################

=head2 resume

Resume the specified session by loading its data from the backend storage.

Returns 1 if the session was successfully resumed or 0 otherwise (i.e. expired
session or unknown ID).

B<Parameters>

=over

=item * $id - session ID

=back

=cut
sub resume {
    my ($self, $id) = @_;

    # TODO Implement somewhere: OpenXPKI::i18n::set_language ($self->get_language());

    OpenXPKI::Exception->throw(
        message => "Attempt to load data into an active session",
        params => { session_id => $self->id },
    ) if $self->is_initialized;

    my $driver = $self->driver;

    # Load data from backend (return if session was not found)
    my $data = $driver->load($id);
    if (not $data) {
        $self->log->info("Session #$id is unknown (maybe expired and purged from backend)", "auth");
        return;
    }

    # Check return type
    OpenXPKI::Exception->throw(
        message => "Session backend driver did not return session data",
        params => { driver => ref $driver },
    ) unless (blessed($data) and $data->isa('OpenXPKI::Server::Session::Data'));

    # Store data object
    $self->data($data);

    if ($self->is_expired) {
        $self->log->info("Session #$id is expired", "auth");
        return;
    }

    $self->log->info("Session #".$self->id." resumed", "auth");
    return 1;
}

=head2 persist

Saves the given session to the backend storage and marks it as "persisted".
Changes to attributes are not allowed anymore on a persisted session and will
lead to exceptions.

=cut
sub persist {
    my $self = shift;
    $self->data->modified(time);        # update timestamp
    $self->driver->save($self->data);   # implemented by the class that consumes this role
    $self->data->_is_persisted(1);
    $self->log->info("Session #".$self->id." persisted", "auth");
}

=head2 purge_expired

Deletes all sessions that are expired from the backend storage.

=cut
sub purge_expired {
    my $self = shift;
    my $amount = $self->driver->delete_all_before(time - $self->lifetime);
    $self->log->info("Purged $amount expired sessions") if $amount;
}

=head2 is_expired

Returns true if the current session is expired.

=cut
sub is_expired {
    my $self = shift;
    my $result = (($self->data->modified + $self->lifetime) < time);
    ##! 32: "checking if ".($self->data->modified + $self->lifetime)." (modified + lifetime) < ".time." (now): ".($result ? "EXPIRED" : "VALID")
    return $result;
}

=head2 set_status_auth

Declare the session to be in status "authentication".

=cut
sub set_status_auth {
    my $self = shift;
    $self->data->status("auth");
}

=head2 set_status_auth

Declare the session to be (in status) "valid".

=cut
sub set_status_valid {
    my $self = shift;
    $self->data->status("valid");
}

=head2 is_valid

Returns true if the session is (in status) "valid".

=cut
sub is_valid {
    my $self = shift;
    return ($self->data->status eq "valid");
}

1;
