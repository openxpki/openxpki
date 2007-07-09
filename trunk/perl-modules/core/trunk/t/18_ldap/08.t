##
## DELETE NODE ERROR MESSAGES VALIDATION
##
## Here we can test the error messages 
## produced by OpenXPKI::LdapUtils->delete_node($$$)
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


# --------------------------------------- checking delete_node error messages
#
# 1) calling delete_node with a bad dn (wrong syntax)
# 2) calling delete_node with a dn that does not exist
# 
#
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

# to add more bad entries for testing modify three ( 3 !) arrays
# keeping them matching each other:
#    $bad_dn_comments    "test diagnostics"
#    $bad_dns            "dns we are going to delete"
#    $bad_dn_errors      "expected error info"
#

 my $bad_dns = [ 
                    '=ou=x1,dc=openxpki,dc=org',
                     'ou=x3,dc=openxpki,dc=org',
               ];

#
# bad entries description 
#
  my $bad_dn_comments = [
    ' 1) calling delete_node with a bad dn (wrong syntax)',
    ' 2) calling delete_node while the node does not exist',
  ]; 

my $bad_dn_errors = [
                {
                  'TEXT' => 'TEXT IGNORED',
                  'ERROR' => 'invalid DN',
                  'NAME' => 'LDAP_INVALID_DN_SYNTAX',
                  'ACTION' => 'I18N_OPENXPKI_LDAPUTILS_DELETE_NODE_SIMPLE',
                  'DESCRIPTION' => 'Invalid DN syntax',
                  'CODE' => 34
                },
                {
                  'TEXT' => 'TEXT IGNORED',
                  'ERROR' => 'No such object',
                  'NAME' => 'LDAP_NO_SUCH_OBJECT',
                  'ACTION' => 'I18N_OPENXPKI_LDAPUTILS_DELETE_NODE_SIMPLE',
                  'DESCRIPTION' => 'No such object',
                  'CODE' => 32
                },
 ];

my $test_number = scalar @{$bad_dns};

if($ENV{DEBUG}){ 
    diag( "NUMBER OF TESTS >" . $test_number . "<\n");
};
plan tests => $test_number;

diag "DELETE NODE ERROR MESSAGES VALIDATION\n";

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
        $utils->reset_error;
        $utils->delete_node( $ldap, $bad_dns->[$i] );
        my $error_hash = $utils->{'ldap_error'}; 
        if( defined $error_hash ) {
             $error_hash->{'TEXT'} = 'TEXT IGNORED';
             is_deeply( $error_hash, 
                        $bad_dn_errors->[$i],
                        $bad_dn_comments->[$i],
             );

            if($ENV{DEBUG}){ 
                dump_error($utils);
            };

        } else {
             ok(0,$bad_dn_comments->[$i]),
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
1;
