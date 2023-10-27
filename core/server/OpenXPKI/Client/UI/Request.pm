package OpenXPKI::Client::UI::Request;
use Moose;
use namespace::autoclean;

=head1 NAME

OpenXPKI::Client::UI::Request

=head1 DESCRIPTION

This class is used to hold the input data received as from the webserver
and provides a transparent interface to the application to retrieve
parameter values regardless which transport format was used.

If the data was POSTed as JSON blob, the parameters are already expanded
with the values in the I<cache> hash. If data was send via a CGI method
(either form-encoded or GET), the I<cache> hash holds the keys and the
value undef and the parameter expansion is done on the first request to
L</param>.

=cut

# Core modules
use MIME::Base64;
use Carp qw( confess );
use OpenXPKI::Dumper;

# CPAN modules
use JSON;
use Log::Log4perl;
use Crypt::JWT qw( decode_jwt );
use Moose::Util::TypeConstraints; # PLEASE NOTE: this enables all warnings via Moose::Exporter


has cgi => (
    required => 1,
    is => 'ro',
    isa => duck_type( [qw( param multi_param content_type cookie header )] ), # not "isa => 'CGI'" as we use CGIMock in tests
);

has session => (
    required => 1,
    is => 'rw',
    isa => 'CGI::Session',
);

# cache (and secure_cache) work as follows:
# All CGI parameter keys are inserted as $key => undef. The undefined value
# indicates that the parameter exists but was not yet queried / decoded.
# Data passed via JSON is directly inserted as $key => $value.
has cache => (
    is => 'rw',
    isa => 'HashRef',
    traits => ['Hash'],
    default => sub { {} },
);

# parameters from a secure JWT
has secure_cache => (
    is => 'rw',
    isa => 'HashRef',
    traits => ['Hash'],
    default => sub { {} },
);

has method => (
    is => 'rw',
    isa => 'Str',
    default => 'GET',
);

has log => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    lazy => 1,
    default => sub { return Log::Log4perl->get_logger; }
);

has id => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { my $id="".shift; $id =~ s/.*\(0x([^\)]+)\)/$1/; $id },
);

has _prefix_base64 => (
    is => 'ro',
    isa => 'Str',
    default => '_encoded_base64_',
);

has _prefix_jwt => (
    is => 'ro',
    isa => 'Str',
    default => '_encrypted_jwt_',
);

=head1 METHODS

=cut

