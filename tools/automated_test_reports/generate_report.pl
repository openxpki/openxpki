#!/usr/bin/env perl

use strict;
use warnings;
use English;

# define your path here if run_test.pl is not in path
# e.g.
# my $run_test = '/Users/klink/dev/openxpki/tools/automated_test_reports/run_test.pl';
my $run_test;

# define an installation prefix (passed to perl Makefile.PL) if necessary
# e.g.
# my $PREFIX = 'PREFIX=~/usr/local';
my $PREFIX = '';

# define a deployment prefix (passed to ./configure in trunk/deployment)
# if necessary
# e.g.
# my $DEPLOYMENT_PREFIX = '--prefix ~/usr/local';
my $DEPLOYMENT_PREFIX = '';

if (! defined $run_test) {
    $run_test = `which run_test.pl`;
    chomp($run_test);
    if ($CHILD_ERROR) {
        die "Could not find run_test.pl, configure it in generate_report.pl or put it in your PATH";
    }
}

if (! -e 'perl-modules/core/trunk/t') {
    # only run from the correct directory
    die "Please start from main OpenXPKI trunk directory\n";
}
my $basedir = `pwd`;
chomp $basedir;

my $output_dir = $ARGV[0];
if (! defined $output_dir) {
    die "Usage: $0 <output directory>";
}

my $tests = {
    'server'       => {
        DIRECTORY => $basedir . "/perl-modules/core/trunk",
        NAME      => 'Server',
    },
    'client'       => {
        DIRECTORY => $basedir . "/clients/perl/OpenXPKI-Client",
        NAME      => 'Client',
    },
    'client_cli'   => {
        DIRECTORY => $basedir . "/clients/perl/OpenXPKI-Client-CLI",
        NAME      => 'CLI client',
    },
    'client_mason' => {
        DIRECTORY => $basedir . "/clients/perl/OpenXPKI-Client-HTML-Mason",
        NAME      => 'Mason client',
    },
    'client_scep'  => {
        DIRECTORY => $basedir . "/clients/perl/OpenXPKI-Client-SCEP",
        NAME      => 'SCEP client',
    },
};

my $revision = sprintf("%04d", `vergen --format SVN_LAST_CHANGED_REVISION`);
if (! $revision) {
    die "Could not determine SVN revision";
}
if (! -x $run_test) {
    die "run_test.pl not found or not executable";
}

# install new deployment tools before testing
chdir $basedir . '/deployment';
if (system("./configure $DEPLOYMENT_PREFIX && make && make install") != 0) {
    die "Could not install new deployment tools";
}

INSTALL:
foreach my $test (sort keys %{ $tests }) {
    print STDERR "Compiling and installing for $test\n";
    chdir $tests->{$test}->{DIRECTORY};
    if (system("perl Makefile.PL $PREFIX && make && make install") != 0) {
        die "Could not compile for $test test";
    }
}

TEST:
foreach my $test (sort keys %{ $tests }) {
    print STDERR "Running test for $test (revision $revision)\n";

    # compile and run each test
    chdir $tests->{$test}->{DIRECTORY};
    my $output_filename = $revision . '_output.txt';
    if (-e $output_filename) {
        # test has already been run, skip
        next TEST;
    }
    system("$run_test $revision $test");
}

chdir $tests->{'server'}->{DIRECTORY};
my @tested_revisions = reverse glob('*_output.txt');
map { s/_output.txt// } @tested_revisions;

open INDEX, '>', $output_dir . '/index.html';
print INDEX << "XEOF";
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
  <head>
    <title>OpenXPKI automated test report</title>
  </head>
  <body>
    <table border=0 cellspacing=0 cellpadding=5>
      <tr>
          <th>Coverage report</th>
          <th>Good files</th>
          <th>Bad files</th>
          <th>Total files</th>
          <th>Skipped files</th>
          <th>Good tests</th>
          <th>Bad tests</th>
          <th>Total tests</th>
          <th>TODO tests</th>
          <th>passed TODO tests</th>
          <th>skipped tests</th>
          <th>CPU time used</th>
      </tr>
XEOF

chdir $basedir;
print STDERR "Generating report ... ";
foreach my $rev (@tested_revisions) {
    print STDERR "r$rev ";
    open my $SVN, "svn log -qr $rev|";
    my $line = <$SVN>;
    my $svn_info = <$SVN>;
    close $SVN;
    $svn_info =~ s{ (.*) \|\ \d+\ lines}{$1}xms;

    print INDEX "<tr><td colspan=12>Report for $svn_info</td></tr>";
    foreach my $test (sort keys %{ $tests }) {
        chdir $tests->{$test}->{DIRECTORY};
        my $files = $rev . '_coverage ' . $rev . '_output.txt ';
        system("mkdir $output_dir/$test");
        system("cp -r $files $output_dir/$test");

        my $summary_filename = $rev . '_summary.html';
        open my $SUMMARY, '<', $summary_filename;
        my $summary = <$SUMMARY>;
        $summary =~ s{Coverage\ report}{$tests->{$test}->{NAME} coverage report}xms;
        close $SUMMARY;
        print INDEX $summary;
    }
}
print STDERR "\n";
close INDEX;
