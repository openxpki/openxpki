use Test::More tests => 13;
use English;

use strict;
use warnings;
use English;

# use Smart::Comments;

our %config;
require 't/common.pl';

diag("CLI client - anonymous login");

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
$res = `$cli --session $session_id auth --stack Anonymous`;
ok($CHILD_ERROR == 0);
chomp $res;

ok($res =~ m{ OK }xms);
### $res

###########################################################################
$res = `$cli --session $session_id list workflow titles`;
ok($CHILD_ERROR == 0);
chomp $res;

ok($res =~ m{ dataonly_cert_request }xms);
### $res

###########################################################################
$res = `$cli --session $session_id list workflow titles`;
ok($CHILD_ERROR == 0);
chomp $res;

ok($res =~ m{ dataonly_cert_request }xms);
### $res

###########################################################################
$res = `$cli --session $session_id logout`;
ok($CHILD_ERROR == 0);


