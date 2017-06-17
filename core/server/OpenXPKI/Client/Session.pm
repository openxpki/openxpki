package OpenXPKI::Client::Session;

use Moose;
use Log::Log4perl;
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

sub renew_session_id {
    my $self = shift;
    $self->backend()->rekey_session();
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
