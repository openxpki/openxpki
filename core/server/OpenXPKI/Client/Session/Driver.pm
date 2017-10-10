package OpenXPKI::Client::Session::Driver;

use Moose;
use English;
use warnings;
use Log::Log4perl qw(:easy);
use Log::Log4perl::MDC;
use Data::Dumper;
use MIME::Base64 qw( encode_base64 decode_base64 );

extends 'CGI::Session::Driver';

# the OXI::Client object
has 'backend' => (
    required => 1,
    is => 'rw',
    isa => 'OpenXPKI::Client',
);

# should be passed by the ui script to be shared, if not we create it
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

sub init { 1 }

sub dump { 1 }

sub store {

    my ($self, $sid, $datastr) = @_;

    my $backend_sid = $self->backend()->get_session_id();
    if (!$backend_sid) {
        $self->logger()->debug('Skipping session store for id ' . $sid . ' - backend already gone');
    } elsif($backend_sid ne $sid) {
        $self->logger()->error("Backend session missmatches frontend session! ($backend_sid / $sid)");
    } else {
        $self->logger()->debug('Session store with id ' . $sid);

        my $res = $self->backend()->send_receive_service_msg('FRONTEND_SESSION',{
            SESSION_DATA => $datastr,
        });

        $self->logger()->trace('Session store result ' . Dumper $res);
    }

}

sub retrieve {

    my ($self, $sid) = @_;

    my $res = $self->backend()->send_receive_service_msg('FRONTEND_SESSION');
    $self->logger()->trace('Session retrieve ' . Dumper $res);
    return $res->{SESSION_DATA} || '';


};

sub remove {

    my ($self, $sid) = @_;

    my $backend_sid = $self->backend()->get_session_id();
    if ($backend_sid && $backend_sid eq $sid) {
        my $res = $self->backend()->send_receive_service_msg('FRONTEND_SESSION',{
            SESSION_DATA => undef,
        });
        $self->logger()->debug('Session removed');
    } else {
        $self->logger()->warn('Unable to remove session - backend already gone');
    }

    return;
}

sub traverse {
    my $self = shift;
    die "traverse() is not supported";
}

1;

__END__;
