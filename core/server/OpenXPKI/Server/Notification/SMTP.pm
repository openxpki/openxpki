## OpenXPKI::Server::Notification::SMTP
## SMTP Notifier
##
## Written 2012 by Oliver Welter for the OpenXPKI project
## (C) Copyright 2012 by The OpenXPKI Project

=head1 Name

OpenXPKI::Server::Notification::SMTP - Notification via SMTP

=head1 Description

This class implements a notifier that sends out notification as
plain plain text message using Net::SMTP. The templates for the mails
are read from the filesystem. 
 
=head1 Configuration
     
    backend:
        class: OpenXPKI::Server::Notification::SMTP
        host: localhost
        port: 25
        username: smtpuser
        password: smtppass
        debug: 0
        
    default:
        to: "[% cert_info.requestor_email %]"
        from: no-reply@openxpki.org
        reply: helpdesk@openxpki.org
        cc: helpdesk@openxpki.org
        prefix: PKI-Request [% meta_wf_id %]
                  
    template:
        dir:   /home/pkiadm/ca-one/mails/

    message:
        csr_created:  
            default:   
                template: csr_created_user
                subject: CSR for [% cert_subject %]
            
            raop:  
                template: csr_created_raop  # Suffix .txt is always added!
                to: ra-officer@openxpki.org
                reply: "[% cert_info.requestor_email %]"
                subject: New CSR for [% cert_subject %]

Calling the notifier with C<MESSAGE=csr_created> will send out two mails.
One to the requestor and one to the ra-officer, both are CC'ed to helpdesk.

B<Note>: The settings To, Cc and Prefix are stored in the workflow on the first
message and reused for each subsequent message on the same channel, so you can
gurantee that each message in a thread is sent to the same people. All settings
from default can be overriden in the local definition. Defaults can be blanked
using an empty string.
=cut 

package OpenXPKI::Server::Notification::SMTP;

use strict;
use warnings;
use English;

use Data::Dumper;

use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::FileUtils;
use OpenXPKI::Serialization::Simple;

use Net::SMTP;

use Moose;

extends 'OpenXPKI::Server::Notification::Base';

#use namespace::autoclean; # Comnflicts with Debugger

# Attribute Setup
has 'transport' => (
	is  => 'ro',
    isa => 'Object',
    reader => '_get_transport',  
    builder => '_init_transport',
    lazy => 1,  
);

has 'default_envelope' => (
    is  => 'ro',
    isa => 'HashRef',
    builder => '_init_default_envelope',
    lazy => 1,  
);


has 'template_dir' => (
    is  => 'ro',
    isa => 'Str',     
    builder => '_init_template_dir',
    lazy => 1,
);

sub _init_transport {    
    my $self = shift;
    
    ##! 8: 'creating transport'
    my $cfg = CTX('config')->get_hash( $self->config() . '.backend' );

    my %smtp = (
        Host => $cfg->{host} || 'localhost',
        Debug => 1        
    );
    
    $smtp{'Port'} = $cfg->{port} if ($cfg->{port});
    $smtp{'User'} = $cfg->{username} if ($cfg->{username});
    $smtp{'Password'} = $cfg->{password} if ($cfg->{password});
    $smtp{'Timeout'} = $cfg->{timeout} if ($cfg->{timeout});
    $smtp{'Debug'} = 1 if ($cfg->{debug});

    my $transport = Net::SMTP->new( %smtp );
    return $transport;
    
}

sub _init_default_envelope {    
    my $self = shift;    
    
    my $envelope = CTX('config')->get_hash( $self->config() . '.default' );
    ##! 8: 'Envelope data ' . Dumper $envelope
    
    return $envelope;       
}

sub _init_template_dir {        
    my $self = shift;        
    my $template_dir = CTX('config')->get( $self->config().'.template.dir' );
    $template_dir .= '/' unless($template_dir =~ /\/$/);
    return $template_dir;
}
 

