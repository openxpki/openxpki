#!/usr/bin/env perl
use strict;
use warnings;

# DESCRIPTION
#     Inserts more files into the EXE_FILES section of Makefile.PL.
#
# SYNOPSIS
#     echo "mytool.pl somejob.pl" | add-exe-to-makefile.pl ./Makefile.PL

use PPI;
use PPI::Dumper;

my $makefile = shift // die "Please specify path to Makefile.PL as first parameter\n";
my $doc = PPI::Document->new($makefile) or die "Makefile.PL not found";

my $sub = $doc->find_first(sub {                         # find
    $_[1]->parent == $_[0]                               # at root level
    and $_[1]->isa("PPI::Statement")                     # a statement
    and $_[1]->first_element->content eq "WriteMakefile" # called "WriteMakefile"
}) or die "Subroutine call WriteMakefile() not found\n";

my $key = $sub->find_first(sub {                            # below that find
    $_[1]->isa("PPI::Token::Quote")                      # a quoted string
    and $_[1]->content =~ /EXE_FILES/                    # called "PREREQ_PM"
}) or die "Argument PREREQ_PM not found in WriteMakefile()\n";

# skip "=>" and go to ArrayRef "[]"
my $list = $key;
do {
    $list = $list->next_sibling;
} while ($list and $list->class ne 'PPI::Structure::Constructor');

$list->add_element(PPI::Token->new(",")) unless $list->find("PPI::Token")->[-1]->content eq ',';

while (<>) {
    $list->add_element(PPI::Token->new("'$_',")) for split /\s+/, $_;
}

print $doc;

1;
