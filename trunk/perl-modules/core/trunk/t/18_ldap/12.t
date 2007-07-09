#
## LDAP ADD BRANCH VALIDATION
##
## Here we can check adding the whole brunch 
## FIXME - only correct values are checked
##
## We need running LDAP server for that
##

use strict;
use warnings;
use utf8;
use Test::More;
use XML::Simple;
use Data::Dumper;
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
$realm->{ldap_client_cert} = '';
$realm->{ldap_client_key}  = '';
$realm->{ldap_ca_cert}     = '';
$realm->{ldap_sasl} = 'no';
#$realm->{ldap_sasl_mech} ='EXTERNAL'; 
$realm->{ldap_login} = 'cn=Manager,dc=openxpki,dc=org';
$realm->{ldap_password} = 'secret';
$realm->{'schema'} = {};

my $config_file = File::Spec->catfile( 
			't',
			'18_ldap', 
			'ldappublic_test.xml'
		  );
my $config = XMLin( $config_file );
my $dumper= Data::Dumper->new([$config],['realm_config']);

$dumper->Indent(1);
my $make_schema = $dumper->Dump();

my $realm_config;
eval $make_schema;

#-------------------------- CONVERTING SCHEMA TO REALM CONFIG FORMAT
my $schema_profiles = [
			 'default', 
			 'certificate', 
			 'ca',
		      ];
  
foreach my $schema_profile ( @{$schema_profiles} ) {
    my $schema_dump = $realm_config->{'schema'}->{$schema_profile};
    my $schema = { };
    foreach my $rdn ( @{$schema_dump->{'rdn'}} ){

# solving the scalar ref problem   
	my $attributetypes;
	my $musts;        
	my $mays = [];         
	my $structurals;
        my $auxiliaries = [];   

 	if( ref( $rdn->{'attributetype'} ) eq 'ARRAY' ) {
            $attributetypes = $rdn->{'attributetype'};
	} else {
            $attributetypes = [ $rdn->{'attributetype'} ];
	}; 
    
 	if( ref( $rdn->{'must'}->{'attributetype'} ) eq 'ARRAY' ) {
            $musts = $rdn->{'must'}->{'attributetype'};
	} else {
            $musts = [ $rdn->{'must'}->{'attributetype'} ];
	}; 
    
	if( defined $rdn->{'may'} ) {
 		if( ref( $rdn->{'may'}->{'attributetype'} ) eq 'ARRAY' ) {
	            $mays = $rdn->{'may'}->{'attributetype'};
		} else {
            		$mays = [ $rdn->{'may'}->{'attributetype'} ];
		}; 
	}; 
    
 	if( ref( $rdn->{'structural'}->{'objectclass'} ) eq 'ARRAY' ) {
            $structurals = $rdn->{'structural'}->{'objectclass'};
	} else {
            $structurals = [ $rdn->{'structural'}->{'objectclass'} ];
	};     
    
	if( defined $rdn->{'auxiliary'} ) {
 		if( ref( $rdn->{'auxiliary'}->{'objectclass'} ) eq 'ARRAY' ) {
	            $auxiliaries = $rdn->{'auxiliary'}->{'objectclass'};
		} else {
        	    $auxiliaries = [ $rdn->{'auxiliary'}->{'objectclass'} ];
		};     
	}; 
     
	$schema->{ $rdn->{'attributetype'} }= 
                       {
		         'attributetype' => $rdn->{'attributetype'},
			 'must'          => $musts,
			 'may'           => $mays,
			 'structural'    => $structurals,
			 'auxiliary'     => $auxiliaries,
		       };
    };
    $realm->{'schema'}->{$schema_profile} = $schema;  
};

    my $cert_extra_attrs = [
				{ 
				    'mail' => 'jmax@openxpki.org',
                            	    'sn'   => 'Maxwell',
                        	},
				{ 
				    'mail' => 'jmax@openxpki.org',
                            	    'sn'   => 'Иванов',
                        	},
			   ];

