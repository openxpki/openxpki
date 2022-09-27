package OpenXPKI::Client::UI::Response;

use Moose;
use Moose::Util::TypeConstraints;

# Core modules
use Digest::SHA qw( sha1_base64 );
use List::Util qw( none all first );

# CPAN modules
use CGI 4.08 qw( -utf8 );
use JSON;

# Project modules
use OpenXPKI::i18n qw( i18nTokenizer );


sub has_hash($@) {
    my $name = shift;
    my %spec = @_;

    # default type 'HashRef' (we need an anonymous type object instead of
    # string 'HashRef' to be able to add coercion later on)
    my $type = subtype(as 'HashRef');

    my $keys = $spec{allowed_keys};
    if ($keys) {
        delete $spec{allowed_keys};
        die "'allowed_keys' must be an ArrayRef" unless ref $keys eq 'ARRAY';
        # create subtype to check hash keys
        my $re = join ' | ', @$keys;
        $type = subtype(
            as 'HashRef',
            where { all { /^( $re )$/x } keys %{$_} },
            message {
                ref $_ eq 'HASH'
                    ? sprintf "Hash key '%s' is not allowed", $name, first { $_ !~ /^( $re )$/x } keys %{$_}
                    : sprintf "Expected HASH ref, got: %s", (ref($_) ? ref($_).' ref' : "Scalar '$_'")
            },
        );
    }
    # optionally coerce plain string into hash value
    my $str_target = $spec{store_str_in};
    if ($str_target) {
        delete $spec{store_str_in};
        if ($keys and none { $_ eq $str_target } @$keys) {
            die "Attribute '$name': key given in 'store_str_in' must be part of 'allowed_keys'";
        }
        coerce $type, from 'Str', via { { "$str_target" => $_ } };
    }
    # create attribute
    has "$name" => (
        is => 'rw',
        isa => $type,
        $str_target ? (coerce => 1) : (),
        %spec,
    );
}

has ui_result => (
    is => 'ro',
    isa => duck_type( [qw( _session __persist_status __fetch_status )] ),
    required => 1,
);

has_hash result => (
    lazy => 1,
    default => sub { {} },
);

has_hash redirect => (
    allowed_keys => [qw( goto type )],
    store_str_in => 'goto',
    predicate => 'has_redirect',
);

has_hash page => (
    allowed_keys => [qw( label shortlabel description breadcrumb className isLarge canonical_uri )],
    predicate => 'has_page',
);

has_hash raw_status => (
    allowed_keys => [qw( level message href field_errors )],
    predicate => 'has_status',
);

has_hash raw_refresh => (
    allowed_keys => [qw( href timeout )],
    predicate => 'has_refresh',
);


sub set_status {
    my $self = shift;
    my $message = shift;
    my $level = shift || 'info';
    my $href = shift || '';

    $self->raw_status({ level => $level, message => $message, href => $href });

    return $self;
}

sub set_refresh {
    my $self = shift;
    my $location = shift;
    my $timeout = shift || 60;

    $self->raw_refresh({ href => $location, timeout => $timeout * 1000 });

    return $self;
}

sub add_section {
    my $self = shift;
    my $arg = shift;

    push @{$self->result()->{main}}, $arg;

    return $self;
}

=head2 render_to_str

Assemble the return hash from the internal caches and return the result as a
string.

=cut
sub render_to_str {
    my $self = shift;

    my $result = $self->result;

    my $status = $self->has_status ? $self->raw_status : $self->ui_result->__fetch_status;
    $result->{status} = $status if $status;
    $result->{page} = $self->page if $self->has_page;
    $result->{refresh} = $self->raw_refresh if $self->has_refresh;

    my $body;

    # page redirect
    if ($self->has_redirect) {
        my $redirect = $self->redirect;
        # Persist and append status
        if ($result->{status}) {
            my $url_param = $self->ui_result->__persist_status($result->{status});
            $redirect->{goto} .= '!' . $url_param;
        }

        $body = encode_json({
            %$redirect,
            session_id => $self->ui_result->_session->id
        });

    # raw data
    } elsif ($result->{_raw}) {
        $body = i18nTokenizer(
            encode_json($result->{_raw})
        );

    # regular response
    } else {
        $result->{session_id} = $self->ui_result->_session->id;

        # Add message of the day if set and we have a page section
        if ($result->{page} && (my $motd = $self->ui_result->_session->param('motd'))) {
             $self->ui_result->_session->param('motd', undef);
             $result->{status} = $motd;
        }
        $body = i18nTokenizer(
            encode_json($result)
        );
    }

    return $body;
}

__PACKAGE__->meta->make_immutable;
