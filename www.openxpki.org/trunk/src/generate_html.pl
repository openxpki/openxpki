#!/usr/bin/perl -w

use strict;

use Cwd;
use Data::Dumper;
use File::Basename;
use File::Find;
use File::Path;
use File::Spec;
use HTML::Mason;
use URI;

# These are directories.  The canonpath method removes any cruft
# like doubled slashes.
my ($source, $target) = map { File::Spec->canonpath($_) } @ARGV;

die "Need a source and target\n"
    unless defined $source && defined $target;

# Make target absolute because File::Find changes the current working
# directory as it runs.
$target = File::Spec->rel2abs($target);

my $interp =
    HTML::Mason::Interp->new( comp_root => File::Spec->rel2abs(cwd) );

find( \&convert, $source );

sub convert {
    # We want to split the path to the file into its components and
    # join them back together with a forward slash in order to make
    # a component path for Mason
    #
    # $File::Find::name has the path to the file we are looking at,
    # relative to the starting directory
    my $comp_path = join '/', File::Spec->splitdir($File::Find::name);

    # Strip off leading part of path that matches source directory
    my $name = $File::Find::name;
    $name =~ s/^$source//;

    # We dont want to copy subversion dirs
    if ($name =~ /\.svn/) {
      return;
    }

    # Generate absolute path to output file
    my $out_file = File::Spec->catfile( $target, $name );

    my $buffer;
    # We don't want to try to convert our autohandler or .mas
    # components.  $_ contains the filename
    # old: if (/(\.html|\.css)$/) {
    if (/(\.html)$/) {

	# This will save the component's output in $buffer
	$interp->out_method(\$buffer);
	$interp->exec("/$comp_path");

    # old: } elsif (/(\.png|\.txt)$/) {
    } elsif (/(\.png|\.txt|\.css)$/) {
	# don't process, just copy
	$buffer = do { local $/; 
		       open my $FH, "<$_" or die "Could not open $_. Stopped";
		       <$FH>;
	}
    } else {
	# ignore mason components et al.
	return;
    }
    
    # In case the directory doesn't exist, we make it
    mkpath(dirname($out_file));
    
    open my $RESULT, "> $out_file" or die "Cannot write to $out_file: $!";
    print $RESULT $buffer or die "Cannot write to $out_file: $!";
    close $RESULT or die "Cannot close $out_file: $!";
}
