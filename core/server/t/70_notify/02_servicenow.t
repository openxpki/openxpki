#!/usr/bin/perl -w


use Data::Dumper;
use OpenXPKI::Config::Test;
use OpenXPKI::Server::Notification::ServiceNow;
use OpenXPKI::Server::Context;
use OpenXPKI::Server::Log;

use Test::More;
plan tests => 7;

OpenXPKI::Server::Context::setcontext({ 'config' => OpenXPKI::Config::Test->new() });
OpenXPKI::Server::Context::setcontext({ 'log' => OpenXPKI::Server::Log->new( CONFIG => 't/28_log/log4perl.conf' ) });

my $backend = OpenXPKI::Server::Notification::ServiceNow->new({ config => 'notification.servicenow' });

ok($backend);

my $ret = $backend->notify( {
	MESSAGE => 'test',
	VARS => { data => { requestor_name => 'Albert Einstein' } },         
  	TOKEN => {},    
});

my $sys_id = $ret->{default}->{sys_id};

diag('SysId: '.$sys_id.' - TicketNo: ' . $ret->{default}->{ticket});

ok(  scalar( @{$backend->failed()} ) == 0 );

sleep 2;

$ret = $backend->notify( {
    MESSAGE => 'update',
    VARS => { data => { requestor_name => 'Albert Einstein' } },         
    TOKEN => $ret,    
});

ok(  scalar( @{$backend->failed()} ) == 0 );

sleep 2;

$ret = $backend->notify( {
    MESSAGE => 'close',
    VARS => { data => { requestor_name => 'Albert Einstein' } },         
    TOKEN => $ret,    
});

ok(  scalar( @{$backend->failed()} ) == 0 );

my $resp =  $backend->read( $sys_id  );

ok( $resp->{'short_description'} eq 'ServiceNow Notification Test');
ok( $resp->{state} == 7);
ok( $resp->{closed_at} ne '');

 