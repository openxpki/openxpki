
=head1 OpenXPKI::Client::Simple

An easy to use class to connect to the openxpki daemon and run commands
Designed as a kind of CLI interface for inline use within scripts. By
default, it will not handle sessions and create a new session using the
given auth info on each new instance (subsequent commands within one call
are run on the same session). If you pass (and maintain) a session object to
the constructor, it is used to persist the backend session during requests.

=head2 Construction

The client is constructed calling the new method, the required configuration
can be set via one of three options:

=head3 Explicit Config

Pass the configuration as hash to the new method, must set at least
I<config.socket> and I<config.realm> (omit if server has only one realm).

The default authentication is anonymous but can be overidden by setting
I<auth.stack> and appropriate keys for the chosen login method.

An instance of Log4perl can be passed via I<logger>, default is to log to
STDERR with loglevel error.

=head3 Explicit Config from File

Pass the name of the config file to use as string to the new method, the
file must be in the standard config ini format and have at least a section
I<global> providing I<socket> and I<realm>.

If an I<auth> section exists, it is mapped as is to the I<auth> parameter.

You can set a loglevel and logfile location using I<log.file> and
I<log.level>. Loglevel must be a Log4perl Level name without the leading
dollar sign (e.g. level=DEBUG).

=head3 Implicit Config from File

If you do not pass a I<config> argument to the new method, the class tries
to find a config file at

=over

=item string set in the environment OPENXPKI_CLIENT_CONF

=item $HOME/.openxpki.conf

=item /etc/openxpki/client.conf

=back

The same rules as above apply, in case you pass auth or logger as explicit
arguments the settings in the file are ignored.

=cut

package OpenXPKI::Client::Simple;

use strict;
use warnings;
use English;
use POSIX qw( strftime );
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Config::Std;
use File::Spec;
use OpenXPKI::Client;
use OpenXPKI::Serialization::Simple;
use Log::Log4perl qw(:easy :levels);
use Log::Log4perl::Level;


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
    is => 'ro',
    isa => 'HashRef',
    init_arg => 'config',
    required => 1,
);


has 'realm' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default  => sub { my $self = shift; return $self->_config()->{'realm'} }
);

has 'socket' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default  => sub { my $self = shift; return $self->_config()->{'socket'} }
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


around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;
    my $args = shift;

    # Called with a scalar = use as config file name
    my $file;
    if ($args && !ref $args) {
        die "Given config file does not exist or is not readable!" unless (-e $args && -r $args);
        $file = $args;
        $args = {};

    } elsif (!$args || !$args->{config}) {
        $file = '/etc/openxpki/client.conf';
        if ($ENV{OPENXPKI_CLIENT_CONF}) {
            $file = $ENV{OPENXPKI_CLIENT_CONF};
            die "OPENXPKI_CLIENT_CONF is set but files does not exist or is not readable!" unless (-e $file && -r $file);

        } elsif ($ENV{HOME} && -d $ENV{HOME} && -r $ENV{HOME}) {

            my $path = File::Spec->canonpath( $ENV{HOME} );
            my $cand = File::Spec->catdir( ( $path, '.openxpki.conf' ) );
            $file = $cand if (-e $cand && -r $cand);

        }

        if (!-r $file ) {
            OpenXPKI::Client::Simple::_build_logger()->fatal("Unable to open configuration file $file");
            die "Unable to open configuration file $file";
        }
    }

    if ($file) {
        my $conf;
        if (!read_config( $file => $conf )) {
            OpenXPKI::Client::Simple::_build_logger()->fatal("Unable to read configuration file $file");
            die "Unable to read configuration file $file";
        }

        $args->{config} = $conf->{global};

        if ($conf->{auth} && !$args->{auth}) {
            $args->{auth} = $conf->{auth};
        }

        if ($conf->{log} && !$args->{logger}) {
            my $level = Log::Log4perl::Level::to_priority( uc( $conf->{log}->{level} || 'ERROR' ));
            if ($conf->{log}->{file}) {
                Log::Log4perl->easy_init( { level   => $level,
                    file  => ">>" . $conf->{log}->{file} } );
            } else {
                Log::Log4perl->easy_init($level);
            }
            $args->{logger} = Log::Log4perl->get_logger();
        }

        if ($args->{logger}) {
            $args->{logger}->trace('Config read from file ' . $file);
        }

        return $class->$orig($args);
    } else {

        return $class->$orig($args);
    }

};

