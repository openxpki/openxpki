
use strict;
use warnings;
use Test;

BEGIN { plan tests => 7 };

print STDERR "OpenXPKI::Transport::Simple\n";

use OpenXPKI::Transport::Simple;
ok(1);

# create client transport socket
my $client = OpenXPKI::Transport::Simple->new
             ({
                 INFILE  => "t/65_ui/client.in",
                 OUTFILE => "t/65_ui/server.in"
             });
ok($client);

# create server transport socket
my $server = OpenXPKI::Transport::Simple->new
             ({
                 INFILE  => "t/65_ui/server.in",
                 OUTFILE => "t/65_ui/client.in"
             });
ok($server);

my $query  = "Hello, I'm your client.";
my $answer = "Hi, that's nice but I don't know you :)";

ok ($client->write ($query));
ok ($server->read() eq $query);
ok ($server->write ($answer));
ok ($client->read() eq $answer);

1;
