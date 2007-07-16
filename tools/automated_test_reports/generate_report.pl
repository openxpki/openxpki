#!/usr/bin/env perl

use strict;
use warnings;
use English;
use XML::Feed;
use XML::Simple;
use Config;

# Define your gmake. Needed for Unixes which have both gmake and make installed.
# On Linux it could be named just 'make'.
my $MAKE = 'make';

# define your path here if run_test.pl is not in path
# e.g.
# my $run_test = '/Users/klink/dev/openxpki/tools/automated_test_reports/run_test.pl';
my $run_test;

# define an installation prefix (passed to perl Makefile.PL) if necessary
# e.g.
# my $PREFIX = 'PREFIX=~/usr/local';
my $PREFIX = '';

# add installation prefix to PERL5LIB
my $PREFIX_DIR = $PREFIX;
$PREFIX_DIR =~ s{ \A \s* PREFIX=}{}xms if ($PREFIX ne '');

if ($PREFIX_DIR ne '') {
    my $installstyle = $Config{installstyle};
    my $perlversion = $Config{version};
    my $archname = $Config{archname};
    $ENV{"PERL5LIB"} = $PREFIX_DIR . "/$installstyle/site_perl/$perlversion/:" .
                       $PREFIX_DIR . "/$installstyle/site_perl/$perlversion/$archname/:" .
                       $PREFIX_DIR . "/$installstyle/site_perl/$perlversion/mach/";
    print STDERR "PERL5LIB contains the following dirs: ".$ENV{"PERL5LIB"}."\n";
}

# define a deployment prefix (passed to ./configure in trunk/deployment)
# if necessary
# e.g.
# my $DEPLOYMENT_PREFIX = '--prefix ~/usr/local';
my $DEPLOYMENT_PREFIX = '';

# add deployment prefix to PATH
# define DEPLOYMENT_PREFIX variable (to be used in OpenXPKI/Tests.pm)
my $DEPLOYMENT_DIR = $DEPLOYMENT_PREFIX;
$DEPLOYMENT_DIR =~ s{ \A \s* --prefix \s* (\S+)}{$1}xms if ($DEPLOYMENT_PREFIX ne '');

if ($DEPLOYMENT_DIR ne '') {
    $ENV{"PATH"} = $DEPLOYMENT_DIR."/bin:" . $ENV{"PATH"};
    $ENV{"DEPLOYMENT_PREFIX"} = $DEPLOYMENT_DIR."/bin";
}

# define the format of the feed (see XML::Feed)
my $FEED_FORMAT = 'Atom';

# define the title and location of the feed
my $FEED_TITLE = "OpenXPKI tests at " . `hostname`;
my $FEED_LINK  = "http://build0.cynops.de/openxpki_tests/";

# define how many revisions you want to show at the HTML page and how
# many you want in the Atom feed
my $MAX_HTML_REVISIONS = 20;
my $MAX_ATOM_REVISIONS = 20;

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

# Numbers added to the test names to provide correct sequence of installation:
# server, client, other clients. Needed for testing on machines with no 
# pre-installed OpenXPKI.

my $tests = {
    '0_server'       => {
        DIRECTORY => $basedir . "/perl-modules/core/trunk",
        NAME      => 'Server',
    },
    '1_client'       => {
        DIRECTORY => $basedir . "/clients/perl/OpenXPKI-Client",
        NAME      => 'Client',
    },
    '2_client_mason' => {
        DIRECTORY => $basedir . "/clients/perl/OpenXPKI-Client-HTML-Mason",
        NAME      => 'Mason client',
    },
    '3_client_scep'  => {
        DIRECTORY => $basedir . "/clients/perl/OpenXPKI-Client-SCEP",
        NAME      => 'SCEP client',
    },
};

my $revision = sprintf("%04d", `vergen --format SVN_REVISION`);
if (! $revision) {
    die "Could not determine SVN revision";
}
if (! -x $run_test) {
    die "run_test.pl not found or not executable";
}

# will contain test name without a number
my $test;

INSTALL:
foreach my $testname (sort keys %{ $tests }) {
    $test = $testname;
    $test =~ s{\d_}{}xms;

    print STDERR "Compiling and installing for $test\n";
    chdir $tests->{$testname}->{DIRECTORY};
    if (system("perl Makefile.PL $PREFIX && $MAKE && $MAKE install") != 0) {
        die "Could not compile for $test test";
    }
}

# install new deployment tools before testing
chdir $basedir . '/deployment';
if (system("./configure $DEPLOYMENT_PREFIX && $MAKE && $MAKE install") != 0) {
    die "Could not install new deployment tools";
}

TEST:
foreach my $testname (sort keys %{ $tests }) {
    $test = $testname;
    $test =~ s{\d_}{}xms;

    print STDERR "Running test for $test (revision $revision)\n";
    chdir $tests->{$testname}->{DIRECTORY};

    # compile and run each test
    my $output_filename = $revision . '_output.txt';
    if (-e $output_filename) {
        # test has already been run, skip
        next TEST;
    }
    my $ENV = '';
    if ($test eq 'client_mason') {
        # we need to set this here, because any attempt to set it within
        # the test file itself fails for some reason ...
        $ENV = 'OPENXPKI_SOCKET_FILE=t/20_webserver/test_instance/var/openxpki/openxpki.socket';
    }
    system("$ENV $run_test $revision $test");
}

chdir $tests->{'0_server'}->{DIRECTORY};
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

