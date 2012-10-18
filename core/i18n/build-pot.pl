#!/usr/bin/env perl

use strict;
use warnings;
use File::Find;

my $prefix = 'I18N_OPENXPKI_';

my @MANIFEST;

my %tags = ();
my $basedir = '';

foreach my $dir (@ARGV) {
    $basedir = $dir;
    @MANIFEST = ();
    if (-e "$dir/MANIFEST") {
        open my $MAN, '<', "$dir/MANIFEST";
        @MANIFEST = <$MAN>;
        close $MAN;
        foreach my $man (@MANIFEST) {
            chomp $man;
        }
    }
    find(\&extract_tags, $dir);
}

sub extract_tags {
    my $filename = $_;
    my $rel_name = $File::Find::name;
    my $dir_name = $File::Find::topdir;
    $rel_name =~ s/$basedir\///;
    if ($File::Find::name !~ m{ \.svn }xms) {
        if (scalar @MANIFEST > 0 && ! grep {$_ eq $rel_name} @MANIFEST) {
            # if we have a MANIFEST file, the file needs to be in it
            # to be searched for tags
            return;
        }
        open my $FILE, '<', $filename;
        while (my $line = <$FILE>) {
            while ($line =~ s{ (I18N_OPENXPKI_[A-Z0-9\_]+) }{}xms) {
                $tags{$1} = 1;
            }
        }
        close $FILE;
    }
}

print <<'XEOF';

# SOME DESCRIPTIVE TITLE.
# Copyright (C) YEAR THE PACKAGE'S COPYRIGHT HOLDER
# This file is distributed under the same license as the PACKAGE package.
# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.
#

msgid ""
msgstr ""
"Project-Id-Version: PACKAGE VERSION\n"
"Report-Msgid-Bugs-To: \n"
"POT-Creation-Date: 2004-09-08 14:02+0200\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
"Language-Team: LANGUAGE <LL@li.org>\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"

XEOF

foreach my $tag (sort keys %tags) {
    print qq{msgid "$tag"\n} . qq{msgstr ""\n};
}
