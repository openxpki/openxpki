use Test::More tests => 13;
use English;

use strict;
use warnings;
use English;

# use Smart::Comments;

our %config;
require 't/common.pl';

diag("CLI client - Operator login and workflow test");

my $cli = "./bin/openxpki --socketfile $config{socket_file}";

my $session_id = `$cli showsession`;
ok($CHILD_ERROR == 0);
chomp $session_id;

ok($session_id =~ m{ \A [ \d a-f ]+ \z }xms);
diag("Got session id $session_id");

###########################################################################
my $res;

$res = `$cli --session $session_id nop`;
ok($CHILD_ERROR == 0);
chomp $res;

ok($res =~ m{ I18N_OPENXPKI_CLIENT_CLI_INIT_GET_AUTH_STACK_MESSAGE }xms);
### $res

###########################################################################
$res = `$cli --session $session_id auth --stack foobar`;
ok($CHILD_ERROR == 0);
chomp $res;

ok($res =~ m{ I18N_OPENXPKI_CLIENT_CLI_INIT_GET_AUTH_STACK_MESSAGE }xms);
### $res

###########################################################################
$res = `$cli --session $session_id auth --stack Operator`;
ok($CHILD_ERROR == 0);
chomp $res;

ok($res =~ m{ Operator\ Password }xms);
### $res

###########################################################################
$res = `$cli --session $session_id login password --user root --pass root`;
ok($CHILD_ERROR == 0);
chomp $res;

ok($res =~ m{ \A \z }xms);
### $res

###########################################################################
$res = `$cli --session $session_id create workflow instance --workflow dataonly_cert_request`;
### $res

TODO: {
    local $TODO = "Does not work properly yet";

    ok($CHILD_ERROR == 0);
    chomp $res;
    
    ok($res =~ m{ 'ID' \s+ => \s+ '(\d+)'  }xms);
    ### $res
    
    my $workflow_id = $1;
    ok($workflow_id > 0);
}
