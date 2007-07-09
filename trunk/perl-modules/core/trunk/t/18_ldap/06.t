##
## ADD NODE VALIDATION
##
## Here we can test the add-node function 
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


 my $new_nodes = { 
                    'ou=x1,dc=openxpki,dc=org' =>  [
                                                              'ou' => 'x1', 
                                                     'objectclass' => [ 
						          'organizationalUnit',
					             ],
						   ],     
                    'o=x3,dc=openxpki,dc=org' =>   [
                                                               'o' => 'x3', 
                                                     'objectclass' => [ 
						          'organization',
					             ],
						   ],
                    'ou=x2,dc=openxpki,dc=org' =>  [
                                                               'ou' => 'x2', 
                                                      'objectclass' => [ 
						          'organizationalUnit',
					              ],
						    ],    
                    'cn=John+sn=Smith,dc=openxpki,dc=org' =>   [
                                                               'cn' => 'John',
							       'sn' => 'Smith', 
                                                      'objectclass' => [ 
						           'person',
					              ],
						    ],  
		  };    	     

# bad entries description 
#
# 1) already exists in new nodes
# 2) already exists in new nodes
# 3) dn does not match attributes
# 4) schema violation

 my $bad_nodes = { 
                    'ou=x1,dc=openxpki,dc=org' =>  [
                                                              'ou' => 'x1', 
                                                     'objectclass' => [ 
						          'organizationalUnit',
					             ],
						   ],     
                    'o=x3,dc=openxpki,dc=org' =>   [
                                                               'o' => 'x3', 
                                                     'objectclass' => [ 
						          'organization',
					             ],
						   ],
                    'ou=x2,dc=openxpki,dc=org' =>  [
                                                               'ou' => 'x1', 
                                                      'objectclass' => [ 
						          'organizationalUnit',
					              ],
						    ],    
                    'cn=x3,dc=openxpki,dc=org' =>   [
                                                             'cn' => 'x3', 
                                                      'objectclass' => [ 
						           'organization',
					              ],
						    ],  
		  };    	     


my $test_number = (scalar (keys %{$new_nodes} )) +
		  (scalar (keys %{$bad_nodes} ))
;

if($ENV{DEBUG}){ 
diag( "NUMBER OF TESTS >" . $test_number . "<\n");
};

plan tests => $test_number;

diag "ADD LDAP NODE VALIDATION\n";

#------------------- Call utils -----------------------------------------

 my $utils = OpenXPKI::LdapUtils->new();
 $ldap = $utils->ldap_connect($realm);

#-------------------- must add ------------------------------------------ Go


 foreach my $node ( keys %{$new_nodes} ){
    if($ENV{DEBUG}){ 
        diag( "ADDING A GOOD NODE ->  $node \n");
    };
    ok( $utils->add_node( $ldap, $node, $new_nodes->{$node} ),
	"adding a node ". $node, 
    );
 };



#-------------------- must fail ----------------------------------------- Go

 foreach my $node ( keys %{$bad_nodes} ){
    if($ENV{DEBUG}){ 
        diag( "ADDING A BAD NODE ->  $node \n");
    };
    ok( 1 - $utils->add_node( $ldap, $node, $bad_nodes->{$node} ),
	"trying to add a bad node ". $node, 
    );
 };

#########################################################################
# clean up ldap tree 
# FIXME - the order of erasing must be reversed 
#
 foreach my $node ( keys %{$new_nodes} ){ $ldap->delete($node)};
 foreach my $node ( keys %{$bad_nodes} ){ $ldap->delete($node)};

 $utils->ldap_disconnect($ldap);

1;
