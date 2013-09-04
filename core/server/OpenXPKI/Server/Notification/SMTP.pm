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
    # Net::SMTP Object   
    isa => 'Object|Undef',     
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

has 'use_html' => (
    is  => 'ro',
    isa => 'Bool',     
    builder => '_init_use_html',
    lazy => 1,
);

has 'is_smtp_open' => (
    is  => 'rw',
    isa => 'Bool',            
);


sub _init_transport {    
    my $self = shift;
    
    ##! 8: 'creating Net::SMTP transport'
    my $cfg = CTX('config')->get_hash( $self->config() . '.backend' );
 
    my %smtp = (
        Host => $cfg->{host} || 'localhost',
    );
    
    $smtp{'Port'} = $cfg->{port} if ($cfg->{port});
    $smtp{'User'} = $cfg->{username} if ($cfg->{username});
    $smtp{'Password'} = $cfg->{password} if ($cfg->{password});
    $smtp{'Timeout'} = $cfg->{timeout} if ($cfg->{timeout});
    $smtp{'Debug'} = 1 if ($cfg->{debug});
    
    my $transport = Net::SMTP->new( %smtp );    
    # Net::SMTP returns undef if it can not reach the configured socket
    if (!$transport || !ref $transport) {
        CTX('log')->log(
            MESSAGE  => sprintf("Failed creating smtp transport (host: %s, user: %s)", $smtp{Host}, $smtp{User}),
            PRIORITY => "fatal",
            FACILITY => "system",
        );
        return undef;
    }
    $self->is_smtp_open(1);
    return $transport;
        
}
 
sub _init_default_envelope {    
    my $self = shift;    
    
    my $envelope = CTX('config')->get_hash( $self->config() . '.default' );
    
    if ($self->use_html() && $envelope->{images}) {
        # Depending on the connector this is already a hash
        $envelope->{images} = CTX('config')->get_hash( $self->config() . '.default.images' ) if (ref $envelope->{images} ne 'HASH');
    }
    
    ##! 8: 'Envelope data ' . Dumper $envelope
    
    return $envelope;       
}

sub _init_template_dir {        
    my $self = shift;        
    my $template_dir = CTX('config')->get( $self->config().'.template.dir' );
    $template_dir .= '/' unless($template_dir =~ /\/$/);
    return $template_dir;
}

sub _init_use_html {
    
    my $self = shift;
    
    ##! 8: 'Test for HTML '
    my $html = CTX('config')->get( $self->config() . '.backend.use_html' );
    
    if ($html) {
        
        # Try to load the Mime class        
        eval "use MIME::Entity;1";                                   
        if ($EVAL_ERROR) {
            CTX('log')->log(
                MESSAGE  => "Initialization of MIME::Entity failed, falling back to plain text",
                PRIORITY => "error",
                FACILITY => "system",
            );
            return 0;
        } else {
            return 1;
        }
    }
    return 0;    
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
        return undef;
    }
    
    my $default_envelope = $self->default_envelope();
    
    my @failed;
    
    # Walk through the handles
    MAIL_HANDLE:
    foreach my $handle (@handles) {
    
        my %vars = %{$template_vars};
    
        # Fetch the config 
        my $cfg = CTX('config')->get_hash( "$msgconfig.$handle" );
        
        # look for images if using HTML        
        if ($self->use_html() && $cfg->{images}) {
           # Depending on the connector this is already a hash
            $cfg->{images} = CTX('config')->get_hash( "$msgconfig.$handle.images" ) if (ref $cfg->{images} ne 'HASH');
        }
        
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
            my @ccrcpt;
            @ccrcpt = split(/,/, $cfg->{cc}) if($cfg->{cc});
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
        
        if (!$vars{to}) {        	
        	CTX('log')->log(
            	MESSAGE  => "Failed sending notification - no receipient",
            	PRIORITY => "error",
            	FACILITY => "system",
	        );
	        push @failed, $handle;
	        next MAIL_HANDLE;        	
        }
                
        if ($self->use_html()) {
            $self->_send_html( $cfg, \%vars ) || push @failed, $handle;
        } else {
            $self->_send_plain( $cfg, \%vars ) ||  push @failed, $handle;
        }            
        
    } 

    $self->failed( \@failed );

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


