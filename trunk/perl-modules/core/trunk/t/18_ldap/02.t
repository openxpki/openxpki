##
## LDAP CONNECT AND BIND VALIDATION
##
## Here we can check the connection using sasl, tls and 
## just login + password credentials
##
## We need running LDAP server for that
##

use strict;
use warnings;
use utf8;
use Test::More;
use OpenXPKI::LdapUtils;
use File::Spec;

#--- check permission to run test
my $test_directory = File::Spec->catfile( 't', '18_ldap');
my $semaphore_file = File::Spec->catfile(
			    $test_directory,
                    	    'enable_talk_to_server',
		     );
if( !( -f $semaphore_file) ) {
    plan skip_all => "No ldap server for testing";
};


# --- get base realm options 
my $realm_generator =  File::Spec->catfile(
			    $test_directory,
                            'get_realm.pl',
		     );
require $realm_generator;
our $realm;

# ldap handle
my $ldap=undef;

# Array of connection configurations
#
# each tag ( [0] - comment) has four options
# 1) tls
# 2) sasl
# 3) sasl mech
# 4) login
# 5) expected result ( 1 means Ok) 
my $connections=[ 
                 [
		    'no tls, no sasl',
                    'no',
		    'no',
		    '',
		    'cn=Manager,dc=openxpki,dc=org',
		     1,
		 ],
                 [
		    'tls, no sasl',
                    'yes',
		    'no',
		    '',
		    'cn=Manager,dc=openxpki,dc=org',
		    1,
		 ],
                 [
		    'no tls, sasl DIGEST-MD5',
                    'no',
		    'yes',
		    'DIGEST-MD5',
		    'sasl1',
		    1,
		 ],
                 [
		    'tls, sasl EXTERNAL',
                    'yes',
		    'yes',
		    'EXTERNAL',
		    'cn=Manager,dc=openxpki,dc=org',
		    1,
		 ],
                 [
		    'no tls, sasl CRAM-MD5',
                    'no',
		    'yes',
		    'CRAM-MD5',
		    'sasl1',
		    1,
		 ],
                 [  
		    'no tls, bad sasl user CRAM-MD5',
                    'no',
		    'yes',
		    'CRAM-MD5',
		    'saslx',
		    0,
		 ],
                 [   
            	    'no tls, bad sasl mechanism PLAIN',
                    'no',
		    'yes',
		    'PLAIN',
		    'sasl1',
		    0,
		 ],
                 [   
		     'no tls, no sasl, bad user',
                     'no',
		     'no',
		     'DIGEST-MD5',
		     'sasl1',
		     0,
		 ],
                 [   
            	    'no tls, EXTERNAL sasl mechanism',
                    'no',
		    'yes',
		    'EXTERNAL',
		    'sasl1',
		    0,
		 ],

		];           


my $test_number = scalar @{$connections} ;
if($ENV{DEBUG}){
    diag( "NUMBER OF TESTS >" . ($test_number + 5) . "<\n");
};
my $utils=OpenXPKI::LdapUtils->new();

#-------------- plan  
# 
#             connection   sasl+tls sasl+tls   utf8 FIXME
#      	        types       some     bad      credentials
#              	            user    certs     not done yet

plan tests => $test_number + 2 +      2 +       1;

diag "CONNECT TO LDAP SERVER VALIDATION\n";

#--------------------------------------------------REGULAR CONNECTIONS
foreach my $connection_type ( @{$connections} ){
    $realm->{ldap_tls}       = $connection_type->[1];
    $realm->{ldap_sasl}      = $connection_type->[2];
    $realm->{ldap_sasl_mech} = $connection_type->[3];
    $realm->{ldap_login}     = $connection_type->[4];

    my $test_name = $connection_type->[0];
    if( $connection_type->[5] ){
       $test_name = 'Check connect : ' . $test_name;
    } else {
       $test_name = 'Check deny : ' . $test_name;
    };

    $ldap = $utils->ldap_connect( $realm );
    if( defined $ldap){
	my $access_check = check_no_write_access($ldap);
	$utils->ldap_disconnect($ldap);
	ok(
	   $connection_type->[5] && !$access_check ,
	   $test_name 
	);
    } else {
	ok(
	   1 - $connection_type->[5],
	   $test_name 
	);
    };
}
#--------------------------------------------- OTHER CERTIFICATES CONNECTIONS
$realm->{ldap_client_cert} = 
    $realm->{'ldap_extra'}->{'badsasl_cert'};
