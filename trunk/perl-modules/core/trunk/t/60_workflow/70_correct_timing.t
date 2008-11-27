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
is($ct->difference(), "10", "difference parsing: 10 seconds");

#    
# 2
#
$hash{difference} = "20m";
$ct = OpenXPKI::Server::Workflow::Condition::CorrectTiming->new(\%hash);
is($ct->difference(), "1200", "difference parsing: 20 minutes (1200 seconds)");

#    
# 3 
#
$hash{difference} = "30h";
$ct = OpenXPKI::Server::Workflow::Condition::CorrectTiming->new(\%hash);
is($ct->difference(), "108000", "difference parsing: 30 hours (108000 seconds)");

#
# 4
#
$hash{difference} = "40d";
$ct = OpenXPKI::Server::Workflow::Condition::CorrectTiming->new(\%hash);
is($ct->difference(), "3456000", "difference parsing: 40 days (3456000 seconds)");

#
# 5
#
$hash{difference} = "50w";
$ct = OpenXPKI::Server::Workflow::Condition::CorrectTiming->new(\%hash);
is($ct->difference(), "30240000", "difference parsing: 50 weeks (30240000 seconds)");
