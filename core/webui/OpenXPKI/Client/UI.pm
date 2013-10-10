# OpenXPKI::Client::ui
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI;

use Moose; 

use English;
use OpenXPKI::Client;
use OpenXPKI::Client::UI::Bootstrap;
use OpenXPKI::Client::UI::Login;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;
 
# ref to the cgi frontend session
has 'session' => (
    required => 1,
    is => 'rw',
    isa => 'Object|Undef',                   
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
    my $session = $self->session();    
    my $old_session =  $session->param('backend_session_id') || undef;    
    $self->logger()->info('old backend session ' . $old_session);
    
    # Fetch errors on session init 
    eval {
        $client->init_session({ SESSION_ID => $old_session });
    };   
    if ($EVAL_ERROR) {
        my $exc = OpenXPKI::Exception->caught();  
        if ($exc && $exc->message() eq 'I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED') {
            # The session has gone - start a new one - might happen if the gui 
            # was idle too long or the server was flushed
            $client->init_session({ SESSION_ID => undef });
            $self->logger()->info('Backend session was gone - start a new one');
        } else {
            $self->logger()->error('Error creating backend session: ' . $EVAL_ERROR->{message});
            $self->logger()->trace($EVAL_ERROR);
            die "Backend communication problem";
        }
    }
    
    my $client_session = $client->get_session_id();    
    # logging stuff only
    if ($old_session && $client_session eq $old_session) {
        $self->logger()->info('Resume backend session with id ' . $client_session);
    } elsif ($old_session) { 
        $self->logger()->info('Re-Init backend session ' . $client_session . '/' . $old_session );        
    } else {
        $self->logger()->info('New backend session with id ' . $client_session);
    }
    $session->param('backend_session_id', $client_session);
    $self->logger()->trace( Dumper $session );
    return $client;
}


sub BUILD {
    my $self = shift;

    if (!$self->session()->param('initialized')) {        
        my $session = $self->session();
        $session->param('initialized', 1);
        $session->param('is_logged_in', 0);
        $session->param('user', undef);
    }

}    
 
sub handle_request {
    
    my $self = shift;
    my $args = shift;    
    my $cgi = $args->{cgi};

    my $action = $cgi->param('action') || '';
     
    # Handle logout / session restart
    # Do this before connecting the server to have the client in the
    # new session and to recover from backend session failure
    if ($action eq 'logout') {
        # TODO - kill backend session, seems to be not implemented yet....
        $self->session()->delete();
        $self->session()->flush();
        $self->session( new CGI::Session(undef, undef, {Directory=>'/tmp'}) );    
    }
    
    my $reply = $self->_client()->send_receive_service_msg('PING');
    my $status = $reply->{SERVICE_MSG};
    $self->logger()->trace('Ping replied ' . Dumper $reply);
    $self->logger()->debug('current session status ' . $status);
        
    if ( $reply->{SERVICE_MSG} eq 'ERROR' ) {
        my $result = OpenXPKI::Client::UI::Login->new();                
        $self->logger()->debug("Got error from server");        
        return $result->set_status_from_error_reply( $reply );    
    }
    
    # Call to bootstrap components
    if ($action =~ /^bootstrap\.(.+)/) {                
        my $result = OpenXPKI::Client::UI::Bootstrap->new({ client => $self });        
        return $result->init_structure( )->render();
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
    my $method_args = shift || {};
    
    my $cgi = $args->{cgi};
    
    # set action - args always wins about cgi
    my $action = (defined $args->{action} ? $args->{action} : $cgi->param('action')) || '';
    
    my $result;
    if ($action) {
        $self->logger()->info('handle action ' . $action);
        #$result =            
    }    
         
    my $page = (defined $args->{page} ? $args->{page} : $cgi->param('page')) || 'home';
    
    my ($class, $method) = split /\./, $page;
    $class = "OpenXPKI::Client::UI::".ucfirst($class);
    eval "use $class;1" or die "Error use'ing $class: $@";
    $self->logger()->debug("Loading page handler class $class");   
    $result = $class->new({ client => $self });
    
    $method  = 'index' if (!$method );
    $method  = "init_$method";
    
    $self->logger()->debug("Method is $method");   
    
    $result->$method( $method_args );
    return $result->render();
    
}

sub handle_login {
    
    my $self = shift;
    my $args = shift;
    
    my $cgi = $args->{cgi};
    my $reply = $args->{reply};
       
    $reply = $self->_client()->send_receive_service_msg('PING') if (!$reply);
        
    my $status = $reply->{SERVICE_MSG};
    
    # Login works in three steps realm -> auth stack -> credentials
    
    my $session = $self->session();
    my $action = $cgi->param('action') || '';

    $self->logger()->info('not logged in - doing auth - action is ' . $action);
    
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
    #$auth_stack = 'External Dynamic';
    
    my $result = OpenXPKI::Client::UI::Login->new({ client => $self });
          
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
            my $i=0;
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
            ##FIXME - Input validation, dynamic config (alternate logins)!
            $reply = $self->_client()->send_receive_service_msg( $status, 
                { LOGIN => $cgi->param('username'), PASSWD => $cgi->param('password') } );
            $self->logger()->trace('Auth result ' . Dumper $reply);

            # Failure here is most likely a wrong password            
            if ( $reply->{SERVICE_MSG} eq 'ERROR' &&
                $reply->{'LIST'}->[0]->{LABEL} eq 'I18N_OPENXPKI_SERVER_AUTHENTICATION_LOGIN_FAILED') {                
                $result->set_status('Login failed','error');
                return $result->render();
            }
        } else {
            $self->logger()->debug('No credentials, render form');
            return $result->init_login_passwd()->render();
        }
    }
    
    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' ) {        
        $self->logger()->info('Authentication successul - fetch session info');            
        # Fetch the user info from the server
        $reply = $self->_client()->send_receive_command_msg( 'get_session_info' );
        if ( $reply->{SERVICE_MSG} eq 'COMMAND' ) { 
            $self->session()->param('user', $reply->{PARAMS});
            $self->logger()->debug('Got session info: '. Dumper $reply->{PARAMS});         
            return $self->handle_page( { 'page' => 'home', 'action' => '', cgi => $cgi }, { initial => 1 } );
        }
    }
            
    if ( $reply->{SERVICE_MSG} eq 'ERROR') {
        $self->logger()->debug('Server Error Msg: '. Dumper $reply);
        return $result->set_status_from_error_reply->render( $reply );
    }
         
    $self->logger()->debug("unhandled error during auth");
    return;         
    
}
1;