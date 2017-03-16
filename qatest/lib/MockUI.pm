package MockUI;
use Moose;
use JSON;
use CGIMock;
use CGI::Session;

extends 'OpenXPKI::Client::UI';

has 'cgi' => (
    is => 'rw',
    isa => 'Object',
    default =>  sub { return CGIMock->new({ data => {  }}); }
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

has rtoken => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => ''
);

sub mock_request {

    my $self = shift;
    my $data = shift;

    if (exists $data->{wf_token} && !$data->{wf_token}) {
        $data->{wf_token} = $self->wf_token();
    }
   
    if (!exists $data->{_rtoken}) {
        $data->{_rtoken} = $self->rtoken();
    }

    $self->cgi->data( $data );

    my($out);
    local *STDOUT;
    open(STDOUT, '>', \$out);

    $self->handle_request( { cgi => $self->cgi } );
    my $json = $self->json()->decode($out);

    if (ref $json->{main} && $json->{main}->[0]->{content}->{fields}) {
        map {  $self->wf_token($_->{value}) if ($_->{name} eq 'wf_token') } @{$json->{main}->[0]->{content}->{fields}};
    }

    return $json;
}

sub update_rtoken {

    my $self = shift;    
    my $result = $self->mock_request({'page' => 'bootstrap!structure'});
    my $rtoken = $result->{rtoken};
    $self->rtoken( $rtoken );
    return $rtoken;
    
}

# Static call that generates a ready-to-use client
sub factory {

    my $log = Log::Log4perl->get_logger();

    my $session = new CGI::Session(undef, undef, {Directory=>'/tmp'});

    my $client = MockUI->new({
        session => $session,
        logger => $log,
        config => { socket => '/var/openxpki/openxpki.socket' }
    });
    
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
    
    $client->update_rtoken();
    
    return $client;
}


1;
