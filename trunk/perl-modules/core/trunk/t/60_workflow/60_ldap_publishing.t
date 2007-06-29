#!/usr/bin/perl
use strict;
use warnings;
use English;
use File::Spec;
use File::Copy;
use Cwd;
use Test::More;
use utf8;
use Net::LDAP;
use Net::LDAP::Util qw(ldap_error_text
		   ldap_error_name
		   ldap_error_desc
		   );
use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

#--- create the path to refer to and some other useful paths
#    to reuse the already deployed server
my $test_directory = getcwd;
$test_directory    = File::Spec->catfile(
			$test_directory,
			't', 
			'60_workflow',
		     );
my $fullinstancedir    = File::Spec->catfile(
			$test_directory,
			'test_instance',
		     );

my $instancedir    = File::Spec->catfile(
			't', 
			'60_workflow',
			'test_instance',
		     );

my $socketfile     = File::Spec->catfile(
			't', 
			'60_workflow',
			'test_instance',
			'var',
			'openxpki',
			'openxpki.socket',
		     );
my $pidfile        = File::Spec->catfile(
			't', 
			'60_workflow',
			'test_instance',
			'var',
			'openxpki',
			'openxpki.pid',
		     );

#--- check permissions to run test
my $semaphore_file = File::Spec->catfile(
			$test_directory,
			'enable_talk_to_server',
		     );
if( !( -f $semaphore_file) ) {
    plan skip_all => "LDAP server was not created for testing";
} else {
    plan 'no_plan' => '';
};

#  we need to manually output the number of tests run
Test::More->builder()->no_header(1);
my $OUTPUT_AUTOFLUSH = 1;
my $NUMBER_OF_TESTS  = 12;

# do not use test numbers because forking destroys all order
Test::More->builder()->use_numbers(0);

diag("LDAP Publishing\n");
print "1..$NUMBER_OF_TESTS\n";

#   Here we enable ldap in ldappublic.xml
my $old_ldap_config = File::Spec->catfile(
			$fullinstancedir,
			'etc',
			'openxpki',
			'ldappublic.xml',
		     );
my $new_ldap_config = File::Spec->catfile(
			$fullinstancedir,
			'etc',
			'openxpki',
			'ldappublic2.xml',
		     );
system(
    "sed -e 's/<ldap_enable>no/<ldap_enable>yes/' " . 
    "< $old_ldap_config " . 
    "> $new_ldap_config "
);
unlink("$old_ldap_config");
copy(
       "$new_ldap_config",
       "$old_ldap_config"
);
unlink("$new_ldap_config");	   

# Fork server, connect to it, test config IDs, create workflow instance
my $redo_count = 0;
my $pid;
FORK:
do {
    $pid = fork();
    if (! defined $pid) {
        if ($!{EAGAIN}) {
            # recoverable fork error
            if ($redo_count > 5) {
                die "Forking failed";
            }
            sleep 5;
            $redo_count++;
            redo FORK;
        }

        # other fork error
        die "Forking failed: $ERRNO";
        last FORK;
    }
} until defined $pid;

