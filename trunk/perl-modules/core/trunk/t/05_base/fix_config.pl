use strict;
use warnings;
use English;
use File::Spec;

## critical directories and files 
my   $test_directory = 't';
my  $token_directory = '25_crypto';
my   $auth_directory = '50_auth';

## critical  files 
my    $auth_config   =   'auth_test.xml';
my    $main_config   = 'config_test.xml';
my   $token_config   =  'token_test.xml';


## build paths
my  $main_config_xml = 
        File::Spec->catfile($test_directory, $main_config   );
my $token_config_xml = 
        File::Spec->catfile($test_directory,
			    $token_directory,
			    $token_config   );
my  $auth_config_xml = 
        File::Spec->catfile($test_directory,
			    $auth_directory,
			    $auth_config   );

## replace parameters

my @pwentry = getpwuid ($UID);
replace_param (FILENAME => "$main_config_xml",
               TAG      => "user",
               VALUE    => $pwentry[0])
    if ($pwentry[0] ne "root");

my @grentry = getgrgid ($GID);
replace_param (FILENAME => "$main_config_xml",
               TAG      => "group",
               VALUE    => $grentry[0])
    if ($grentry[0] ne "root"); # On BSDs user root belongs to group 'wheel'
                                # and group 'root' is absent altogether

if ($pwentry[0] ne "root")
{
    ## warn the user
    diag "Please note that you are not root.\n".
                 "The tests cannot verify that the change UID and GID operations work.\n";
}


my $test_openssl = File::Spec->catfile('t','cfg.binary.openssl');  
my $openxpki_openssl = `cat $test_openssl`;
chomp $openxpki_openssl;
my $openssl_binary = $openxpki_openssl;
replace_param (FILENAME => "$token_config_xml",
               TAG      => "shell",
               VALUE    => $openssl_binary);

## prepare GOST configuration
if (exists $ENV{GOST_OPENSSL_ENGINE})
{
    $ENV{GOST_OPENSSL} = $openssl_binary if (not exists $ENV{GOST_OPENSSL});
    replace_param (FILENAME => "$token_config_xml",
                   PARAM    => "__GOST_ENGINE_LIBRARY__",
                   VALUE    => $ENV{GOST_OPENSSL_ENGINE});
    replace_param (FILENAME => "$token_config_xml",
                   PARAM    => "__GOST_OPENSSL__",
                   VALUE    => $ENV{GOST_OPENSSL});
}
else
{
    ## drop all the GOST configuration to avoid exceptions during initialization
    replace_param (FILENAME => "$main_config_xml",
                   PARAM    => "default_gost",
                   VALUE    => "default");
    replace_param (FILENAME => "$main_config_xml",
                   PARAM    => "cagost",
                   VALUE    => "ca1");
}

## prepare nCipher configuration
if ((exists $ENV{NCIPHER_LIBRARY}) and (exists $ENV{CHIL_LIBRARY}) and (exists $ENV{NCIPHER_KEY})) 
{
    replace_param (FILENAME => "$token_config_xml",
                   PARAM    => "__CHIL_LIBRARY__",
                   VALUE    => $ENV{CHIL_LIBRARY});
    replace_param (FILENAME => "$token_config_xml",
                   PARAM    => "__NCIPHER_LIBRARY__",
                   VALUE    => $ENV{NCIPHER_LIBRARY});
    replace_param (FILENAME => "$token_config_xml",
                   PARAM    => "__NCIPHER_KEY__",
                   VALUE    => $ENV{NCIPHER_KEY});
}
else
{
    ## drop all the nCipher configuration to avoid exceptions during initialization
    replace_param (FILENAME => "$main_config_xml",
                   PARAM    => "default_nciph",
                   VALUE    => "default");
    replace_param (FILENAME => "$main_config_xml",
                   PARAM    => "canciph",
                   VALUE    => "ca1");
}

if( not exists $ENV{OPENXPKI_LDAP_MODULE_PATH} or
    not exists $ENV{OPENXPKI_LDAP_DAEMON_PATH} )  {
    # do not use ldap	
    replace_param (FILENAME => "$auth_config_xml",
                   PARAM    => "__LDAP_CA_PATH__",
                   VALUE    => "no");
} else {
    # specify the directory to look for the CA certificate
    my $test_directory_certs   = File::Spec->catfile(
				$test_directory,
				$auth_directory,
   				'ldap_certs',
		     ); 
    replace_param (FILENAME => "$auth_config_xml",
                   PARAM    => "__LDAP_CA_PATH__",
                   VALUE    => "$test_directory_certs");
}; 

sub replace_param
{
    my $keys     = { @_ };
    my $filename = $keys->{FILENAME};
    my $tag      = $keys->{TAG};
    my $param    = $keys->{PARAM};
    my $value    = $keys->{VALUE};

    open FD, $filename or die "Cannot open configuration file $filename.\n";
    my $file = "";
    while (<FD>)
    {
        $file .= $_;
    }
    close FD;

    if (exists $keys->{TAG})
    {
        $file =~ s{(<$tag>)([^<]*)(</$tag>\s*)}
                  {$1$value$3}sgx;
    } else {
        $file =~ s{$param}
                  {$value}sgx;
    }

    open FD, '>', $filename or die "Cannot open configuration file $filename for writing.\n";
    print FD $file;
    close FD;
}

1;
