## SUFFIX SELECTION VALIDATION
##
## Here we can check the suffix selection function.
##
## We do not need running LDAP server for that
## 

use strict;
use warnings;
use utf8;
use File::Spec;
use Test::More;
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

# A hash with DN-s for tests:
#		$dn => suffix index in @{$suffixes} ( - 1 if not found )
# messages about suffixes are in  %suffix_messages - keep it
# syncronized with @{$suffixes} and %cert_dns
# FIXME - would be nice to create those structures dynamically 
#


my %cert_dns=(
            "CN=aa+SN=dC,OU=Decels,L=GB,ST=SomeYz,DC=OpenXPKI,DC=org" => 0,
            "CN=aa+SN=dC,OU=Decels,L=GB,ST=SomeYz,DC=OpenXPKI,C=RU"   => 1,
            "CN=aa+SN=dC,OU=Decels,L=GB,ST=SomeYz,DC=IPMCE,C=RU"      => -1,
            "CN=aa+SN=dC,OU=Decels,L=GB,ST=SomeYz,DC=IPMCE,DC=org"    => -1,
            "CN=aa+SN=dC,OU=Decels,L=GB,ST=SomeYz,DC=OpenXPKI,DC=RU"  => -1,
	    "CN=Иван+SN=dC,OU=Decels,L=GB,ST=SomeYz,DC=OpenXPKI,DC=org" => 
	    0,
	    "CN=John+SN=Иванов,OU=Decels,L=GB,ST=SomeYz,DC=OpenXPKI,DC=org" => 
	    0,
	    "CN=Иван+SN=Иванов,OU=Decels,L=GB,ST=SomeYz,DC=OpenXPKI,DC=org" => 
	    0,
	    "CN=John+SN=dC,OU=Отдел Инвормации,L=RU,ST=Россия,DC=OpenXPKI,DC=org" => 
	    0,
	    "CN=Иван+SN=dC,OU=Decels,L=GB,O=Институт Механики,DC=org" => 
	    2,
	    "CN=John+SN=Иванов,OU=Decels,L=GB,O=Институт Механики,DC=org" => 
	    2,
	    "CN=Иван+SN=Иванов,OU=Decels,L=GB,O=Институт Механики,DC=org" => 
	    2,
	    "CN=John+SN=dC,OU=Отдел Инвормации,L=RU,O=Институт Механики,DC=org" => 
	    2,
	    "CN=Иван+SN=dC,OU=Decels,L=GB,ST=SomeYz,DC=OpenXPKIй,DC=org" => 
	    -1,
	    "CN=John+SN=Иванов,OU=Decels,L=GB,ST=SomeYz,DC=OpenXPKIй,DC=org" => 
	    -1,
  	    "CN=Иван+SN=Иванов,OU=Decels,L=GB,ST=SomeYz,DC=OpenXPKIй,DC=org" => 
	    -1,
	    "CN=John+SN=dC,OU=Отдел Инвормации,L=RU,ST=Россия,DC=OpenXPKIй,DC=org" => 
	    -1,
	    "CN=Иван+SN=dC,OU=Decels,L=GB,O=Институт Механикий,DC=org" => 
	    -1,
	    "CN=John+SN=Иванов,OU=Decels,L=GB,O=Институт Механикий,DC=org" => 
	    -1,
	    "CN=Иван+SN=Иванов,OU=Decels,L=GB,O=Институт Механикий,DC=org" => 
	    -1,
	    "CN=John+SN=dC,OU=Отдел Инвормации,L=RU,O=Институт Механикий,DC=org" => 
	    -1,
            );

my $suffixes=[ 
                'dc=openxpki,dc=org' , 
                'dc=openxpki,c=RU',
                'O=Институт Механики,DC=org',
             ];

#                                 ^
# keep this hash | and this array | synchronized
#                v
my %suffix_messages=( 
            		'dc=openxpki,dc=org' => 
			    'dc=openxpki,dc=org', 
            		'dc=openxpki,c=RU'   => 
			    'dc=openxpki,c=RU',
            		'O=Институт Механики,DC=org' =>
			    ' (UTF-8 characters)',
                    );



my  @results=();
my $utils=OpenXPKI::LdapUtils->new();
my $test_number = scalar (keys %cert_dns);

plan tests => $test_number;


diag "GET SUFFIX VALIDATION\n";

if($ENV{DEBUG}){
    diag( "NUMBER OF TESTS >" . $test_number . "<\n");
};


foreach my $cert_dn ( keys %cert_dns ) {

   if($ENV{DEBUG}){
       diag( "--- DN  --- ".  $cert_dn . "\n");
   };
   
   my $suffix = $utils->get_suffix( $cert_dn , $suffixes );
   if( defined $suffix ){

        if($ENV{DEBUG}){ 
            diag( "SUFFIX  --- ". $suffix . "\n");
        };
        is(
	    $suffix, 
	    $suffixes->[$cert_dns{$cert_dn}],
	    'Find a suffix '. $suffix_messages{$suffix}
	);
   } else {

        if($ENV{DEBUG}){ 
            diag( "SUFFIX  --- NOT FOUND\n");
        };
        is(-1,$cert_dns{$cert_dn},'The suffix does not match anything');
   };       
};
1;