=head2 _send_plain

Send the message using Net::SMTP

=cut
sub _send_plain {
    
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
    
    my $smtp = $self->transport();
    return 0 unless($smtp);

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

=head2 _send_html

Send the message using MIME::Tools

=cut


sub _send_html {
    
    my $self = shift;
    my $cfg = shift;
    my $vars = shift;
            
    my $tt = Template->new();

    require MIME::Entity;

    # Parse the templates - txt and html 
    my $plain = $self->_render_template_file( $self->template_dir().$cfg->{template}.'.txt', $vars );
    my $html = $self->_render_template_file( $self->template_dir().$cfg->{template}.'.html', $vars );


    if (!$plain && !$html) {
        CTX('log')->log(
            MESSAGE  => "Both mail parts are empty ($cfg->{template})",
            PRIORITY => "error",
            FACILITY => "system",
        );
        return 0;
    }
    
    
    # Parse the subject
    my $subject = $self->_render_template($cfg->{subject}, $vars); 
            
    my @args = (
        From    => $cfg->{from},
        To      => $vars->{to},        
        Subject => "$vars->{prefix} $subject",
        Type    =>'multipart/alternative',                    
    );
    
    
    push @args, (Cc => join(",", @{$vars->{cc}})) if ($vars->{cc});
    push @args, ("Reply-To" => $cfg->{reply}) if ($cfg->{reply});
    
    ##! 16: 'Building with args: ' . Dumper @args
              
    my $msg = MIME::Entity->build( @args );
    
    # Plain part
    if ($plain) {
    	##! 16: ' Attach plain text'
    	$msg->attach(
        	Type     =>'text/plain',
        	Data     => $plain
	    );
    } 

    
    ##! 16: 'base created'
    
    # look for images - makes the mail a bit complicated as we need to build a second mime container
    if ($html && $cfg->{images}) {
    	
		##! 16: ' Multipart html + image'
        
        my $html_part = MIME::Entity->build(
            'Type' => 'multipart/related',
        );
        
        # The HTML Body
        $html_part->attach(
            Type        =>'text/html',
            Data        => $html
        );
        
        # The hash contains the image id and the filename
        ATTACH_IMAGE:
        foreach my $imgid (keys(%{$cfg->{images}})) {
            my $imgfile = $self->template_dir().'images/'.$cfg->{images}->{$imgid};            
            if (! -e $imgfile) {
                CTX('log')->log(
                    MESSAGE  => sprintf("HTML Notify - imagefile not found (%s)", $imgfile),
                    PRIORITY => "error",
                    FACILITY => "system",
                );
                next ATTACH_IMAGE;
            }
            
            $cfg->{images}->{$imgid} =~ /\.(gif|png|jpg)$/i;
            my $mime = lc($1);
            
            if (!$mime) {
                CTX('log')->log(
                    MESSAGE  => sprintf("HTML Notify - invalid image extension", $imgfile),,
                    PRIORITY => "error",
                    FACILITY => "system",
                );
                next ATTACH_IMAGE;
            }            
            
            $html_part->attach(
                Type => 'image/'.$mime,
                Id   => $imgid,
                Path => $imgfile,
            );
        }
        
        $msg->add_part($html_part);
        
    } elsif ($html) {
		##! 16: ' html without image'
        ## Add the html part:
        $msg->attach(
            Type        =>'text/html',
            Data        => $html
        );
    } 
    
	# a reusable Net::SMTP object
    my $transport = $self->transport();
    return 0 unless($transport); 
    
    # Host accepts a Net::SMTP object
    # @res is the list of receipients processed, empty on error
    my @res = $msg->smtpsend( Host => $transport, MailFrom => $cfg->{from} );
    if(!scalar @res) {        
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

sub _cleanup {
    
    my $self = shift;
        
    if ($self->is_smtp_open()) {
        $self->transport()->quit();
    }
    
    return;
}
 

1;

__END__
