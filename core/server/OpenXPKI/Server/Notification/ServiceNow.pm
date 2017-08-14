## OpenXPKI::Server::Notification::ServiceNow
## Notifier for the ServiceNow Ticket System
## using their public SOAP API via SOAP::Lite
##
## Written 2013 by Oliver Welter for the OpenXPKI project
## (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Server::Notification::ServiceNow;

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

use SOAP::Lite on_fault => sub {
    my($soap, $res) = @_;
    OpenXPKI::Exception->throw(message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_SERVICENOW_SOAP_ERROR',
        params => { error => ref $res ? $res->faultdetail : $soap->transport->status } );
};

use Moose;

extends 'OpenXPKI::Server::Notification::Base';

has 'transport' => (
    is      => 'ro',
    isa     => 'Object',
    reader  => '_transport',
    builder => '_init_transport',
    lazy    => 1,
);

has 'template_dir' => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_init_template_dir',
    lazy    => 1,
);

has 'xmlns' => (
    is        => 'ro',
    isa       => 'Str',
    'default' => 'http://www.service-now.com/',
);

sub _init_transport {

    my $self = shift;

    ##! 8: 'creating transport'
    my $cfg = CTX('config')->get_hash( $self->config() . '.backend' );

    my $endpoint = $cfg->{server}.'?SOAP';

    # pass in credentials by overriding the method
    our @credentials = ($cfg->{username} => $cfg->{password});
    BEGIN {
       sub SOAP::Transport::HTTP::Client::get_basic_credentials { return @credentials; }
    }

    my $soap;
    my $timeout = $cfg->{timeout} || 30;
    # declare the SOAP endpoint here
    eval { $soap = SOAP::Lite->proxy($endpoint, timeout => $timeout); };

    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_SERVICENOW_COULD_NOT_INSTANTIATE_CLIENT',
            params => { 'ERROR' => $EVAL_ERROR, },
        );
    }

    return $soap;
}

sub _init_template_dir {
    my $self         = shift;
    my $template_dir = CTX('config')->get( $self->config() . '.template.dir' );
    $template_dir .= '/' unless ( $template_dir =~ /\/$/ );
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

    my $msg           = $args->{MESSAGE};
    my $token         = $args->{TOKEN};
    my $template_vars = $args->{VARS};

    my $msgconfig = $self->config() . '.message.' . $msg;

    # Test if there is an entry for this kind of message
    my @handles = CTX('config')->get_keys($msgconfig);

    ##! 8: 'Starting message ' . $msg

    ##! 16: 'Found handles ' . Dumper @handles

    ##! 32: 'Template vars: ' . Dumper $template_vars

    if ( !@handles ) {
        CTX('log')->system()->debug("No notifcations to send for $msgconfig");

        return 0;
    }

    # Walk through the handles

    my @failed;
  QUEUE_HANDLE:
    foreach my $handle (@handles) {

        my $pi = $token->{$handle};

        ##! 16: 'Starting handle '.$handle.', PI: ' . Dumper $pi

        # We do the eval per handle
        eval {

            my $cfg = CTX('config')->get_hash("$msgconfig.$handle");

            # Check if there is a ticket or the first action is open
            my $sys_id;

            OpenXPKI::Exception->throw(
                message =>
                 'I18N_OPENXPKI_SERVER_NOTIFICATION_RT_NO_ACTION',
                params => { HANDLE => "$msgconfig.$handle", }
            ) if ( !$cfg->{action} );


            my $action = $cfg->{action};
            delete $cfg->{action};

            # Crosscheck open/exists
            if ( $pi->{sys_id} ) {

                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_SERVICENOW_OPEN_ON_EXISTING_TICKET',
                    params => { HANDLE => $msgconfig . $handle, }
                ) if ( $action eq "open" );

                $sys_id = $pi->{sys_id};

            } elsif ( $action ne "open" ) {
                OpenXPKI::Exception->throw(
                    message =>
                      'I18N_OPENXPKI_SERVER_NOTIFICATION_SERVICENOW_NO_OPEN_TICKET',
                    params => { HANDLE => "$msgconfig.$handle", }
                );
            }

            ##! 16: 'action ' . $action
            ##! 32: 'Config ' . Dumper $cfg
            if ( $action eq "open" ) {

                my $ticket =
                    $self->_insert( { CFG => $cfg, VARS => $template_vars } );
                    ##! 16: 'Initial open - new ticket id: ' . $ticket->{ticket_id}
                    $pi->{ticket} = $ticket->{ticket_id};
                    $pi->{sys_id} = $ticket->{sys_id};


            }
            # Update a ticket
            elsif ( $action eq "update" ) {

                $cfg->{sys_id} = $pi->{sys_id};
                $self->_update( { CFG => $cfg, VARS => $template_vars } );

            }
            # Shortcut for setting the status to resolved
            elsif ( $action eq "close" ) {
                ##! 32: 'Closing ticket '

                $cfg->{sys_id} = $pi->{sys_id};
                $cfg->{state} = 7;
                $self->_update( { CFG => $cfg, VARS => $template_vars } );

            } else {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_SERVICENOW_UNKNOWN_ACTION',
                    params => { HANDLE => $msgconfig . $handle, ACTION => $action }
                );
            }

        };

        $token->{$handle} = $pi;

        if ($EVAL_ERROR) {
            CTX('log')->system()->error('ServiceNow action failed on ticket '
                  . $pi->{sys_id}
                  . ' with '
                  . $EVAL_ERROR);


            push @failed, $handle;
        }
    }    # end handle

    $self->failed( \@failed );

    return $token;

}

