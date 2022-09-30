package OpenXPKI::Client::UI::Response;

use Moose;
use Moose::Util::TypeConstraints;

# Core modules
use Digest::SHA qw( sha1_base64 );
use List::Util qw( none all first );

# CPAN modules
use CGI 4.08 qw( -utf8 );
use JSON;
use Moose::Util qw( does_role );

# Project modules
use OpenXPKI::i18n qw( i18nTokenizer );
use OpenXPKI::Client::UI::Response::Page;
use OpenXPKI::Client::UI::Response::Redirect;
use OpenXPKI::Client::UI::Response::Refresh;
use OpenXPKI::Client::UI::Response::Status;
use OpenXPKI::Client::UI::Response::ScalarParams;
use OpenXPKI::Client::UI::Response::User;
use OpenXPKI::Client::UI::Response::Section::Form;

has ui_result => (
    is => 'ro',
    isa => duck_type( [qw( _session __persist_status __fetch_status )] ),
    required => 1,
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

has _user => (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::User',
    default => sub { OpenXPKI::Client::UI::Response::User->new },
    lazy => 1,
    reader => 'user',
);

has _scalar_params => (
    is => 'rw',
    isa => 'OpenXPKI::Client::UI::Response::ScalarParams',
    default => sub { OpenXPKI::Client::UI::Response::ScalarParams->new },
    lazy => 1,
    handles => [qw( rtoken language tenant ping )]
);

has 'menu' => (
    is => 'rw',
    isa => 'ArrayRef',
    predicate => 'has_menu',
);

has 'on_exception' => (
    is => 'rw',
    isa => 'ArrayRef[Hashref]',
    predicate => 'has_on_exception',
    # status_code => [ 400, 401 ],
    # redirect => $uri
);

has 'raw_response' => (
    is => 'rw',
    isa => 'Any',
    predicate => 'has_raw_response',
);

has '_main' => (
    is => 'rw',
    isa => 'ArrayRef',
    traits => ['Array'],
    handles => {
        add_section => 'push',
    },
    default => sub { [] },
    predicate => 'has_main',
);

has '_infobox' => (
    is => 'rw',
    isa => 'ArrayRef',
    traits => ['Array'],
    handles => {
        add_infobox_section => 'push',
    },
    default => sub { [] },
    predicate => 'has_infobox',
);

sub set_page { shift->_page(OpenXPKI::Client::UI::Response::Page->new(@_)) }
sub set_redirect { shift->_redirect(OpenXPKI::Client::UI::Response::Redirect->new(@_)) }
sub set_refresh { shift->_refresh(OpenXPKI::Client::UI::Response::Refresh->new(@_)) }
sub set_status { shift->_status(OpenXPKI::Client::UI::Response::Status->new(@_)) }
sub set_user { shift->_user(OpenXPKI::Client::UI::Response::User->new(@_)) }

sub new_form { my $self = shift; OpenXPKI::Client::UI::Response::Section::Form->new(@_) }
sub add_form { my $self = shift; my $form = $self->new_form(@_); $self->add_section($form); return $form }

=head2 render_to_str

Assemble the return hash from the internal caches and return the result as a
string.

=cut
sub render_to_str {
    my $self = shift;

    my $status = $self->status->is_set ? $self->status->resolve : $self->ui_result->__fetch_status;

    #
    # A) page redirect
    #
    if ($self->redirect->is_set) {
        # Persist and append status
        if ($status) {
            my $url_param = $self->ui_result->__persist_status($status);
            $self->redirect->to($self->redirect->to . '!' . $url_param);
        }
        return encode_json({
            %{ $self->redirect->resolve },
            session_id => $self->ui_result->_session->id
        });
    }


    #
    # B) raw data
    #
    if ($self->has_raw_response) {
        return i18nTokenizer(encode_json($self->raw_response));
    }

    #
    # C) regular response
    #
    my $result = {};

    # Dedicated data transfer objects (DTO) for complex parameters
    $result->{status} = $status if $status;
    if ($self->page->is_set && (my $motd = $self->ui_result->_session->param('motd'))) {
        # show message of the day if we have a page section (may overwrite status)
        $self->ui_result->_session->param('motd', undef);
        $result->{status} = $motd;
    }

    $result->{page} = $self->page->resolve if $self->page->is_set;
    $result->{refresh} = $self->refresh->resolve if $self->refresh->is_set;
    $result->{user} = $self->user->resolve if $self->user->is_set;

    # One DTO for several simple parameters
    $result = { %$result, %{$self->_scalar_params->resolve} } if $self->_scalar_params->is_set;

    # Not-yet-DTO parameters
    my $maybe_resolve = sub { my $v = shift; return (does_role($v, 'OpenXPKI::Client::UI::Response::DTORole') ? $v->resolve : $v) };

    $result->{main} = [ map { $maybe_resolve->($_) } @{ $self->_main } ] if $self->has_main;
    $result->{right} = [ map { $maybe_resolve->($_) } @{ $self->_infobox } ] if $self->has_infobox;
    $result->{structure} = $self->menu if $self->has_menu;
    $result->{on_exception} = $self->on_exception if $self->has_on_exception;

    $result->{session_id} = $self->ui_result->_session->id;

    return i18nTokenizer(encode_json($result));
}

__PACKAGE__->meta->make_immutable;
