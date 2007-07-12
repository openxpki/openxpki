#
## LDAP NODE ATTRIBUTES BUILDING VALIDATION
##
## Here we can check the suffix selection function.
##
## We do not need running LDAP server for that
##

use strict;
use warnings;
use utf8;
use Test::More;
use XML::Simple;
use Data::Dumper;
use File::Spec;
use OpenXPKI::LdapUtils;

#--- check permission to run test
my $test_directory = File::Spec->catfile( 't', '18_ldap');
my $semaphore_file = File::Spec->catfile(
			    $test_directory,
                    	    'enable_talk_to_server',
		     );
if( !( -f $semaphore_file) ) {
    plan skip_all => "No ldap server for testing";
};


my  $utils=OpenXPKI::LdapUtils->new();

my $config_file = File::Spec->catfile(
			't', '18_ldap', 'ldappublic_dummy.xml'
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
my $schemas=[];
		      
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
    push @{$schemas}, $schema;
};

    my $schema;
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

    my $dn_hashes        = [
				{ 
				    'dc' => ['openxpki','org'],
                            	    'ou' => 'Security',
			    	    'o'  => 'University'
				},
				{ 
				    'dc' => ['openxpki','org'],
                            	    'ou' => 'Security',
			    	    'o'  => 'Институт Механики',
				},
				{ 
				    'dc' => ['openxpki','org'],
                            	    'ou' => 'Security',
			    	    'o'  => 'Институт IPMCE',
				},
			   ];
			    
    my $parsed_rdns      = [
				[ 
                            	    [ 'cn' ,'James'],
                            	    [ 'uid','jmax'],
                        	],
				[ 
                            	    [ 'cn' ,'Server'],
                        	],
				[ 
                            	    [ 'cn' ,'Иван'],
                            	    [ 'uid','jmax'],
                        	],
				[ 
                            	    [ 'cn' ,'Интертех'],
                        	],
				[ 
                            	    [ 'cn' ,'Иван Smith'],
                            	    [ 'uid','jmax'],
                        	],
				[ 
                            	    [ 'cn' ,'Интертех Corp.'],
                        	],
			   ];   	  
    my $expected_hashes =  [
				{
    				    'objectclass' => [
		        		'opencaEmailAddress',
			        	'pkiUser',
					'organizationalPerson',
					'person',
				        'inetOrgPerson'
				    ],
				      'ou' => 'Security',
				     'uid' => 'jmax',
				      'cn' => 'James',
				      'sn' => 'Maxwell',
				    'mail' => 'jmax@openxpki.org',
				       'o' => 'University',
			        },
				{
    				    'objectclass' => [
		        		'opencaEmailAddress',
					'organizationalRole',
			        	'pkiCA',
				    ],
				      'ou' => 'Security',
				      'cn' => 'Server',
				    'mail' => 'jmax@openxpki.org',
			        },
				{
    				    'objectclass' => [
		        		'opencaEmailAddress',
			        	'pkiUser',
					'organizationalPerson',
					'person',
				        'inetOrgPerson'
				    ],
				      'ou' => 'Security',
				     'uid' => 'jmax',
				      'cn' => 'Иван',
				      'sn' => 'Иванов',
				    'mail' => 'jmax@openxpki.org',
				       'o' => 'University',
			        },
				{
    				    'objectclass' => [
		        		'opencaEmailAddress',
					'organizationalRole',
			        	'pkiCA',
				    ],
				      'ou' => 'Security',
				      'cn' => 'Интертех',
				    'mail' => 'jmax@openxpki.org',
			        },
				{
    				    'objectclass' => [
		        		'opencaEmailAddress',
			        	'pkiUser',
					'organizationalPerson',
					'person',
				        'inetOrgPerson'
				    ],
				      'ou' => 'Security',
				     'uid' => 'jmax',
				      'cn' => 'Иван Smith',
				      'sn' => 'Иванов',
				    'mail' => 'jmax@openxpki.org',
				       'o' => 'University',
			        },
				{
    				    'objectclass' => [
		        		'opencaEmailAddress',
					'organizationalRole',
			        	'pkiCA',
				    ],
				      'ou' => 'Security',
				      'cn' => 'Интертех Corp.',
				    'mail' => 'jmax@openxpki.org',
			        },
				{
    				    'objectclass' => [
		        		'opencaEmailAddress',
			        	'pkiUser',
					'organizationalPerson',
					'person',
				        'inetOrgPerson'
				    ],
				      'ou' => 'Security',
				     'uid' => 'jmax',
				      'cn' => 'Иван',
				      'sn' => 'Иванов',
				    'mail' => 'jmax@openxpki.org',
				       'o' => 'Институт Механики',
			        },
				{
    				    'objectclass' => [
		        		'opencaEmailAddress',
			        	'pkiUser',
					'organizationalPerson',
					'person',
				        'inetOrgPerson'
				    ],
				      'ou' => 'Security',
				     'uid' => 'jmax',
				      'cn' => 'Иван Smith',
				      'sn' => 'Иванов',
				    'mail' => 'jmax@openxpki.org',
				       'o' => 'Институт IPMCE',
			        },

			   ];


    #
    # TEST STRUCTURE - indexes for arrays of parameteres    
    #
    #		      [ schema, extras, dn_hash, parsed, expected, message ]
    #
    # message is used to indicate UTF-8 tests
    #
    
    my $test_structure = [
			    [  1, 0, 0, 0, 0,''                          ],	 	    	
			    [  0, 0, 0, 1, 1,''                          ],	 	    	
			    [  1, 1, 0, 2, 2,'(UTF-8 attributes)'        ],	 	    	
			    [  0, 1, 0, 3, 3,'(UTF-8 attributes)'        ],	 	    	
			    [  1, 1, 0, 4, 4,'(Mixed attributes)'        ],	 	    	
			    [  0, 1, 0, 5, 5,'(Mixed attributes)'        ],	 	    	
			    [  1, 1, 1, 2, 6,'(UTF-8 attributes in dn)'  ],	 	    	
			    [  1, 1, 2, 4, 7,'(Mixed attributes in dn)'  ],	 	    	
			 ];

    my $test_number = scalar @{$test_structure};

    plan tests => $test_number;

    diag "LDAP NODE ATTRIBUTES BUILDING VALIDATION\n";

    for( my $i=0; $i < $test_number ;$i++) {

	my $i_schemas      = $test_structure->[$i]->[0];
	my $i_extras       = $test_structure->[$i]->[1];
	my $i_dn_hash      = $test_structure->[$i]->[2];
	my $i_parsed_rdn   = $test_structure->[$i]->[3];
	my $i_expected     = $test_structure->[$i]->[4];
	my $utf8_indicator = $test_structure->[$i]->[5];
	my @add_ldap_args = $utils->get_ldap_node_attributes( 
                    	    			    $schemas->[$i_schemas],
            	                	    $cert_extra_attrs->[$i_extras],
				    		   $dn_hashes->[$i_dn_hash],
                    	        		 $parsed_rdns->[$i_parsed_rdn],
                    		    );

	my $test_dumper = Data::Dumper->
				new( 
				    [ {@add_ldap_args} ],
				    ['test_hash']
				 );
	$test_dumper->Indent(1);
	my $test_hash_code = $test_dumper->Dump();
	
#    print $test_hash_code;
#      |
#     use this to create expected hash code if it is really valid
#
#
	my $test_hash;
	eval  $test_hash_code;
        is_deeply(
			$test_hash, 
	    $expected_hashes->[$i_expected], 
	    "Building node attributes for <" .
		$schema_profiles->[$i_schemas] .
		"> profile " . $utf8_indicator,
	);
    };
1;	


