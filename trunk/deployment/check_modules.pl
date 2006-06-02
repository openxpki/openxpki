#!/usr/bin/perl

# perl 5.6.1 - Solaris Perl understand this too ;)
use 5.006_001;

use Getopt::Long;
use Pod::Usage;

my %params;
GetOptions(\%params,
	   qw(
	      help|?
	      man
              dump
              debug
	      )) 
 or pod2usage(-verbose => 0);

pod2usage(-exitstatus => 0, -verbose => 2) if $params{man};
pod2usage(-verbose => 1) if ($params{help});


# find all files

my $result = `find . -type f -print`;
my @list = grep !/^(\.|\.\.)$/, split /\n/, $result;

our @modules = ("OpenXPKI::Server");
FILE:
foreach my $filename (@list)
{
    next FILE if ($filename =~ m{ \.svn\/ }xms);

    # extract use statements
    open my $fh, $filename or die "Cannot open file $filename.\n";
    ### $filename
    print "File: $filename\n" if ($params{debug});
    while (my $line = <$fh>) {
	chomp $line;
	my ($module) = ( $line =~ m{ \A use \s+ (\S+) .* ; }xms );
	if (defined $module) {
	    ### $module
	    print "  Module: $module\n" if ($params{debug});
	    push @modules, $module;
	}
    }
    close $fh;
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
    if ($params{dump}) {
	print $module . "\n";
    }
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
__END__

=head1 NAME

check_modules.pl [options]

 Options:
   --help                brief help message
   --man                 full documentation
   --dump                print required modules


=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.
