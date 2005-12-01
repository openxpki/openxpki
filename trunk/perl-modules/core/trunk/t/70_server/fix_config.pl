use strict;
use warnings;
use English;

## load file

my $filename = "t/config.xml";
open FD, $filename or die "Cannot open configuration file $filename.\n";
my $file = "";
while (<FD>)
{
    $file .= $_;
}
close FD;
my $change_config = 0;

my @pwentry = getpwuid ($UID);
if ($pwentry[0] ne "root")
{
    $change_config = 1;

    ## replace user root
    $file =~ s/<user>root<\/user>/<user>$pwentry[0]<\/user>/;

    ## replace group root
    my @grentry = getgrgid ($GID);
    $file =~ s/<group>root<\/group>/<group>$grentry[0]<\/group>/;

    ## warn the user
    print STDERR "Please note that you are not root.\n".
                 "The tests cannot verify that the change UID and GID operations work.\n";
}

if ($change_config)
{
    rename ($filename, $filename.".org.log");
    open FD, ">$filename" or die "Cannot open configuration file $filename for writing.\n";
    print FD $file;
    close FD;
}

1;
