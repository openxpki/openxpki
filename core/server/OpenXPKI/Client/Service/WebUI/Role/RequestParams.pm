package OpenXPKI::Client::Service::WebUI::Role::RequestParams;
use OpenXPKI -role;
use namespace::autoclean;

requires 'request';
requires 'session';
requires 'log';
requires 'decrypt_jwt';
requires 'json';

=head1 NAME

OpenXPKI::Client::Service::WebUI::Role::Request

=head1 DESCRIPTION

Extends the L<OpenXPKI::Client::Service::Role::Request> role with methods to query
request parameters (browser request data) regardless of the transport format
that was used.

If the data was POSTed as JSON blob, the parameters are already expanded
with the values in the I<cache> hash. If data was sent via HTTP GET or POST
(form-encoded), the I<cache> hash holds the keys and the value I<undef> and the
parameter expansion is done on the first request to L</param>.

=cut

# Core modules
use MIME::Base64;
use Carp qw( confess );
use OpenXPKI::Dumper;
use List::Util qw( first );


use constant PREFIX_BASE64 => '_encoded_base64_';
use constant PREFIX_JWT => '_encrypted_jwt_';

# _param_cache (and _secure_param_cache) work as follows:
# All GET/POST parameter keys are inserted as $key => undef. The undefined value
# indicates that the parameter exists but was not yet queried / decoded.
# Data passed via JSON is directly inserted as $key => $value.
has _param_cache => (
    is => 'rw',
    isa => 'HashRef',
    traits => ['Hash'],
    default => sub { {} },
);

# parameters from a secure JWT
has _secure_param_cache => (
    is => 'rw',
    isa => 'HashRef',
    traits => ['Hash'],
    default => sub { {} },
);

=head1 METHODS

=cut

# Around modifier with fallback BUILD method:
# "around 'BUILD'" complains if there is no BUILD method in the inheritance
# chain of the consuming class. So we define an empty fallback method.
# If the consuming class defines an own BUILD method it will overwrite ours.
# The "around" modifier will work in any case.
# Please note that "around 'build'" is only allowed in roles.
# https://metacpan.org/dist/Moose/view/lib/Moose/Manual/Construction.pod#BUILD-and-parent-classes
sub BUILD {}
after 'BUILD' => sub ($self, $args) {
    #
    # Preset all keys in the cache (for JSON data, also set the values)
    #

    # store keys from GET/POST params
    for my $key ($self->request->params->names->@*) {
        $self->_param_cache->{$key} = undef; # we do not yet query/cache the value but make the key known
        $self->_flag_encoded_value($key);
        $self->log->trace(sprintf('Request parameter: %s = %s', $key, join(',', $self->request->every_param($key)->@*))) if $self->log->is_trace;
    }

    # store keys and values from JSON POST data
    if (($self->request->headers->content_type // '') eq 'application/json') {
        $self->log->debug('Incoming POST data in JSON format (application/json)');

        my $data = $self->json->decode( $self->request->body );
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
};

# Check if parameter key hints an encoded value (Base64 or JWT): insert the
# sanitized key name into the cache so the "exists" check in _params() or
# _secure_params() will succeed.
sub _flag_encoded_value ($self, $key) {
    my $prefix_b64 = PREFIX_BASE64;
    my $prefix_jwt = PREFIX_JWT;

    # Base64 encoded binary data
    if (my ($k) = $key =~ /^$prefix_b64(.*)/) {
        $self->_param_cache->{$k} = undef;
    }
    # JWT encrypted data
    elsif (my ($sk) = $key =~ /^$prefix_jwt(.*)/) {
        $self->_secure_param_cache->{$sk} = undef;
    }
}

sub add_params {
    my $self = shift;
    my %params = @_;

    for my $key (keys %params) {
        # normalize all values to ArrayRef because _param() expects this
        $self->_param_cache->{$key} = (ref $params{$key} eq 'ARRAY' ? $params{$key} : [ $params{$key} ]);
        # check key name for "encoded"/"encrypted" flag
        $self->_flag_encoded_value($key);
    }
}

sub add_secure_params {
    my $self = shift;
    my %params = @_;

    for my $key (keys %params) {
        # normalize all values to ArrayRef because _param() expects this
        $self->_secure_param_cache->{$key} = (ref $params{$key} eq 'ARRAY' ? $params{$key} : [ $params{$key} ]);
        # check key name for "encoded"/"encrypted" flag
        $self->_flag_encoded_value($key);
    }
}

=head2 param

Returns the value of an input parameter.

To get all values of a multi-valued parameter use L</multi_param>.

=cut

sub param ($self, $key) {
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

sub multi_param ($self, $key) {
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

sub secure_param ($self, $key) {
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

sub _params ($self, $key) {
    my $msg = sprintf "Param request for '%s': ", $key;

    # try key without trailing array indicator if it does not exist
    if ($key =~ m{\[\]\z} && !exists $self->_param_cache->{$key}) {
        $key = substr($key,0,-2);
        $msg.= "strip array markers, new key '$key', ";
    }

    # Try JWT encrypted data first (may be a nested structure when decrypted)
    if (my @values = $self->_secure_params($key)) {
        return @values;
    }

    # valid key?
    return unless exists $self->_param_cache->{$key};

    # cache miss - query parameter
    unless (defined $self->_param_cache->{$key}) {
        my $prefix_b64 = PREFIX_BASE64;
        my @queries = (
            # Try CGI parameters (and strip leading/trailing whitespaces)
            sub {
                return map { my $v = $_; $v =~ s/ ^\s+ | \s+$ //gx; $v } $self->request->every_param($key)->@*
            },
            # Try Base64 encoded parameter from JSON input
            sub {
                return map { decode_base64($_) } $self->_get_param_cache($prefix_b64.$key)
            },
            # Try Base64 encoded CGI parameters
            sub {
                return map { decode_base64($_) } $self->request->every_param($prefix_b64.$key)->@*
            },
        );
        for my $query (@queries) {
            my @values = $query->();
            if (scalar @values) {
                $self->_param_cache->{$key} = \@values;
                last;
            }
        }
        $self->log->trace($msg . 'not in cache. Query result: (' . join(', ', $self->_get_param_cache($key)) . ')') if $self->log->is_trace;
    }
    else {
        $self->log->trace($msg . 'return from cache');
    }

    return $self->_get_param_cache($key); # list
}

sub _secure_params ($self, $key) {
    my $msg = sprintf "Secure param request for '%s': ", $key;

    # valid key?
    return unless exists $self->_secure_param_cache->{$key};

    # cache miss - query parameter
    unless (defined $self->_secure_param_cache->{$key}) {
        # Decrypt JWT
        my @values = map { $self->decrypt_jwt($_) } $self->_get_param_cache(PREFIX_JWT.$key);
        $self->add_secure_params($key => \@values) if scalar @values;
        $self->log->trace($msg . 'not in cache. Query result: (' . join(', ', @values) . ')') if $self->log->is_trace;
    }
    else {
        $self->log->trace($msg . 'return from cache');
    }

    return $self->_get_secure_param_cache($key); # list
}

# Returns a list of values for a parameter (may be a single value or an empty list)
sub _get_param_cache ($self, $key) {
    return @{ $self->_param_cache->{$key} // [] }
}

# Returns a list of values for a secure parameter (may be a single value or an empty list)
sub _get_secure_param_cache ($self, $key) {
    return @{ $self->_secure_param_cache->{$key} // [] }
}

1;

