#!/usr/bin/env perl

use strict;
use warnings;

my $output_dir = $ARGV[0];
if (! defined $output_dir) {
    die "Usage: $0 <report_dir>";
}
if (! -e 'perl-modules/core/trunk/t') {
    # only run from the correct directory
    die "Please start from main OpenXPKI trunk directory\n";
}

open my $SVN, 'svn log -qr HEAD|';
<$SVN>;
my $svn_info = <$SVN>;
my ($newest_revision) = ($svn_info =~ m{ \A r(\d+) .* }xms);

my $local_revision = `vergen --format SVN_LAST_CHANGED_REVISION`;

for (my $rev = $local_revision + 1; $rev <= $newest_revision; $rev++) {
    print STDERR "Updating to revision $rev ...\n";
    `svn update -r $rev`;
    print STDERR "Running tests for revision $rev ...\n";
    `generate_report.pl $output_dir`;
}
