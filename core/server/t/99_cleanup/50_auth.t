use strict;
use warnings;
use English;
use Test::More;
use File::Spec;

#--- top DIRECTORY
my $test_directory 	 = 't';
my $test_group           = '50_auth'; 

#------------------PREDEFINED CRITICAL FILE NAMES

my $auth_conf_file = File::Spec->catfile(
			$test_directory, 
        		$test_group,
			'auth_test.xml' 
		     );

plan tests =>  1;
#### DELETE AUTH CONFIG
if (-f $auth_conf_file){ unlink $auth_conf_file; };
ok ( !(-f $auth_conf_file),"Deleting auth config file");
1;


