#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw( $Bin );

use PPI;
use PPI::Dumper;

my $makefile = $ARGV[0] // "$Bin/../../core/server/Makefile.PL";
my $doc = PPI::Document->new($makefile) or die "Makefile.PL not found";
$doc->prune("PPI::Token::Whitespace");
$doc->prune("PPI::Token::Comment");

my $sub = $doc->find_first(sub {                         # find
    $_[1]->parent == $_[0]                               # at root level
    and $_[1]->isa("PPI::Statement")                     # a statement
    and $_[1]->first_element->content eq "WriteMakefile" # called "WriteMakefile"
}) or die "Subroutine call WriteMakefile() not found\n";

my $key = $sub->find_first(sub {                            # below that find
    $_[1]->isa("PPI::Token::Quote")                      # a quoted string
    and $_[1]->content =~ /PREREQ_PM/                    # called "PREREQ_PM"
}) or die "Argument PREREQ_PM not found in WriteMakefile()\n";

my $list = $key->next_sibling->next_sibling; # skip "=>" and go to HashRef "{}"
$list->prune("PPI::Token::Operator");     # remove all "=>"
my %modmap = map { s/(\x27|\x22)//g; $_ }    # remove single or double quotes
    map { $_->content }
    @{$list->find("PPI::Token")};

my @modlist =
    map { sprintf("requires '%s' => '%s';", $_, $modmap{$_}) }
    sort keys %modmap;

print "$_\n" for (@modlist);

1;
