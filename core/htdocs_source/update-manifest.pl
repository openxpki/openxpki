#!/usr/bin/env perl
use strict;
use warnings;

# Core modules
use Cwd qw( abs_path );
use List::Util qw( first );
use File::Find;
use File::Spec::Functions qw( abs2rel );
use File::Basename qw( dirname );
#
# Updates the MANIFEST file to include all generated web UI assets
# that are tracked in Git.
#

die "Usage: update-manifest.pl [DIRECTORY]" unless scalar @ARGV == 1;

my $server_path = $ARGV[0];
die "$server_path not found" unless -r $server_path;

my $htdocs_path = abs_path("$server_path/htdocs");
my $mf_path = abs_path("$server_path/MANIFEST");
my $mf_dir = dirname($mf_path);

# read MANIFEST contents (but filter out htdocs/*)
open my $mf, '<', $mf_path or die "Could not open manifest $mf_path: $!\n";
my @contents = ();
@contents = grep { $_ !~ /^htdocs\// } <$mf>;
chomp @contents;
close $mf;

# search for tag
my $index = first { $contents[$_] =~ m/UPDATE_MANIFEST_UI_LIST/ } 0..$#contents
 or die "Tag UPDATE_MANIFEST_UI_LIST not found in MANIFEST\n";

# list files on disk
my @files;
find({ no_chdir => 1, wanted => sub { push @files, abs2rel($_, $mf_dir) if -f } }, $htdocs_path);

# insert file list into MANIFEST contents
splice @contents, $index+1, 0, sort @files;

# write MANIFEST
open $mf, '>', $mf_path or die "Could not open manifest for writing\n";
print $mf join "\n", @contents;
close $mf;
