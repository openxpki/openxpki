use strict;
use warnings;
use English;
use Test::More;
use DateTime;

use OpenXPKI::Server::Workflow::Condition::CorrectTiming;

print "Running tests for CorrectTiming...\n";

plan tests => 5;



# hash used as input parameter
my %hash = ();

# result variable
my $ct = undef;


#
# 1
#
$hash{difference} = "10";
$ct = OpenXPKI::Server::Workflow::Condition::CorrectTiming->new(\%hash);
is($ct->difference(), "+000000000010", "difference parsing: 10 seconds");

#    
# 2
#
$hash{difference} = "20m";
$ct = OpenXPKI::Server::Workflow::Condition::CorrectTiming->new(\%hash);
is($ct->difference(), "+0000000020", "difference parsing: 20 minutes");

#    
# 3
#
$hash{difference} = "3h";
$ct = OpenXPKI::Server::Workflow::Condition::CorrectTiming->new(\%hash);
is($ct->difference(), "+00000003", "difference parsing: 3 hours");

#    
# 4
#
$hash{difference} = "2d";
$ct = OpenXPKI::Server::Workflow::Condition::CorrectTiming->new(\%hash);
is($ct->difference(), "+000002", "difference parsing: 2 days");

#
# 5
#
$hash{difference} = "13w";
$ct = OpenXPKI::Server::Workflow::Condition::CorrectTiming->new(\%hash);
is($ct->difference(), "+000091", "difference parsing: 13 weeks");
