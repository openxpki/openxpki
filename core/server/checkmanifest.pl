#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw( $Bin );
use File::Spec::Functions qw( abs2rel );
use Cwd 'abs_path';

my $show_all = ($ARGV[0] // "") eq "--all";

# Ignore list of dynamically generated files that are included in MANIFEST
my @dynamic = qw(
    OpenXPKI/VERSION.pm
    t/cfg.binary.openssl
);

my $basedir = abs_path($Bin);

my $exit_code = 0;

# fetch files tracked in Git
my @git_ls = `git ls-files $basedir`;
chomp @git_ls;
my $files_git = { map { (abs2rel($_, $basedir) => 1) } @git_ls };

# fetch files in MANIFEST
my $files_manifest = {};
open my $manifest, '<', "$basedir/MANIFEST"
    or die "Could not open manifest\n";
while (<$manifest>) {
    chomp;
    next unless /^\S+$/;
    next if /^\s*#/;
    $files_manifest->{$_} = 1;
}

# find non-existing files listed in MANIFEST
my $header_printed = 0;
my $dynamic_list = { map { ( $_ => 1) } @dynamic };
for (sort keys %$files_manifest) {
    next if $files_git->{$_};
    next if $dynamic_list->{$_};
    $exit_code = 1;
    print "\nSuperfluous in MANIFEST (not tracked in Git):\n=============================================\n" unless $header_printed++;
    print "$_\n";
}

$header_printed = 0;
for (sort keys %$files_git) {
    next if $files_manifest->{$_};
    my $hint = "";
    $hint = "(tests)     # " if $_ =~ /^t\//;
    $hint = "(private)   # " if $_ =~ /^(checkmanifest\.pl|t\/TODO|\.perltidyrc|README.testing)/;
    $hint = "(symlinks)  # " if $_ =~ /(00_cleanup|htdocs\/index\.html)/;
    $hint = "(legacy)    # " if $_ =~ /^OpenXPKI\/Server\/(ACL\.pm|Workflow\/Condition\/(ACL|ValidCSRSerialPresent)\.pm|Workflow\/Validator\/CertSubject\.pm)/;
    $hint = "(separate)  # " if $_ =~ /^CGI_Session_Driver\/Makefile/;
    next if ($hint and not $show_all);
    $exit_code = 1;
    print "\nMissing in MANIFEST but tracked in Git:\n=======================================\n" unless $header_printed++;
    print "$hint$_\n";
}

exit $exit_code;

__END__

## Old checkmanifest.sh (simpler but didn't cover whole source tree):
# #!/bin/bash
#
# OLD=`pwd`
# cd `dirname $0`;
#
# echo "Files missing in MANIFEST"
# for f in `git ls-files OpenXPKI bin cgi-bin htdocs`; do grep -q $f MANIFEST || echo $f; done;
#
# echo
# echo "Files in MANIFEST missing in git"
# for f in `grep -v "#" MANIFEST`; do (git ls-files $f --error-unmatch 2>/dev/null >/dev/null) || echo  $f; done;
#
# cd $OLD;
