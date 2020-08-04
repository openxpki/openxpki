package OpenXPKI::Random;

use strict;
use warnings;
use utf8;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use MIME::Base64;

use POSIX;
use Moose;

=head1 OpenXPKI::Random

Return random numbers safe for cryptographic use

https://www.xkcd.com/221/

=cut

has token => (
    is => 'ro',
    lazy => 1,
    default => sub {
        return CTX('api2')->get_default_token();
    },
);

has socket => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;
        return OpenXPKI::Config::Backend->new(LOCATION => $self->config_dir);
    },
);

sub BUILD {
    my $self = shift;
    my $args = shift;

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

=item I<base64|hex|bin>

The encoding of the returned data.
The default is I<base64>.

=item I<fast|regular|strong>

The default uses /dev/urandom which should be sufficient for everyday use
such as passwords or UUIDs. I<fast> might return insecure numbers, I<string>
will call the default tokens I<create_random> method which calls
I<openssl rand> which CAN be setup using an engine / HSM.

Note: fast has currently no extra implementation and uses /dev/urandom.

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

    CTX('log')->system()->trace("Request to $length bytes of random using mode $mode")
        if (CTX('log')->system()->is_trace);

    if ($mode eq 'strong') {
       $rand = $self->_get_strong_random( $length );
    } else {
       $rand = $self->_get_regular_random( $length  );
    }

    if ($format eq 'base64') {
        $rand = encode_base64($rand, '');
    } elsif ($format eq 'hex') {
        $rand = unpack('H*', $rand);
    }

    return $rand;

}

sub _get_strong_random {

    my $self = shift;
    my $length = shift;

    return $self->token()->command({
        COMMAND => 'create_random',
        RANDOM_LENGTH => $length,
        BINARY => 1,
    });

}

sub _get_regular_random {

    my $self = shift;
    my $length = shift;

    my $socket = CTX('config')->get(['system', 'random', 'socket', 'location']) // '/dev/urandom';

    # if socket is the empty string we use openssl instead
    if (!$socket) {
        CTX('log')->system()->trace("No socket set for get_random, fallback to openssl") if (CTX('log')->system()->is_trace);
        return $self->token()->command({
            COMMAND => 'create_random',
            RANDOM_LENGTH => $length,
            BINARY => 1,
            NOENGINE => 1,
        });
    }

    sysopen RND, $socket, O_RDONLY;

    my $rand = '';
    my $numread = 0;
    my $buf;
    while ($numread < $length) {
        my $read = sysread RND, $buf, $length - $numread;
        next unless $read;
        OpenXPKI::Exception->throw (
            message => "Error while reading from $socket. $!"
        ) if ($read == -1);
        $rand .= $buf;
        $numread += $read;
    }

    return $rand;

}

1;

__END__;

