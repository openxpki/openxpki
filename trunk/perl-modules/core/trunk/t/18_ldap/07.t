##
## ADD NODE ERROR MESSAGES VALIDATION
##
## Here we can test the error messages 
## produced by OpenXPKI::LdapUtils->add_node($$$)
##
## We need running LDAP server for that
##

use strict;
use warnings;
use utf8;
use Test::More;
use OpenXPKI::LdapUtils;
use Data::Dumper;
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


# we use test nodes to add them and provide existing nodes for test
 my $test_nodes = { 
                    'ou=x1,dc=openxpki,dc=org' =>  [
                                                              'ou' => 'x1', 
                                                     'objectclass' => [ 
						          'organizationalUnit',
					             ],
						   ],     
                    'ou=x2,dc=openxpki,dc=org' =>  [
                                                               'ou' => 'x2', 
                                                      'objectclass' => [ 
						          'organizationalUnit',
					              ],
						    ],    
                  };    	     
#
# bad entries description 
#
# to add more bad entries for testing modify three ( 3 !) arrays
# keeping them matching each other:
#    $bad_nodes_comments    "test diagnostics"
#    $bad_nodes             "dn + attributes"
#    $bad_nodes_errors      "expected error info"
#
  my $bad_nodes_comments = [
    ' 1) calling add_node with a bad dn (wrong syntax)',
    ' 2) calling add_node while intermediate node does not exist',
    ' 3) calling add_node with an attribute value that does not match dn',
    ' 4) calling add_node with an attribute that violates schema',
    ' 5) calling add_node with an object class that is not in schema',
    ' 6) calling add_node with two structural object classes',
    ' 7) calling add_node with the dn that matches existing node',
  ]; 

 my $bad_nodes = [ 
# 1) calling add_node with a bad dn (wrong syntax)
                   {
                   '=ou=x1,dc=openxpki,dc=org' =>  [
                                                              'ou' => 'x1', 
                                                     'objectclass' => [ 
						          'organizationalUnit',
					             ],
						   ],
                   },
# 2) calling add_node while intermediate node does not exist
                   {
               'o=x3,o=x3,dc=openxpki,dc=org' =>   [
                                                               'o' => 'x3', 
                                                     'objectclass' => [ 
						          'organization',
					             ],
						   ],
                   },
# 3) calling add_node with an attribute value that does not match dn
                   {
                    'ou=x5,dc=openxpki,dc=org' =>  [
                                                               'ou' => 'x1', 
                                                      'objectclass' => [ 
						          'organizationalUnit',
					              ],
						    ],
                   },
# 4) calling add_node with an attribute that violates schema
                   {
                    'cn=x6,dc=openxpki,dc=org' => [
                                                             'cn' => 'x6', 
                                                      'objectclass' => [ 
						           'organization',
					              ],
						  ],
                   },
# 5) calling add_node with an object class that is not in schema
                   {
                    'ou=x7,dc=openxpki,dc=org' => [
                                                              'ou' => 'x7', 
                                                     'objectclass' => [ 
                                                          'organizationalUNIX',
                                                     ],
                                                  ],     
                   },
#  6) calling add_node with two structural object classes
                   {
               'o=x9+ou=x9,dc=openxpki,dc=org' =>  [
                                                               'o' => 'x9', 
                                                              'ou' => 'x9', 
                                                     'objectclass' => [ 
                                                              'organization',
                                                        'organizationalUnit',
                                                     ],
                                                   ],     
                   },
# 7) calling add_node with the dn that matches existing node 
                   {
                    'ou=x1,dc=openxpki,dc=org' =>  [
                                                              'ou' => 'x1', 
                                                     'objectclass' => [ 
                                                          'organizationalUnit',
                                                     ],
                                                   ],     
		   },    	     
    ];

