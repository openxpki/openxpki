use strict;
use warnings;

use Test::More;
plan tests => 3;

use OpenXPKI::Debug;
use XML::Simple;
use Data::Dumper;
use English;

if ($ENV{DEBUG}) {
    $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Init'} = 128;
}
require OpenXPKI::Server::Init;

diag "Testing conversion of our XML cache to Workflow XMLin datastructure";

my $our_xs = XML::Simple->new(
    ForceArray   => 1,
    ForceContent => 1,
    SuppressEmpty => undef,
    KeyAttr => [],
);

my $force_array = [ 'action', 'field', 'source_list', 'param', 'validator', 'arg' ];

my $our_xml = $our_xs->XMLin('t/60_workflow/test_action.xml');
$our_xml = OpenXPKI::Server::Init::__flatten_content($our_xml, $force_array);

my $workflow_xs = XML::Simple->new(
    ForceArray   => $force_array,
    KeyAttr      => [],
);

my $workflow_xml = $workflow_xs->XMLin('t/60_workflow/test_action.xml');

if ($ENV{DEBUG}) {
    print "our XML: " . Dumper $our_xml;
    print "workflow XML: " . Dumper $workflow_xml;
}
is_deeply($workflow_xml, $our_xml, 'Converted our XML to workflow structure');

eval {
    $our_xml = OpenXPKI::Server::Init::__flatten_content($our_xml, $force_array);
};
is($EVAL_ERROR, '', 'Calling __flatten_content twice creates no error');
is_deeply($workflow_xml, $our_xml, 'Calling __flatten_content twice does not change structure');

