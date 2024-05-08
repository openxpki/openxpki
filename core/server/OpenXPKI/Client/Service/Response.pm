package OpenXPKI::Client::Service::Response;
use OpenXPKI qw( -class -typeconstraints );

# CPAN modules
use Mojo::Message::Response;

# Project modules
use OpenXPKI::i18n qw(i18nGettext);
use OpenXPKI::Server::Context qw( CTX );

# Use predefined numeric codes for dedicated problems
our %named_messages = (
    #
    # Client errors
    #
    40000 => 'Bad Request',
    40001 => 'Signature invalid',
    40002 => 'Unable to parse request',
    40003 => 'Request body is empty',
    40004 => 'Missing or invalid parameters',
    40005 => 'No result for given pickup parameters',
    40006 => 'Request was rejected',
    40007 => 'Unknown operation',
    40008 => 'No operation specified',
    # RPC
    40080 => 'No method set in request',
    40081 => 'Decoding of JSON encoded POST data failed',
    40083 => 'RAW post not allowed (no method set in request)',
    40084 => 'RAW post with unknown content type',
    40087 => 'Content type JOSE not enabled',
    40088 => 'Processing JWS protected payload failed',
    40089 => 'Method header is missing in JWS',
    40090 => 'Unsupported JWS algorithm',
    40091 => 'Content type pkcs7 not enabled',

    40100 => 'Unauthorized',
    40101 => 'Authentication credentials missing or incorrect',

    40300 => 'HTTPS required',

    40400 => 'Not Found',
    40401 => 'Not Found (Empty request endpoint and no default server set)',
    # RPC
    40480 => 'Invalid method / setup incomplete',
    40481 => 'Resume requested but no workflow found',
    40482 => 'Resume requested but workflow is not in manual state',
    40483 => 'Resume requested but expected workflow action not available',

    #
    # Server errors
    #
    50000 => 'Server error',
    50001 => 'Unable to fetch configuration from server - connect failed',
    50002 => 'Unable to initialize client',
    50003 => 'Unexpected response from backend',
    50005 => 'ENV variable "server" and servername are both set but are mutually exclusive',
    50006 => 'ENV variable "server" requested but RPC endpoint could not be determined from URL',
    50007 => 'Requested RPC endpoint is not configured properly',
    50010 => 'Unable to initialize endpoint parameters',
    # RPC
    50080 => 'Could not unwrap PKCS#7 contents',
    50082 => 'Unable to query OpenAPI specification from OpenXPKI server',

    50100 => 'Operation not implemented',
);

=head1 NAME

OpenXPKI::Client::Service::Response - Protocol independent service response encapsulation

=head1 SYNOPSIS

    return OpenXPKI::Client::Service::Response->new(
        result => $res,
    );

Response incl. workflow details:

    return OpenXPKI::Client::Service::Response->new(
        result => "...PEM...",
        workflow => $workflow,
    );

Error response:

    die OpenXPKI::Client::Service::Response->new_error( 50002 );

Error response with custom error message:

    die OpenXPKI::Client::Service::Response->new_error(
        400 => 'urn:ietf:params:acme:error:alreadyRevoked'
    );

    # ...is a shortcut for the longer version:
    die OpenXPKI::Client::Service::Response->new(
        error => 400,
        error_message => 'urn:ietf:params:acme:error:alreadyRevoked',
    );

=head1 ATTRIBUTES

=head2 result

Service specific result I<Str> or I<HashRef>.

    OpenXPKI::Client::Service::Response->new(
        result => json_encode(...),
    );

=cut
has result => (
    is => 'rw',
    isa => 'Str|HashRef',
    lazy => 1,
    default => '',
    predicate => 'has_result',
);

=head2 extra_headers

Extra HTTP headers to be added (I<HashRef>).

    OpenXPKI::Client::Service::Response->new(
        ...
        extra_headers => {
            'content-type' => 'application/x-pem-file',
        },
    );

=cut
has extra_headers => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
);

=head2 error

Either an internal 5-digit or an official 3-digit HTTP status error code I<Str>.

Internally all codes are represented as 5-digit codes, so 3-digit codes will be
filled up with trailing zeros:

    my $r = OpenXPKI::Client::Service::Response->new(error => 403);
    say $r->error;
    # 40300

There is a shortcut constructor L</new_error> to define error responses.

=cut
subtype 'OpenXPKI::Client::Service::Response::error',
    as 'Int',
    where { $_ >= 10000 and $_ <= 59999 };

# Fill up short (3-digit) error codes with trailing zeros
coerce 'OpenXPKI::Client::Service::Response::error',
    from 'Str',
    via { 0 + ($_. '0' x (5 - length $_)) };

