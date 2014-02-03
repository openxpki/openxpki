# OpenXPKI::Client::Simple
# An easy to use class to connect to the openxpki daemon and run commands
# Designed as a kind of CLI interface for inline use within scripts
# Will NOT handle sessions and create a new session using the given auth info
# on each new instance (subsequent commands within one call are run on the same
# session)   
# 
# Written by Oliver Welter for the OpenXPKI project 2014
# Copyright (c) 2014 by The OpenXPKI Project

package OpenXPKI::Client::Simple;

use strict;
use warnings;
use English;
use POSIX qw( strftime );
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use OpenXPKI::Client;
use OpenXPKI::Serialization::Simple;
use Log::Log4perl qw(:easy);


use Moose;
use Data::Dumper;

has auth => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default  => sub { return { stack => 'Anonymous', user => undef, pass => undef } }        
);

has realm => (
    is => 'rw',
    isa => 'Str',    
    default => '',
    lazy => 1,        
);

has socketfile => (
    is => 'rw',
    isa => 'Str',    
    default => '/var/openxpki/openxpki.socket',
    lazy => 1,        
);

has client => (
    is => 'ro',
    isa => 'Object',
    builder  => '_build_client',
    lazy => 1,        
);

has log => (
    is => 'rw',
    isa => 'Object',
    builder  => '_build_logger',
    init_arg => 'logger',
    lazy => 1,
); 

has last_reply => (
    is => 'rw',
    isa => 'HashRef|Undef',
    default => undef,           
);

sub _build_logger { 
    Log::Log4perl->easy_init();
    return Log::Log4perl->get_logger();
};

sub _build_client {

    my $self = shift;
    
    my $client = OpenXPKI::Client->new({
        SOCKETFILE => $self->socketfile(),
    });
 
    if (! defined $client) {
        die "Could not instantiate OpenXPKI client. Stopped";
    }
    
    if (! $client->init_session()) {
        die "Could not initiate OpenXPKI server session. Stopped";
    }
       
    # run login
           
    my $session_id = $client->get_session_id();
    my $log = $self->log();
    $log->debug("Session id: $session_id");
    
    my $reply = $client->send_receive_service_msg('PING');
    
    my $status = $reply->{SERVICE_MSG};  
    if ($status eq 'GET_PKI_REALM') {
        my $realm = $self->realm();
        if (! $realm ) {
            $log->fatal("Found more than one realm but no realm is specified");
            $log->debug("Realms found:" . Dumper (keys %{$reply->{PARAMS}->{PKI_REALMS}}));
            die "No realm specified";
        }
        $log->debug("Selecting realm $realm");
        $reply = $client->send_receive_service_msg('GET_PKI_REALM',
            { PKI_REALM => $realm });
    }
        
    if ($reply->{SERVICE_MSG} eq 'GET_AUTHENTICATION_STACK') {
        my $auth = $self->auth();
        if (! $auth || !$auth->{stack}) {
            $log->fatal("Found more than one auth stack but no stack is specified");
            $log->debug("Stacks found:" . Dumper (keys %{$reply->{PARAMS}->{AUTHENTICATION_STACKS}}));
            die "No auth stack specified";
        }
        $log->debug("Selecting auth stack ". $auth->{stack});
        $reply = $client->send_receive_service_msg('GET_AUTHENTICATION_STACK',
            { AUTHENTICATION_STACK => $auth->{stack} });
        
    }
    
    if ($reply->{SERVICE_MSG} eq 'GET_PASSWD_LOGIN') {
        my $auth = $self->auth();
        if (! $auth || !$auth->{stack}) {
            $log->fatal("Login/Password required but not configured");            
            die "No login/password specified";
        }
        $log->debug("Do login with user ". $auth->{user});
        $reply = $client->send_receive_service_msg('GET_PASSWD_LOGIN',{
            LOGIN => $auth->{user}, PASSWD => $auth->{pass},
        });
    }
    
    if ($reply->{SERVICE_MSG} ne 'SERVICE_READY') {
        $log->fatal("Initialization failed - message is " . $reply->{SERVICE_MSG});
        $log->debug('Last reply: ' .Dumper $reply);
        die "Initialization failed. Stopped";
    }
    return $client;
}

sub run_command {
    
    my $self = shift;
    my $command = shift;
    my $params = shift || {};
 
    my $reply = $self->client()->send_receive_service_msg('COMMAND', {
        COMMAND => $command,
        PARAMS => $params
    });
    
    $self->last_reply( $reply );
    if ($reply->{SERVICE_MSG} eq 'COMMAND') {
        return $reply->{PARAMS};        
    } else {                   
        my $message;
        if ($reply->{'LIST'} && ref $reply->{'LIST'} eq 'ARRAY') {            
            # Workflow errors            
            if ($reply->{'LIST'}->[0]->{PARAMS} && $reply->{'LIST'}->[0]->{PARAMS}->{__ERROR__}) {
                $message = $reply->{'LIST'}->[0]->{PARAMS}->{__ERROR__};
            } elsif($reply->{'LIST'}->[0]->{LABEL}) {    
                $message = $reply->{'LIST'}->[0]->{LABEL};
            }
        } else {
            $message = 'unknown error';
        }
        $self->log()->error($message);
        die "Error running command: $message";
    }
}

sub handle_workflow {
    
    my $self = shift;
    my $params = shift;
        
    my $reply;
    # execute exisiting workflow
    
    # Auto serialize workflow params
    my $serializer = OpenXPKI::Serialization::Simple->new();
    foreach my $key (keys %{$params->{PARAMS}}) {
        if (ref $params->{PARAMS}->{$key}) {
            $params->{PARAMS}->{$key} = $serializer->serialize($params->{PARAMS}->{$key});
        }
    }
        
    if ($params->{ID}) {
        if (!$params->{ACTION}) {
            die "No action specified";
        }
        $self->log()->info(sprintf('execute workflow action %s on %01d', $params->{ACTION}, $params->{ID}));
        $self->log()->debug('workflow params:  '. Dumper $params->{PARAMS});
        $reply = $self->run_command('execute_workflow_activity',{
            ID => $params->{ID},                
            ACTIVITY => $params->{ACTION},
            PARAMS => $params->{PARAMS},              
        });
                
        if ($reply && $reply->{SERVICE_MSG} eq 'COMMAND') {
            $self->log()->debug('new Workflow State: ' . $reply->{PARAMS}->{WORKFLOW}->{STATE});
        }        
               
    } elsif ($params->{TYPE}) { 
        $reply = $self->run_command('create_workflow_instance',{
            WORKFLOW => $params->{TYPE},
            PARAMS => $params->{PARAMS},           
        });
        if ($reply) {
            $self->log()->debug(sprintf('Workflow created (ID: %d), State: %s', 
                $reply->{WORKFLOW}->{ID}, $reply->{WORKFLOW}->{STATE}));
        }
    } else {
        $self->log()->fatal("Neither workflow id nor type given");
        die "Neither workflow id nor type given";
    }
                      
    return $reply;               
}


sub disconnect {
    my $self = shift;
    $self->execute('LOGOUT');
    return;    
}

1;

__END__

=head1 NAME
 