if ($pid) {
    local $SIG{'CHLD'} = 'IGNORE';
    Test::More->builder()->use_numbers(0);
    # this is the parent
    start_test_server({
        FOREGROUND => 1,
        DIRECTORY  => $instancedir,
    });
}
else {
    Test::More->builder()->use_numbers(0);
    # child here

  CHECK_SOCKET:
    foreach my $i (1..60) {
        if (-e $socketfile) {
            last CHECK_SOCKET;
        }
        else {
            sleep 1;
        }
    }
# 1
    ok(-e $pidfile, "PID file exists");
# 2
    ok(-e $socketfile, "Socketfile exists");
    my $client = OpenXPKI::Client->new({
        SOCKETFILE => $socketfile,
    });
# 3
    ok(login({
        CLIENT   => $client,
        USER     => 'raop',
        PASSWORD => 'RA Operator',
      }), 'Logged in successfully');

    my $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_LDAP_PUBLISHING',
            PARAMS   => {
                'cert_role' => 'User',
                'certificate' => "-----BEGIN CERTIFICATE-----\n" .
"MIIEsjCCBBugAwIBAgICE/8wDQYJKoZIhvcNAQEFBQAwgYAxCzAJBgNVBAYTAlJV\n" . 
"MQ8wDQYDVQQIEwZNb3Njb3cxDzANBgNVBAcTBk1vc2NvdzEOMAwGA1UEChMFSVBN\n" .
"Q0UxETAPBgNVBAsTCFNlY3VyaXR5MQswCQYDVQQDEwJDQTEfMB0GCSqGSIb3DQEJ\n" .
"ARYQZGVtb2NhQG15LmRvbWFpbjAeFw0wNzA2MTkwNjI4NTNaFw0wNzEyMTkwNjI4\n" .
"NTNaMD0xEzARBgoJkiaJk/IsZAEZFgNvcmcxGDAWBgoJkiaJk/IsZAEZFghPcGVu\n" .
"WFBLSTEMMAoGA1UEAwwDWGFhMFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAM6gezNE\n" .
"hYAmCqdFvdafO+dQ/GFxEamHCgsyTQvpa17zQTbuCy8yYymph9Dn9GqIY1oHBRbC\n" .
"+wvBYk8tkv6EDJ0CAwEAAaOCAr8wggK7MF4GCCsGAQUFBwEBBFIwUDAnBggrBgEF\n" .
"BQcwAoYbaHR0cDovL2xvY2FsaG9zdC9jYWNlcnQuY3J0MCUGCCsGAQUFBzABhhlo\n" .
"dHRwOi8vb2NzcC5vcGVueHBraS5vcmcvMIG1BgNVHSMEga0wgaqAFOdQv5aHgtvY\n" .
"THHZc8i4t8Bf0bn9oYGGpIGDMIGAMQswCQYDVQQGEwJSVTEPMA0GA1UECBMGTW9z\n" .
"Y293MQ8wDQYDVQQHEwZNb3Njb3cxDjAMBgNVBAoTBUlQTUNFMREwDwYDVQQLEwhT\n" .
"ZWN1cml0eTELMAkGA1UEAxMCQ0ExHzAdBgkqhkiG9w0BCQEWEGRlbW9jYUBteS5k\n" .
"b21haW6CCQDM5FjTEjEeJjAMBgNVHRMBAf8EAjAAMGEGA1UdHwRaMFgwIKAeoByG\n" .
"Gmh0dHA6Ly9sb2NhbGhvc3QvY2FjcmwuY3J0MDSgMqAwhi5sZGFwOi8vbG9jYWxo\n" .
"b3N0L2NuPU15JTIwQ0EsZGM9T3BlblhQS0ksZGM9b3JnMCkGA1UdJQQiMCAGCCsG\n" .
"AQUFBwMCBggrBgEFBQcDBAYKKwYBBAGCNxQCAjALBgNVHQ8EBAMCA/gwKQYJYIZI\n" .
"AYb4QgEEBBwWGmh0dHA6Ly9sb2NhbGhvc3QvY2FjcmwuY3J0MCkGCWCGSAGG+EIB\n" .
"AwQcFhpodHRwOi8vbG9jYWxob3N0L2NhY3JsLmNydDARBglghkgBhvhCAQEEBAMC\n" .
"BLAwXgYJYIZIAYb4QgENBFEWT1RoaXMgaXMgYSB1c2VyIGNlcnRpZmljYXRlLlxu\n" .
"CSAgICBHZW5lcmF0ZWQgd2l0aCBPcGVuWFBLSSB0cnVzdGNlbnRlciBzb2Z0d2Fy\n" .
"ZS4wEAYDVR0gBAkwBzAFBgMqAwQwHQYDVR0OBBYEFG9WNE8wP7Tce9ZCiHxvOelm\n" .
"zWNlMA0GCSqGSIb3DQEBBQUAA4GBADkiSrmDnim/qAXgHm0UQoZ3i7joihL0KoiU\n" .
"FQur5XPKSNAd/GfL2rEfa+ps4QWux6JpiEAEbcI+d0qWSRYiRp/od9c57lRBdKG9\n" .
"IiLkIyG9UJhMRxtbMWvtHuxNhh+Qk1VRtaOXo/RuehfoS9Z3wKSqhabXGM0pnOpX\n" .
"PFUTJ8Ab\n" .
"-----END CERTIFICATE-----\n" 
            },
        },
    );
#4
    ok(! is_error_response($msg), 'Successfully created LDAP publishing workflow instance');
    my $wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID} ;
# 5
    ok(defined $wf_id, 'Workflow ID exists');
# 6
    is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 
       'WAITING_FOR_START', 'WF is in state WAITING_FOR_START');

