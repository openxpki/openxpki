#!/usr/bin/env perl

use strict;
use warnings;
use File::Find;

my $dir    = $ARGV[0];
my $prefix = 'I18N_OPENXPKI_';

my %tags = ();
find(\&extract_tags, $dir);

sub extract_tags {
    my $filename = $_;
    if ($File::Find::name !~ m{ \.svn }xms) {
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

foreach my $tag (keys %tags) {
    print qq{msgid "$tag"\n} . qq{msgstr ""\n};
}