has error => (
    is => 'rw',
    isa => 'OpenXPKI::Client::Service::Response::error',
    coerce => 1,
    predicate => 'has_error',
    clearer => 'clear_error',
    lazy => 1,
    default => 0,
);

=head2 error_details

Error details I<HashRef>.

=cut
has error_details => (
    is => 'rw',
    isa => 'HashRef',
    traits => ['Hash'],
    handles => {
        'has_error_details' => 'count',
    },
    lazy => 1,
    default => sub { {} },
);

=head2 custom_error_message

Error message. Only used if L</error> has been set.

Will be set automatically if L</workflow> was set and its context contains
the C<error_code> item.

=cut
# Please not there is a method error_message() below
has custom_error_message => (
    is => 'rw',
    isa => 'Str',
    init_arg  => 'error_message',
    predicate => 'has_custom_error_message',
);

=head2 retry_after

Timeout indicator for the HTTP client to retry the request (I<Int>, seconds).

=cut
has retry_after => (
    is => 'ro',
    isa => 'Int',
    predicate => 'is_pending',
    lazy => 1,
    default => 0,
);

=head2 workflow

Workflow info I<HashRef> as returned by
L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info/get_workflow_info>.

Setting this attribute also sets L</state>, L</proc_state> and
L</error_message> according to the workflow informations.

=cut
has workflow => (
    is => 'rw',
    isa => 'HashRef',
    traits => ['Hash'],
    handles => {
        'has_workflow' => 'count',
    },
    lazy => 1,
    default => sub { {} },
    trigger => \&__process_workflow,
);
sub __process_workflow ($self, $workflow) {
    $self->state($workflow->{state}) if $workflow->{state};
    $self->proc_state($workflow->{proc_state}) if $workflow->{proc_state};
    $self->transaction_id($workflow->{context}->{transaction_id}) if $workflow->{context}->{transaction_id};
    $self->custom_error_message($workflow->{context}->{error_code}) if $workflow->{context}->{error_code};
}

=head2 http_status_code

HTTP status code I<Str>.

If not explicitely set it defaults to:

=over

=item * C<202> if L</retry_after> was set,

=item * the first 3 digits if L</error> if set,

=item * C<200> otherwise.

=back

=cut
has http_status_code => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    builder => '__build_http_status_code',
);
sub __build_http_status_code ($self) {
    # Pending request
    return '202' if $self->is_pending;
    # Error
    return substr($self->error,0,3) if $self->has_error;
    # Default
    return '200';
}

=head2 http_status_message

HTTP status message I<Str>.

If not explicitely set it defaults to:

=over

=item * C<"Request Pending - Retry Later (TRANSACTION_ID)"> if L</retry_after> was set,

=item * L</error_message> if L</error> if set,

=item * the default HTTP status message for the current L</http_status_code> otherwise.

=back

=cut
has http_status_message => (
    is => 'ro',
    isa => 'Str|Undef',
    lazy => 1,
    builder => '__build_http_status_message',
);
sub __build_http_status_message ($self) {
    # Pending request
    return 'Request Pending - Retry Later' . ($self->has_transaction_id ? sprintf(' (%s)',  $self->transaction_id) : '') if $self->is_pending;
    # Error
    return $self->error_message if $self->has_error;
    # Default
    return Mojo::Message::Response->default_message($self->http_status_code);
}

=head2 http_status_line

Readonly HTTP status line I<Str>: C<"STATUS_CODE STATUS_MESSAGE">.

=cut
has http_status_line => (
    is => 'ro',
    isa => 'Str',
    init_arg => undef,
    lazy => 1,
    builder => '__build_http_status_line',
);
sub __build_http_status_line ($self) {
    return sprintf(
        "%03d %s",
        $self->http_status_code,
        $self->http_status_message,
    );
}

=head2 state

Readonly workflow C<state> I<Str>, automatically set if L</workflow> was set.

=cut
has state => ( ## --> better __state and is_state($s) which will also test $self->has_state ??!
    is => 'rw',
    isa => 'Str',
    init_arg => undef,
    trigger => sub { die '"state" can only be set once' if scalar @_ > 2 },
    predicate => 'has_state',
);

=head2 proc_state

Readonly workflow C<proc_state> I<Str>, automatically set if L</workflow> was set.

=cut
has proc_state => (
    is => 'rw',
    isa => 'Str',
    init_arg => undef,
    trigger => sub { die '"proc_state" can only be set once' if scalar @_ > 2 },
    predicate => 'has_proc_state',
);

