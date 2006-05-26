#!/usr/bin/perl

# perl 5.6.1 - Solaris Perl understand this too ;)
use 5.006_001;

# use Smart::Comments;

# find all files

my $result = `find . -type f -print`;
my @list = grep !/^(\.|\.\.)$/, split /\n/, $result;

our @modules = ("OpenXPKI::Server");
foreach my $filename (@list)
{
    # extract use statements
    open my $fh, $filename or die "Cannot open file $filename.\n";
    ### $filename
    while (my $line = <$fh>) {
	chomp $line;
	if (m{ \A use \s+ (\S+) }xms) {
	    ### $1
	    push @modules, $1;
	}
    }
}

# checking modules
my $last = "";
my @missing = ();
foreach my $module (sort @modules)
{
    next if ($module =~ /\$/);  # no dynamic includes
    next if ($last eq $module); # no double checks
    next if ($module =~ m{ use\ (?:Errno|POSIX) }xms ); # whitelisted modules
    $last = $module;

    ### $module
    if (not eval "use $module;" and $@)
    {
        push @missing, $module;
    }
}

if (not @missing)
{
    print STDOUT "All modules are available.\n";
} else {
    print STDOUT "There are some modules missing.\n";
    foreach my $module (@missing)
    {
        print STDERR "    $module\n";
    }
    exit 1;
}

1;
