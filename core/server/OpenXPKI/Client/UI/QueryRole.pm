package OpenXPKI::Client::UI::QueryRole;
use Moose::Role;

requires qw( session_param __generate_uid status);

# Project modules
use OpenXPKI::Exception;


sub __save_query {
    my $self = shift;
    my $id = (ref $_[0] ne 'HASH') ? shift : $self->__generate_uid;
    my $query = shift;

    die "Query data HashRef must contain 'pagename' key" unless $query->{pagename};
    die "Query data HashRef must contain 'query' key" unless $query->{query};

    $self->session_param("query_${id}" => {
        %{ $query },
        '__id' => $id,
    });

    return $id;
}

sub __load_query {
    my $self = shift;
    my $pagename = shift or die "No 'pagename' given to __load_query()";
    my $id = shift or die "No 'id' given to __load_query()";

    # load query from session
    my $result = $self->session_param("query_${id}");

    # check expired or broken id
    if (not $result or not $result->{count}) {
        $self->status->error('I18N_OPENXPKI_UI_SEARCH_RESULT_EXPIRED_OR_EMPTY');
        return;
    }

    my $query_page = $result->{pagename} // '';
    if ($query_page ne $pagename) {
        OpenXPKI::Exception->throw(message => "Possible attack - attempt to load '$query_page' query parameters in page '$pagename'");
    }

    return $result;
}

1;
