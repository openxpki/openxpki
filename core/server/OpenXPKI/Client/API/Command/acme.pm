package OpenXPKI::Client::API::Command::acme;
use OpenXPKI -role;

with 'Connector::Role::SSLUserAgent';

# Core modules
use JSON;
use Data::Dumper;
use List::Util qw( none );

has LOCATION => (
    is => 'rw',
    isa => 'Str',
);

has directory => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_load_directory',
);

sub _load_directory {
    my $self = shift;
    my $ua = $self->agent();
    my $response = $ua->get($self->LOCATION());
    die 'Unable to contact ACME server' unless ($response->is_success);
    die 'Unable to parse directory' unless($response->header('content_type') =~ m{application/json});
    return decode_json($response->decoded_content);
}


=head1 NAME

OpenXPKI::CLI::Command::acme

=head1 DESCRIPTION

Handle account registrations for the NICE ACME backend.

B<NOTE>: This manages the account key in situations where OpenXPKI is
used as ACME client to enroll certficates with an external CA. To
manage the ACME clients enrolling against OpenXPKI you have to use the
ACME client registration process via the endpoints and workflows.

=cut

sub nonce {
    my $self = shift;
    return $self->agent->get($self->directory()->{newNonce})->header('replay-nonce');
}

1;
