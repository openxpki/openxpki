package OpenXPKI::Random;
use OpenXPKI -class;

use OpenXPKI::Server::Context qw( CTX );
use MIME::Base64;
use Crypt::PRNG;
use Log::Log4perl;

use Fcntl qw( :DEFAULT ); # import F_* and O_* constants

=head1 OpenXPKI::Random

Return random numbers safe for cryptographic use

https://www.xkcd.com/221/

The class is usable both inside the server and in client or standalone
tools. Primary source of random is /dev/urandom or, in server context,
the socket given in C<system.random.socket.location>.

Falls back to (L<Crypt::PRNG>) if socket does not exist.

The C<mode=strong> is only available in server context, it uses the crypto
default token with the configured engine.

=cut

has token => (
    is => 'ro',
    lazy => 1,
    default => sub {
        return CTX('api2')->get_default_token();
    },
);

# Logger abstraction: inside the server we route through the system log,
# in client / standalone / test contexts we fall back to a plain Log4perl
# logger so callers never have to guard logging with hascontext() checks.
has logger => (
    is => 'ro',
    lazy => 1,
    default => sub {
        return OpenXPKI::Server::Context::hascontext('server')
            ? CTX('log')->system()
            : Log::Log4perl->get_logger();
    },
);

# Entropy source location. Inside the server it is read from the config
# (system.random.socket.location), everywhere else we use /dev/urandom.
# The builder returns the empty string when no usable source is found
# (explicitly unset, or not existing / not readable) which switches
# get_random over to the token / PRNG fallback.
has socket => (
    is => 'ro',
    lazy => 1,
    builder => '_build_socket',
);

sub _build_socket {
    my $self = shift;

    my $socket = OpenXPKI::Server::Context::hascontext('server')
        ? (CTX('config')->get(['system', 'random', 'socket', 'location']) // '/dev/urandom')
        : '/dev/urandom';

    # empty string explicitly disables the socket source
    return '' unless $socket;

    # fall back if the configured source is missing or not readable
    return '' unless (-e $socket && -r $socket);

    return $socket;
}

=head1 Configuration

If your system provides /dev/urandom there is no need for any configuration.

If you want to use another random source, add the following to the config:

    system:
        random:
            socket:
                location: '/dev/myentropypool'

The source need to be a socket that returns a stream of bytes. If you set
location to the empty string, the class will use the system tokens
get_random call instead.

=head2 get_random

The call expects three positional parameters:

=over

=item I<Int> random number of bytes

The number of random bytes, this is NOT the length of the string received.
This argument is mandatory.

=item I<base64|hex|bin|base64url>

The encoding of the returned data.
The default is I<base64>.

=item I<fast|regular|strong>

The default uses /dev/urandom which should be sufficient for everyday use
such as passwords or UUIDs. I<fast> might return insecure numbers, I<string>
will call the default tokens I<create_random> method which calls
I<openssl rand> which CAN be setup using an engine / HSM.

Note: fast has currently no extra implementation and uses /dev/urandom.

=back

=cut

sub get_random {

    my $self = shift;

    my $length = shift || '';
    my $format = shift || 'base64';
    my $mode = shift || 'regular';

    OpenXPKI::Exception->throw (
        message => "Invalid length given for get_random",
        params => { length => $length }
    ) unless ($length && $length =~ m{\A \d+ \z}x);

    OpenXPKI::Exception->throw (
        message => "Invalid format given for get_random",
        params => { format => $format }
    ) unless ($format =~ m{\A(hex|bin|base64)\z});

    OpenXPKI::Exception->throw (
        message => "Invalid mode given for get_random",
        params => { mode => $mode }
    ) unless ($mode =~ m{\A(fast|regular|strong)\z});

    my $rand;

    $self->logger->trace("Request to $length bytes of random using mode $mode")
        if ($self->logger->is_trace);

    if ($mode eq 'strong') {
       $rand = $self->_get_random_from_token( $length, 1 );
    } elsif ($self->socket) {
       $rand = $self->_get_random_from_socket( $length  );
    } elsif (OpenXPKI::Server::Context::hascontext('server')) {
        $rand = $self->_get_random_from_token( $length );
    } else {
        $rand = $self->_get_random_from_prng( $length  );
    }

    if ($format eq 'base64') {
        $rand = encode_base64($rand, '');
    } elsif ($format eq 'base64url') {
        $rand = MIME::Base64::encode_base64url($rand, '');
    } elsif ($format eq 'hex') {
        $rand = unpack('H*', $rand);
    }

    return $rand;

}

sub _get_random_from_token {

    my $self = shift;
    my $length = shift;
    my $engine = shift;

    OpenXPKI::Exception->throw (
        message => "Generating random using the token layer works only in server context"
    ) unless OpenXPKI::Server::Context::hascontext('server');

    return $self->token()->command({
        COMMAND => 'create_random',
        RANDOM_LENGTH => $length,
        BINARY => 1,
        NOENGINE => ($engine ? 0 : 1),
    });

}

sub _get_random_from_socket {

    my $self = shift;
    my $length = shift;

    my $socket = $self->socket;

    OpenXPKI::Exception->throw (
        message => "No socket given to fetch random from"
    ) unless($socket);

    sysopen my $RND, $socket, O_RDONLY;

    OpenXPKI::Exception->throw (
        message => "Given socket does not exist or is not readable"
    ) unless ($RND);

    my $rand = '';
    my $numread = 0;
    my $buf;
    while ($numread < $length) {
        my $read = sysread $RND, $buf, $length - $numread;
        next unless $read;
        OpenXPKI::Exception->throw (
            message => "Error while reading from $socket. $!"
        ) if ($read == -1);
        $rand .= $buf;
        $numread += $read;
    }

    return $rand;

}

sub _get_random_from_prng {

    my $self = shift;
    my $length = shift;

    return Crypt::PRNG::random_bytes($length);

}


__PACKAGE__->meta->make_immutable;

__END__;

