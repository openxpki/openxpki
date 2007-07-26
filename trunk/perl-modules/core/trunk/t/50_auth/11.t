##
## AUTHENTICATION USING LDAP+TLS VALIDATION
##
## Here we can check LDAP-based authentication methods with TLS. 
##
## We need running LDAP server for that
##

use strict;
use warnings;
use utf8;
use English;
use Test::More;
use XML::Simple;
use Data::Dumper;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;

use File::Spec;

#--- check permission to run test
my $test_directory = File::Spec->catfile( 't', '50_auth');
my $semaphore_file = File::Spec->catfile(
			    $test_directory,
                    	    'enable_talk_to_server',
		     );
if( !( -f $semaphore_file) ) {
    plan skip_all => "No ldap server for testing";
};

diag "OpenXPKI::Server::Authentication::LDAP\n";

# search prefix
my $search_prefix        = 'OpenXPKI User '; 

# attribute used to map to auth method
my $role_map_attr       = 'title'; 

# attribute used to map to auth method
my $auth_meth_attr       = 'uid'; 

# attribute value mapped to password authentication
# (password hash is stored in LDAP database) 
my $auth_meth_pw_value   = 'X1';

# attribute value mapped to simple bind authentication
# (password is stored in LDAP database and we try to bind using that password) 
my $auth_meth_bind_value = 'X2';


# Prepaire credentials and role maps for LDAP entries

my @credentials = (
    {
	   'login'=>'A', 
	'password'=>'Ox1',
       'role_attr'=>'manager',
	    'role'=>'User',
	    'meth'=>$auth_meth_pw_value,
	  'result'=>1,
    },
    {
	   'login'=>'B', 
	'password'=>'Ox2',
       'role_attr'=>'manager',
	    'role'=>'User',
	    'meth'=>$auth_meth_bind_value,
	  'result'=>1,
    },
    {
	   'login'=>'C', 
	'password'=>'Ox3',
       'role_attr'=>'programmer',
	    'role'=>'RA Operator',
	    'meth'=>$auth_meth_pw_value,
	  'result'=>1,
    },
    {
	   'login'=>'D', 
	'password'=>'Ox4',
       'role_attr'=>'programmer',
	    'role'=>'RA Operator',
	    'meth'=>$auth_meth_bind_value,
	  'result'=>1,
    },
    {
	   'login'=>'E', 
	'password'=>'Ox5',
       'role_attr'=>'CEO',
	    'role'=>'CA Operator',
	    'meth'=>$auth_meth_pw_value,
	  'result'=>1,
    },
    {
	   'login'=>'F', 
	'password'=>'Ox6',
       'role_attr'=>'CEO',
	    'role'=>'CA Operator',
	    'meth'=>$auth_meth_bind_value,
	  'result'=>1,
    },
);

# Prepaire bad credentials to check exceptions
my @bad_credentials = (
    {'login'=>'Q', 'password'=>'Ox1',},
    {'login'=>'A', 'password'=>'QQQ',},
    {'login'=>'B', 'password'=>'QQQ',},
);

# Prepaire attributes for LDAP entries
my $auth_nodes = {};

foreach my $login_set (@credentials){
  my $auth_cn   = $search_prefix .
	            $login_set->{'login'};       
  my $auth_dn = 'cn=' . $auth_cn . 
                ',o=Security,dc=openxpki,dc=org';
  $auth_nodes->{$auth_dn} = [
			         'cn' => $auth_cn,
			         'sn' => 'Mister X',
		       $role_map_attr => $login_set->{'role_attr'},
		      $auth_meth_attr => $login_set->{'meth'},
		       'userPassword' => $login_set->{'password'},     
                        'objectclass' => [ 
					    'person',
				    	    'inetOrgPerson',
					    'organizationalPerson',
					    'opencaEmailAddress',
					    'pkiUser',
					],    
 	                ];
};

# test N 1 ->  auth configuration
my $test_number = 1;
 
    my $number_of_credentials = (scalar (keys %{$auth_nodes}));
    my $number_of_bad_credentials = scalar @bad_credentials;
    $test_number += $number_of_credentials * 3 + $number_of_bad_credentials;
#                   NUMBER OF TESTS
#               extras + credentials + bad credentials
#                            | x 4
#                     user role result
#
    plan tests => $test_number;

#------------------- $index will store the number of performed tests.
my $index=0;

#### START of SKIP block - we skip the rest if something goes wrong
##
SKIP: {

## nodes must be ready, only real authentication tests are coming ...

## init XML cache
OpenXPKI::Server::Init::init(
    {
	CONFIG => 't/config_test.xml',
	TASKS => [
        'current_xml_config',
        'log',
        'dbi_backend',
        'xml_config',
    ],
	SILENT => 1,
    });

## load authentication configuration
my $auth = OpenXPKI::Server::Authentication::LDAP->new({
        XPATH   => ['pki_realm', 'auth', 'handler' ], 
        COUNTER => [ 0         , 0     , 7         ],
});

ok($auth, 'Auth object creation');

    foreach my $login_set (@credentials){
	my $ldap_login      = $login_set->{'login'};       
	my $ldap_password   = $login_set->{'password'};       
	my $expected_role   = $login_set->{'role'};       
	my $expected_result = $login_set->{'result'};       
	
	my ($user, $role, $reply) = $auth->login_step({
	    STACK   => 'LDAP TLS user',
	    MESSAGE => {
    		'SERVICE_MSG' => 'GET_PASSWD_LOGIN',
	        'PARAMS'      => {
        	    'LOGIN'  => $ldap_login,
        	    'PASSWD' => $ldap_password,
    		},
	    },
	});
	is($user, $ldap_login,    'Correct user');
	is($role, $expected_role, 'Correct role');
	if($expected_result){
	    is($reply->{'SERVICE_MSG'}, 'SERVICE_READY', 'Service ready');    
	} else {
	    ok($reply->{'SERVICE_MSG'} ne 'SERVICE_READY', 'Rejection');    
	};    
    };	

    foreach my $login_set (@bad_credentials){
	my $ldap_login      = $login_set->{'login'};       
	my $ldap_password   = $login_set->{'password'};       

        eval {	
	    my ($user, $role, $reply) = $auth->login_step({
		STACK   => 'LDAP TLS user',
		MESSAGE => {
    		    'SERVICE_MSG' => 'GET_PASSWD_LOGIN',
		    'PARAMS'      => {
        	        'LOGIN'  => $ldap_login,
        	        'PASSWD' => $ldap_password,
    		    },
		},
	    });
	};
	ok(OpenXPKI::Exception->caught(),'Bad credentials rejected');
    };	
}; # the end of SKIP BLOCK
1;
