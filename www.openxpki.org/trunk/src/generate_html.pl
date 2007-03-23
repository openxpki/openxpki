#!/usr/bin/perl -w

use strict;

use Cwd;
use File::Basename;
use File::Find;
use File::Path;
use File::Spec;
use HTML::Mason;
use URI;

use Getopt::Long;
#use Smart::Comments;

my $force;
GetOptions('force' => \$force);

# These are directories.  The canonpath method removes any cruft
# like doubled slashes.
my ($source, $target) = map { File::Spec->canonpath($_) } @ARGV;

die "Need a source and target\n"
    unless defined $source && defined $target;

my $usr_file;
my $usr_file_name = '.svn_user_name';
my $usr_name = '';
my %possible_names = map { $_ => 1 } qw( 
   alech
   bellmich
   djulia
   mbartosch
   oliwel
   svysh
   pgrig
);

if (-e($usr_file_name) && -s _) {                                                                                                                          
    open($usr_file,$usr_file_name);
    $usr_name = <$usr_file>;
    close($usr_file);
    chomp($usr_name);
    $usr_name = '' if (!exists($possible_names{$usr_name}));
}

if ($usr_name eq '') {
    do { 
        print "Enter your username for SourceForge (to be used in footers of html docs): ";
        $usr_name = <STDIN>;
        chomp($usr_name);
    } until ($usr_name =~ m{ \A [a-zA-Z0-9]+ [-\w]* \Z }xms);

    if (exists($possible_names{$usr_name})) {
        open($usr_file,">",$usr_file_name);
        print $usr_file "$usr_name";
        close($usr_file);
        print "Your username for SourceForge is kept in file src/.svn_user_name as $usr_name\n";
    }
    else {
        print "Supplied username for SourceForge does not match a list of OpenXPKI developers. \n";
        print "     If you are a new developer then: \n";
        print "          edit src/generate_html.pl, \n";
        print "          rerun gmake from src directory, \n";
        print "          commit src/generate_html.pl. \n";
        exit 0;
    }
}

$ENV{'SVN_USER_NAME'} = $usr_name;

my %files_status;
my @svn_output = `svn status`;
my $mason_files_changed = 0;
foreach my $line (@svn_output) {
    chomp($line);
    $line =~ m/ \A \s* ([ACDIMRX?!~]) \s* ([^\s]+?) \s* \Z /xms;
    $files_status{$2} = $1;
    $mason_files_changed = 1 if ($2 =~ m/ \A lib\/.*\.mas \Z /xms);
}

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
    my $name_with_source = $name;
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
        if ((exists($files_status{$name_with_source}) || $force || $mason_files_changed )) {
            if ((exists($files_status{$name_with_source})) && ($files_status{$name_with_source} =~ m/ \A \? \Z /xms)) { 
                # file is not under version control 
	        print STDERR "WARNING: $name_with_source ignored (not under version control)\n";
                return;
            }
            else {
	        $interp->out_method(\$buffer);
	        $interp->exec("/$comp_path");
            }
        }
        else { # file was not changed
            return;
        }

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

    ### $out_file
    open my $RESULT, "> $out_file" or die "Cannot write to $out_file: $!";
    print $RESULT $buffer or die "Cannot write to $out_file: $!";
    close $RESULT or die "Cannot close $out_file: $!";
}