# Workflow transaction ID, set automatically if "workflow" was set and
# its context contains the "transaction_id" item.
has transaction_id => (
    is => 'rw',
    isa => 'Str',
    init_arg => undef,
    trigger => sub { die '"transaction_id" can only be set once' if scalar @_ > 2 },
    predicate => 'has_transaction_id',
);


# this allows a constructor with the error code as scalar
around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;

    return $class->$orig( error => $_[0] ) if (@_ == 1 and not ref $_[0]);
    return $class->$orig( @_ );

};

=head1 METHODS

=head2 new_error

Alternate constructor to specify HTTP error codes and error messages.

    OpenXPKI::Client::Service::Response->new_error( 500 );
    # is equal to:
    OpenXPKI::Client::Service::Response->new(
        error => 500
    );

    OpenXPKI::Client::Service::Response->new_error( 500 => 'Something bad happened');
    # is equal to:
    OpenXPKI::Client::Service::Response->new(
        error => 500,
        error_message => 'Something bad happened',
    );

=cut
sub new_error ($class, @args) {
    die 'new_error() requires an error code' unless @args > 0;
    return $class->new(
        error => $args[0],
        defined $args[1] ? ( error_message => $args[1] ) : (),
    );
}

=head2 error_message

Returns the custom error message if set:

    my $r = OpenXPKI::Client::Service::Response->new_error( 500 => 'Something bad happened');
    say $r->error_message;
    # Server error: Something bad happened

...or a predefined message if a known internal error code was used:

    my $r = OpenXPKI::Client::Service::Response->new_error( 50002 );
    say $r->error_message;
    # Unable to initialize client

Returns the empty string if L</error> was not set.

=cut
sub error_message ($self) {
    return ''
      unless $self->has_error;

    my @msg;
    # general message
    my $general = $named_messages{$self->error};
    push @msg, $general if $general;
    # detailed message
    push @msg, i18nGettext($self->custom_error_message) if $self->has_custom_error_message;

    # generic fallback message
    @msg = sprintf('Unknown error (%s)', $self->error) unless scalar @msg;

    return join ': ', @msg;
}

=head2 is_server_error

Returns C<1> if L</error> was set to C<5xxxx> or C<5xx> or C<0> otherwise.

=cut
sub is_server_error ($self) {
    return 0 unless $self->has_error;
    return $self->error >= 50000 ? 1 : 0;
}

=head2 is_client_error

Returns C<1> if L</error> was set to C<5xxxx> or C<5xx> or C<0> otherwise.

=cut
sub is_client_error ($self) {
    return 0 unless $self->has_error;
    return ($self->error >= 40000 and $self->error < 50000) ? 1 : 0;
}

=head2 is_state

Returns C<1> if the workflow is in the given C<state>, C<0> otherwise (also if there is no C<state> information).

Does a case insensitive string comparison.

=cut
sub is_state ($self, $state) {
    return 0 unless $self->has_state;
    return 0 unless lc($self->state) eq lc($state);
    return 1;
}

=head2 is_proc_state

Returns C<1> if the workflow is in the given C<proc_state>, C<0> otherwise (also if there is no C<proc_state> information).

Does a case insensitive string comparison.

=cut
sub is_proc_state ($self, $proc_state) {
    return 0 unless $self->proc_has_state;
    return 0 unless lc($self->proc_state) eq lc($proc_state);
    return 1;
}

=head2 add_debug_headers

Adds some debugging HTTP headers from workflow information if L</workflow> was previously set.

=cut
sub add_debug_headers ($self) {
    my $workflow = $self->workflow or return;

    if ($workflow->{id}) {
        $self->extra_headers->{'X-OpenXPKI-Workflow-Id'} = $workflow->{id};
    }
    if ($self->has_transaction_id) {
        my $tid = $self->transaction_id;
        # this should usually be a hexadecimal string but to avoid any surprise
        # we check this here and encoded if needed.
        $tid = Encode::encode("MIME-B", $tid) if $tid =~ m{\W};
        $self->extra_headers->{'X-OpenXPKI-Transaction-Id'} = $tid;
    }
    if (my $error = $workflow->{context}->{error_code}) {
        # header must not be any longer than 76 chars in total
        $error = substr(i18nGettext($error),0,64);
        # use mime encode if header is non-us-ascii, 42 chars plus tags is the
        # maximum to stay below 76 chars (starts to wrap otherwise)
        $error = Encode::encode("MIME-B", substr($error,0,42)) if $error =~ m{\W};
        $self->extra_headers->{'X-OpenXPKI-Error'} = $error;
    }
}

__PACKAGE__->meta->make_immutable;

 __END__;
