use Test::More tests => 2;
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
my $stderr = '2>/dev/null';
if ($debug) {
    $stderr = '';
}

diag("SCEP Client Test: initial enrollment");

my $sscep = 'sscep';
my $cgi_dir = $config{cgi_dir};


SKIP: {
    if (system("$sscep >/dev/null $stderr") != 0) {
	skip "sscep binary not installed.", 2;
    }
    if (! (`$config{openssl} version` =~ m{\A OpenSSL\ 0\.9\.8 }xms)) {
        skip "OpenSSL 0.9.8 not available.", 2;
    }

    #ok(mkpath([ $cgi_dir ]));
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

        # create a key and a certificate request
        my $openssl = $config{'openssl'};
        `$openssl genrsa -out t/instance/request_key.pem 1024 $stderr`;
        `(echo '.'; echo '.'; echo '.'; echo 'OpenXPKI'; echo 'SCEP test certificate'; echo 'SCEP test certificate'; echo '.'; echo '.'; echo '.')| openssl req -new -key t/instance/request_key.pem -out t/instance/request.csr $stderr`;

        # use sscep to start the enrollment
        my $scep_uri = "http://127.0.0.1:$config{http_server_port}/cgi-bin/scep";
        my $scep_result = `$sscep enroll -u $scep_uri -c $config{server_dir}/cacert-0 -k t/instance/request_key.pem -r t/instance/request.csr -l t/instance/certificate -t 5 -n 0 -v $stderr`;
        if ($debug) {
            print STDERR $scep_result;
        }
        ok($scep_result =~ m{pkistatus:\ PENDING}xms);
        
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
