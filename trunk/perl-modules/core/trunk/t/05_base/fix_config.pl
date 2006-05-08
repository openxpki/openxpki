use strict;
use warnings;
use English;

my @pwentry = getpwuid ($UID);
replace_param (FILENAME => "t/config.xml",
               TAG      => "user",
               VALUE    => $pwentry[0])
    if ($pwentry[0] ne "root");

my @grentry = getgrgid ($GID);
replace_param (FILENAME => "t/config.xml",
               TAG      => "group",
               VALUE    => $grentry[0])
    if ($grentry[0] ne "root"); # On BSDs user root belongs to group 'wheel'
                                # and group 'root' is absent altogether

if ($pwentry[0] ne "root")
{
    ## warn the user
    print STDERR "Please note that you are not root.\n".
                 "The tests cannot verify that the change UID and GID operations work.\n";
}

my $openssl_binary = `cat t/cfg.binary.openssl`;
replace_param (FILENAME => "t/25_crypto/token.xml",
               TAG      => "shell",
               VALUE    => $openssl_binary);

## prepare GOST configuration
if (exists $ENV{GOST_OPENSSL_ENGINE})
{
    $ENV{GOST_OPENSSL} = $openssl_binary if (not exists $ENV{GOST_OPENSSL});
    replace_param (FILENAME => "t/25_crypto/token.xml",
                   PARAM    => "__GOST_ENGINE_LIBRARY__",
                   VALUE    => $ENV{GOST_OPENSSL_ENGINE});
    replace_param (FILENAME => "t/25_crypto/token.xml",
                   PARAM    => "__GOST_OPENSSL__",
                   VALUE    => $ENV{GOST_OPENSSL});
}
else
{
    ## drop all the GOST configuration to avoid exceptions during initialization
    replace_param (FILENAME => "t/config.xml",
                   PARAM    => "default_gost",
                   VALUE    => "default");
    replace_param (FILENAME => "t/config.xml",
                   PARAM    => "cagost",
                   VALUE    => "ca1");
}

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

    my $i = 0;
    while (-e sprintf ("%s.%03d", $filename, $i)) {$i++;}

    rename ($filename, sprintf ("%s.%03d", $filename, $i));
    open FD, ">$filename" or die "Cannot open configuration file $filename for writing.\n";
    print FD $file;
    close FD;
}

1;
