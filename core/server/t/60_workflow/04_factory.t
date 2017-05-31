use strict;
use warnings;

use Test::More;
use Scalar::Util qw( refaddr );

plan tests => 2;

use_ok('OpenXPKI::Workflow::Factory', 'class loading');

note "OpenXPKI specific workflow factory";

my $instance1 = OpenXPKI::Workflow::Factory->new();
my $instance2 = OpenXPKI::Workflow::Factory->new();

isnt(refaddr $instance1, refaddr $instance2, 'two calls to instance produce different instances');

