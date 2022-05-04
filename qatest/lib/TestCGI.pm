package TestCGI;
use Moose;
use JSON;
use YAML;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use URI::Escape;
use LWP::UserAgent;
use IO::Socket::SSL qw( SSL_VERIFY_NONE );
use Test::More;
no warnings qw( redundant );

has config => (
    is => 'ro',
    isa => 'Str',
    default =>  sub {
        if ($ENV{OPENXPKI_TEST_CONFIG}) {
            return $ENV{OPENXPKI_TEST_CONFIG};
        }
        if (-e 'test.yaml') {
            return 'test.yaml';
        }
        if (-e '../test.yaml') {
            return '../test.yaml';
        }
        die "Unable to find test configuration file";
    },
);

has param => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '__load_config',
);

has json => (
    is => 'rw',
    isa => 'Object',
    default =>  sub { return JSON->new()->utf8; }
);

has wf_token => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => ''
);

has session_id => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => ''
);

has realm => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => ''
);

has rtoken => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => ''
);

has logger => (
    is => 'rw',
    isa => 'Object',
    default =>  sub { return  Log::Log4perl->get_logger(); }
);

has last_result => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { return { }; }
);

has ssl_opts => (
    is => 'rw',
    isa => 'HashRef|Undef',
);

sub __load_config {

    my $self = shift;
    my $config = YAML::LoadFile( $self->config() );

    if ($config->{ssl_opts} && ref $config->{ssl_opts} eq 'HASH' && !$self->ssl_opts()) {
        $self->ssl_opts( $config->{ssl_opts} );
    }

    if ($config->{realm} && !$self->realm()) {
        $self->realm($config->{realm}),
    }

    return $config;

}

sub update_rtoken {

    my $self = shift;
    my $result = $self->mock_request({'page' => 'bootstrap!structure'});
    my $rtoken = $result->{rtoken};
    $self->rtoken( $rtoken );
    return $rtoken;

}

