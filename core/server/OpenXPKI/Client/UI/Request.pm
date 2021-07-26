package OpenXPKI::Client::UI::Request;

use Moose;
use namespace::autoclean;

# Core modules
use Data::Dumper;
use MIME::Base64;

# CPAN modules
use JSON;
use Log::Log4perl;
use Moose::Util::TypeConstraints;


has cgi => (
    required => 1,
    is => 'ro',
    isa => duck_type( [qw( param multi_param content_type )] ), # not "isa => 'CGI'" as we use CGIMock in tests
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

has logger => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    lazy => 1,
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
        my $data = $json->decode( scalar $self->cgi->param('POSTDATA') );

        # wrap Scalars and HashRefs in an ArrayRef as param() expects it (but leave ArrayRefs as is)
        $cache{$_} = (ref $data->{$_} eq 'ARRAY' ? $data->{$_} : [ $data->{$_} ]) for keys %$data;

        $self->logger->trace(Dumper $data) if $self->logger->is_trace;
        $self->method('POST');
    }

    # special transformations: insert sanitized keys names in the cache so the
    # check in param() will succeed.
    foreach my $key (keys %cache) {
        # base64 encoded binary data
        if (my ($item) = $key =~ /^_encoded_base64_(.*)/) {
            $cache{$item} = undef;
            next;
        }
    }

    $self->logger->debug('Request parameters: ' . join(' | ', keys %cache));

    $self->cache( \%cache );

}

sub param {

    my $self = shift;
    my $name = shift;

    my $msg = "Param request for '$name': ";

    # send all keys
    if (!$name) {
        die "Request without key is only allowed in list context" unless wantarray;
        return keys %{$self->cache};
    }

    # try key without trailing array indicator if it does not exist
    if ($name =~ m{\[\]\z} && !exists $self->cache->{$name}) {
        $name = substr($name,0,-2);
        $msg.= "strip array markers, new key '$name', ";
    }

    # valid key?
    return unless exists $self->cache->{$name};

    # cache miss - query parameter
    unless (defined $self->cache->{$name}) {
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
        $self->logger->trace($msg . 'not in cache. Query result: ' . join(' | ', @{ $self->cache->{$name} })) if $self->logger->is_trace;
    }
    else {
        $self->logger->trace($msg . 'return from cache');
    }

    if (wantarray) {
        return @{ $self->cache->{$name} };
    }
    else {
        return $self->cache->{$name}->[0] if defined $self->cache->{$name};
        return;
    }

}


__PACKAGE__->meta->make_immutable;


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