print STDERR "Generating report ... ";
REV_REPORT:
foreach my $rev (@tested_revisions[0..$MAX_HTML_REVISIONS-1]) {
    next REV_REPORT if (!$rev);
    print STDERR "r$rev ";
    chdir $basedir;
    open my $SVN, "svn log -qr $rev ..|";
    
    # my $line = <$SVN>;
    # my $svn_info = <$SVN>;
    ## execution of the two previous lines fails on FreeBSD 
    ## with 'Broken pipe' error message 

    my $svn_info;
    my $i = 0;
    while (my $line = <$SVN>) {
        chomp $line;
        $svn_info = $line if ($i == 1);
        $i++;
    }
    close $SVN;
    $svn_info =~ s{ (.*) \|\ \d+\ lines}{$1}xms;

    print INDEX "<tr><td colspan=12>Report for $svn_info</td></tr>";
    foreach my $testname (sort keys %{ $tests }) {
        $test = $testname;
        $test =~ s{\d_}{}xms;

        chdir $tests->{$testname}->{DIRECTORY};
        my $files = $rev . '_coverage ' . $rev . '_output.txt ';
        system("mkdir $output_dir/$test 2>/dev/null");

        ## 'cp -r' does not work on FreeBSD
        system("cp -R $files $output_dir/$test");

        my $summary_filename = $rev . '_summary.html';
        my $opened = open my $SUMMARY, '<', $summary_filename;
        my $summary;
        if (! $opened) {
            $summary = '<tr color="303030"><td colspan=12>' . $tests->{$testname}->{NAME} . ' summary unavailable</td></tr>' . "\n";
        }
        else {
            $summary = <$SUMMARY>;
            $summary =~ s{Coverage\ report}{$tests->{$testname}->{NAME} coverage report}xms;
            close $SUMMARY;
        }
        print INDEX $summary;
    }
}
print STDERR "\n";
close INDEX;

print STDERR "Generating feed ... ";
my $feed = XML::Feed->new($FEED_FORMAT);
$feed->title($FEED_TITLE);
$feed->link($FEED_LINK);

REV_FEED:
foreach my $rev (@tested_revisions[0..$MAX_ATOM_REVISIONS-1]) {
    next REV_FEED if (!$rev);
    my $entry = XML::Feed::Entry->new($FEED_FORMAT);

    print STDERR "r$rev ";
    chdir $basedir;
    open my $SVN, "svn log -qr $rev ..|";

    # my $line = <$SVN>;
    # my $svn_info = <$SVN>;
    ## execution of the two previous lines fails on FreeBSD
    ## with 'Broken pipe' error message

    my $svn_info;
    my $i = 0;
    while (my $line = <$SVN>) {
        chomp $line;
        $svn_info = $line if ($i == 1);
        $i++;
    }
    close $SVN;

    my @svn_info = split(/ \| /, $svn_info);
    my $author = $svn_info[1];
    my $date   = $svn_info[2];
    my ($year, $month, $day, $hour, $minute, $second, $tz) = 
        ($date =~ m{\A (\d{4}) \- (\d{2}) \- (\d{2}) [ ]
                       (\d{2}) : (\d{2}) : (\d{2}) [ ] ([\+\-]\d{4})}xms);
    my $dt = DateTime->new(
        year   => $year,
        month  => $month,
        day    => $day,
        hour   => $hour,
        minute => $minute,
        second => $second,
        time_zone => $tz,
    );
    
    my $svn_changes = do {
        local $INPUT_RECORD_SEPARATOR;
        open my $SVN, "svn log -vr $rev ..|";
        <$SVN>;
    };

    my $all_green = 1;
    my $all_summaries = '<table border=0 cellspacing=0 cellpadding=5>';
    my @failed;
    foreach my $testname (sort keys %{ $tests }) {
        $test = $testname;
        $test =~ s{\d_}{}xms;

        chdir $tests->{$testname}->{DIRECTORY};
        my $summary_filename = $rev . '_summary.html';
        my $opened = open my $SUMMARY, '<', $summary_filename;
        if (! $opened) {
            $all_green = 0;
            push @failed, "$test n/a";
        }
        else {
            my $summary = <$SUMMARY>;
            $summary =~ s{Coverage\ report}{$tests->{$testname}->{NAME} coverage report}xms;
            my $xs = XML::Simple->new();
            my $summary_ref = $xs->XMLin($summary);
            if ($summary_ref->{'td'}->[6] ne '0 (0.00%)') {
                $all_green = 0;
                # push failed total tests
                push @failed, "$test: " . $summary_ref->{'td'}->[6];
            }
            $all_summaries .= $summary;
            close $SUMMARY;
        }
    }
    $all_summaries .= '</table>';
    if ($all_green) {
        $entry->title("$rev: All green");
    }
    else {
        $entry->title("$rev: Failed: " . join q{, }, @failed);
    }
    $entry->author($author);
    my $body = "<H1>Report for $rev</H1>" . $all_summaries;
    $body   .= "<H1>Changes</H1><pre>" . $svn_changes . "</pre>";
    $entry->content(XML::Feed::Content->new({body => $body }));
    $entry->modified($dt);
    $entry->link($FEED_LINK);

    $feed->add_entry($entry);
}
$feed->modified(DateTime->now);
open FEED, '>', "$output_dir/" . lc($FEED_FORMAT);
print FEED $feed->as_xml();
close(FEED);
print STDERR "\n";