sub _build_client {

    my $self = shift;

    my $client = OpenXPKI::Client->new({
        SOCKETFILE => $self->socket(),
    });

    if (! defined $client) {
        die "Could not instantiate OpenXPKI client. Stopped";
    }

    my $log = $self->logger();

    $log->debug("Initialize client");

    my $reply;
    # if we have a frontend session object, we also create a backend session
    if ($self->session()) {
        $reply = $self->__reinit_session( $client );

    # Init a fresh backend session
    } else {

        $reply = $client->init_session();
        if (!$reply) {
            die "Could not initiate OpenXPKI server session. Stopped";
        }
        $log->debug("Started volatile session with id: " . $client->get_session_id() );
    }

    # this should not happen
    $reply = $client->send_receive_service_msg('PING') unless($reply);
    $self->last_reply( $reply );

    if ($reply->{SERVICE_MSG} eq 'GET_PKI_REALM') {
        my $realm = $self->realm();
        if (! $realm ) {
            $log->fatal("Found more than one realm but no realm is specified");
            $log->trace("Realms found:" . Dumper (keys %{$reply->{PARAMS}->{PKI_REALMS}}));
            die "No realm specified";
        }
        $log->debug("Selecting realm $realm");
        my $auth = $self->auth();
        $reply = $client->send_receive_service_msg('GET_PKI_REALM',{
            PKI_REALM => $realm,
            (!ref $auth->{stack} ? (AUTHENTICATION_STACK => $auth->{stack}) : ()),
        });
        $self->last_reply( $reply );
    }

    if ($reply->{SERVICE_MSG} eq 'GET_AUTHENTICATION_STACK') {
        my $auth = $self->auth();

        my $auth_stack;
        # Option 1: No Auth stack in config - we are screwed
        if (!$auth->{stack}) {
            $log->fatal("Found more than one auth stack but no stack is specified");
            $log->trace("Stacks found:" . join(" ", keys %{$reply->{PARAMS}->{AUTHENTICATION_STACKS}}));
            die "No auth stack specified";

        }

        # Option 2: Single Auth stack in config - take it
        if (!ref $auth->{stack}) {
            $auth_stack = $auth->{stack};

        # Option 3: Mutliple Auth stacks in config
        # check type against current env for prereqs
        # Those are currently hardcoded:
        # type "sso" requires OPENXPKI_USER or REMOTE_USER in ENV
        # type "x509" requires SSL_CLIENT_CERT
        # type "passwd" is always selected
        } else {
            my $stacks = $reply->{PARAMS}->{AUTHENTICATION_STACKS};
            foreach my $stack (@{$auth->{stack}}) {
                if (!$stacks->{$stack}) {
                    $log->debug("Auth stack $stack in config is not offered by server");
                    next;
                }
                my $stack_type = $stacks->{$stack}->{type} || 'passwd';
                if ($stack_type eq 'passwd') {
                    $log->debug("Selecting $stack / passwd");
                    $auth_stack = $stack;
                    last;
                } elsif ($stack_type eq 'client') {
                    if (!$ENV{REMOTE_USER} && !$ENV{'OPENXPKI_USER'}) {
                        $log->debug("Skipping $stack / client");
                        next;
                    }
                    $log->debug("Selecting $stack / client");
                    $auth_stack = $stack;
                    last;
                } elsif ($stack_type eq 'x509') {
                    if (!$ENV{SSL_CLIENT_CERT}) {
                        $log->debug("Skipping $stack / x509");
                        next;
                    }
                    $log->debug("Selecting $stack / x509");
                    $auth_stack = $stack;
                    last;
                } else {
                    $log->debug("Skipping $stack / unknown type $stack_type");
                }
            }
            # failed to select a stack (might be better to use the first or last one as a default?)
            if (!$auth_stack) {
                $log->fatal("Mutliple auth stacks given but none matches the prepreqs");
                die "No auth stack could be selected specified";
            }
        }

        $log->debug("Selecting auth stack ". $auth_stack);
        # we send the stack without params which will either return a session
        # for anonymous stacks or the required parameter list.

        $reply = $client->send_receive_service_msg('GET_AUTHENTICATION_STACK',{
            AUTHENTICATION_STACK => $auth_stack,
        });
        $self->last_reply( $reply );
        $log->trace("Auth stack request ". Dumper $reply) if $log->is_trace;
    }

    # FIXME / TODO - most of this code is duplicated in the WebUI Login code
    if ($reply->{SERVICE_MSG} =~ /GET_(.*)_LOGIN/) {
        my $login_type = $1;

        my $auth = $reply->{PARAMS};
        my $data;
        # no configuration defined yet
        if ($login_type eq 'X509') {
            $data->{certificate} = $ENV{SSL_CLIENT_CERT};
            my @chain;
            # larger chains are very unlikely and we dont support stupid clients
            for (my $cc=0;$cc<=3;$cc++)   {
                my $chaincert = $ENV{'SSL_CLIENT_CERT_CHAIN_'.$cc};
                last unless ($chaincert);
                push @chain, $chaincert;
            }
            $data->{chain} = \@chain if(@chain);

        } elsif ($login_type eq 'CLIENT') {
            $self->logger()->trace('ENV is ' . Dumper \%ENV) if $self->logger->is_trace;
            # we reuse the defaults for the old SSO handler from the UI

            if ($auth->{envkeys}) {
                foreach my $key (keys %{$auth->{envkeys}}) {
                    my $envkey = $auth->{envkeys}->{$key};
                    $self->logger()->debug("Try to load $key from $envkey");
                    next unless defined ($ENV{$envkey});
                    $data->{$key} = $ENV{$envkey};
                }
            # legacy support
            } elsif (my $user = $ENV{'OPENXPKI_USER'} || $ENV{'REMOTE_USER'} || '') {
                $data->{username} = $user;
                $data->{role} = $ENV{'OPENXPKI_GROUP'} if($ENV{'OPENXPKI_GROUP'});
            }

        } elsif($login_type eq 'PASSWD') {

            # just add any parameters except stack
            $data = { %{$self->auth()} };
            delete $data->{stack};

        } else {
            $log->error("Unsupported login scheme: $login_type");
            die "Unsupported login scheme: $login_type. Stopped";
        }

        $data = $self->__jwt_signature($data, $reply->{SIGN}) if ($reply->{SIGN});

        $log->trace("Auth data ". Dumper $data) if $log->is_trace;
        $reply = $client->send_receive_service_msg('GET_'.$login_type.'_LOGIN', $data );
        $self->last_reply( $reply );
    }

    if ($reply->{SERVICE_MSG} ne 'SERVICE_READY') {
        $log->fatal("Initialization failed - message is " . $reply->{SERVICE_MSG});
        $log->trace('Last reply: ' .Dumper $reply) if $log->is_trace;
        die "Initialization failed. Stopped";
    }
    return $client;
}