=head2 read ( sys_id )
read the contents of a ticket - used for automated tests
=cut

sub read {

    my $self = shift;
    my $sys_id = shift;

    my @params;
    push( @params, SOAP::Data->name( sys_id => $sys_id  ) );

    my $resp = $self->_do_call('get', @params );

    return $resp;

}


sub _cleanup {

}

=head2 _do_call ( method, @args )
Dispatch the call to the SOAP API and do error handling
=cut
sub _do_call {

    my $self = shift;
    my $action = shift;
    my @args = @_;

    # invoke the SOAP call
    my $method = SOAP::Data->name($action)
       ->attr( { xmlns => $self->xmlns() } );

    my $result = $self->_transport()->call( $method => @args );

    if ($result->fault) {
        ##! 8: 'SOAP failed ' . Dumper $result->fault
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_NOTIFICATION_SERVICENOW_SOAP_CALL_FAILED',
            params => {
                faultcode => $result->fault->{'faultcode'},
                faultstring => $result->fault->{'faultstring'},
        });

    }

    return $result->body->{ $action.'Response' };

}

=head2 _insert
Prepare
=cut
sub _insert {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;
    my $cfg  = $args->{CFG};
    my $vars = $args->{VARS};

    ##! 16: 'Template vars: ' . Dumper $vars

    # create params list
    my @params = @{$self->_prepare_params( $args )};

    # invoke the SOAP call - insert to create a ticket
    my $result = $self->_do_call( 'insert', @params );

    my $ticket = {
       'sys_id' => $result->{sys_id},
       'ticket_id' => $result->{number}
    };

    ##! 8: "Created a new ticket, ID " . $ticket->{ticket_id}

    CTX('log')->system()->info('Opening new ServiceNow ticket - id ' . $ticket->{ticket_id});


    ##! 1: 'end'
    return $ticket;

}

=head2 _update
=cut
sub _update {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;
    my $cfg  = $args->{CFG};
    my $vars = $args->{VARS};

    ##! 16: 'Template vars: ' . Dumper $vars

    # create params list
    my @params = @{$self->_prepare_params( $args )};

    my $result = $self->_do_call( 'update', @params );

    ##! 8: "Ticket updated " . $cfg->{sys_id}

    CTX('log')->system()->info("ServiceNow Ticket updated " . $cfg->{sys_id});


    ##! 1: 'end'
    return $result;


}

sub _prepare_params {

    ##! 1: 'start'

    my $self = shift;
    my $args = shift;
    my $cfg  = $args->{CFG};
    my $vars = $args->{VARS};

    ##! 16: 'Template vars: ' . Dumper $vars

    my @params;

    # Add the message to the params - if any (can be empty if only attributes are updated)
    my $text;
    $text = $self->_render_template_file( $self->template_dir() . $cfg->{template} . '.txt', $vars ) if($cfg->{template});
    delete $cfg->{template};
    ##! 32: 'render the text' . $text
    push( @params, SOAP::Data->name( comments => $text ) ) if($text);

    foreach my $key ( keys %{$cfg} ) {
        my $val = $self->_render_template( $cfg->{$key}, $vars );
        #! 32: "Adding custom field $key => $val"
        push( @params, SOAP::Data->name( $key => $val  ) ) if ($val);
    }

    ##! 32: 'Params: ' . Dumper @params

    return \@params;



}

1;
