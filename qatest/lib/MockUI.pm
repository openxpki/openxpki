package MockUI;

use Moose;
use namespace::autoclean;

extends 'OpenXPKI::Client::UI';

use JSON;
use CGIMock;
use CGI::Session;
use OpenXPKI::Client::UI::Request;


has cgi => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    default => sub { return CGIMock->new },
);

has json => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    default => sub { return JSON->new->utf8 },
);

has wf_token => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => '',
);

has rtoken => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => '',
);


sub mock_json_request {
    my ($self, $data) = @_;

    $self->cgi->content_type('application/json');
    $self->cgi->data({ POSTDATA => $self->json->encode($self->__insert_token($data)) });

    return $self->__request;
}

sub mock_request {
    my ($self, $data) = @_;

    $self->cgi->content_type('application/x-www-form-urlencoded');
    $self->cgi->data($self->__insert_token($data));

    return $self->__request;
}

sub __insert_token {
    my ($self, $data) = @_;

    my %result = %$data;
    $result{wf_token} = $self->wf_token if (exists $data->{wf_token} and not $data->{wf_token});
    $result{_rtoken} = $self->rtoken unless exists $data->{_rtoken};

    return \%result;
}

sub __request {
    my $self = shift;

    my($out);
    local *STDOUT;
    open(STDOUT, '>', \$out);

    my $result = $self->handle_request(
        OpenXPKI::Client::UI::Request->new(
            cgi => $self->cgi,
            session => $self->session,
            logger => $self->log,
        )
    );
    $result->render;
    my $json = $self->json->decode($out);

    if (ref $json->{main} and my $fields = $json->{main}->[0]->{content}->{fields}) {
        $self->wf_token($_->{value}) for grep { $_->{name} eq 'wf_token' } @$fields;
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

    my $session = CGI::Session->new(undef, undef, {Directory=>'/tmp'});

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


__PACKAGE__->meta->make_immutable;
