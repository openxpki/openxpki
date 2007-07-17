use strict;
use warnings;
use English;
use Template;
use Test::More;
use File::Spec;

#--- top DIRECTORY
my $test_directory 	 = 't';
my $test_group           = '50_auth'; 

#------------------PREDEFINED CRITICAL FILE NAMES

my $ldap_pid_file = File::Spec->catfile(
				    $test_directory,
				    $test_group,
				    'ldap_var',
				    'slapd.pid',
		    );
my $ldap_conf_file = File::Spec->catfile(
			$test_directory, 
        		$test_group,
			'ldap_conf', 
			'slapd.conf' 
		     );
my $semaphore_file       = File::Spec->catfile(
				    $test_directory,
				    $test_group,
				    'enable_talk_to_server',
		           );

#------------------ ENUMERATE TASKS TO CALC TEST NUMBER
my @test_tasks = (
		    '1 delete semaphore file',
		    '2 check pidfile and stop ldap server',
		    '3 clean directories',
		    '4 delete ldap config',
		);    
my $test_number = scalar @test_tasks;
plan tests =>  $test_number;

diag "Cleaning after LDAP tests\n";

#### 1) DELETING SEMAPHORE FILE 

# ------- indicate that server is running
my $ldap_server_flag = 1;

if( -f $semaphore_file){
    unlink  $semaphore_file;
    if( -f $semaphore_file){
	diag("\n Could not delete $semaphore_file " .
    	     "\n Clean it up manually \n"
	);
        ok(0,"Deleting semaphore file");
    } else {
	ok(1,"Deleting semaphore file");        	 
    };    
} else {
    $ldap_server_flag = 0;
    ok(1,"Deleting semaphore file");        	 
};    



SKIP: {

#### 2) STOP LDAP SERVER
#
# steps:
#	I   check flag (set if semaphore file existed)
#       II  check environment
#	III check pidfile
#	IV  check ps and pid
#	V   if everything is ok - kill process
#       VI  check if it is alive somehow

#--- I) check flag

if ( ! $ldap_server_flag ) {
    diag("\n No semaphore file found," .
	 "\n skipping ldap server stopping\n"
    );
    skip '',1;  	     
};

#--- II)  check environment
if( not exists $ENV{OPENXPKI_LDAP_MODULE_PATH} or
    not exists $ENV{OPENXPKI_LDAP_DAEMON_PATH} ) {
    diag("\n No OPENXPKI_LDAP environment variables found," .
         "\n skipping ldap server stopping\n"
    );
    skip '',1;  	     
};


#--- III) check pidfile
if( ! ( -f $ldap_pid_file ) ) {
    diag("\n No ldap server pid file found," .
         "\n skipping ldap server stopping\n"
    );
    skip '',1;  	     
};

#--- IV)  check ps and pid
open(LDAPPID , "<" ,$ldap_pid_file );
my $ldap_pid = <LDAPPID>; 
chomp $ldap_pid;
close(LDAPPID);
my $daemon_path = $ENV{OPENXPKI_LDAP_DAEMON_PATH};

#
# FIXME why cannot we use Proc::ProcessTable ?
#
my $check = system(
		"ps -p $ldap_pid -o command | grep " .
		'"' . $daemon_path . '"'
	    );	
if( $check ) {
    diag("\n No running slapd with the specified pid found," .
         "\n skipping ldap server stopping\n"
    );
    skip '',1;  	     
};

#--- V)  if everything is ok - kill process
#
# FIXME - send TERM first ?
#
kill 9, $ldap_pid;

#--- VI) check if it is alive somehow
sleep 5;
$check = system(
		"ps -p $ldap_pid -o command | grep " .
		'"' . $daemon_path . '"'
         );
ok($check,"Stopping LDAP server");

};
#-------------- end of SKIP block

#### 3) DELETE DIRS
foreach my $dir (
            	    "ldap_certs",
            	    "ldap_keys",
                    "ldap_var",
    	    	    "ldap_db",
		 ) {
    my $ldap_dir = File::Spec->catfile(
				$test_directory,
    				$test_group, 
				$dir
		   );		 
    if (-d $ldap_dir) {
	system("rm -r -d $ldap_dir");
    };
};
ok(1,"Deleting directories");

#### 4) DELETE LDAP CONFIG
if (-f $ldap_conf_file){ unlink $ldap_conf_file; };
ok ( !(-f $ldap_conf_file),"Deleting ldap-server config file");

1;