# 7
    ok(1,"SKIPPED null activity check");
#   ok(exists $msg->{PARAMS}->{ACTIVITY}->{'null'}, '<null> activity exists');
#    $wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID} ;
# 8
    ok(defined $wf_id, 'Workflow ID exists again');

    # Go to LDAP

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
              'ACTIVITY' => 'null',
              'ID' => $wf_id,
              'PARAMS' => {
                          },
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_LDAP_PUBLISHING',
        },
    ); 
# 9
    ok(! is_error_response($msg), 'Successfully started') or diag Dumper $msg;
# 10
    is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 
       'SUCCESS', 'WF is in state SUCCESS');
# 11 
# CONNECT TO SERVER
my $testldap = Net::LDAP->new("localhost:60389");
if( defined $testldap) {
    my $msg = $testldap->bind ("cn=Manager,dc=OpenXPKI,dc=org",
                        	password => "secret",
                        	version => 3 );
    if ( $msg->is_error()) {
	my $strange_error = "\nCODE => " . $msg->code() . 
    	    	    	   "\nERROR => " . $msg->error() .
	            	    "\nNAME => " . ldap_error_name($msg) .
                    	    "\nTEXT => " . ldap_error_text($msg) .
                     "\nDESCRIPTION => " . ldap_error_desc($msg) . "\n";
	diag("Fail to bind to LDAP server");
	ok(0,'Check if the certificate is really published');		     
	if( $ENV{DEBUG} ) {
    	    diag($strange_error);
	};
    } else {
	 $msg = $testldap->search(  base => 'cn=Xaa,dc=OpenXPKI,dc=org',
	                          scope  => 'base',
		                  filter => 'cn=*',
	       );
   	 if ( $msg->is_error()) {
	    my $strange_error =     "\nCODE => " . $msg->code() . 
    			    	   "\nERROR => " . $msg->error() .
	            		    "\nNAME => " . ldap_error_name($msg) .
                    		    "\nTEXT => " . ldap_error_text($msg) .
	                     "\nDESCRIPTION => " . ldap_error_desc($msg) . "\n";
	    diag("Found nothing in LDAP database");
	    ok(0,'Check if the certificate is really published');
	    if( $ENV{DEBUG} ) {
    		diag($strange_error);
	    };
	 } else {	  
	    my $expected_entry = {
				 "cn" => [ 
						"Xaa", 
					 ],
				 "sn" => [ 
						"NOT SUBSTITUTED YET"
					 ],
			"objectClass" => [ 
						"opencaEmailAddress",
						"pkiUser",
						"organizationalPerson",
						"person",
						"inetOrgPerson",
					 ],
	     "userCertificate;binary" => "BINARY VALUE",
                                 };
	 
	    my $num_found = $msg->count;
	    if( $num_found == 1 ){
                my $entry = $msg->entry(0);
		my $created_entry = {};
        	foreach my $attr ( $entry->attributes ) {
		    my $attr_value = $entry->get_value( $attr, asref => 1 );
		    if( !( $attr =~ m/;binary$/ ) ) { 
	    	        $created_entry->{$attr} = $attr_value;
		    } else {
			$created_entry->{$attr} = "BINARY VALUE";
		    };	
		};
		is_deeply(
		    $created_entry,
		    $expected_entry,
		    'Check if the certificate is really published',
		);
	    } else {
		diag("Found more than one entry - strange");
		ok(0,'Check if the certificate is really published');
	    };
	};
    };
$testldap->unbind;
} else {
    diag("Fail to connect to LDAP server");
    ok(0,'Check if the certificate is really published');		     
};

# LOGOUT
    eval {
        $msg = $client->send_receive_service_msg('LOGOUT');
    };
    diag "Terminated connection";

#   Here we disable ldap in ldappublic.xml 
#   to prevent automatic launcihing ldap-publishing in other tests
    system(
        "sed -e 's/<ldap_enable>yes/<ldap_enable>no/' " . 
        "< $old_ldap_config  " . 
        "> $new_ldap_config "
    );
    unlink("$old_ldap_config");
    copy(
           "$new_ldap_config",
           "$old_ldap_config"
    );
    unlink("$new_ldap_config");	   

#   That's all for child
    exit 0;
}

# 12
ok(1, 'Done'); # this is to make Test::Builder happy, which otherwise
               # believes we did not do any testing at all ... :-/
