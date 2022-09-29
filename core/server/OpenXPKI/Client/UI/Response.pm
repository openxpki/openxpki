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
use OpenXPKI::Client::UI::Response::Page;
use OpenXPKI::Client::UI::Response::Redirect;
use OpenXPKI::Client::UI::Response::Refresh;
use OpenXPKI::Client::UI::Response::Status;

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

has_hash _result => (
    lazy => 1,
    default => sub { {
        main => [],
        right => [],
    } },
);

has _page => (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Page',
    default => sub { OpenXPKI::Client::UI::Response::Page->new },
    lazy => 1,
    reader => 'page',
);

has _redirect => (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Redirect',
    default => sub { OpenXPKI::Client::UI::Response::Redirect->new },
    lazy => 1,
    reader => 'redirect',
);

has _refresh => (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Refresh',
    default => sub { OpenXPKI::Client::UI::Response::Refresh->new },
    lazy => 1,
    reader => 'refresh',
);

has _status => (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::Status',
    default => sub { OpenXPKI::Client::UI::Response::Status->new },
    lazy => 1,
    reader => 'status',
);

sub set_page { shift->_page(OpenXPKI::Client::UI::Response::Page->new(@_)) }
sub set_redirect { shift->_redirect(OpenXPKI::Client::UI::Response::Redirect->new(@_)) }
sub set_refresh { shift->_refresh(OpenXPKI::Client::UI::Response::Refresh->new(@_)) }
sub set_status { shift->_status(OpenXPKI::Client::UI::Response::Status->new(@_)) }

sub add_section {
    my $self = shift;
    my $arg = shift;

    die "Section data passed to 'add_section' must be a HashRef" unless ref $arg eq 'HASH';
    push @{$self->_result->{main}}, $arg;
    return $self;
}

sub add_infobox_section {
    my $self = shift;
    my $arg = shift;

    die "Section data passed to 'add_infobox_section' must be a HashRef" unless ref $arg eq 'HASH';
    push @{$self->_result->{right}}, $arg;
    return $self;
}

=head2 render_to_str

Assemble the return hash from the internal caches and return the result as a
string.

=cut
sub render_to_str {
    my $self = shift;

    my $result = $self->_result;

    my $status = $self->status->is_set ? $self->status->resolve : $self->ui_result->__fetch_status;
    $result->{status} = $status if $status;
    $result->{page} = $self->page->resolve if $self->page->is_set;
    $result->{refresh} = $self->refresh->resolve if $self->refresh->is_set;

    my $body;

    # page redirect
    if ($self->redirect->is_set) {
        # Persist and append status
        if ($status) {
            my $url_param = $self->ui_result->__persist_status($status);
            $self->redirect->to($self->redirect->to . '!' . $url_param);
        }
        $body = encode_json({
            %{ $self->redirect->resolve },
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
