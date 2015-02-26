#!/usr/bin/perl -w

use strict;
use warnings;
use English;

use Test::Harness qw( execute_tests );
use Benchmark;

$OUTPUT_AUTOFLUSH = 1;

$Test::Harness::Timer    = 1;
$Test::Harness::switches = '-MDevel::Cover=-silent,1';
$Test::Harness::Verbose  = 1;

$ENV{DEBUG} = 1;
$ENV{RUN_ALL_TESTS} = 1;

# delete the coverage database
`cover -delete`;

my @test_files =  glob("t/*/*.t");
push @test_files, glob("t/*.t");

my $revision  = $ARGV[0];
$revision     = sprintf("%04d", $revision);
my $path      = $ARGV[1];

# redirect test output to file
open STDOUT, '>', "$revision" . '_output.txt';
open STDERR, '>&STDOUT';

# execute tests and record the time it takes
my $t0 = Benchmark->new();
my ($total, $failed) = execute_tests(
    tests => \@test_files,
);
my $t1 = Benchmark->new();

open my $SUMMARY, '>', $revision . "_summary.html";

my $color = '#ff9999'; # default color is red
if ($total->{bad} == 0 && $total->{max} > 0) {
    # everything went well, change color to green
    $color = '#99ff99';
}

# calculate percentages
my $percentage_good_files = '0%';
my $percentage_bad_files  = '0%';

if ($total->{files} > 0) {
    $percentage_good_files = sprintf("%2.2f%%", 100 * ($total->{good} / $total->{files}));
    $percentage_bad_files = sprintf("%2.2f%%", 100 * ($total->{bad} / $total->{files}));
}
my $bad_tests = $total->{max} - $total->{ok};

my $percentage_good_tests = '0%';
my $percentage_bad_tests  = '0%';
if ($total->{max} > 0) {
    $percentage_good_tests = sprintf("%2.2f%%", 100 * ($total->{ok} / $total->{max}));
    $percentage_bad_tests = sprintf("%2.2f%%", 100 * ($bad_tests / $total->{max}));
}

my $cpu_time = timestr(timediff($t1, $t0));
$cpu_time =~ s{.*(\d+\.\d+)\ CPU.*}{$1}xms;

my $revision_coverage_link = "<a href=\"$path/$revision" . '_coverage/coverage.html' . "\">Coverage report</a>";

my $output_bad_link = "<a href=\"$path/$revision" . '_output.txt' . "\">$total->{bad} ($percentage_bad_files)</a>";
my $output_good_link = "<a href=\"$path/$revision" . '_output.txt' . "\">$total->{good} ($percentage_good_files)</a>";

print $SUMMARY "<tr bgcolor=\"$color\"><td>$revision_coverage_link</td><td>$output_good_link</td><td>$output_bad_link</td><td>$total->{files} / $total->{tests}</td><td>$total->{skipped}</td><td>$total->{ok} ($percentage_good_tests)</td><td>$bad_tests ($percentage_bad_tests)</td><td>$total->{max}</td><td>$total->{todo}</td><td>$total->{bonus}</td><td>$total->{sub_skipped}</td><td>$cpu_time</td></tr>\n";

close $SUMMARY;

# generate coverage report
my $cover_cmd = "cover -silent -output $revision" . '_coverage';
`$cover_cmd`;