sub __jwt_signature {

    my $self = shift;
    my $payload = shift;
    my $jws = shift;

    my $auth = $self->auth();
    return unless($auth->{'sign.key'});
    $self->logger()->debug('Sign data using key id ' . $jws->{keyid} );
    my $pkey = decode_base64($auth->{'sign.key'});
    return encode_jwt(payload => $payload, key=> \$pkey, alg=>'ES256');

}


sub run_legacy_command {
    my $self = shift;
    my $command = shift;
    die "run_legacy_command is no longer supported (command $command)";
}

sub run_command {

    my $self = shift;
    my $command = shift;
    my $params = shift || {};
    my $api = shift || 2;

    die "run_command must be called with API version 2 ($command / $api)" if ($api != 2);

    my $reply = $self->client()->send_receive_service_msg('COMMAND', {
        COMMAND => $command,
        PARAMS => $params,
        API => $api
    });

    $self->last_reply( $reply );
    if ($reply->{SERVICE_MSG} ne 'COMMAND') {
        my $message;
        if (my $err = $reply->{'ERROR'}) {
            if ($err->{PARAMS} && $err->{PARAMS}->{__ERROR__}) {
                $message = $err->{PARAMS}->{__ERROR__};
            } elsif($err->{LABEL}) {
                $message = $err->{LABEL};
            }
        } else {
            $message = 'unknown error';
        }
        $self->logger()->error($message);
        $self->logger()->trace(Dumper $reply) if $self->logger->is_trace;
        $self->last_error($message);
        die "Error running command: $message";
    }
    $self->last_error('');
    return $reply->{PARAMS};
}

=head2 handle_workflow

Combined method to interact with workflows. Action depends on the parameters
given. Return value is always the workflow info structure.

Legacy Mode: If arguments are passed with uppercase keys (ID, TYPE, ACTIVITY),
the return structure also contains uppercase keys. This is provided for
backward compatibility and will be removed with the next major release!

=over

=item id

