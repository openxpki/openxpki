##
## CHECK NODE VALIDATION
##
## Here we can test the check-node function 
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

#---------------------- C O N F I G U R A T I O N -------------------------
my $realm={};
my $ldap=undef;
$realm->{ldap_enable} = "yes";
$realm->{ldap_excluded_roles} = 'RA Operator';
$realm->{ldap_suffix}=['dc=openxpki,dc=org','dc=openxpki,c=RU'];
$realm->{ldap_server} = 'localhost';
$realm->{ldap_port} = '60389';
$realm->{ldap_version} = '3';
$realm->{ldap_tls} = 'no';
#$realm->{ldap_client_cert} = '/usr/local/etc/openldap/certs/saslcert.pem';
#$realm->{ldap_client_key}  = '/usr/local/etc/openldap/keys/saslkey.pem';
#$realm->{ldap_ca_cert}     = '/usr/local/etc/openldap/certs/cacert.pem';
$realm->{ldap_sasl} = 'no';
#$realm->{ldap_sasl_mech} ='EXTERNAL'; 
$realm->{ldap_login} = 'cn=Manager,dc=openxpki,dc=org';
$realm->{ldap_password} = 'secret';

 my @nodes = (
		[ 'dc=openxpki,dc=org'          , 1],
                [ 'o=ipmce,dc=openxpki,dc=org'  , 0], 
	        [ 'cn=n,dc=openxpki,dc=org'     , 0],
	        [ 'cn=BAD,dc=openxpki,dc=org'   , 0],    
             );
my $test_number = scalar @nodes ;

if($ENV{DEBUG}){ 
    diag( "TEST NUMBER >" . $test_number . "<\n");
};

plan tests => $test_number;

diag "CHECK LDAP NODE VALIDATION\n";

#------------------------------------------------------------------ Go
 my $utils = OpenXPKI::LdapUtils->new();
 $ldap = $utils->ldap_connect($realm);

 foreach my $node ( @nodes ){
    if( $utils->check_node( $ldap,$node->[0] ) ) {
        ok( $node->[1], "find existing node" );
        if($ENV{DEBUG}){ 
            diag( $node->[0] . "  <- EXISTS\n");
        };
    } else {
        ok( 1 - $node->[1], "detect missing node" );
        if($ENV{DEBUG}){ 
            diag( $node->[0] . "  <- NOT FOUND\n");
        };
    };	
 };
 $utils->ldap_disconnect($ldap);

1;
