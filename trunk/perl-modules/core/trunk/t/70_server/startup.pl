use strict;
use warnings;
use English;
use POSIX;
use Errno;

use OpenXPKI::Debug;

if (grep /^--debug$/, @ARGV)
{
    $OpenXPKI::Debug::LEVEL{'.*'} = 100;
    print STDERR "Starting server in full debug mode for all modules ...\n";
}

require OpenXPKI::Server;

#OpenXPKI::Server->new ("CONFIG" => "t/config.xml");
my $configfile = "t/config.xml";

FORK: 
{
    my $pid;
    if ($pid = fork) {
	# parent here
	# child process pid is available in $pid
	waitpid(-1, 0);
	
	# FIXME: find out if the server is REALLY running properly
	
	exit 0;
    }
    elsif (defined $pid) { # $pid is zero here if defined
	# child here
	# parent process pid is available with getppid
	
	if (! OpenXPKI::Server->new ("CONFIG" => $configfile)) {
	    print STDERR "Could not start OpenXPKI Server daemon.\n";
	    exit 1;
	}
    }
    elsif ($!{EAGAIN}) {
	# EAGAIN is the supposedly recoverable fork error
	sleep 5;
	redo FORK;
    }
    else {
	# weird fork error
	die "Can't fork: $!\n";
    }
}


1;
