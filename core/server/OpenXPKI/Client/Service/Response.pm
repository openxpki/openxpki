package OpenXPKI::Client::Service::Response;
use Moose;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::i18n qw(i18nGettext);
use OpenXPKI::Server::Context qw( CTX );

## constructor and destructor stuff

has error => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_error',
    clearer => 'clear_error',
    lazy => 1,
    default => 0,
);

has __error_message => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_error_message',
    clearer => 'clear_error_message',
    init_arg  => 'error_message',
);

has retry_after => (
    is => 'ro',
    isa => 'Int',
    predicate => 'is_pending',
    lazy => 1,
    default => 0,
);

has workflow => (
    is => 'rw',
    isa => 'HashRef',
    predicate => 'has_workflow',
    default => sub { return {}; }
);

has extra_headers => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    builder => '__build_extra_headers',
);

has result => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => '',
);

has transaction_id => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->workflow->{context}->{transaction_id} // '';
    },
);

# Use predefined numeric codes for dedicated problems
our %named_messages = (
    '40001' => 'Signature invalid',
    '40002' => 'Unable to parse request',
    '40003' => 'Incoming enrollment with empty body',
    '40004' => 'Missing or invalid parameters',
    '40006' => 'Request was rejected',
    '50001' => 'Unable to initialize client',
    '50003' => 'Unexpected response from backend',
    '50011' => 'Unable to initialize endpoint parameters',
);

# this allows a constructor with the error code as scalar
around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;

    my $args = shift;
    if (!ref $args) {
        $args = { error => $args };
    }

    return $class->$orig( $args );

};

sub __build_extra_headers {

    my $self = shift;
    return {} unless($self->has_workflow());

    my $workflow = $self->workflow();
    my $extra_header = {};
    if ($workflow->{id}) {
        $extra_header->{'X-OpenXPKI-Workflow-Id'} = $workflow->{id};
    }
    if (my $tid = $self->transaction_id()) {
        # this should usually be a hexadecimal string but to avoid any surprise
        # we check this here and encoded if needed.
        $tid = Encode::encode("MIME-B", $tid) if ($tid =~ m{\W});
        $extra_header->{'X-OpenXPKI-Transaction-Id'} = $tid;
    }
    if (my $error = $workflow->{context}->{error_code}) {
        # header must not be any longer than 76 chars in total
        $error = substr(i18nGettext($error),0,64);
        # use mime encode if header is non-us-ascii, 42 chars plus tags is the
        # maximum to stay below 76 chars (starts to wrap otherwise)
        $error = Encode::encode("MIME-B", substr($error,0,42)) if ($error =~ m{\W});
        $extra_header->{'X-OpenXPKI-Error'} = $error;
    }
    return $extra_header;
}


sub http_status_code {
    my $self = shift;
    return '202' if ($self->is_pending());
    return '200' unless ($self->has_error());
    return substr($self->error(),0,3) || '500';
}

sub http_status_line {

    my $self = shift;
    if ($self->is_pending()) {
        return sprintf('202 Request Pending - Retry Later (%s)', $self->transaction_id());
    }

    if ($self->has_error()) {
        my $err = $self->http_status_code();
        if (my $msg = $OpenXPKI::Client::Service::Response::named_messages{$self->error()}) {
            $err .= ' '.$msg;
        } else {
            $err .= ' Other Error ' . $self->error();
        }
        return $err;
    }

    return '200 OK';
}

sub error_message {

    my $self = shift;
    return '' unless ($self->has_error());

    return i18nGettext($self->__error_message()) if ($self->has_error_message());

    return $OpenXPKI::Client::Service::Response::named_messages{$self->error()}
        || 'Unknown error';

}

sub is_server_error {

    my $self = shift;
    return 0 unless ($self->has_error());
    my $err = $self->error();
    return 0 unless ($err >= 50000);
    return $err;

}

sub is_client_error {

    my $self = shift;
    return 0 unless ($self->has_error());
    my $err = $self->error();
    return 0 unless ($err >= 40000 && $err < 50000);
    return $err;

}

__PACKAGE__->meta->make_immutable;

 __END__;

=head1 NAME

OpenXPKI::Client::Service::Response
