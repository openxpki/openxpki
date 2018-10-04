#!/usr/bin/perl

# Helper to migrate the old log statements to the new ones
# There is NO error checking! Validate the results by your own!

use English;
use strict;

while (my $file = shift) {

print "$file\n";

my $string;
{
  local $/ = undef;
  open FILE, "<", $file or die "Couldn't open file: $!";
  $string = <FILE>;
  close FILE;
}


$string =~ s{(([ \t]*?)CTX\('log'\)->log\(\s*MESSAGE\s*=>\s*(.*?),\s*PRIORITY\s*=>[\s\'\"]+(debug|info|warn|error|fatal)[^)]*FACILITY\s*=>[\s\'\"\[]+(system|audit|auth|workflow|application)[\s\'\"\]\,]+\);) }{$2CTX('log')->$5()->$4($3);\n }xmsg;

#$string =~ s{(([ \t]*?)CTX\('log'\)->log\(\s*MESSAGE\s*=>\s*([^,]*),\s*FACILITY\s*=>[\s\'\"\[]+(system|audit|auth|workflow|application)[\s\'\"\]\,]+,\s*PRIORITY\s*=>[\s\'\"]+(debug|info|warn|error|fatal)[^)]+\);) }{$2CTX('log')->$4()->$5($3);\n }xmsg;

open FILE, ">", $file or die "Couldn't open file for writing: $!";
print FILE $string;
close FILE;

}
