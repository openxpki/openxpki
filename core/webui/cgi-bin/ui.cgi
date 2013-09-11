#!/usr/bin/perl

use CGI;
use JSON;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Exception;
use Log::Log4perl qw(:easy);
use OpenXPKI::Serialization::Simple;

Log::Log4perl->easy_init($DEBUG);

sub handle {

my $q = CGI->new;
my $socketfile = '/var/openxpki/openxpki.socket';
my $timeout    = 120;
my $auth_stack = '_System';

my $json = new JSON();


my $log = Log::Log4perl->get_logger();


print $q->header('text/json');

my $client;
eval {
    $client = OpenXPKI::Client->new(
        {
            SOCKETFILE => $socketfile,
            TIMEOUT    => $timeout,
        }
    );
};

if ( my $exc = OpenXPKI::Exception->caught() ) {
    $log->error(
        "Could not establish OpenXPKI connection via socket file $socketfile: "
          . $exc->message );
          
    print $json->encode({'error' => 'no socket'});
    return 1;                    
}

if ( !$client ) {
    $log->error("Could instantiate client object");
    print $json->encode({'error' => 'no client'});
    return 1;
}

if ( !$client->is_connected() ) {
    $log->error("Could not connect to server");
    print $json->encode({'error' => 'no server'});
    return 1;
}

if ( !$client->init_session() ) {
    $log->error("Could not initialize session");
    print $json->encode({'error' => 'no session'});
    return 1;
}

my $session_id = $client->get_session_id();

$log->debug("Session id: $session_id");

my $reply = $client->send_receive_service_msg('PING');

SERVICE_MESSAGE:
while (1) {
    my $status = $reply->{SERVICE_MSG};
    $log->debug("Status: $status");

    if ( $status eq 'GET_PKI_REALM' ) {
        $log->debug("PKI Realm: $pki_realm");
        $reply =
          $client->send_receive_service_msg( 'GET_PKI_REALM',
            { PKI_REALM => $pki_realm, } );
        next SERVICE_MESSAGE;
    }

    if ( $reply->{SERVICE_MSG} eq 'GET_AUTHENTICATION_STACK' ) {
        if ( defined $auth_stack ) {
            $log->debug("Authentication stack: $auth_stack");
            $reply =
              $client->send_receive_service_msg( 'GET_AUTHENTICATION_STACK',
                { AUTHENTICATION_STACK => $auth_stack, } );
            next SERVICE_MESSAGE;
        }
        else {
            $log->error("Authentication stack requested but not configured");
            print $json->encode({'error' => 'no auth'});
            return 1;
        }
    }

    if ( $reply->{SERVICE_MSG} eq 'GET_PASSWD_LOGIN' ) {
        $log->error(
            "Username/password login requested (only anonymous login supported)"
        );
        print $json->encode({'error' => 'no credentials'});
        return 1;

        #       $reply = $client->send_receive_service_msg('GET_PASSWD_LOGIN',
        #                              {
        #                              LOGIN => $params{authuser},
        #                              PASSWD => $params{authpass},
        #                              });
        #       next SERVICE_MESSAGE;
    }

    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' ) {
        last SERVICE_MESSAGE;
    }

    $log->error("Unhandled service message: '$status'");
    print $json->encode({'error' => 'Unhandled message'});

    return 1;
}

# logged in, now run required commands

my $serializer = OpenXPKI::Serialization::Simple->new();
    
my $query = $q->param('record[subject]');
$query =~s /[^a-z0-9%=,\.\-]//ig;

$log->debug( "search query: " . $query );

$reply = $client->send_receive_service_msg(
    'COMMAND',
    {
        COMMAND => 'search_cert',
        PARAMS  => {
            LIMIT => 10,
            SUBJECT => $query             
        }
    }
);

$log->debug( "search result: " . Dumper $reply);

if ( exists $reply->{SERVICE_MSG} ) {
    if ( $reply->{SERVICE_MSG} eq 'ERROR' ) {
        $log->error("Could not create workflow instance");

        print $json->encode({'error' => 'com error'});
        return 1;
    }

    if ( $reply->{SERVICE_MSG} eq 'COMMAND' ) {
        my $i = 1;
        my @result;
        foreach my $item (@{$reply->{PARAMS}}) {
            push @result, {
                'recid' =>  $i++,
                'serial' => $item->{CERTIFICATE_SERIAL},
                'subject' => $item->{SUBJECT},
                'email' => $item->{EMAIL} || '',
                'notbefore' => $item->{NOTBEFORE},
                'notafter' => $item->{NOTAFTER},
                'issuer' => $item->{ISSUER_DN},
                'identifier' => $item->{IDENTIFIER},                
            }
        }        
        
        
        $log->debug( "dumper result: " . Dumper @result);
        
        print $json->encode ( {
            'total' => scalar @result,
            'page' => 1,
            'records' => \@result
        } );

        return 0;
    }
}

}

handle();