#!/usr/bin/perl

use strict;
use warnings;
use English;

my @added_files   = `svn status|grep ^A|cut -c 8-500`;
my @deleted_files = `svn status|grep ^D|cut -c 8-500`;

open my $MANIFEST, '<', 'MANIFEST';
my $manifest = do {
    local $INPUT_RECORD_SEPARATOR;
    <$MANIFEST>;
};
close $MANIFEST;

my @manifest = split(/\n/, $manifest);
foreach my $added_file (@added_files) {
    push @manifest, $added_file;
}
foreach my $deleted_file (@deleted_files) {
    @manifest = grep { $_ . "\n" ne $deleted_file } @manifest;
}
open $MANIFEST, '>', 'MANIFEST';
print $MANIFEST join "\n", @manifest;
close $MANIFEST;