sub mock_request {

    my $self = shift;
    my $data = shift;
    my $follow = shift || 0;

    if (exists $data->{wf_token} && !$data->{wf_token}) {
        $data->{wf_token} = $self->wf_token();
    }

    my $ua = LWP::UserAgent->new;

    my $p = $self->param();

    $ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

    my $server_endpoint = sprintf $p->{uri}->{webui}, $self->realm();

    my $ssl_opts = $self->ssl_opts;
    if ($ssl_opts) {
        $ua->ssl_opts( %{$ssl_opts} );
        $self->logger()->trace( 'Adding SSL Opts ' . Dumper $ssl_opts ) if $self->logger->is_trace;
    }

    $ua->default_header( 'Accept'       => 'application/json' );
    $ua->default_header( 'X-OPENXPKI-Client' => 1);

    if ($self->session_id()) {
        $ua->default_header( 'Cookie' => 'oxisess-webui='.$self->session_id() );
    }

    # always use POST for actions
    my $res;
    if ($data->{action}) {
        # add XSRF token
        if (!exists $data->{_rtoken}) {
            $data->{_rtoken} = $self->rtoken();
        }

        $self->logger()->trace( Dumper $data ) if $self->logger->is_trace;

        # strip off trailing array indicator and trim whitespace
        %{$data} = map {
            my ($kk) = ($_ =~ m{([^\[]+)(\[\])?\z});
            my $vv = $data->{$_} // '';
            $vv =~ s{\A\s+|\s+\z}{}xmsg unless (ref $vv);
            $kk => $vv;
        } keys %{$data};

        $res = $ua->request(HTTP::Request->new('POST', $server_endpoint,
            HTTP::Headers->new( Content_Type => 'application/json'),
            $self->json()->encode( $data )
        ));

    } else {
        my $qsa = '?';
        map { $qsa .= sprintf "%s=%s&", $_, uri_escape($data->{$_} // ''); } keys %{$data};
        $res = $ua->get( $server_endpoint.$qsa );
    }

    # Check the outcome of the response
    if (!$res->is_success) {
        warn $res->status_line;
        return {};
    }

    if ($res->header('Content-Type') !~ /application\/json/) {
        return $res->content;
    }

    if (my $cookie = $res->header('Set-Cookie')) {
        if ($cookie =~ /oxisess-webui=([^;]+);/) {
            $self->session_id($1);
        }
    }

    my $json = $self->json()->decode( $res->content );

    if ($json->{goto} && $follow) {
        $self->logger()->debug( 'Got redirect and follow is set: ' . $json->{goto} );
        return $self->mock_request({ page => $json->{goto} });
    }

    if (ref $json->{main} && $json->{main}->[0]->{content}->{fields}) {
        map {  $self->wf_token($_->{value}) if ($_->{name} eq 'wf_token') } @{$json->{main}->[0]->{content}->{fields}};
    }

    $self->last_result($json);
    return $json;
}

sub get_field_from_result {

    my $self = shift;
    my $field_name = shift;

    my $fields = eval { $self->last_result->{main}->[0]->{content}->{data} } // [];
    my ($field) = grep { ($_->{name} eq $field_name or $_->{label} eq $field_name) } @$fields;

    return unless $field;
    return $field->{value};
}


sub prefill_from_result {

    my $self = shift;
    my $use_placeholder = shift || 0;
    my $json = $self->last_result();
    if (!(ref $json->{main} && $json->{main}->[0]->{content}->{fields})) {
        return {};
    }

    my $data = {};
    foreach my $t (@{ $json->{main}->[0]->{content}->{fields} }) {
        my $k = $t->{name};
        next if ($k eq 'wf_token' || $k eq 'action');
        my $v = $t->{value};
        if ($use_placeholder && (!defined $v || $v eq '') && $t->{placeholder}) {
            $v = $t->{placeholder};
        }
        $data->{$k} = $v if (defined $v);
    }
    return $data;
}


sub fail_workflow {

    my $self = shift;
    my $workflow_id = shift;

    my $result = $self->mock_request({
        'page' => 'workflow!load!wf_id!' . $workflow_id
    });

    # force failure
    $result = $self->mock_request({
        'action' => $result->{right}->[0]->{content}->{buttons}->[0]->{action},
        'wf_token' => undef
    });

    return $result->{right}->[0]->{content}->{data}->[2]->{value};
}

# Submit and approve CSR. Returns cert ID if workflow was successful.
sub approve_csr {

    my $self = shift;
    my $wf_id = shift;

    # Submit
    $self->try_action('csr_submit');

    # Submit with policy violation
    $self->try_action('csr_enter_policy_violation_comment');

    # Enter comment
    if ($self->has_field('policy_comment')) {
        note "< policy violation: enter comment";
        $self->run_action('workflow', { 'policy_comment' => 'Testing', 'wf_token' => undef });
    }

    # Approve with policy violation
    if ($self->try_action('csr_approve_csr_with_comment')) {
        note "< policy violation: enter operator comment";
        $self->run_action('workflow', { 'operator_comment' => 'Testing' });
    }

    # Standard approval
    $self->try_action('csr_approve_csr');

    if ($self->last_result->{status} and $self->last_result->{status}->{level} eq 'success') {
        my $cert = $self->get_field_from_result('cert_identifier');
        my $cert_id = $cert ? $cert->{value} : undef;
        note "> certificate identifier: ". ($cert_id // '<undef>');
        return $cert_id;
    }

    return;
}

sub has_button_action {

    my $self = shift;
    my $action = shift;

    # main site action
    return $action if (eval { $self->last_result->{main}->[0]->{action} } // '') eq $action;

    # individual button
    my $buttons = $self->last_result->{main}->[0]->{content}->{buttons};
    my ($full_action) = grep { m/!wf_action!$action\b/ } map { $_->{action} // '' } @$buttons;
    return $full_action;
}

# Calls the first available action of the given list, passing the given parameters.
# Does nothing if no action was performed.
sub try_action {

    my $self = shift;
    my $actions = shift;
    my $params = shift;

    $actions = [ $actions ] unless ref $actions eq 'ARRAY';

    for my $action (@$actions) {
        my $full_action;

        # main site action
        $full_action = $action if ((eval { $self->last_result->{main}->[0]->{action} } // '') eq $action);

        # individual button
        if (!$full_action) {
            my $buttons = $self->last_result->{main}->[0]->{content}->{buttons};
            ($full_action) = grep { m/!wf_action!$action\b/ } map { $_->{action} // '' } @$buttons;
        }

        next unless $full_action;

        note "> calling action: $full_action";
        return $self->mock_request({
            'action' => $full_action,
            'wf_token' => $self->wf_token,
            %{ $params // {} },
        });
    }

    return;
}

# Calls the first available action of the given list, passing the given parameters.
# Throws an exception if no action was performed.
sub run_action {

    my $self = shift;
    my $actions = shift;
    my $params = shift;

    $actions = [ $actions ] unless ref $actions eq 'ARRAY';
    my $result = $self->try_action($actions, $params);

    die sprintf("None of the given action were available: %s\n%s", join(', ', @$actions), Dumper($self->last_result))
      unless $result;

    return $result;
}

sub has_field {

    my $self = shift;
    my $field = shift;

    my $fields = $self->last_result->{main}->[0]->{content}->{fields};
    return scalar grep { ($_->{name} // '') eq $field } @$fields;
}

# Static call that generates a ready-to-use client.
# Parameters:
# - I<Str> $realm
# - I<Bool> $user_raop: set to 0 to try login with basic user (no raop)
sub factory {

    my $realm = shift;
    my $user_raop = shift || 1;

    my $client = TestCGI->new(realm => $realm);
    my $result;

    $client->mock_request({});

    $client->update_rtoken();

    $result = $client ->mock_request({ page => 'login'});

    $client->run_action('login!stack', { 'auth_stack' => "Testing" });

    # try login with 'user' (docker-ee, Vagrant Box "develop") and 'alice' (community config)
    my @try_users = $user_raop ? [ 'raop' ] : [ 'user', 'alice' ];
    for my $user (@try_users) {
        $client->run_action('login!password', { 'username' => $user, 'password' => 'openxpki' });
        last if ($client->last_result->{goto} // '') eq 'redirect!welcome';
    }

    die "Login failed - no redirect to start page: ".Dumper($client->last_result)
      unless ($client->last_result->{goto} // '') eq 'redirect!welcome';

    # refetch new rtoken, also inits session via bootstrap
    $client->update_rtoken();

    return $client;
}


1;
