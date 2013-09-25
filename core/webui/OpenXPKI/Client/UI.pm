# OpenXPKI::Client::ui
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI;

use Moose; 

use OpenXPKI::Client;
use OpenXPKI::Client::UI::Login;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;
 
# ref to the cgi frontend session
has '_session' => (
    required => 1,
    is => 'ro',
    isa => 'Object|Undef',                   
    init_arg => 'session',
);

# the OXI::Client object
has '_client' => (        
    required => 0,
    lazy => 1,
    is => 'rw',
    isa => 'Object',
    builder => '_init_client',                   
);

# should be passed by the ui script to be shared, if not we create it
has 'logger' => (
    required => 0,    
    lazy => 1,
    is => 'ro',
    isa => 'Object',
    'default' => sub{ return Log::Log4perl->get_logger( ); } 
);

# the OXI::Client object
has '_config' => (        
    required => 1,    
    is => 'ro',
    isa => 'HashRef',
    init_arg => 'config',                   
);

=head2 _init_client

Builder that creates an instance of OpenXPKI::Client and cares about 
switching/creating the backend session
 
=cut
sub _init_client {


    my $self = shift;    
    my $client = OpenXPKI::Client->new(
        {
             SOCKETFILE => $self->_config()->{'socket'},
        });

    # create new session    
    my $old_session =  $self->_session()->{backend_session_id} || undef;
    $client->init_session({ SESSION_ID => $old_session });
    
    my $client_session = $client->get_session_id();    
    if ($old_session && $client_session eq $old_session) {
        $self->logger()->info('Resume backend session with id ' . $client_session);
    } else {
        if ($old_session) { 
            $self->logger()->info('Re-Init backend session ' . $client_session . '/' . $old_session );        
        } else {
            $self->logger()->info('New backend session with id ' . $client_session);
        }
        $self->_session()->{backend_session_id} = $client_session;        
    }
    return $client;
}


sub BUILD {
    my $self = shift;

}    

sub handle_request {
    
    my $self = shift;
    my $args = shift;    
    my $cgi = $args->{cgi};
    
    my $reply = $self->_client()->send_receive_service_msg('PING');
    my $status = $reply->{SERVICE_MSG};
    $self->logger()->trace('Ping replied ' . Dumper $reply);
    $self->logger()->debug('current session status ' . Dumper $status);
    
    
    if ( $reply->{SERVICE_MSG} eq 'ERROR' ) {
        my $result = OpenXPKI::Client::UI::Login->new();                
        $self->logger()->debug("Got error from server");        
        return $result->set_status_from_error_reply( $reply );    
    }
           
    # Only handle requests if we have an open channel
    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' ) {      
        return $self->handle_page( $args );         
    }
    
    # try to log in 
    return $self->handle_login( { cgi => $cgi, reply => $reply } );           
    
}

sub handle_page {

    my $self = shift;
    my $args = shift;
    
    my $cgi = $args->{cgi};
    
    # set action - args always wins about cgi
    my $action = (defined $args->{action} ? $args->{action} : $cgi->param('action')) || '';
    
    my $result;
    if ($action) {
        $self->logger()->info('handle action ' . $action);
        #$result =            
    }    
         
    my $page = (defined $args->{page} ? $args->{page} : $cgi->param('page')) || 'home';
    
        
    
    
}

sub handle_login {
    
    my $self = shift;
    my $args = shift;
    
    my $cgi = $args->{cgi};
    my $reply = $args->{reply};

    $self->logger()->info('not logged in - doing auth');
        
    $reply = $self->_client()->send_receive_service_msg('PING') if (!$reply);
        
    my $status = $reply->{SERVICE_MSG};
    
    # Login works in three steps realm -> auth stack -> credentials
    
    my $session = $self->_session();
    my $action = $cgi->param('action') || '';
    
    # Special handling for pki_realm and stack params
    if ($action eq 'login.realm' && $cgi->param('pki_realm')) {
        $session->{'pki_realm'} = $cgi->param('pki_realm');
        $session->{'auth_stack'} = undef;
        $self->logger()->debug('set realm in session: ' . $cgi->param('pki_realm') ); 
    } 
    if($action eq 'login.stack' && $cgi->param('auth_stack')) {
        $session->{'auth_stack'} = $cgi->param('auth_stack');
        $self->logger()->debug('set auth_stack in session: ' . $cgi->param('auth_stack') );
    }
    
    my $pki_realm = $session->{'pki_realm'} || '';
    my $auth_stack =  $session->{'auth_stack'};
    
    my $result = OpenXPKI::Client::UI::Login->new();
          
    if ( $status eq 'GET_PKI_REALM' ) {
        if ($pki_realm) {            
            $reply = $self->_client()->send_receive_service_msg( 'GET_PKI_REALM', { PKI_REALM => $pki_realm, } );
            $status = $reply->{SERVICE_MSG};
            $self->logger()->debug("Selected realm $pki_realm, new status " . $status);
        } else {
            my $realms = $reply->{'PARAMS'}->{'PKI_REALMS'};
            my @realm_list = map { $_ = {'value' => $realms->{$_}->{NAME}, 'label' => $realms->{$_}->{DESCRIPTION}} } keys %{$realms};
            $self->logger()->trace("Offering realms: " . Dumper \@realm_list );
            return $result->init_realm_select( \@realm_list  )->render();
        }        
    }

    if ( $status eq 'GET_AUTHENTICATION_STACK' ) {
        if ( $auth_stack ) {
            $self->logger()->debug("Authentication stack: $auth_stack");
            $reply = $self->_client()->send_receive_service_msg( 'GET_AUTHENTICATION_STACK', { AUTHENTICATION_STACK => $auth_stack, } );
            $status = $reply->{SERVICE_MSG};            
        } else {
            my $stacks = $reply->{'PARAMS'}->{'AUTHENTICATION_STACKS'};
            my @stack_list = map { $_ = {'value' => $stacks->{$_}->{NAME}, 'label' => $stacks->{$_}->{DESCRIPTION}} } keys %{$stacks} ;  
            $self->logger()->trace("Offering stacks: " . Dumper \@stack_list );
            return $result->init_auth_stack( \@stack_list )->render();
        }
    } 
    
    $self->logger()->debug("Selected realm $pki_realm, new status " . $status);
    
    # we have more than one login handler and leave it to the login 
    # class to render it right. 
    if ( $status =~ /GET_(.*)_LOGIN/ ) {
        my $login_type = $1;
        
        ## FIXME - need a good way to configure login handlers        
        
        $self->logger()->info('Requested login type ' . $login_type );
        # Credentials are passed!
        if ($cgi->param('action') eq 'login.password') {
            $self->logger()->debug('Seems to be an auth try - validating');
            ##FIXME - Input validation!
            $reply = $self->_client()->send_receive_service_msg( $status, 
                { LOGIN => $cgi->param('username'), PASSWD => $cgi->param('password') } );

            $self->logger()->trace('Auth result ' . Dumper $reply);
        } else {
            $self->logger()->debug('No credentials, render form');
            return $result->init_login_passwd()->render();
        }
    }
    
    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' ) {        
        $self->logger()->info('Authentication successul');
        return $self->handle_page( { 'page' => 'home', 'action' => '', cgi => $cgi }  );
    }
            
    if ( $reply->{SERVICE_MSG} eq 'ERROR') {
        return $result->set_status_from_error_reply->render( $reply );
    }
         
    $self->logger()->debug("unhandled error during auth");
    return;         
    
}
1;