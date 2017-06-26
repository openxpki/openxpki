package OpenXPKI::Server::Session;
use Moose;
use utf8;

# Core modules
use Scalar::Util qw( blessed );

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Server::Session::Data;
use OpenXPKI::Debug;
use OpenXPKI::Server::Log;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::MooseParams;

=head1 NAME

OpenXPKI::Server::Session - Factory to create, persist and resume sessions

=head1 SYNOPSIS

To start a new session:

    my $session = OpenXPKI::Server::Session->new(load_config => 1)->create;
    $session->data->pki_realm("ca-one");
    ...
    $session->persist;

To resume an existing session:

    my $session = OpenXPKI::Server::Session->new(load_config => 1);
    $session->resume($id);

Or if you want to specify config and logger explicitely:

    my $session = OpenXPKI::Server::Session
        ->new(
            type => "Database",
            config => { dbi => $dbi },
            log => OpenXPKI::Server::Log->new,
        )
        ->create;
    ...

=cut

################################################################################
# Attributes
#

has log => (
    is => 'rw',
    isa => 'Log::Log4perl::Logger',
    lazy => 1,
    default => sub {
        my $log = OpenXPKI::Server::Context::hascontext('log') ? CTX('log') : OpenXPKI::Server::Log->new(CONFIG => undef);
        return $log->application,
    },
);

# storage driver name (= last part of any package in the OpenXPKI::Server::Session::Driver::* namespace)
has type => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has config => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

# storage driver
has driver => (
    is => 'ro',
    does => 'OpenXPKI::Server::Session::DriverRole',
    lazy => 1,
    builder => '_build_driver',
    init_arg => undef,
);

# session lifetime
has lifetime => (
    is => 'ro',
    isa => 'Int',
    default => 1800, # 30 minutes
);

has data => (
    is => 'rw',
    isa => 'OpenXPKI::Server::Session::Data',
    handles => {
        id => "id",
        is_valid => "is_valid",
        data_as_hashref => "get_attributes",
    },
    predicate => "is_initialized",
    clearer => "clear_data",
);

has data_class => (
    is => 'ro',
    isa => 'ClassName',
    lazy => 1,
    default => 'OpenXPKI::Server::Session::Data',
);

has data_factory => (
    is => 'ro',
    isa => 'CodeRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        # data_factory = an anonymous subroutine which creates an instance
        return sub { $self->data_class->new(@_) };
    },
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
    eval {
        $instance = $class->new(
            %{ $self->config },
            log => $self->log,
            data_factory => $self->data_factory,
        );
    };
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
around BUILDARGS => sub {
    my ($orig, $class, %args) = @_;

    # Load config if load_config => 1 was given
    if (delete $args{load_config}) {
        my $conf = CTX('config')->get_hash("system.server.session")
            or OpenXPKI::Exception->throw (
                message => "Session configuration 'system.server.session' missing",
            );
        $args{type} = delete($conf->{type});
        # backwards compatibility: default to type "File"
        if (not $args{type}) {
            $args{type} = "File";
            my $log = $args{log};
            $log //= CTX('log')->system if OpenXPKI::Server::Context::hascontext('log');
            $log->warn("Configuration syntax has changed: please specify 'system.server.session.type' (defaulting to 'File' for now)") if $log;
        }
        $args{lifetime} = delete($conf->{lifetime}) if $conf->{lifetime};
        $args{config} = $conf; # rest of it
    }
    return $class->$orig(%args);
};

=head1 STATIC METHODS

=head2 new

Constructor that creates a new session with an empty data object.

=head1 METHODS

=cut

## POD for methods that come from Moose attributes ("handles")

=head2 id

Accessor to get or set the session ID
(shortcut for C<$session-E<gt>data-E<gt>id>).

=head2 is_valid

Accessor to mark the session as "valid" or query the current state
(shortcut for C<$session-E<gt>data-E<gt>is_valid>).

=head2 data_as_hashref

Returns a HashRef containing names and values of all previously set session
attributes.

B<Parameters>

=over

=item * @attrs - optional: list of attribute names if only a subset shall be returned.

=back

=head2 is_initialized

Returns 1 if the session is initialized, i.e. either data has been set or a
persisted session was resumed.

=cut

#######################################

=head2 create

Creates a new sesssion.

=cut
sub create {
    my ($self) = @_;
    $self->data( $self->data_factory->() );
    $self->log->debug(sprintf("New session of type '%s' created", $self->type));
    return $self;
}

=head2 resume

Resume the specified session by loading its data from the backend storage.

Returns the object reference to C<OpenXPKI::Server::Session> if the
session was successfully resumed or undef otherwise (i.e. expired session or
unknown ID).

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
        $self->log->info("Failed to resume session #$id: unknown ID (maybe expired and purged from backend)");
        return;
    }

    # Check return type
    OpenXPKI::Exception->throw(
        message => "Session backend driver returned invalid data",
        params => { driver => ref $driver },
    ) unless (blessed($data) and $data->isa('OpenXPKI::Server::Session::Data'));

    # Store data
    $data->is_dirty(0);
    $self->data($data);

    if ($self->is_expired) {
        $self->log->info("Failed to resume session #$id: expired");
        return;
    }

    $self->log->debug("Session resumed");
    return $self;
}

=head2 persist

Saves the session to the backend storage if any session data has changed.

Returns C<1> if data was actually written to the backend, C<undef> otherwise.

B<Named parameters>

=over

=item * force - C<Bool> force writing session even if nothing has changed. This
will update the I<modified> timestamp of the stored session.

=back

=cut
sub persist {
    my ($self, %params) = named_args(\@_,   # OpenXPKI::MooseParams
        force => { isa => 'Bool', optional => 1 },
    );
    ##! 1: "persist()"
    return unless ($self->is_initialized and ($self->data->is_dirty or $params{force}));
    ##! 1: "- data is set and dirty (or 'force' was specified)"
    $self->data->modified(time);        # update timestamp
    $self->driver->save($self->data);   # implemented by the class that consumes this role
    $self->data->is_dirty(0);
    $self->log->debug("Session persisted");
    ##! 1: "- done"
    return 1;
}

=head2 delete

Deletes the session data from the backend storage and then from this session
object, so that it cannot be access anymore.

Returns C<1> if data was actually written to the backend or C<undef> if there is
no session data yet.

=cut
sub delete {
    my ($self) = @_;
    return unless $self->is_initialized;
    $self->driver->delete($self->data);   # implemented by the class that consumes this role
    my $id = $self->id;
    $self->clear_data;
    $self->log->debug("Session deleted");
    return 1;
}

=head2 new_id

Switches the session to a new ID and updates the backend.

Returns the new session ID.

=cut
sub new_id {
    my ($self) = @_;
    return unless $self->is_initialized;
    $self->driver->delete($self->data);   # implemented by the class that consumes this role
    my $oldid = $self->id;
    $self->data->clear_id;
    $self->log->debug("Session got a new ID: #".$self->id);
    $self->persist(force => 1); # enforce it for double safety
    return $self->id;
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

__PACKAGE__->meta->make_immutable;