my $bad_nodes_errors = [
                {
                  'TEXT' => 'TEXT IGNORED',
                  'ERROR' => 'invalid DN',
                  'NAME' => 'LDAP_INVALID_DN_SYNTAX',
                  'ACTION' => 'I18N_OPENXPKI_LDAPUTILS_ADD_NODE_SIMPLE',
                  'DESCRIPTION' => 'Invalid DN syntax',
                  'CODE' => 34
                },
                {
                  'TEXT' => 'TEXT IGNORED',
                  'ERROR' => 'No such object',
                  'NAME' => 'LDAP_NO_SUCH_OBJECT',
                  'ACTION' => 'I18N_OPENXPKI_LDAPUTILS_ADD_NODE_SIMPLE',
                  'DESCRIPTION' => 'No such object',
                  'CODE' => 32
                },
                {
                  'TEXT' => 'TEXT IGNORED',
                  'ERROR' => 'value of naming attribute \'ou\' is not present in entry',
                  'NAME' => 'LDAP_NAMING_VIOLATION',
                  'ACTION' => 'I18N_OPENXPKI_LDAPUTILS_ADD_NODE_SIMPLE',
                  'DESCRIPTION' => 'Naming violation',
                  'CODE' => 64
                },
                {
                  'TEXT' => 'TEXT IGNORED',
                  'ERROR' => 'object class \'organization\' requires attribute \'o\'',
                  'NAME' => 'LDAP_OBJECT_CLASS_VIOLATION',
                  'ACTION' => 'I18N_OPENXPKI_LDAPUTILS_ADD_NODE_SIMPLE',
                  'DESCRIPTION' => 'Object class violation',
                  'CODE' => 65
                },
                {
                  'TEXT' => 'TEXT IGNORED',
                  'ERROR' => 'objectclass: value #0 invalid per syntax',
                  'NAME' => 'LDAP_INVALID_SYNTAX',
                  'ACTION' => 'I18N_OPENXPKI_LDAPUTILS_ADD_NODE_SIMPLE',
                  'DESCRIPTION' => 'Invalid syntax',
                  'CODE' => 21
                },
                {
                  'TEXT' => 'TEXT IGNORED',
                  'ERROR' => 'invalid structural object class chain (organization/organizationalUnit)',
                  'NAME' => 'LDAP_OBJECT_CLASS_VIOLATION',
                  'ACTION' => 'I18N_OPENXPKI_LDAPUTILS_ADD_NODE_SIMPLE',
                  'DESCRIPTION' => 'Object class violation',
                  'CODE' => 65
                },
                {
                  'TEXT' => 'TEXT IGNORED',
                  'ERROR' => 'Already exists',
                  'NAME' => 'LDAP_ALREADY_EXISTS',
                  'ACTION' => 'I18N_OPENXPKI_LDAPUTILS_ADD_NODE_SIMPLE',
                  'DESCRIPTION' => 'Already exists',
                  'CODE' => 68
                },
];

my $test_number = scalar @{$bad_nodes};

if($ENV{DEBUG}){ 
    diag( "NUMBER OF TESTS >" . $test_number . "<\n");
};

plan tests => $test_number;

diag "ADD NODE ERROR MESSAGES VALIDATION\n";

#------------------- Call utils -----------------------------------------

 my $utils = OpenXPKI::LdapUtils->new();
 $ldap = $utils->ldap_connect($realm);

#-------------------- add some nodes for testing ---------------------- Go

 foreach my $node ( keys %{$test_nodes} ){
    $utils->add_node( $ldap, $node, $test_nodes->{$node} ); 
 
    if($ENV{DEBUG}){ 
        diag( "ADDING TEST NODE ->  $node \n");
        dump_error($utils);     
    };
 };


#-------------------- must fail to add and we will check reasons----------- Go

 for( my $i=0; $i < $test_number ; $i++ ) {
     foreach my $node ( keys %{$bad_nodes->[$i]} ) {
        $utils->reset_error;
        $utils->add_node(   $ldap, 
                            $node, 
                            $bad_nodes->[$i]->{$node},
                );
        my $error_hash = $utils->{'ldap_error'}; 
        if( defined $error_hash ) {
            $error_hash->{'TEXT'} = 'TEXT IGNORED';
            is_deeply( $error_hash, 
                       $bad_nodes_errors->[$i],
                       $bad_nodes_comments->[$i],
            );

            if($ENV{DEBUG}){ 
                dump_error($utils);
            };

        } else {
            ok(0,$bad_nodes_comments->[$i]),
        }; 
     };
 };

#########################################################################
# clean up ldap tree
#
# FIXME - the order of erasing must be reversed
#
 foreach my $node ( keys %{$test_nodes} ){ $ldap->delete($node)};

 $utils->ldap_disconnect($ldap);

1;

# Use dump_error to get right samples of error hashes
#
sub dump_error
{
    my $utils = shift;
    my $error_hash = $utils->{'ldap_error'}; 
    if( defined $error_hash ) {
        $error_hash->{'TEXT'} = 'TEXT IGNORED';
        my $dumper= Data::Dumper->new([ $error_hash ],['err_messages']);
        $dumper->Indent(1);
        my $dump_errors = $dumper->Dump();
        diag("\n---------------- EMULATING ERRORS --------------");
        diag($dump_errors);
    
#         uncomment this to get TEXT field printed too
#         (we does not check it and replace it with 'TEXT IGNORED')
#      
#     
#         my $uerror = "ACTION: " . $utils->{'ldap_error'}->{'ACTION'}      . "\n" .
#                      "  CODE: " . $utils->{'ldap_error'}->{'CODE'}        . "\n" .
#                      " ERROR: " . $utils->{'ldap_error'}->{'ERROR'}       . "\n" .
#                      "  NAME: " . $utils->{'ldap_error'}->{'NAME'}        . "\n" .
#                      "  TEXT: " . $utils->{'ldap_error'}->{'TEXT'}        . "\n" .
#                 "DESCRIPTION: " . $utils->{'ldap_error'}->{'DESCRIPTION'} . "\n";
#         diag($uerror);
    
       return 1;
    } else {
       return 0; 
    };
}

