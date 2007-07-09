## GET EXISTING PATH VALIDATION
##
## Here we can check the function returning existing path.
##
## We need running LDAP server for that
##
#
#
use utf8;
use strict;
use warnings;
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
$realm->{ldap_server} = 'localhost';
$realm->{ldap_port} = '60389';
$realm->{ldap_version} = '3';
$realm->{ldap_tls} = 'no';
$realm->{ldap_sasl} = 'no';
$realm->{ldap_login} = 'cn=Manager,dc=openxpki,dc=org';
$realm->{ldap_password} = 'secret';

# ------------------------------ ADD TEST NODES FIRST ------------------

 my $test_nodes = [ 
                    'ou=x1,dc=openxpki,dc=org' =>  
			[
                    		     'ou' => 'x1', 
                            'objectclass' => [ 
				'organizationalUnit',
			    ],
			],     
    	   'o=x3x4,ou=x1,dc=openxpki,dc=org' =>   
			[
                    		      'o' => 'x3x4', 
                            'objectclass' => [ 
			      'organization',
			    ],
			],
     'ou=x2\\+qq,o=x3x4,ou=x1,dc=openxpki,dc=org' =>  
    			[
                    		     'ou' => 'x2+qq', 
                    	    'objectclass' => [ 
				'organizationalUnit',
			    ],
			],    
    'cn=John+sn=Smith,ou=x1,dc=openxpki,dc=org' =>   
			[
                        	     'cn' => 'John',
				     'sn' => 'Smith', 
                    	    'objectclass' => [ 
				'person',
			    ],
			],  
    'ou=Институт,dc=openxpki,dc=org' =>  
			[
                    		     'ou' => 'Институт', 
                            'objectclass' => [ 
				'organizationalUnit',
			    ],
			],     
    	   'o=Институт TWO,ou=Институт,dc=openxpki,dc=org' =>   
			[
                    		      'o' => 'Институт TWO', 
                            'objectclass' => [ 
			      'organization',
			    ],
			],
     'ou=x2\\+Институт,o=Институт TWO,ou=Институт,dc=openxpki,dc=org' =>  
    			[
                    		     'ou' => 'x2+Институт', 
                    	    'objectclass' => [ 
				'organizationalUnit',
			    ],
			],    
    'cn=Иван+sn=Smith,ou=Институт,dc=openxpki,dc=org' =>   
			[
                        	     'cn' => 'Иван',
				     'sn' => 'Smith', 
                    	    'objectclass' => [ 
				'person',
			    ],
			],  
		  ];    	     

 my $node_number = scalar @{$test_nodes};

 my $utils = OpenXPKI::LdapUtils->new();
 $ldap = $utils->ldap_connect($realm);
 if( !defined $ldap) {
	plan skip_all => 'Failed to connect to LDAP server';
 }; 
 for(my $i=0; $i<$node_number; $i+=2){
    if( !$utils->add_node( $ldap, $test_nodes->[$i],$test_nodes->[$i+1] ) ) {
	$utils->ldap_disconnect($ldap);
	plan skip_all => 'Failed to add nodes for testing';
    };	
 };

# FIXME change dn to match added test nodes
#
# TEST SAMPLES:
#		$xdn => [ $depth,  $expected_depth ,     $message ]
#                 |         |           |                    |
#                 DN  where to search  where it must be   ok message
#
 my $x_dns={
            'CN=aa+SN=dC,OU=Decels,L=GB,ST=SomeYz,' .
		'DC=OpenXPKI,DC=org'  => [ 3, 0, 
					   'we expect not to find any node'
					 ],
	    'C=RU' 		      => [ 1, 0,
					   'we expect not to find any node'
					 ],
            'CN=aa+SN=dC\,\++OU=Decels\,7,L=GB,OU=x1,' . 
	       'DC=OpenXPKI,DC=org\,' => [ 4, 0,
					   'we expect not to find any node'
					 ],
            'CN=aa+SN=dC\,\++OU=Decels\,7,L=GB,OU=x1,' . 
	         'DC=OpenXPKI,DC=org' => [ 4, 3, 'we expect to find a node'],
	    'O=ipmce,' . 
		'dc=openxpki,dc=org'  => [ 2, 2, 'looking for the top node'],
	    'O=msu,' . 
		'dc=openxpki,dc=org'  => [ 4, -1, 'detecting bad depth'],
            'cn=XX,ou=x2\+qq,o=x3x4,ou=x1,'.
	         'dc=openxpki,dc=org' => [ 4, 2, 'we expect to find a node'],  

            'CN=Иван Smith+SN=dC,OU=Decels,L=GB,ST=SomeYz,' .
		'DC=OpenXPKI,DC=org'  => [ 3, 0, 
					   'we expect not to find any node' .
					   ' (UTF-8 in DN)'
					 ],
	    'CN=Иван Smith'	      => [ 1, 0,
					   'we expect not to find any node' .
					   ' (UTF-8 in DN)'
					 ],
            'CN=Иван Smith+SN=dC\,\++OU=Decels\,7,L=GB,OU=x1,' . 
	       'DC=OpenXPKI,DC=org\,' => [ 4, 0,
					   'we expect not to find any node' .
					   ' (UTF-8 in DN)'
					 ],
            'CN=aa+SN=dC\,\++OU=Decels\,7,L=GB,OU=Институт,' . 
	         'DC=OpenXPKI,DC=org' => [ 4, 3, 'we expect to find a node' .
					   ' (UTF-8 in DN)'
					 ],
	    'O=ИвX25,' . 
		'dc=openxpki,dc=org'  => [ 2, 2, 'looking for the top node' .
					   ' (UTF-8 in DN)'
		        		 ],
	    'O=ИвX25,' . 
		'dc=openxpki,dc=org'  => [ 4, -1, 'detecting bad depth' . 
					   ' (UTF-8 in DN)'
					 ],
            'cn=XX,ou=x2\\+Институт,o=Институт TWO,' . 
		 'ou=Институт,'.
	         'dc=openxpki,dc=org' => [ 4, 2, 'we expect to find a node' .
					   ' (UTF-8 in DN)'
					 ],  

	   };


my $test_number = scalar (keys %{$x_dns}) ;
if($ENV{DEBUG}){
    diag( "NUMBER OF TESTS >" . $test_number . "<\n");
};

plan tests => $test_number;

diag "GET EXISTING PATH VALIDATION\n";

#------------------------------------------------------------------ Go

 $ldap = $utils->ldap_connect($realm);

 foreach my $xdn ( keys %{$x_dns} ){
    my $depth          = $x_dns->{$xdn}->[0];
    my $expected_depth = $x_dns->{$xdn}->[1];
    my $message	       = $x_dns->{$xdn}->[2];

    if($ENV{DEBUG}){
	diag( "$xdn DEPTH  $depth EXPECTED $expected_depth \n" );
    };

    my $index = $utils->get_existing_path( $ldap, $xdn, $depth );
    ok( $index == $expected_depth, $message); 
    if( $index > 0 ){
	if($ENV{DEBUG}){
	    diag("FOUND A NODE AT DEPTH $index \n" );
	};
    } else {
	if( $index == 0 ){
	    if($ENV{DEBUG}){
	        diag("NO NODES EXISTS \n" );
	    };
	} else {
	    if($ENV{DEBUG}){
		diag( "WRONG DN SYNTAX \n");
	    };	
	};
    };	
 };


#########################################################################
# clean up ldap tree 
#
 for(my $i = $node_number-2; $i>=0; $i-=2){
	$ldap->delete($test_nodes->[$i]),
 };

 $utils->ldap_disconnect($ldap);

1;
