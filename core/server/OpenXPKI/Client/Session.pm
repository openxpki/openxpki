package OpenXPKI::Client::Session;

use English;
use Moose;
use Log::Log4perl qw( :levels );
use OpenXPKI::Client::Session::Driver;
use Data::Dumper;
use Crypt::CBC;


extends 'CGI::Session';

# the OXI::Client object
has 'backend' => (
    required => 1,
    is => 'rw',
    isa => 'OpenXPKI::Client',
);

has 'logger' => (
    required => 0,
    lazy => 1,
    is => 'ro',
    isa => 'Object',
    'default' => sub{
        Log::Log4perl->initialized() || Log::Log4perl->easy_init($ERROR);
        return Log::Log4perl->get_logger('session');
    }
);

sub factory {

    my $backend = shift;
    my $logger = shift;
    if (!$backend) {
        die "You must pass an OpenXPKI::Client instance to the factory";
    }
    my $sess_id = $backend->get_session_id();
    my $self = OpenXPKI::Client::Session->new( "id:static", $sess_id, { backend => $backend, logger => $logger } );
    $self->backend($backend);
    $self->param('backend_session_id', $sess_id);

    return $self;
}


around 'delete' => sub {
    my $orig = shift;
    my $self = shift;

    $self->$orig();

    # this crashes in case the backend session is unavailable
    eval {
        $self->backend()->logout();
        $self->logger()->debug('session deleted.');
    };

    # to make sure the backend session is really gone, we try to reload
    # it and send the logout then
    if ($EVAL_ERROR && $self->backend()->get_session_id()) {
        $self->logger()->warn('session delete failed, try to reconnect.');
        eval {
            $self->backend()->init_session( {
                SESSION_ID => $self->backend()->get_session_id() } );
            $self->backend()->logout();
            $self->logger()->debug('session delete succeeded after reconnect.');
        };
    };

    $self->param('backend_session_id' => undef);
    $self->dataref->{_SESSION_ID} = undef;

    return;
};

sub renew_session_id {
    my $self = shift;

    # in case we know there is no backend session (after logout)
    # we start with a new one right away
    if (!$self->backend()->get_session_id()) {
        $self->logger()->debug('session renew while not in session - do init.');
        $self->backend()->init_session();
    } else {
        eval {
            $self->backend()->rekey_session();
            $self->logger()->debug('session rekeying done');
        };
        # if the backend channel broke, we get an error on rekey
        # to avoid loops on the ui just create a new session
        if ($EVAL_ERROR) {
            $self->logger()->warn('session error while rekeying - do init.');
            $self->backend()->init_session();
        }
    }
    my $new_backend_session_id = $self->backend()->get_session_id();
    $self->param('backend_session_id', $new_backend_session_id);
    $self->dataref->{_SESSION_ID} = $new_backend_session_id;
    return $new_backend_session_id;
}

sub _driver {
    my $self = shift;
    defined($self->{_OBJECTS}->{driver}) and return $self->{_OBJECTS}->{driver};
    my $pm = "OpenXPKI::Client::Session::Driver";
    defined($self->{_OBJECTS}->{driver} = $pm->new( $self->{_DRIVER_ARGS} ))
        or die "Can not create OpenXPKI::Client::Session::Driver;";
    return $self->{_OBJECTS}->{driver};
}


1;

__END__;