=head1 Functions
=head2 notify
see @OpenXPKI::Server::Notification::Base 
=cut 
sub notify {
    
    ##! 1: 'start'
    
    my $self = shift;
    my $args = shift;
    
    my $msg = $args->{MESSAGE};        
    my $token = $args->{TOKEN};
    
    my $template_vars = $args->{VARS};
        
    my $msgconfig = $self->config().'.message.'.$msg;
    
    ##! 1: 'Config Path ' . $msgconfig
    
    # Test if there is an entry for this kind of message
    my @handles = CTX('config')->get_keys( $msgconfig );
    
    ##! 16: 'Found handles ' . Dumper @handles
    
    if (!@handles) {
        CTX('log')->log(
            MESSAGE  => "No notifcations to send for $msgconfig",
            PRIORITY => "debug",
            FACILITY => "system",
        );  
        return 0;
    }
    
    my $default_envelope = $self->default_envelope();
    
    my $smtp = $self->_get_transport();

    # Walk through the handles
    MAIL_HANDLE:
    foreach my $handle (@handles) {
    
        my %vars = %{$template_vars};
    
        # Fetch the config 
        my $cfg = CTX('config')->get_hash( "$msgconfig.$handle" );
        
        ##! 16: 'Local config ' . Dumper $cfg
        
        # Merge with default envelope
        foreach my $key (keys %{$default_envelope}) {
            $cfg->{$key} = $default_envelope->{$key} if (!defined $cfg->{$key});
        }
        
        ##! 8: 'Process handle ' . $handle
        
        # Look if there is info from previous notifications
        # Persisted information includes:
        # * to: Receipient address
        # * cc: CC-Receipient, array of address
        # * prefix: subject prefix (aka Ticket-Id)
        my $pi = $token->{$handle};        
        if (!defined $pi) {
            $pi = { 
                prefix => '',
                to => '',
                cc => [], 
            };
 
            # Create prefix            
            if (my $prefix = $cfg->{prefix}) {
                $pi->{prefix} = $self->_render_template($prefix, \%vars);
                ##! 32: 'Creating new prefix ' . $pi->{prefix}
            }

            # Receipient        
            $pi->{to} = $self->_render_receipient( $cfg->{to}, \%vars );
            ##! 32: 'Got new rcpt  ' . $pi->{to}            
        
            # CC-Receipient             
            my @cclist;
            ##! 32: 'Building new cc list'
            # explicit from configuration, can be a comma sep. list
            my @ccrcpt = split(/,/, $cfg->{cc});
            foreach my $cc (@ccrcpt) {
                my $rcpt = $self->_render_receipient( $cc, \%vars );
                ##! 32: 'New cc rcpt: ' . $cc . ' -> ' . $rcpt                
                push @cclist, $rcpt if($rcpt);
            }
            $pi->{cc} = \@cclist;
            ##! 32: 'New cclist ' . Dumper $pi->{cc}
            
            # Write back info to be persisted
            $token->{$handle} = $pi;         
        }
    
        ##! 16: 'Persisted info: ' . Dumper $pi                       
        # Copy PI to vars
        foreach my $key (keys %{$pi}) {
            $vars{$key} = $pi->{$key}; 
        }            
        
        $self->_send( $cfg, \%vars );
               
        
    } 
      
    $self->_cleanup();
    return $token;
    
}

=head2

=cut
sub _render_receipient {
    
    ##! 1: 'Start'
    my $self = shift;
    my $mail = shift;
    my $vars = shift;
        
    $mail = $self->_render_template( $mail, $vars );
    
    #  trim whitespace
    $mail =~ s/\s+//;
    
    if ($mail !~ /^[\w\.-]+\@[\w\.-]+$/) {
        ##! 8: 'This is not an address ' . $mail
        CTX('log')->log(
            MESSAGE  => "Not a mail address: $mail",
            PRIORITY => "error",
            FACILITY => "system",
        );
        return undef;
    }
    
    return $mail;
        
}


=head2

=cut
sub _send {
    
    my $self = shift;
    my $cfg = shift;
    my $vars = shift;
               
    my $output = $self->_render_template_file( $self->template_dir().$cfg->{template}.'.txt', $vars );
    
    my $subject= $self->_render_template( $cfg->{subject}, $vars );
                    
    # Now send the message
    # For Net::SMTP we need to build the full message including the header part        
    my $smtpmsg = "User-Agent: OpenXPKI Notification Service using Net::SMTP\n";
    $smtpmsg .= "Date: " . DateTime->now()->strftime("%a, %d %b %Y %H:%M:%S %z\n");
    $smtpmsg .= "OpenXPKI-Thread-Id: $vars->{'thread'}\n";
    $smtpmsg .= "From: " . $cfg->{from} . "\n";
    $smtpmsg .= "To: " . $vars->{to} . "\n";
    $smtpmsg .= "Cc: " . join(",", @{$vars->{cc}}) . "\n" if ($vars->{cc});        
    $smtpmsg .= "Reply-To: " . $cfg->{reply} . "\n" if ($cfg->{reply});
    $smtpmsg .= "Subject: $vars->{prefix} $subject\n";
    $smtpmsg .= "\n$output";


    ##! 64: "SMTP Msg --------------------\n$smtpmsg\n ----------------------------------";        
    
    my $smtp = $self->_get_transport();

    $smtp->mail( $cfg->{from} );
    $smtp->to( $vars->{to} );
    
    foreach my $cc (@{$vars->{cc}}) {
        $smtp->to( $cc );    
    }
        
    $smtp->data();
    $smtp->datasend($smtpmsg);        
    
    if( $smtp->dataend() ) {        
        CTX('log')->log(
            MESSAGE  => sprintf("Failed sending notification (%s, %s)", $vars->{to}, $subject),
            PRIORITY => "error",
            FACILITY => "system",
        );
        return 0;
    }
    CTX('log')->log(
        MESSAGE  => sprintf("Notification was send (%s, %s)", $vars->{to}, $subject),
        PRIORITY => "info",
        FACILITY => "system",
    );

    return 1;
    
}

=head2

=cut
sub _cleanup {
    
    my $self = shift;
    
    my $smtp = $self->_get_transport();    
    $smtp->quit();
    return;
}
 

1;

__END__
