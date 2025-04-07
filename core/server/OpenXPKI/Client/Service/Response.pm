package OpenXPKI::Client::Service::Response;
use OpenXPKI qw( -class -typeconstraints );

# CPAN modules
use Mojo::Message::Response;

# Project modules
use OpenXPKI::i18n qw( i18nGettext i18nTokenizer );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Log4perl;

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
    40009 => 'Invalid content type',
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
    50001 => 'Unable to connect to backend',
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

    die OpenXPKI::Client::Service::Response->new( 50002 );

Error response with custom error message:

    die OpenXPKI::Client::Service::Response->new(
        400 => 'urn:ietf:params:acme:error:alreadyRevoked'
    );

    # ...is a shortcut for the longer version:
    die OpenXPKI::Client::Service::Response->new(
        error => 400,
        error_message => 'urn:ietf:params:acme:error:alreadyRevoked',
    );

Error response with predefined plus custom error message:

    die OpenXPKI::Client::Service::Response->new( 50002 => 'We have had a problem' );

=head1 ATTRIBUTES

=head2 result

Service specific result I<Str>, I<HashRef> or I<Object>.

    OpenXPKI::Client::Service::Response->new(
        result => json_encode(...),
    );

=cut
has result => (
    is => 'rw',
    isa => 'Str|HashRef|Object',
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
    traits => ['Hash'],
    handles => {
        add_header => 'set',
    }
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
my $str_or_any = subtype as 'Str';
coerce $str_or_any, from 'Any', via { "$_" };
has custom_error_message => (
    is => 'rw',
    isa => $str_or_any,
    coerce => 1,
    init_arg  => 'error_message',
    predicate => 'has_custom_error_message',
    clearer => 'clear_custom_error_message',
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

Workflow info I<HashRef>. Equals the item C<workflow> in the I<HashRef> returned by
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

=head2 redirect_url

Extra HTTP headers to be added (I<HashRef>).

    OpenXPKI::Client::Service::Response->new(
        ...
        redirect_url => 'https://www.openxpki.org',
    );

=cut
has redirect_url => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
    traits => ['Hash'],
    predicate => 'is_redirect',
);

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

=head2 log

A logger object, per default set to C<OpenXPKI::Log4perl-E<gt>get_logger>.

=cut
has log => (
    is => 'rw',
    isa => duck_type( [qw(
           trace    debug    info    warn    error    fatal
        is_trace is_debug is_info is_warn is_error is_fatal
    )] ),
    lazy => 1,
    default => sub ($self) { OpenXPKI::Log4perl->get_logger },
);

=head1 METHODS

=head2 new

Constructor with shortcut syntax and an error message filter.

An error code may be given as an internal code only:

    OpenXPKI::Client::Service::Response->new( 40080 );
    # equal to:
    OpenXPKI::Client::Service::Response->new(
        error => 40080
    );

An additional custom error message may also be specified:

=over

=item * if B<error_message> is given and starts with C<"I18N_OPENXPKI_UI_">
it will be translated:

    OpenXPKI::Client::Service::Response->new( 500 => 'I18N_OPENXPKI_UI_BLAH' );
    # equal to:
    OpenXPKI::Client::Service::Response->new(
        error => 500,
        error_message => i18nTokenizer('I18N_OPENXPKI_UI_BLAH'),
    );

=item * if it starts with C<"urn:ietf:params:acme:error"> it will be kept as is:

    OpenXPKI::Client::Service::Response->new( 400 => 'urn:ietf:params:acme:error:rejectedIdentifier' );
    # equal to:
    OpenXPKI::Client::Service::Response->new(
        error => 400,
        error_message => 'urn:ietf:params:acme:error:rejectedIdentifier',
    );

=item * otherwise it will be logged and removed:

    OpenXPKI::Client::Service::Response->new( 500 => 'Something bad happened');
    # equal to:
    $self->log->error('Something bad happened');
    OpenXPKI::Client::Service::Response->new(
        error => 500,
    );

=back

=cut

around BUILDARGS => sub ($orig, $class, @args) {
    # shortcut: only scalar error code or code+message
    if (scalar 0 < @args < 3 and not blessed $args[0] and $args[0] =~ /^\A\d+\z/) {
        @args = (
            error => $args[0],
            $args[1] ? (error_message => $args[1]) : (),
        );
    }

    return $class->$orig( @args );
};

sub BUILD ($self, $args) {
    # don't send internal error messages to client except:
    # - ACME error codes and
    # - translated I18N_OPENXPKI_UI_* messages
    if ($self->has_custom_error_message) {
        my $msg = $self->custom_error_message;
        chomp $msg;
        if ($msg =~ /I18N_OPENXPKI_UI_/) {
            # keep I18N string (but translate)
            $self->custom_error_message(i18nTokenizer($msg));
        } elsif ($msg =~ m{\Aurn:ietf:params:acme:error}) {
            # keep ACME error code
            $self->custom_error_message($msg);
        } else {
            # delete (but log) other internal message
            $self->log->error($msg);
            $self->clear_custom_error_message;
        }
    }
}

=head2 new_error

Alias for L</new>.

=cut
sub new_error { shift->new(@_) }

=head2 error_message

Returns error message depending on the error details:

=over

=item * custom error message if it was given

    my $r = OpenXPKI::Client::Service::Response->new( 500 => 'Something bad happened');
    say $r->error_message;
    # "Something bad happened"

=item * predefined message if only internal error code was given

    my $r = OpenXPKI::Client::Service::Response->new( 50002 );
    say $r->error_message;
    # "Unable to initialize client"

=item * predefined + custom error message if both were given

    my $r = OpenXPKI::Client::Service::Response->new( 50002 => 'Something bad happened');
    say $r->error_message;
    # "Unable to initialize client: Something bad happened"

=item * the empty string if L</error> was not set

=back

=cut
sub error_message ($self) {
    return ''
      unless $self->has_error;

    my @msg;
    # general message
    my $general = $named_messages{$self->error};
    push @msg, $general if $general;
    # detailed message
    push @msg, $self->custom_error_message if $self->has_custom_error_message;

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
        $self->add_header('X-OpenXPKI-Workflow-Id' => $workflow->{id});
    }
    if ($self->has_transaction_id) {
        my $tid = $self->transaction_id;
        # this should usually be a hexadecimal string but to avoid any surprise
        # we check this here and encoded if needed.
        $tid = Encode::encode("MIME-B", $tid) if $tid =~ m{\W};
        $self->add_header('X-OpenXPKI-Transaction-Id' => $tid);
    }
    if (my $error = $workflow->{context}->{error_code}) {
        # header must not be any longer than 76 chars in total
        $error = substr(i18nGettext($error),0,64);
        # use mime encode if header is non-us-ascii, 42 chars plus tags is the
        # maximum to stay below 76 chars (starts to wrap otherwise)
        $error = Encode::encode("MIME-B", substr($error,0,42)) if $error =~ m{\W};
        $self->add_header('X-OpenXPKI-Error' => $error);
    }
}

=head2 redirect_to

HTTP redirect to the given URL.

    $response->redirect_to('https://www.openxpki.org');

B<Parameters>

=over

=item * I<Str> C<$target> - URL

=back

=cut
sub redirect_to ($self, $target) {
    $self->redirect_url($target);
    $self->http_status_code(302);
}

__PACKAGE__->meta->make_immutable;

=pod

=head2 add_header

Sets the given HTTP header.

    $response->add_header('content-type' => 'text/plain');

B<Parameters>

=over

=item * I<Str> C<$name> - header name.

=item * I<Str> C<$value> - header value.

=back

=cut
### add_header() is an accessor for "extra_headers" (see attribute above)

=head2 is_redirect

Returns TRUE if L</redirect_to> was called, FALSE otherwise.

=cut
### is_redirect() is an accessor for "redirect_url" (see attribute above)
