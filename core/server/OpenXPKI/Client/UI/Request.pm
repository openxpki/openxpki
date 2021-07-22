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

has data => (
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

    my %keys;
    my @keys = $self->cgi->param;
    map { $keys{$_} = undef } @keys;

    # keys and values from JSON
    if (($self->cgi->content_type // '') eq 'application/json') {
        $self->logger->debug('Incoming JSON');
        my $json = JSON->new->utf8;
        my $data = $json->decode( scalar $self->cgi->param('POSTDATA') );
        %keys = ( %keys, %$data );
        $self->logger->trace( Dumper $data );
        $self->method('POST');
    }

    # there are two special transformations
    # keys key{subkey} should be available with their explicit key and
    # mapped as hash via the base key
    # binary data is base64 encoded with the key name prefixed with the
    # literal '_encoded_base64_'
    # this loop creates the expected keys so the entry check in the param
    # loops will recognize them
    foreach my $key (keys %keys) {
        if (substr($key,0,16) eq '_encoded_base64_') {
            $keys{substr($key,16)} = undef;
            next;
        }
        next unless ($key =~ m{ \A (\w+)\{(\w+)\} \z }xs);
        my $item = $1; my $subkey = $2;
        $self->logger->debug("Translate hash parameter $key");
        $keys{$item} = {} unless($keys{$item});
        $keys{$item}{$subkey} = $keys{$key};
    }

    $self->logger->debug(Dumper \%keys);

    $self->data( \%keys );

}

sub param {

    my $self = shift;
    my $name = shift;

    $self->logger()->debug('Param request for '.$name);

    # send all keys
    if (!$name) {
        die "Request without key is only allowed in array mode" unless (wantarray);
        return keys %{$self->data()};
    }

    # try key without trailing array indicator if it does not exist
    if ($name =~ m{\[\]\z} && !exists $self->data()->{$name}) {
        $name =  substr($name,0,-2);
        $self->logger()->debug('Strip trailing array markers, new key '.$name);
    }

    return unless (exists $self->data()->{$name});

    my $cgi = $self->cgi;
    my @queries = (
        # Try CGI parameters (and strip whitespaces)
        sub { return unless $cgi; return map { my $v = $_; $v =~ s/^\s+|\s+$//g; $v } ($cgi->multi_param($name)) },
        # Try Base64 encoded parameter from JSON input
        sub { return unless $self->data()->{"_encoded_base64_$name"};
            return map { decode_base64($_) } (ref $self->data()->{"_encoded_base64_$name"} ? @{$self->data()->{"_encoded_base64_$name"}} : ($self->data()->{"_encoded_base64_$name"})) },
        # Try Base64 encoded CGI parameters
        sub { return unless $cgi; return map { decode_base64($_) } ($cgi->multi_param("_encoded_base64_$name")) },
    );

    if  (!defined $self->data()->{$name}) {

        $self->logger()->debug('Not in cache, query cgi');
        my @values;
        for my $query (@queries) {
            @values = $query->();
            last if defined $values[0];
        }

        $self->logger()->debug('Got value ' . Dumper \@values);
        if (wantarray) {
            $self->data()->{$name} = \@values;
            return @values;
        } elsif (defined $values[0]) {
            $self->data()->{$name} = $values[0];
            return $values[0];
        } else {
            return;
        }

    }

    $self->logger()->debug('Return from cache');
    if (wantarray) {
        return ($self->data()->{$name})
            if(!ref $self->data()->{$name});

        return @{$self->data()->{$name}};
    }

    return $self->data()->{$name}->[0]
            if (ref $self->data()->{$name} eq 'ARRAY');

    return $self->data()->{$name};

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