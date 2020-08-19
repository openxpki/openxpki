use strict;
use warnings;

# Core modules
use Test::More tests => 7;
use Test::Exception;
use File::Temp qw( tempfile );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);


BEGIN { use_ok( 'OpenXPKI::Transport::Simple' ); }

my (undef, $client_in) = tempfile(UNLINK => 1);
my (undef, $server_in) = tempfile(UNLINK => 1);

# create client transport socket
my $client;
lives_ok {
    $client = OpenXPKI::Transport::Simple->new({
        INFILE  => $client_in,
        OUTFILE => $server_in,
    });
} "new client instance";

# create server transport socket
my $server;
lives_ok {
    $server = OpenXPKI::Transport::Simple->new({
        INFILE  => $server_in,
        OUTFILE => $client_in,
    });
} "new server instance";

my $query  = "Hello, I'm your client.";
my $answer = "Hi, that's nice but I don't know you :)";

ok ($client->write ($query), "client writes");
is ($server->read(), $query, "server reads");
ok ($server->write ($answer), "server writes");
is ($client->read(), $answer, "client reads");

1;
