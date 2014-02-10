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

use Test::More tests => 5;

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
is(scalar (@{$result->{main}->[0]->{content}->{fields}->[0]->{options}}), 8);

$cgi->data({
    'action' => 'login!stack',
    'auth_stack' => "External Dynamic",
});
$result = $client->handle_request({ cgi => $cgi });   

$cgi->data({
    'action' => 'login!password',
    'username' => 'raop',
    'password' => 'RA Operator'
});
$result = $client->handle_request({ cgi => $cgi });    

$cgi->data({
    'page' => 'workflow!index!type!I18N_OPENXPKI_WF_TYPE_CHANGE_METADATA',    
});
$result = $client->handle_request({ cgi => $cgi });  

$cgi->data({
    action => 'workflow!index',
    wf_type => 'I18N_OPENXPKI_WF_TYPE_CHANGE_METADATA',
});
$result = $client->handle_request({ cgi => $cgi });

$cgi->data({
    action => 'workflow!index',
    wf_token => 'wfl_12345',
    cert_identifier => 'nVPEjsDbulDtq-hlA9LCHYYhWoI'    
});
$result = $client->handle_request({ cgi => $cgi });  
  
$cgi->data({
    action => 'workflow!index',
    wf_token => 'wfl_12345',
    'metadata_update{email}' => 'uli.update@mycompany.local',
    'metadata_update{requestor}' => 'Uli Update'     
});
#$result = $client->handle_request({ cgi => $cgi });  
  
print Dumper $result; 


