#!/usr/bin/perl

use strict;
use warnings;
use CGI::Session;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use OpenXPKI::Client::UI;

Log::Log4perl->easy_init($DEBUG);
#Log::Log4perl->easy_init($ERROR);

use Test::More tests => 7;

package CGIMock;

use Moose;

has data => (
    is => 'rw',
    isa => 'HashRef',
    default => sub{ return {} }
);

sub param {

    my $self = shift;
    my $name = shift;
    
    if ($name) {
        return $self->data()->{$name} || undef;
    }
    return $self->data();
        
}
 
1;

package main;

BEGIN {
    use_ok( 'OpenXPKI::Client::UI' ); 
}

require_ok( 'OpenXPKI::Client::UI' );

my $log = Log::Log4perl->get_logger();

my $session = new CGI::Session(undef, undef, {Directory=>'/tmp'});
my $session_id = $session->id;
ok ($session->id, 'Session id ok');


my $result;
my $client = OpenXPKI::Client::UI->new({
    session => $session,
    logger => $log,
    config => { socket => '/var/openxpki/openxpki.socket' } 
});

my $cgi = CGIMock->new({ data => {  }});

$result = $client->handle_request({ cgi => $cgi });    

is($result->{page}->{label}, 'Please log in');
is(scalar (@{$result->{main}->[0]->{fields}->[0]->{options}}), 8);

$session->close();

$session = new CGI::Session(undef, $session_id, {Directory=>'/tmp'});
is ($session->id, $session_id, 'Session resumed');

$cgi->data({
    'action' => 'login.stack',
    'auth_stack' => "External Dynamic",
});
$result = $client->handle_request({ cgi => $cgi });    

$session->close();

$session = new CGI::Session(undef, $session_id, {Directory=>'/tmp'});
is ($session->id, $session_id, 'Session resumed');

$cgi->data({
    'action' => 'login.password',
    'username' => 'ui user',
    'password' => 'User'
});
$result = $client->handle_request({ cgi => $cgi });    


$log->debug( Dumper $result );

$session->delete();



