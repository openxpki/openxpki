# OpenXPKI::Client::ui
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI;

use Moose;

use English;
use OpenXPKI::Client;
use OpenXPKI::i18n qw( i18nGettext );
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
has 'backend' => (
    required => 0,
    lazy => 1,
    is => 'rw',
    isa => 'Object',
    builder => '_init_backend',
    trigger => \&_init_backend,
);

# should be passed by the ui script to be shared, if not we create it
has 'logger' => (
    required => 0,
    lazy => 1,
    is => 'ro',
    isa => 'Object',
    'default' => sub{ return Log::Log4perl->get_logger( ); }
);

has '_config' => (
    required => 1,
    is => 'ro',
    isa => 'HashRef',
    init_arg => 'config',
);

# Hold warnings from init
has _status => (
    is => 'rw',
    isa => 'HashRef|Undef',
    lazy => 1,
    default => undef
);

=head2 _init_backend

Builder that creates an instance of OpenXPKI::Client and cares about
switching/creating the backend session

=cut 
sub _init_backend {
 
    my $self = shift;
 
    # the trigger has the client as argument, the builder has not
    my $client = shift;
    
    if (!$client) {
        $client = OpenXPKI::Client->new({
            SOCKETFILE => $self->_config()->{'socket'},
        });
        $self->logger()->debug('Create backend client instance');
    } else {
        $self->logger()->debug('Use provide client instance');
    }
    
    my $session = $self->session();
    my $old_session =  $session->param('backend_session_id') || undef;
    eval {
        $self->logger()->debug('First session reinit with id ' . ($old_session || 'init'));        
        $client->init_session({ SESSION_ID => $old_session });
    };
    
    if ($EVAL_ERROR) {
        my $exc = OpenXPKI::Exception->caught();
        if ($exc && $exc->message() eq 'I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED') {
            $self->logger()->info('Backend session was gone - start a new one');
            # The session has gone - start a new one - might happen if the gui
            # was idle too long or the server was flushed
            $client->init_session({ SESSION_ID => undef });            
            $self->_status({ level => 'warn', i18nGettext('I18N_OPENXPKI_UI_BACKEND_SESSION_GONE')});
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
    my $page = $cgi->param('page') || '';

    # Check for goto redirection first
    if ($action =~ /^redirect!(.+)/  || $page =~ /^redirect!(.+)/) {
        my $goto = $1;
        my $result = OpenXPKI::Client::UI::Result->new({ client => $self, cgi => $cgi });
        $self->logger()->debug("Send redirect to $goto");
        $result->redirect( $goto );
        return $result->render();
    }

    # Handle logout / session restart
    # Do this before connecting the server to have the client in the
    # new session and to recover from backend session failure
    if ($page eq 'logout' || $action eq 'logout') {        
        if ($self->backend()->is_logged_in()) {        
            $self->backend()->logout();
        }
        $self->logger()->info('Logout from session');
        $self->flush_session();
    }    

    my $reply = $self->backend()->send_receive_service_msg('PING');
    my $status = $reply->{SERVICE_MSG};
    $self->logger()->trace('Ping replied ' . Dumper $reply);
    $self->logger()->debug('current session status ' . $status);

    if ( $reply->{SERVICE_MSG} eq 'START_SESSION' ) {
        $reply = $self->backend()->init_session();
        $self->logger()->debug('Init new session');
        $self->logger()->trace('Init replied ' . Dumper $reply);
    }
    
    if ( $reply->{SERVICE_MSG} eq 'ERROR' ) {
        my $result = OpenXPKI::Client::UI::Result->new({ client => $self, cgi => $cgi });
        $self->logger()->debug("Got error from server");
        return $result->set_status_from_error_reply( $reply );
    }
    

    # Call to bootstrap components
    if ($page =~ /^bootstrap!(.+)/) {
        my $result = OpenXPKI::Client::UI::Bootstrap->new({ client => $self, cgi => $cgi });
        return $result->init_structure( )->render();
    }

    # Only handle requests if we have an open channel
    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' ) {
        return $self->handle_page( $args );
    }
   
    # if the backend session logged out but did not terminate
    # we get the problem that ui is logged in but backend is not
    $self->flush_session() if ($self->session()->param('is_logged_in'));

    # try to log in
    return $self->handle_login( { cgi => $cgi, reply => $reply } );

}

sub handle_page {

    my $self = shift;
    my $args = shift;
    my $method_args = shift || {};

    my $cgi = $args->{cgi};

    # set action and page - args always wins about cgi
    my $action = (defined $args->{action} ? $args->{action} : $cgi->param('action')) || '';
    my $page = (defined $args->{page} ? $args->{page} : $cgi->param('page')) || 'home';

    my $result;
    if ($action) {
        $self->logger()->info('handle action ' . $action);

        my ($class, $method, %extra) = split /!/, $action;

        $self->logger()->debug("Loading action handler class $class, extra params " . Dumper \%extra );

        $class = "OpenXPKI::Client::UI::".ucfirst($class);
        $self->logger()->debug("Loading page action class $class");
        eval "use $class;1";
        if ($EVAL_ERROR) {
            $self->logger()->error("Failed loading action class $class");
            $self->_status({ level => 'error', 'message' => i18nGettext('I18N_OPENXPKI_UI_ACTION_NOT_FOUND')});
        } else {
            $method  = 'index' if (!$method );
            $method  = "action_$method";
            $self->logger()->debug("Method is $method");
            $result = $class->new({ client => $self, cgi => $cgi, extra => \%extra });
            $result->$method( $method_args );
        }
    }

    # Render a page only if  there is no action result
    if (!$result) {

        my ($class, $method, %extra);
        # Handling of special page requests - to be replaced by hash if it grows
        if ($page eq 'welcome') {
            $class = 'home';
            $method = 'welcome';
        } else {
            ($class, $method, %extra) = split /!/, $page;
        }
        $class = "OpenXPKI::Client::UI::".ucfirst($class);
        $self->logger()->debug("Loading page handler class $class, extra params " . Dumper \%extra );

        eval "use $class;1";
        if ($EVAL_ERROR) {
            $self->logger()->error("Failed loading page class $class");
            $result = OpenXPKI::Client::UI::Bootstrap->new({ client => $self,  cgi => $cgi });
            $result->init_error();
            $result->set_status(i18nGettext('I18N_OPENXPKI_UI_PAGE_NOT_FOUND'),'error');

        } else {
            $result = $class->new({ client => $self, cgi => $cgi, extra => \%extra });
            $method  = 'index' if (!$method );
            $method  = "init_$method";
            $self->logger()->debug("Method is $method");
            $result->$method( $method_args );

        }
    }

    return $result->render();

}

sub handle_login {

    my $self = shift;
    my $args = shift;

    my $cgi = $args->{cgi};
    my $reply = $args->{reply};

    $reply = $self->backend()->send_receive_service_msg('PING') if (!$reply);

    my $status = $reply->{SERVICE_MSG};

    # Login works in three steps realm -> auth stack -> credentials

    my $session = $self->session();
    my $page = $cgi->param('page') || '';
    my $action = $cgi->param('action') || '';

    $self->logger()->info('not logged in - doing auth - page is '.$page.' - action is ' . $action);

    # Special handling for pki_realm and stack params
    if ($action eq 'login!realm' && $cgi->param('pki_realm')) {
        $session->param('pki_realm', $cgi->param('pki_realm'));
        $session->param('auth_stack', undef);
        $self->logger()->debug('set realm in session: ' . $cgi->param('pki_realm') );
    }
    if($action eq 'login!stack' && $cgi->param('auth_stack')) {
        $session->param('auth_stack', $cgi->param('auth_stack'));
        $self->logger()->debug('set auth_stack in session: ' . $cgi->param('auth_stack') );
    }
    
    # ENV always overrides session, keep this after the above block to prevent
    # people from hacking into the session parameters
    if ($ENV{OPENXPKI_PKI_REALM}) {
        $session->param('pki_realm', $ENV{OPENXPKI_PKI_REALM});
    }
    if ($ENV{OPENXPKI_AUTH_STACK}) {
        $session->param('auth_stack', $ENV{OPENXPKI_AUTH_STACK});
    }

    my $pki_realm = $session->param('pki_realm') || '';
    my $auth_stack =  $session->param('auth_stack') || '';

    my $result = OpenXPKI::Client::UI::Login->new({ client => $self, cgi => $cgi });

    # if this is an initial request, force redirect to the login page
    # will do an external redirect in case loginurl is set in config
    if ($action !~ /^login/ && $page !~ /^login/) {                 
        # Requests to pages can be redirected after login, store page in session       
        if ($page && $page ne 'logout' && $page ne 'welcome') {
            $self->logger()->debug("Store page request for later redirect " . $page);
            $self->session()->param('redirect', $page);
        }
        
        # Link to an internal method using the class!method 
        if (my $loginpage = $self->_config()->{loginpage}) {
            
            # internal call to handle_page
            return $self->handle_page({ action => '', page => $loginpage, cgi => $cgi });
        
        } elsif (my $loginurl = $self->_config()->{loginurl}) {
                        
            $self->logger()->debug("Redirect to external login page " . $loginurl );
            $result->reload(1);
            $result->redirect( { goto => $loginurl, target => '_blank' } );  
            return $result->render();
            # Do a real exit to skip the error handling of the script body
            exit;
                    
        } else {
            $self->logger()->debug('Redirect to login page');
            $result->reload(1);
            $result->redirect('login');
        }
    }  

    if ( $status eq 'GET_PKI_REALM' ) {
        if ($pki_realm) {
            $reply = $self->backend()->send_receive_service_msg( 'GET_PKI_REALM', { PKI_REALM => $pki_realm, } );
            $status = $reply->{SERVICE_MSG};
            $self->logger()->debug("Selected realm $pki_realm, new status " . $status);
        } else {
            my $realms = $reply->{'PARAMS'}->{'PKI_REALMS'};
            my @realm_list = map { $_ = {'value' => $realms->{$_}->{NAME}, 'label' => i18nGettext($realms->{$_}->{DESCRIPTION})} } keys %{$realms};
            $self->logger()->trace("Offering realms: " . Dumper \@realm_list );
            return $result->init_realm_select( \@realm_list  )->render();
        }
    }

    if ( $status eq 'GET_AUTHENTICATION_STACK' ) {
        # Never auth with an internal stack!
        if ( $auth_stack && $auth_stack !~ /^_/) {
            $self->logger()->debug("Authentication stack: $auth_stack");
            $reply = $self->backend()->send_receive_service_msg( 'GET_AUTHENTICATION_STACK', { AUTHENTICATION_STACK => $auth_stack, } );
            $status = $reply->{SERVICE_MSG};
        } else {
            my $stacks = $reply->{'PARAMS'}->{'AUTHENTICATION_STACKS'};
            
            # List stacks and hide those starting with an underscore
            my @stack_list = map {
                ($stacks->{$_}->{NAME} !~ /^_/) ? ($_ = {'value' => $stacks->{$_}->{NAME}, 'label' => i18nGettext($stacks->{$_}->{LABEL})} ) : ()
            } keys %{$stacks};
              
            # Directly load stack if there is only one
            if (scalar @stack_list == 1)  {
                $self->logger()->trace("Only one stacks avail - autoselect: " . Dumper $stacks );
                $reply = $self->backend()->send_receive_service_msg( 'GET_AUTHENTICATION_STACK', { AUTHENTICATION_STACK => $stack_list[0]->{value} } );
                $status = $reply->{SERVICE_MSG};
            } else {            
                $self->logger()->trace("Offering stacks: " . Dumper \@stack_list );
                return $result->init_auth_stack( \@stack_list )->render();
            }
        }
    }

    $self->logger()->debug("Selected realm $pki_realm, new status " . $status);
    $self->logger()->trace(Dumper $reply);

    # we have more than one login handler and leave it to the login
    # class to render it right.
    if ( $status =~ /GET_(.*)_LOGIN/ ) {
        my $login_type = $1;

        ## FIXME - need a good way to configure login handlers
        $self->logger()->info('Requested login type ' . $login_type );

        # SSO Login uses data from the ENV, so no need to render anything
        if ( $login_type eq 'CLIENT_SSO' ) {
            $self->logger()->trace('ENV is ' . Dumper \%ENV);
            $self->logger()->info('Sending SSO Login ( '.$ENV{'REMOTE_USER'}.' )');
            $reply =  $self->backend()->send_receive_service_msg( 'GET_CLIENT_SSO_LOGIN',
                { LOGIN => $ENV{'REMOTE_USER'}, PSEUDO_ROLE => '' } );
            $self->logger()->trace('Auth result ' . Dumper $reply);

        } elsif( $login_type  eq 'PASSWD' ) {

            # Credentials are passed!
            if ($cgi->param('action') eq 'login!password') {
                $self->logger()->debug('Seems to be an auth try - validating');
                ##FIXME - Input validation, dynamic config (alternate logins)!
                $reply = $self->backend()->send_receive_service_msg( $status,
                    { LOGIN => $cgi->param('username'), PASSWD => $cgi->param('password') } );
                $self->logger()->trace('Auth result ' . Dumper $reply);

            } else {
                $self->logger()->debug('No credentials, render form');
                return $result->init_login_passwd()->render();
            }
        }
    }

    if ( $reply->{SERVICE_MSG} eq 'SERVICE_READY' ) {
        $self->logger()->info('Authentication successul - fetch session info');
        # Fetch the user info from the server
        $reply = $self->backend()->send_receive_command_msg( 'get_session_info' );
        if ( $reply->{SERVICE_MSG} eq 'COMMAND' ) {
            
            # Generate a new frontend session to prevent session fixation
            # The backend session remains the same but can not be used by an 
            # adversary as the id is never exposed and we destroy the old frontend
            # session so access to the old session is not possible
            my $new_session_front = new CGI::Session(undef, undef, { Directory=>'/tmp' });
            $new_session_front->param('backend_session_id', $self->backend()->get_session_id() );
            $new_session_front->param('user', $reply->{PARAMS});
            $new_session_front->param('pki_realm', $reply->{PARAMS}->{pki_realm});
            $new_session_front->param('is_logged_in', 1);
            $new_session_front->param('initialized', 1);
            
            # fetch redirect from old session before deleting it!
            $new_session_front->param('redirect', $self->session()->param('redirect'));
               
            $self->session()->delete();                                           
            $self->session( $new_session_front );
            
            $main::cookie->{'-value'} = $new_session_front->id;
            push @main::header, ('-cookie', $cgi->cookie( $main::cookie ));
            
            $self->logger()->debug('Got session info: '. Dumper $reply->{PARAMS});
            $self->logger()->debug('CGI Header ' . Dumper \@main::header );
            
            $result->init_index();            
            return $result->render();
        }
    }
    
    if ( $reply->{SERVICE_MSG} eq 'ERROR') {
        
        $self->logger()->debug('Server Error Msg: '. Dumper $reply);
        
        # Failure here is likely a wrong password
        if ($reply->{'LIST'} && $reply->{'LIST'}->[0]->{LABEL} eq 'I18N_OPENXPKI_SERVER_AUTHENTICATION_LOGIN_FAILED') {
            $result->set_status(i18nGettext('I18N_OPENXPKI_UI_LOGIN_FAILED'),'error');            
        } else {
            $result->set_status_from_error_reply($reply);
        }
        return $result->render();
    }

    $self->logger()->debug("unhandled error during auth");
    return;

}

sub flush_session {

    my $self = shift;
    $self->logger()->info("flush session");
    $self->session()->delete();
    $self->session()->flush();
    $self->session( new CGI::Session(undef, undef, {Directory=>'/tmp'}) );

}

1;
