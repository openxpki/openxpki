package OpenXPKI::Client::UI::Request;

use Data::Dumper;
use JSON;
use MIME::Base64;
use Log::Log4perl;

use Moose;

has cgi => (
    is => 'ro',
    isa => 'Object',
    required => 1,
);

has cache => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { return {}; }
);

has method => (
    is => 'rw',
    isa => 'Str',
    default => 'GET',
);

has 'logger' => (
    required => 0,
    lazy => 1,
    is => 'ro',
    isa => 'Object',
    default => sub { return Log::Log4perl->get_logger; }
);

sub BUILD {

    my $self = shift;

    #
    # Preset all keys in the cache (for JSON data, also set the values)
    #
    my %cache;

    # store keys from CGI params
    my @keys = $self->cgi->param;
    $cache{$_} = undef for @keys;

    # store keys and values from JSON POST data
    if (($self->cgi->content_type // '') eq 'application/json') {
        $self->logger->debug('Incoming POST data in JSON format (application/json)');
        my $json = JSON->new->utf8;
        my $json_data = $json->decode( scalar $self->cgi->param('POSTDATA') );

        # wrap values in an ArrayRef as param() expects it
        $cache{$_} = [ $json_data->{$_} ] for keys %$json_data;

        $self->logger->trace( Dumper $json_data );
        $self->method('POST');
    }

    # special transformations: create the expected keys in the cache so the
    # check in param() will succeed.
    foreach my $key (keys %cache) {
        # binary data is base64 encoded with the key name prefixed with
        # '_encoded_base64_'
        if (substr($key,0,16) eq '_encoded_base64_') {
            $cache{substr($key,16)} = undef;
            next;
        }

        # keys key{subkey} should be available with their explicit key and
        # mapped as hash via the base key
        if ($key =~ m{ \A (\w+)\{(\w+)\} \z }xs) {
            my $item = $1; my $subkey = $2;
            $self->logger->debug("Translate hash parameter $key");
            $cache{$item} = {} unless($cache{$item});
            $cache{$item}{$subkey} = $cache{$key};
        }
    }

    $self->logger->debug('Request parameters: ' . join(' | ', keys %cache));

    $self->cache( \%cache );

}

sub param {

    my $self = shift;
    my $name = shift;

    $self->logger->debug('Param request for '.$name);

    # send all keys
    if (!$name) {
        die "Request without key is only allowed in list context" unless wantarray;
        return keys %{$self->cache};
    }

    # try key without trailing array indicator if it does not exist
    if ($name =~ m{\[\]\z} && !exists $self->cache->{$name}) {
        $name =  substr($name,0,-2);
        $self->logger->debug('Strip trailing array markers, new key '.$name);
    }

    # valid key?
    return unless exists $self->cache->{$name};

    # cache miss - query parameter
    unless (defined $self->cache->{$name}) {
        $self->logger->debug('Not in cache, query cgi');

        my $cgi = $self->cgi;
        my @queries = (
            # Try CGI parameters (and strip whitespaces)
            sub {
                return unless $cgi;
                return map { my $v = $_; $v =~ s/^\s+|\s+$//g; $v } ($cgi->multi_param($name))
            },
            # Try Base64 encoded parameter from JSON input
            sub {
                my $value = $self->cache->{"_encoded_base64_$name"};
                return unless $value;
                return map { decode_base64($_) } (ref $value ? @{$value} : ($value))
            },
            # Try Base64 encoded CGI parameters
            sub {
                return unless $cgi;
                return map { decode_base64($_) } ($cgi->multi_param("_encoded_base64_$name"))
            },
        );

        for my $query (@queries) {
            my @values = $query->();
            if (scalar @values) {
                $self->cache->{$name} = \@values;
                last;
            }
        }
        $self->logger->debug('Not in cache, queried value: ' . Dumper $self->cache->{$name});
    }
    else {
        $self->logger->debug('Return from cache');
    }

    if (wantarray) {
        return @{ $self->cache->{$name} };
    }
    else {
        return $self->cache->{$name}->[0] if defined $self->cache->{$name};
        return;
    }

}


1;


__END__;

=head1 Name

OpenXPKI::Client::UI::Request

=head1 Description

This class is used to hold the input data received as from the webserver
and provides a transparent interface to the application to retrieve
parameter values regardless which transport format was used.

If the data was POSTed as JSON blob, the parameters are already expanded
with the values in the I<data> hash. If data was send via a CGI method
(either form-encoded or GET), the I<data> hash holds the keys and the
value undef and the parameter expansion is done on the first request.

The C<param> method will B<not> try to guess the type of the attribute,
the requestor must use the method in list context to retrieve a
multi-valued attribute. As the CGI transport does not provide information
on the character of the attribute, the class always tries to translate items
from scalar to array and vice-versa.