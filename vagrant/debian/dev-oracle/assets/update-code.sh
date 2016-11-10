#!/bin/bash

# Copy latest OpenXPKI code from host into Vagrant box

#
# Grab and install Perl module dependencies from Makefile.PL using PPI
#
cpanm --quiet --notest PPI

perl -e '
use PPI;
use PPI::Dumper;

$doc = PPI::Document->new("/code-repo/core/server/Makefile.PL");
$doc->prune("PPI::Token::Whitespace");
$doc->prune("PPI::Token::Comment");

my $sub = $doc->find_first(sub {                         # find
    $_[1]->parent == $_[0]                               # at root level
    and $_[1]->isa("PPI::Statement")                     # a statement
    and $_[1]->first_element->content eq "WriteMakefile" # called "WriteMakefile"
}) or die "Subroutine call WriteMakefile() not found\n";

$key = $sub->find_first(sub {                            # below that find
    $_[1]->isa("PPI::Token::Quote")                      # a quoted string
    and $_[1]->content =~ /PREREQ_PM/                    # called "PREREQ_PM"
}) or die "Argument PREREQ_PM not found in WriteMakefile()\n";

$list = $key->next_sibling->next_sibling; # skip "=>" and go to HashRef "{}"
$list->prune("PPI::Token::Operator");     # remove all "=>"
%modmap = map { s/(\x27|\x22)//g; $_ }    # remove single or double quotes
    map { $_->content }
    @{$list->find("PPI::Token")};

use version;
my @modlist =
    map { "$_~".$modmap{$_} }
    grep {
        ! (
            eval "require $_;" and
            eval "version->parse($_->VERSION) >= version->parse($modmap{$_})"
        )
    }
    keys %modmap;

if (@modlist) {
    print "cpanm: installing ".scalar(@modlist)." missing OpenXPKI dependencies\n";
    system("cpanm --quiet --notest ".join(" ", @modlist));
}
'

#
# Copy current code
#
echo "Copying current code and binaries from repo"
rsync -q -c -P -a  /code-repo/core/server/OpenXPKI/* /usr/lib/x86_64-linux-gnu/perl5/5.20/OpenXPKI/

if [ "$1" != "--no-restart" ]; then
    echo "Restarting OpenXPKI"
    openxpkictl restart >/dev/null

    if [[ $(openxpkictl status 2>&1) == *"not running"* ]]; then
        echo "Error starting OpenXPKI"
        exit 1
    fi
fi
