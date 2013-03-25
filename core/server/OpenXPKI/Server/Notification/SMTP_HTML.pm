## OpenXPKI::Server::Notification::SMTP_HTML
## SMTP Notifier using Mime::Lite for HTML Mails
##
## Written 2013 by Oliver Welter for the OpenXPKI project
## (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Server::Notification::SMTP_HTML;
#use base qw( OpenXPKI::Server::Notification );

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

use MIME::Lite;

use Moose;

extends 'OpenXPKI::Server::Notification::SMTP';


has+ 'transport' => (
    is => 'ro',
    isa => 'ArrayRef',
    reader => '_get_transport',  
    builder => '_init_transport',
    lazy => 1,  
);

sub _init_transport {       
    
    my $self = shift;
    
    ##! 8: 'creating transport'
    my $cfg = CTX('config')->get_hash( $self->config() . '.backend' );

    my @args = ( 'smtp' );
        
    push @args, $cfg->{host} || 'localhost';    
    push @args, ('Port' => $cfg->{port}) if ($cfg->{port});    
    push @args, ('User' => $cfg->{username}) if ($cfg->{username});
    push @args, ('Password' => $cfg->{password}) if ($cfg->{password});
    push @args, ('Timeout' => $cfg->{timeout}) if ($cfg->{timeout});
    push @args, ('Debug' => 1) if ($cfg->{debug});
    
    return \@args;

}
sub _cleanup {
}



sub _send {
    
    my $self = shift;
    my $cfg = shift;
    my $vars = shift;
            
    my $tt = Template->new();

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
              
    my $msg = MIME::Lite->new( @args );

    # Plain part
    $msg->attach(
        Type     =>'text/plain',
        Data     => $plain
    ) if ($plain);

    ### Add the image part:
    $msg->attach(
        Type        =>'text/html',
        Data        => $html
    ) if ($html);
        
    my $transport = $self->_get_transport(); 
    
    if( $msg->send( @{$transport} ) ) {        
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
    
}

1;