#
# The test removes the last created node after adding a branch
# Specifying sequence 
#    rdn4,rdn3,rdn2,rdn1 
#    rdn3,rdn2,rdn1 
#    rdn2,rdn1 
#    rdn1 
# in test_structure
# we can remove all the nodes created without special cleaning
#
    my $dns = [ 
               'ou=x1,dc=openxpki,dc=org',
    	       'o=x3x4,ou=x1,dc=openxpki,dc=org',
               'ou=x1,dc=openxpki,dc=org',
               'cn=John+uid=Bill,o=x3x4,ou=x2,dc=openxpki,dc=org',
               'o=x3x4,ou=x2,dc=openxpki,dc=org',
               'ou=x2,dc=openxpki,dc=org',

               'ou=Институт Механики,dc=openxpki,dc=org',
    	       'o=x3x4,ou=Институт Механики,dc=openxpki,dc=org',
               'ou=Институт Механики,dc=openxpki,dc=org',
               'cn=Иван+uid=Bill,o=Институт,' .
	    	    'ou=Институт,dc=openxpki,dc=org',
               'o=Институт,ou=Институт,dc=openxpki,dc=org',
               'ou=Институт,dc=openxpki,dc=org',

               'ou=Интертех Corp.,dc=openxpki,dc=org',
    	       'o=Институт TWO,ou=Интертех Corp.,' . 
	    	    'dc=openxpki,dc=org',
               'ou=Интертех Corp.,dc=openxpki,dc=org',
               'cn=Иван Smith+uid=Bill,o=Институт TWO,' .
	    	    'ou=Институт TWO,dc=openxpki,dc=org',
               'o=Институт TWO,ou=Институт TWO,' .
	    	    'dc=openxpki,dc=org',
               'ou=Институт TWO,dc=openxpki,dc=org',
	      ];    	     

    #
    # TEST STRUCTURE - indexes for arrays of parameteres    
    #
    #		      [ dn, schema_profile , extras, expected, message ]
    #
    # message is used to indicate utf8 test
    # FIXME - expected is reserved for node structure check
    #
    # we do not use suffix for connect - watch out! 
    # only dc=openxpki,dc=org suffix is supported by
    # test LDAP server configuration	 
    my $test_structure = [
                            [ 0,  1, 0, 0,'' ],
                            [ 1,  1, 0, 0,'' ],
                            [ 2,  1, 0, 0,'' ],
                            [ 3,  1, 0, 0,'' ],
                            [ 4,  1, 0, 0,'' ],
                            [ 5,  1, 0, 0,'' ],
                            [ 6,  1, 0, 0,' (UTF-8 characters in DN)' ],
                            [ 7,  1, 0, 0,' (UTF-8 characters in DN)' ],
                            [ 8,  1, 0, 0,' (UTF-8 characters in DN)' ],
                            [ 9,  1, 0, 0,' (UTF-8 characters in DN)' ],
                            [ 10, 1, 0, 0,' (UTF-8 characters in DN)' ],
                            [ 11, 1, 0, 0,' (UTF-8 characters in DN)' ],
                            [ 12, 1, 0, 0,' (Mixed characters in DN)' ],
                            [ 13, 1, 0, 0,' (Mixed characters in DN)' ],
                            [ 14, 1, 0, 0,' (Mixed characters in DN)' ],
                            [ 15, 1, 0, 0,' (Mixed characters in DN)' ],
                            [ 16, 1, 0, 0,' (Mixed characters in DN)' ],
                            [ 17, 1, 0, 0,' (Mixed characters in DN)' ],
			 ];


 my $test_number = scalar @{$test_structure};

if($ENV{DEBUG}){ 
        diag( "NUMBER OF TESTS >" . $test_number . "<\n");
};

plan tests => $test_number;

diag " LDAP ADD BRANCH VALIDATION\n";

#------------------------------------------------------------------ Go
 my $utils = OpenXPKI::LdapUtils->new();

 for( my $i=0; $i<$test_number; $i++ ) {
      my $i_dn         = $test_structure->[$i]->[0];
      my $i_profile    = $test_structure->[$i]->[1];
      my $i_extras     = $test_structure->[$i]->[2];
      my $i_expected   = $test_structure->[$i]->[3];
      my $message      = $test_structure->[$i]->[4];
      if( $message eq '' ) {
          $message = $dns->[$i_dn];
      };
    
    my $suffix = $utils->get_suffix(
                               $dns->[$i_dn],
                               $realm->{ldap_suffix},
                           );
    if( defined $suffix ) { 
	# we do not use suffix for connect - watch out! 
    	$ldap = $utils->ldap_connect($realm);
	if( defined $ldap ) { 
	    $utils->add_branch( 
                  $ldap,
                  $realm->{'schema'},     
                  $dns->[$i_dn],
                  $suffix,
                  $schema_profiles->[$i_profile],
                  $cert_extra_attrs->[$i_extras],    
            );
    	    if( ( defined $utils->{'ldap_error'} ) && $ENV{DEBUG} ) {
        	my $uerror = 
                   "ACTION: " . $utils->{'ldap_error'}->{'ACTION'} . "\n" .
                   "  CODE: " . $utils->{'ldap_error'}->{'CODE'}   . "\n" .
                   " ERROR: " . $utils->{'ldap_error'}->{'ERROR'}  . "\n" .
                   "  NAME: " . $utils->{'ldap_error'}->{'NAME'}   . "\n" .
                   "  TEXT: " . $utils->{'ldap_error'}->{'TEXT'}   . "\n" .
                   "DESCRIPTION: " . 
                    	   $utils->{'ldap_error'}->{'DESCRIPTION'} . "\n";
                diag("\n-------- ADD BRANCH ERROR DETAILS --------------");
                diag($uerror);
    	    };       
            ok( 
             $utils->check_node(  $ldap, $dns->[$i_dn]  ) &&
             $utils->delete_node(  $ldap, $dns->[$i_dn] ) ,
              "Adding branch " . $message,
            );  
	    #--- FIXME would be nice to check the structure of nodes added 
	    $utils->ldap_disconnect($ldap);
	} else {
	    diag("Ldap connection failed");
	    ok(0,'Adding branch');
	};
    } else {
	diag("Suffix detection failed");
	ok(0,'Adding branch');
    };	
};    
1;	
