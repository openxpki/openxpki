##
## RESET ERROR VALIDATION
##
## Here we can test the OpenXPKI::LdapUtils->reset_error method
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
$realm->{ldap_sasl} = 'no';
$realm->{ldap_login} = 'cn=Manager,dc=openxpki,dc=org';
$realm->{ldap_password} = 'secret';


 my $bad_dn = '=ou=x1,dc=openxpki,dc=org';

plan tests => 2;

diag "RESET ERROR VALIDATION\n";


 my $utils = OpenXPKI::LdapUtils->new();
 $ldap = $utils->ldap_connect($realm);

 $utils->check_node( $ldap, $bad_dn );
 ok( defined $utils->{'ldap_error'} ,
         'checking setting error after passing a bad dn'
 );
 $utils->reset_error;
 $utils->check_node( $ldap, $bad_dn );
 $utils->reset_error;
 ok( !defined $utils->{'ldap_error'} ,
         'checking resetting error after passing a bad dn'
 );


1;

