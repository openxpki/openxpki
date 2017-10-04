package TestCGI;
use Moose;
use JSON;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use URI::Escape;
use LWP::UserAgent;

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


sub update_rtoken {

    my $self = shift;
    my $result = $self->mock_request({'page' => 'bootstrap!structure'});
    my $rtoken = $result->{rtoken};
    $self->rtoken( $rtoken );
    return $rtoken;

}

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

sub mock_request {

    my $self = shift;
    my $data = shift;

    if (exists $data->{wf_token} && !$data->{wf_token}) {
        $data->{wf_token} = $self->wf_token();
    }

    my $ua = LWP::UserAgent->new;
    my $server_endpoint = 'http://localhost/cgi-bin/webui.fcgi';

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

        $self->logger()->is_trace() && $self->logger()->trace( Dumper $data );

        $ua->default_header( 'content-type' => 'application/x-www-form-urlencoded');
        $res = $ua->post($server_endpoint, $data);
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

    my $json = $self->json()->decode( $res->content );
    if (ref $json->{main} && $json->{main}->[0]->{content}->{fields}) {
        map {  $self->wf_token($_->{value}) if ($_->{name} eq 'wf_token') } @{$json->{main}->[0]->{content}->{fields}};
    }

    if (my $cookie = $res->header('Set-Cookie')) {
        if ($cookie =~ /oxisess-webui=([^;]+);/) {
            $self->session_id($1);
        }
    }

    return $json;
}

# Static call that generates a ready-to-use client
sub factory {

    my $client = TestCGI->new();

    $client->update_rtoken();

    $client ->mock_request({ page => 'login'});

    $client ->mock_request({
        'action' => 'login!stack',
        'auth_stack' => "Testing",
    });

    $client ->mock_request({
        'action' => 'login!password',
        'username' => 'raop',
        'password' => 'openxpki'
    });

    # refetch new rtoken, also inits session via bootstrap
    $client->update_rtoken();

    return $client;
}


1;