sub BUILD {
    my $self = shift;

    #
    # Preset all keys in the cache (for JSON data, also set the values)
    #

    # store keys from CGI params
    for my $key ($self->cgi->param) {
        $self->cache->{$key} = undef; # we do not yet query/cache the value but make the key known
        $self->_check_param_encoding($key);
        $self->log->trace(sprintf('CGI param: %s=%s', $key, join(',', $self->cgi->multi_param($key)))) if $self->log->is_trace;
    }

    # store keys and values from JSON POST data
    if (($self->cgi->content_type // '') eq 'application/json') {
        $self->log->debug('Incoming POST data in JSON format (application/json)');

        $self->method('POST');

        my $data = decode_json( scalar $self->cgi->param('POSTDATA') );
        # Resolve stringified depth-one-hashes - turn parameters like
        #   key{one} = 34
        #   key{two} = 56
        # into a HashRef
        #   key => { one => 34, two => 56 }
        foreach my $combined_key (keys $data->%*) {
            if (my ($key, $subkey) = $combined_key =~ m{ \A (\w+)\{(\w+)\} \z }xs) {
                $data->{$key} //= {};
                $data->{$key}->{$subkey} = $data->{$combined_key};
            }
        }
        $self->log->trace('JSON param: ' . SDumper $data) if $self->log->is_trace;

        $self->add_params($data->%*);
    }
}

# Check if parameter key hints an encoded value (Base64 or JWT): insert the
# sanitized key name into the cache so the "exists" check in _params() or
# _secure_params() will succeed.
sub _check_param_encoding {
    my $self = shift;
    my $key = shift;

    my $prefix_b64 = $self->_prefix_base64;
    my $prefix_jwt = $self->_prefix_jwt;

    # Base64 encoded binary data
    if (my ($k) = $key =~ /^$prefix_b64(.*)/) {
        $self->cache->{$k} = undef;
    }
    # JWT encrypted data
    elsif (my ($sk) = $key =~ /^$prefix_jwt(.*)/) {
        $self->secure_cache->{$sk} = undef;
    }
}

sub add_params {
    my $self = shift;
    my %params = @_;

    for my $key (keys %params) {
        # normalize all values to ArrayRef because _param() expects this
        $self->cache->{$key} = (ref $params{$key} eq 'ARRAY' ? $params{$key} : [ $params{$key} ]);
        # check key name for "encoded"/"encrypted" flag
        $self->_check_param_encoding($key);
    }
}

sub add_secure_params {
    my $self = shift;
    my %params = @_;

    for my $key (keys %params) {
        # normalize all values to ArrayRef because _param() expects this
        $self->secure_cache->{$key} = (ref $params{$key} eq 'ARRAY' ? $params{$key} : [ $params{$key} ]);
        # check key name for "encoded"/"encrypted" flag
        $self->_check_param_encoding($key);
    }
}

=head2 param

Returns the value of an input parameter.

To get all values of a multi-valued parameter use L</multi_param>.

=cut

sub param {
    my $self = shift;
    my $key = shift;

    confess 'param() must be called in scalar context' if wantarray; # die
    confess 'param() expects a single key (string) as argument' if (not $key or ref $key); # die

    my @values = $self->_params($key); # list context
    if (defined $values[0]) {
        return $values[0];
    } else {
        $self->log->trace("Requested parameter '$key' was not found");
        return;
    }
}

=head2 multi_param

Returns all values of a multi-value input parameter.

Can only be used in list context.

=cut

sub multi_param {
    my $self = shift;
    my $key = shift;

    confess 'multi_param() must be called in list context' unless wantarray; # die
    confess 'multi_param() expects a single key (string) as argument' if (not $key or ref $key); # die

    my @values = $self->_params($key); # list context
    return @values;
}

=head2 secure_param

Returns the value of an input parameter that was encrypted via JWT and can thus
be trusted.

Encryption might happen either by calling the special virtual page
C<encrypted!JWT_TOKEN> or with a form field of C<type: encrypted>.

C<undef> is returned if the parameter does not exist or was not encrypted.

B<Parameters>

=over

=item * I<Str> C<$key> - parameter name to retrieve.

=back

=cut

sub secure_param {
    my $self = shift;
    my $key = shift;

    confess 'secure_param() must be called in scalar context' if wantarray; # die
    confess 'secure_param() expects a single key (string) as argument' if (not $key or ref $key); # die

    my @values = $self->_secure_params($key); # list context

    if (defined $values[0]) {
        return $values[0];
    } else {
        $self->log->trace("Requested secure parameter '$key' was not found");
        return;
    }
}

sub _params {
    my $self = shift;
    my $key = shift;

    my $msg = sprintf "Param request for '%s': ", $key;

    # try key without trailing array indicator if it does not exist
    if ($key =~ m{\[\]\z} && !exists $self->cache->{$key}) {
        $key = substr($key,0,-2);
        $msg.= "strip array markers, new key '$key', ";
    }

    # Try JWT encrypted data first (may be a nested structure when decrypted)
    if (my @values = $self->_secure_params($key)) {
        return @values;
    }

    # valid key?
    return unless exists $self->cache->{$key};

    # cache miss - query parameter
    unless (defined $self->cache->{$key}) {
        my $prefix_b64 = $self->_prefix_base64;
        my @queries = (
            # Try CGI parameters (and strip leading/trailing whitespaces)
            sub {
                return map { my $v = $_; $v =~ s/ ^\s+ | \s+$ //gx; $v } ($self->cgi->multi_param($key))
            },
            # Try Base64 encoded parameter from JSON input
            sub {
                return map { decode_base64($_) } $self->_get_cache($prefix_b64.$key)
            },
            # Try Base64 encoded CGI parameters
            sub {
                return map { decode_base64($_) } $self->cgi->multi_param($prefix_b64.$key)
            },
        );
        for my $query (@queries) {
            my @values = $query->();
            if (scalar @values) {
                $self->cache->{$key} = \@values;
                last;
            }
        }
        $self->log->trace($msg . 'not in cache. Query result: (' . join(', ', $self->_get_cache($key)) . ')') if $self->log->is_trace;
    }
    else {
        $self->log->trace($msg . 'return from cache');
    }

    return $self->_get_cache($key); # list
}

sub _secure_params {
    my $self = shift;
    my $key = shift;

    my $msg = sprintf "Secure param request for '%s': ", $key;

    # valid key?
    return unless exists $self->secure_cache->{$key};

    # cache miss - query parameter
    unless (defined $self->secure_cache->{$key}) {
        # Decrypt JWT
        my $prefix_jwt = $self->_prefix_jwt;
        my @values = map { $self->_decrypt_jwt($_) } $self->_get_cache($prefix_jwt.$key);
        $self->add_secure_params($key => \@values) if scalar @values;
        $self->log->trace($msg . 'not in cache. Query result: (' . join(', ', @values) . ')') if $self->log->is_trace;
    }
    else {
        $self->log->trace($msg . 'return from cache');
    }

    return $self->_get_secure_cache($key); # list
}

# Returns a list of values for a parameter (may be a single value or an empty list)
sub _get_cache {
    my $self = shift;
    my $key = shift;
    return @{ $self->cache->{$key} // [] }
}

# Returns a list of values for a secure parameter (may be a single value or an empty list)
sub _get_secure_cache {
    my $self = shift;
    my $key = shift;
    return @{ $self->secure_cache->{$key} // [] }
}

sub _decrypt_jwt {

    my $self = shift;
    my $token = shift;

    return unless $token;

    my $jwt_key = $self->session->param('jwt_encryption_key');
    unless ($jwt_key) {
        $self->log->debug("JWT encrypted parameter received but client session contains no decryption key");
        return;
    }

    my $decrypted = decode_jwt(token => $token, key => $jwt_key);

    return $decrypted;

}

__PACKAGE__->meta->make_immutable;
