
=head1

An easy to use class to connect to the openxpki daemon and run commands
Designed as a kind of CLI interface for inline use within scripts. By
default, it will not handle sessions and create a new session using the
given auth info on each new instance (subsequent commands within one call
are run on the same session). If you pass (and maintain) a session object to
the constructor, it is used to persist the backend session during requests.

=cut

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

# ref to the cgi frontend session
# if undef we behave as "one shot" client
has 'session' => (
    is => 'rw',
    isa => 'Object|Undef',
    default => undef,
    lazy => 1,
);

has '_config' => (
    required => 1,
    is => 'ro',
    isa => 'HashRef',
    init_arg => 'config',
);

has client => (
    is => 'rw',
    isa => 'Object|Undef',
    builder  => '_build_client',
    lazy => 1,
    clearer => '_clear_client',
);

has logger => (
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

has last_error => (
    is => 'rw',
    isa => 'Str|Undef',
    default => undef,
);

sub _build_logger {
    if(!Log::Log4perl->initialized()) {
        Log::Log4perl->easy_init($ERROR);
    }
    return Log::Log4perl->get_logger();
};

sub _build_client {

    my $self = shift;

    my $client = OpenXPKI::Client->new({
        SOCKETFILE => $self->_config()->{'socket'},
    });

    if (! defined $client) {
        die "Could not instantiate OpenXPKI client. Stopped";
    }

    my $log = $self->logger();

    $log->debug("Initialize client");

    # if we have a frontend session object, we also create a backend session
    if ($self->session()) {
        $self->__reinit_session( $client );

    # Init a fresh backend session
    } else {

        if (! $client->init_session()) {
            die "Could not initiate OpenXPKI server session. Stopped";
        }
        $log->debug("Started volatile session with id: " . $client->get_session_id() );
    }

    # check if we need a login and iterate the necessary steps
    my $reply = $client->send_receive_service_msg('PING');

    my $status = $reply->{SERVICE_MSG};
    if ($status eq 'GET_PKI_REALM') {
        my $realm = $self->_config()->{'realm'};
        if (! $realm ) {
            $log->fatal("Found more than one realm but no realm is specified");
            $log->trace("Realms found:" . Dumper (keys %{$reply->{PARAMS}->{PKI_REALMS}}));
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
            $log->trace("Stacks found:" . Dumper (keys %{$reply->{PARAMS}->{AUTHENTICATION_STACKS}}));
            die "No auth stack specified";
        }
        $log->debug("Selecting auth stack ". $auth->{stack});
        $reply = $client->send_receive_service_msg('GET_AUTHENTICATION_STACK',
            { AUTHENTICATION_STACK => $auth->{stack} });

    }

    if ($reply->{SERVICE_MSG} =~ /GET_(.*)_LOGIN/) {
        my $login_type = $1;
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
        $log->trace('Last reply: ' .Dumper $reply);
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
    if ($reply->{SERVICE_MSG} ne 'COMMAND') {
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
        $self->logger()->error($message);
        $self->logger()->trace(Dumper $reply);
        $self->last_error($message);
        die "Error running command: $message";
    }
    $self->last_error('');
    return $reply->{PARAMS};
}

=head2 handle_workflow

Combined method to interact with workflows. Action depends on the parameters
given. Return value is always the workflow info structure.

=over

=item ID

Returns the workflow info for the existing workflow with given id.

=item ACTIVITY

Only in combination with ID, executes the given action and returns the
workflow info after processing was done. Will die if execute fails.

=item TYPE

Create a new workflow of given type, only effective if ID is not given.

=item PARAMS

Parameter hash to be passed to create/execute method as input values.

=back

=cut

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

    if ($params->{ACTIVITY} && $params->{ID}) {

        $self->logger()->info(sprintf('execute workflow action %s on %01d', $params->{ACTIVITY}, $params->{ID}));
        $self->logger()->trace('workflow params:  '. Dumper $params->{PARAMS});
        $reply = $self->run_command('execute_workflow_activity',{
            ID => $params->{ID},
            ACTIVITY => $params->{ACTIVITY},
            PARAMS => $params->{PARAMS},
        });

        if (!$reply || !$reply->{WORKFLOW}) {
            $self->logger()->fatal("No workflow object received after execute!");
            die "No workflow object received!";
        }

        $self->logger()->debug('new Workflow State: ' . $reply->{WORKFLOW}->{STATE});

    } elsif ($params->{ID}) {

        $self->logger()->debug(sprintf('request for workflow info on %01d', $params->{ID}));

        $reply = $self->run_command('get_workflow_info',{
            ID => $params->{ID},
        });

        if (!$reply || !$reply->{WORKFLOW}) {
            $self->logger()->fatal("No workflow object received after execute!");
            die "No workflow object received!";
        }

        $self->logger()->trace($reply->{WORKFLOW});

    } elsif ($params->{TYPE}) {
        $reply = $self->run_command('create_workflow_instance',{
            WORKFLOW => $params->{TYPE},
            PARAMS => $params->{PARAMS},
        });

        if (!$reply || !$reply->{WORKFLOW}) {
            $self->logger()->fatal("No workflow object received after create!");
            die "No workflow object received!";
        }

        $self->logger()->debug(sprintf('Workflow created (ID: %d), State: %s',
            $reply->{WORKFLOW}->{ID}, $reply->{WORKFLOW}->{STATE}));

    } else {
        $self->logger()->fatal("Neither workflow id nor type given");
        die "Neither workflow id nor type given";
    }

    $self->logger()->trace('Result of workflow action: ' . Dumper $reply);

    return $reply->{WORKFLOW};
}


sub disconnect {

    my $self = shift;

    $self->logger()->info('Disconnect client');
    my $reply = $self->client->send_receive_service_msg('LOGOUT');

    $self->_clear_client();
    return $self;
}

sub __reinit_session {

    my $self = shift;
    my $client = shift;

    my $session = $self->session();
    if (!$session) {
        die "Can not reinit backend session without frontend session!";
    }

    my $old_session =  $session->param('backend_session_id') || undef;
    $self->logger()->info('old backend session ' . $old_session) if ($old_session);

    # Fetch errors on session init
    eval {
        $client->init_session({ SESSION_ID => $old_session });
    };
    if (my $eval_err = $EVAL_ERROR) {
        my $exc = OpenXPKI::Exception->caught();
        if ($exc && $exc->message() eq 'I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED') {
            # The session has gone - start a new one - might happen if the client was idle too long
            $client->init_session({ SESSION_ID => undef });
            $self->logger()->info('Backend session was gone - start a new one');
        } else {
            $self->logger()->error('Error creating backend session: ' . $eval_err->{message});
            $self->logger()->trace($eval_err);
            die "Backend communication problem";
        }
    }

    my $client_session = $client->get_session_id();
    # logging stuff only
    if ($old_session && $client_session eq $old_session) {
        $self->logger()->info('Resume backend session with id ' . $client_session);
    } elsif ($old_session) {
        $self->logger()->info('Re-Init backend session ' . $client_session . ' / ' . $old_session );
    } else {
        $self->logger()->info('New backend session with id ' . $client_session);
    }
    $session->param('backend_session_id', $client_session);
    $self->logger()->trace( Dumper $session );

    return $self;

}

1;

__END__