Returns the workflow info for the existing workflow with given id.

=item activity

Only in combination with ID, executes the given action and returns the
workflow info after processing was done. Will die if execute fails.

=item type

Create a new workflow of given type, only effective if ID is not given.

=item params

Parameter hash to be passed to create/execute method as input values.

=back

=cut


sub handle_workflow {

    my $self = shift;
    my $params = shift;

    my $reply;
    # execute exisiting workflow

    my $wf_id = $params->{id};
    my $wf_action = $params->{activity};
    my $wf_type = $params->{type};
    my $wf_params = $params->{params};

    my $return_uppercase = 0;
    # legacy mode - uppercase arguments
    if ($params->{ID} || $params->{TYPE}) {
        $return_uppercase = 1;
        $wf_id = $params->{ID} || 0;
        $wf_action = $params->{ACTIVITY} || '';
        $wf_type = $params->{TYPE} || '';
        $wf_params = $params->{PARAMS};
    }

    if ($wf_action && $wf_id) {

        $self->logger()->info(sprintf('execute workflow action %s on %01d', $wf_action, $wf_id));
        $self->logger()->trace('workflow params:  '. Dumper $wf_params) if $self->logger->is_trace;
        $reply = $self->run_command('execute_workflow_activity',{
            id => $wf_id,
            activity => $wf_action,
            params => $wf_params,
        });

        if (!$reply || !$reply->{workflow}) {
            $self->logger()->fatal("No workflow object received after execute!");
            die "No workflow object received!";
        }

        $self->logger()->debug('new Workflow State: ' . $reply->{workflow}->{state});

    } elsif ($wf_id) {

        $self->logger()->debug(sprintf('request for workflow info on %01d', $wf_id));

        $reply = $self->run_command('get_workflow_info',{
            id => $wf_id,
        });

        if (!$reply || !$reply->{workflow}) {
            $self->logger()->fatal("No workflow object received after execute!");
            die "No workflow object received!";
        }

        $self->logger()->trace($reply->{workflow});

    } elsif ($wf_type) {
        $reply = $self->run_command('create_workflow_instance',{
            workflow => $wf_type,
            params => $wf_params,
            ($params->{use_lock} ? (use_lock => $params->{use_lock}) : ()),
        });

        if (!$reply || !$reply->{workflow}) {
            $self->logger()->fatal("No workflow object received after create!");
            die "No workflow object received!";
        }

        $self->logger()->debug(sprintf('Workflow created (ID: %d), State: %s',
            $reply->{workflow}->{id}, $reply->{workflow}->{state}));

    } else {
        $self->logger()->fatal("Neither workflow id nor type given");
        die "Neither workflow id nor type given";
    }

    $self->logger()->trace('Result of workflow action: ' . Dumper $reply) if $self->logger->is_trace;

    my $ret = $reply->{workflow};
    if ($return_uppercase) {
        my %ret = map { uc ($_) =>  $reply->{workflow}->{$_} } keys %{$reply->{workflow}};
        $ret = \%ret;
    }

    return $ret;
}

=head2 disconnect

Close the connection and detach from the communication socket.

=cut

sub disconnect {

    my $self = shift;

    $self->logger()->info('Disconnect client');

    # Use detach if an external session was provided
    # otherwise the session will be terminated!
    if ($self->session()) {
        $self->client->detach();
    } else {
        $self->client->logout();
    }

    $self->client->close_connection();

    $self->_clear_client();
    return $self;
}

=head2 __reinit_session

Try to reconnect an existing session. Returns the result of init_session
from the underlying client.

=cut

sub __reinit_session {

    my $self = shift;
    my $client = shift;

    my $session = $self->session();
    if (!$session) {
        die "Can not reinit backend session without frontend session!";
    }

    my $old_session =  $session->param('backend_session_id') || undef;
    $self->logger()->info('old backend session ' . $old_session) if ($old_session);

    my $reply;
    # Fetch errors on session init
    eval {
        $reply = $client->init_session({ SESSION_ID => $old_session });
    };
    if (my $eval_err = $EVAL_ERROR) {
        my $exc = OpenXPKI::Exception->caught();
        if ($exc && $exc->message() eq 'I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED') {
            # The session has gone - start a new one - might happen if the client was idle too long
            $reply = $client->init_session({ SESSION_ID => undef });
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
    $self->logger()->trace( Dumper $session ) if $self->logger->is_trace;

    return $reply;

}

1;

__END__

