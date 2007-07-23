## Base module tests
##

use strict;
use warnings;
use Test::More;

use File::Temp;
use File::Spec;

use OpenXPKI;

plan tests => 1;

diag "BASE CONFIG: REPAIR CONFIG\n";

## fix configuration files if needed

## critical directories and files 
my   $test_directory = "t";
my  $token_directory = "25_crypto";
my   $auth_directory = "50_auth";

my    $auth_template  = 'auth.xml';
my    $auth_config    = 'auth_test.xml';

my    $main_template  = 'config.xml';
my    $main_config    = 'config_test.xml';

my    $token_template = 'token.xml';
my    $token_config   = 'token_test.xml';


my $make_main_config_command = 
        'cp ' . 
        File::Spec->catfile($test_directory, $main_template ) . 
	' ' .
        File::Spec->catfile($test_directory, $main_config   );
system($make_main_config_command);

my $make_token_config_command = 
        'cp ' . 
        File::Spec->catfile($test_directory,
			    $token_directory,
			    $token_template ) . 
	' ' .
        File::Spec->catfile($test_directory,
			    $token_directory,
			    $token_config   );
system($make_token_config_command);

my $make_auth_config_command = 
        'cp ' . 
        File::Spec->catfile($test_directory,
			    $auth_directory,
			    $auth_template ) . 
	' ' .
        File::Spec->catfile($test_directory,
			    $auth_directory,
			    $auth_config   );
system($make_auth_config_command);

my $fixer = 
    File::Spec->catfile(
	't',
	'05_base',
	'fix_config.pl',
    );
    	
require "$fixer";
ok(1);


1;