$realm->{ldap_client_key}  = 
    $realm->{'ldap_extra'}->{'badsasl_key'};

    my $bad_connection_type  = $connections->[1];
#   tls without sasl accepts all certificates    
    $realm->{ldap_tls}       = $bad_connection_type->[1];
    $realm->{ldap_sasl}      = $bad_connection_type->[2];
    $realm->{ldap_sasl_mech} = $bad_connection_type->[3];
    $realm->{ldap_login}     = $bad_connection_type->[4];

    $ldap = $utils->ldap_connect( $realm );
    if( defined $ldap){
        my $access_check = 1 - check_no_write_access($ldap);
	$utils->ldap_disconnect($ldap);
	ok(
	   $access_check,
	   'Check connect : ' . $bad_connection_type->[0] .
	    " with some certificate" 
	);
    } else {
	ok(
	   0,
	   'Check connect : ' . $bad_connection_type->[0] .
	   " with some certificate" 
	);
    };

    $bad_connection_type = $connections->[3];
#   tls with sasl External mechanism accepts all certificates    
#   but the wrong one gives no rights
    $realm->{ldap_tls}       = $bad_connection_type->[1];
    $realm->{ldap_sasl}      = $bad_connection_type->[2];
    $realm->{ldap_sasl_mech} = $bad_connection_type->[3];
    $realm->{ldap_login}     = $bad_connection_type->[4];

    $ldap = $utils->ldap_connect( $realm );
    if( defined $ldap){
        my $access_check = check_no_write_access($ldap);
	$utils->ldap_disconnect($ldap);
	ok(
	   $access_check,
	   'Check connect : ' . $bad_connection_type->[0] .
	    " with a non registered user certificate" 
	);
    } else {
	ok(
	   0,
	   'Check connect : ' . $bad_connection_type->[0] .
	    " with a non registered user certificate" 
	);
    };


#--------------------------------------------- NO CA CERTIFICATES CONNECTIONS
$realm->{ldap_client_cert} = 
    $realm->{'ldap_extra'}->{'verybadsasl_cert'};
$realm->{ldap_client_key}  = 
    $realm->{'ldap_extra'}->{'verybadsasl_key'};

    $bad_connection_type  = $connections->[1];
#   tls without sasl must die with non verifiable certificate    
    $realm->{ldap_tls}       = $bad_connection_type->[1];
    $realm->{ldap_sasl}      = $bad_connection_type->[2];
    $realm->{ldap_sasl_mech} = $bad_connection_type->[3];
    $realm->{ldap_login}     = $bad_connection_type->[4];

    $ldap = $utils->ldap_connect( $realm );
    ok( !defined $ldap,
	'Check deny : ' . $bad_connection_type->[0] .
	" with a certificate signed by some CA" 
    );
    if( defined $ldap){
	$utils->ldap_disconnect($ldap);
    };

    $bad_connection_type = $connections->[3];
#   tls with sasl External mechanism must die with 
#   non verifiable certificate    
    $realm->{ldap_tls}       = $bad_connection_type->[1];
    $realm->{ldap_sasl}      = $bad_connection_type->[2];
    $realm->{ldap_sasl_mech} = $bad_connection_type->[3];
    $realm->{ldap_login}     = $bad_connection_type->[4];

    $ldap = $utils->ldap_connect( $realm );
    ok( !defined $ldap,
	'Check deny : ' . $bad_connection_type->[0] .
	" with a certificate signed by some CA" 
    );

    if( defined $ldap){
	$utils->ldap_disconnect($ldap);
    };

    TODO: {
        todo_skip 'connect using utf8 credentials - not done yet', 1 if 1;
	ok(1)
    };
1;


sub check_no_write_access
{
    my $ldap = shift;
    my $base_dn='dc=openxpki,dc=org';
    my $ounit='xTESTxLDAPx';
    my $addmsg = $ldap->add( 'ou=' . $ounit . ',' . $base_dn,
	                    attr => [
                          'ou'   => $ounit,
                   'objectclass' => ['organizationalUnit'],
		            ],
               );
    if ($addmsg->is_error()) {
      return 1;
    } else {
	$ldap->delete( 'ou=' . $ounit . ',' . $base_dn);
	return 0;
    };
}
