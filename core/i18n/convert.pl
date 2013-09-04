#!/usr/bin/perl -w

# Copyright (C) 2004 Michael Bell.
# License: GPL version 2

our $iconv     = "iconv";
our $QUIET_ARG = 0;

my $po_file  = $ARGV[0];
print STDERR "Translation file: $po_file\n";
my $encoding = get_po_encoding ($po_file);

my $command = "$iconv -f $encoding -t UTF-8 $po_file";
print STDERR "Final command: $command\n";
my $ret = `$command`;
print $ret;

# Original code taken from:
#
#  The Intltool Message Merger
#
#  Copyright (C) 2000, 2003 Free Software Foundation.
#  Copyright (C) 2000, 2001 Eazel, Inc
#
#  Authors:  Maciej Stachowiak <mjs@noisehavoc.org>
#            Kenneth Christiansen <kenneth@gnu.org>
#            Darin Adler <darin@bentspoon.com>

sub get_po_encoding
{
    my ($in_po_file) = @_;
    my $encoding = "";

    open IN_PO_FILE, $in_po_file or die;
    while (<IN_PO_FILE>)
    {
        ## example: "Content-Type: text/plain; charset=ISO-8859-1\n"
        if (/Content-Type\:.*charset=([-a-zA-Z0-9]+)\\n/)
        {
            $encoding = $1;
            last;
        }
    }
    close IN_PO_FILE;

    if (!$encoding)
    {
        print STDERR "Warning: no encoding found in $in_po_file. Assuming ISO-8859-1\n" unless $QUIET_ARG;
        $encoding = "ISO-8859-1";
    }

    system ("$iconv -f $encoding -t UTF-8 </dev/null 2>/dev/null");
    if ($?) {
        $encoding = get_local_charset($encoding);
    }

    return $encoding
}
