#!/usr/bin/perl -w


use Data::Dumper;
use OpenXPKI::Config::Test;
use OpenXPKI::Server::Notification::SMTP;
use OpenXPKI::Server::Context;
use OpenXPKI::Server::Log;

use Test::More;
plan tests => 2;

OpenXPKI::Server::Context::setcontext({ 'config' => OpenXPKI::Config::Test->new() });
OpenXPKI::Server::Context::setcontext({ 'log' => OpenXPKI::Server::Log->new( CONFIG => 't/28_log/log4perl.conf' ) });

my $backend = OpenXPKI::Server::Notification::SMTP->new({ config => 'notification.smtp' });

ok($backend);

my $ret = $backend->notify( {
	MESSAGE => 'test',
	VARS => { data => { sender => "root\@localhost", rcpt => "root\@localhost", requestor_name => 'Albert Einstein' } },         
  	TOKEN => {},    
});

my @failed = @{$backend->failed()};
ok( scalar(@failed) == 0 );
 