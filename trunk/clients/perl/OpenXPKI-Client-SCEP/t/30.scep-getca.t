use Test::More tests => 4;
use File::Path;
use File::Spec;
use File::Copy;
use Cwd;
use English;

use POSIX ":sys_wait_h";
use Errno;

use strict;
use warnings;

our %config;
require 't/common.pl';

my $debug = $config{debug};
my $stderr = '2>/tmp/stderr';
#if ($debug) {
#    $stderr = '';
#}

diag("SCEP Client Test: GetCACert");

my $sscep = 'sscep';
my $cgi_dir = $config{cgi_dir};


SKIP: {
    if (system("$sscep >/dev/null $stderr") != 0) {
	skip "sscep binary not installed.", 4;
    }
    if (! (`$config{openssl} version` =~ m{\A OpenSSL\ 0\.9\.8 }xms)) {
        skip "OpenSSL 0.9.8 not available.", 4;
    }

    ok(mkpath($cgi_dir));
    # create configuration
    open my $HANDLE, ">", "$cgi_dir/scep.cfg";
    print $HANDLE "[global]\n";
    print $HANDLE "socket=$config{socket_file}\n";
    print $HANDLE "realm=I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA\n";
    print $HANDLE "iprange=127.0.0.0/8\n";
    print $HANDLE "profile=I18N_OPENXPKI_PROFILE_TLS_SERVER\n";
    print $HANDLE "servername=testscepserver1\n";
    print $HANDLE "encryption_algorithm=3DES\n";
    close $HANDLE;

    ok(copy("bin/scep", $cgi_dir));
    chmod 0755, $cgi_dir . '/scep';

    my $scep_uri = "http://127.0.0.1:$config{http_server_port}/cgi-bin/scep";

    my $cacert_base = "$config{server_dir}/cacert";


    my $redo_count = 0;
    my $pid;
  FORK:
    do {
	$pid = fork();
	if (! defined $pid) {
	    if ($!{EAGAIN}) {
		# recoverable fork error
		if ($redo_count > 5) {
		    print STDERR "FAILED.\n";
		    print STDERR "Could not fork process\n";
		    return;
		}
		print STDERR '.';
		sleep 5;
		$redo_count++;
		redo FORK;
	    }

	    # other fork error
	    print STDERR "FAILED.\n";
	    print STDERR "Could not fork process: $ERRNO\n";
	    return;
	}
    } until defined $pid;

    if ($pid) {
	# parent here
	# child process pid is available in $pid
        sleep 3;

        # use the sscep client to get the CA certificates
        ok(system("$sscep getca -v -d -u $scep_uri -c $cacert_base $stderr") == 0);

        my $index = 0;
        ok(-r "$cacert_base-$index");

        kill(9, $pid);

	my $kid;
	do {
	    $kid = waitpid(-1, WNOHANG);
	} until $kid > 0;


   } else {
	# child here
	# parent process pid is available with getppid
	
        # start a minimal HTTP server to test the CGI
        my $http_server = getcwd . "/t/http_server.pl";
        chdir $cgi_dir;
        exec("perl $http_server $config{http_server_port}");
    }
}
