package OpenXPKI::Client::UI::Users;
use Moose;

extends 'OpenXPKI::Client::UI::Result';
with qw(
    OpenXPKI::Client::UI::Role::QueryCache
    OpenXPKI::Client::UI::Role::Pager
);

use Data::Dumper;


=head2 init_index

Default shows the search form as well as a paged table that contains all users

=cut
sub init_index {
    my $self = shift;
    my $args = shift;

    # render title + empty search form
    $self->set_page(
        label => 'I18N_OPENXPKI_UI_USER_TITLE'
        breadcrumb => {
            is_root => 1,
            label => 'I18N_OPENXPKI_UI_USER_SEARCH_LABEL',
            class => 'user-search',
        },
    );
    $self->render_search_form();

    # count users + store result object in session to allow paging
    my $result_count = $self->send_command_v2('search_users_count');
    my $querymeta = {
        pagename => 'users',
        count => $result_count,
        query => {},
        input => {},
        criteria => [],
    };
    my $queryid = $self->__save_query($querymeta);

    # construct query that fetches the first 25 users
    my $query={};
    $query->{limit} = 25;
    $query->{start} = 0;

    if (!$query->{order}) {
        $query->{order} = 'username';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 0;
        }
    }
    # fetch+render the first 25 entries
    my $query_result = $self->send_command_v2(search_users => $query);
    my @result = $self->__render_result_list($query_result);
    $self->__render_result_table($queryid, $querymeta, \@result, 25, 0);
    return $self;
}

=head2 init_result

Load the result of a query, based on a query id and paging information

=cut
sub init_result {

    my $self = shift;
    my $args = shift;

    my $queryid = $self->param('id');
    my $limit = $self->param('limit') || 25;

    my $startat = $self->param('startat') || 0;

    # Safety rule
    if ($limit > 500) {  $limit = 500; }

    # Load query from session
    my $result = $self->__load_query(users => $queryid)
        or return $self->render_search_form();

    # Add limits
    my $query = $result->{query};
    $query->{limit} = $limit;
    $query->{start} = $startat;

    if (!$query->{order}) {
        $query->{order} = 'username';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 0;
        }
    }

    $self->log->trace( "persisted query: " . Dumper $result) if $self->log->is_trace;

    my $query_result = $self->send_command_v2( 'search_users', $query );

    $self->log->trace( "search result: " . Dumper $query_result) if $self->log->is_trace;

    my $criteria = '<br>' . (join ", ", @{$result->{criteria}});

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_USER_SEARCH_RESULT_LABEL',
        description => 'I18N_OPENXPKI_UI_USER_SEARCH_RESULT_DESC' . $criteria ,
        breadcrumb => {
            label => 'I18N_OPENXPKI_UI_USER_SEARCH_RESULT_TITLE',
            class => 'user-search-result',
        },
    );

    my @result = $self->__render_result_list( $query_result);
    $self->log->trace( "dumper result: " . Dumper @result) if $self->log->is_trace;
    $self->__render_result_table($queryid, $result, \@result,$limit,$startat);
    return $self;

}


=head2 init_pager

Similar to init_result but returns only the data portion of the table as
partial result.

=cut

sub init_pager {

    my $self = shift;
    my $args = shift;

    my $queryid = $self->param('id');

    # Load query from session
    my $result = $self->__load_query(users => $queryid)
        or return $self->render_search_form();

    # will be removed once inline paging works
    my $startat = $self->param('startat');

    my $limit = $self->param('limit') || 25;
    if ($limit > 500) {  $limit = 500; }

    $startat = int($startat / $limit) * $limit;

    # Add limits to query
    my $query = $result->{query};
    $query->{limit} = $limit;
    $query->{start} = $startat;

    if ($self->param('order')) {
        $query->{order} = $self->param('order');
    }

    if (defined $self->param('reverse')) {
        $query->{reverse} = $self->param('reverse');
    }

    $self->log->trace( "persisted query: " . Dumper $result) if $self->log->is_trace;
    $self->log->trace( "executed query: " . Dumper $query) if $self->log->is_trace;

    my $query_result = $self->send_command_v2( 'search_users', $query );

    $self->log->trace( "search result: " . Dumper $query_result) if $self->log->is_trace;

    my @result = $self->__render_result_list( $query_result );

    $self->log->trace( "dumper result: " . Dumper @result) if $self->log->is_trace;

    $self->confined_response({ data => \@result });

    return $self;
}



=head2 action_search

Handle search requests and display the result as grid

=cut

sub action_search {
    my $self = shift;
    my $args = shift;
    $self->log->trace("input params: " . Dumper $self->cgi()->param()) if $self->log->is_trace;

    # assemble query
    my $query = {};
    my $input = {}; # store the input data the reopen the form later
    my $verbose = {};

    # handle fields that are compared with placeholders: username, realname, mail
    foreach my $key (qw(username realname mail)) {
        my $val = $self->param($key);
        $self->log->trace("$key: $val") if $self->log->is_trace;
        if (defined $val && $val ne '') {
            $query->{$key} = '%'.$val.'%';
            $input->{$key} = $val;
            $verbose->{$key} = $val;
        }
    }
    # handle fields that are compared exactly: role
    foreach my $key (qw(role)) {
        my $val = $self->param($key);
        $self->log->trace("$key: $val") if $self->log->is_trace;
        if (defined $val && $val ne '') {
            $query->{$key} = $val;
            $input->{$key} = $val;
            $verbose->{$key} = $val;
        }
    }


    my @criteria;
    foreach my $item ((
        { name => 'username', label => 'I18N_OPENXPKI_UI_USER_USERNAME'},
        { name => 'mail', label => 'I18N_OPENXPKI_UI_USER_MAIL'},
        { name => 'realname', label => 'I18N_OPENXPKI_UI_USER_REALNAME'},
        { name => 'role', label => 'I18N_OPENXPKI_UI_USER_ROLE'}
        )) {

        my $val = $verbose->{ $item->{name} };
        next unless ($val);
        $val =~ s/[^\w\s*\,\-\=]//g;
        push @criteria, sprintf '<nobr><b>%s:</b> <i>%s</i></nobr>', $item->{label}, $val;
    }

    # real results are handled by the result page, but we need to know if there are any results...
    my $result_count = $self->send_command_v2( 'search_users_count', $query  );

    # No results founds
    if (!$result_count) {
        $self->status->error('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES');
        return $self->render_search_form({ preset => $input });
    }
    # store search query in session for paging etc...
    my $queryid = $self->__save_query({
        pagename => 'users',
        id => $queryid,
        count => $result_count,
        query => $query,
        input => $input,
        criteria => \@criteria,
    });
    # after handling the search: redirect to result page
    $self->redirect->to('users!result!id!'.$queryid);

    return $self;

}

=head2 __render_result_list

Helper to render the output result list from a sql query result.

=cut
sub __render_result_list {
    my $self = shift;
    my $query_result = shift;
    my @result;
    foreach my $user (@{$query_result}) {
        push @result, [
            $user->{'username'},
            $user->{'mail'},
            $user->{'realname'},
            $user->{'role'},
        ];
    }
    return @result;
}

=head2 __render_result_table

Helper to render the result table.

Takes four arguments: the stored result object, the entries to display, limit and startat (for paging)
=cut
sub __render_result_table {
    my $self = shift;
    my $queryid = shift;
    my $result = shift;
    my $entries = shift;
    my $limit = shift;
    my $startat = shift;

    # columns of the result table
    my @columns=[
        { sTitle => "I18N_OPENXPKI_UI_USER_USERNAME" },
        { sTitle => "I18N_OPENXPKI_UI_USER_MAIL" },
        { sTitle => "I18N_OPENXPKI_UI_USER_REALNAME" },
        { sTitle => "I18N_OPENXPKI_UI_USER_ROLE" },
    ];
    $self->main->add_section({
        type => 'grid',
        className => 'users',
        content => {
            actions => [{
                page => 'workflow!index!wf_type!edit_user!username!{I18N_OPENXPKI_UI_USER_USERNAME}',
                label => 'I18N_OPENXPKI_UI_USER_EDIT_USER',
                target => 'top',
            }],
            columns => @columns,
            data => $entries,
            empty => 'I18N_OPENXPKI_UI_USER_LIST_EMPTY_LABEL',
            pager => $self->__build_pager(
                pagename => 'users',
                id => $queryid,
                query => $result->{query},
                count => $result->{count},
                limit => $limit,
                startat => $startat,
            ),
            buttons => [
                {
                    label => 'I18N_OPENXPKI_UI_SEARCH_RELOAD_FORM',
                    page => "users!search!query!${queryid}",
                    format => 'expected',
                },
                {
                    label => 'I18N_OPENXPKI_UI_USER_ADD_USER',
                    page => 'workflow!index!wf_type!add_user',
                    format => 'optional',
                },
            ],
        }
    });
}


=head2 render_search_form

Renders the search form

=cut
sub render_search_form {
    my $self = shift;
    my $args = shift;

    # add search form to current page
    my $form = $self->main->add_form(
        action => 'users!search',
        description => 'I18N_OPENXPKI_UI_USER_SEARCH_DESC',
        submit_label => 'I18N_OPENXPKI_UI_USER_SEARCH_SUBMIT_LABEL',
    );

    # define search fields
    my $preset = $args->{preset} // {};
    $form->add_field(
        name => 'username', label => 'I18N_OPENXPKI_UI_USER_USERNAME', type => 'text', is_optional => 1, value => $preset->{username},
    )->add_field(
        name => 'mail', label => 'I18N_OPENXPKI_UI_USER_MAIL', type => 'text', is_optional => 1, value => $preset->{mail},
    )->add_field(
        name => 'realname', label => 'I18N_OPENXPKI_UI_USER_REALNAME', type => 'text', is_optional => 1, value => $preset->{realname},
    )->add_field(
        name => 'role', label => 'I18N_OPENXPKI_UI_USER_ROLE',type => 'select', is_optional => 1, value => $preset->{role},
        options => [
            { label => 'I18N_OPENXPKI_UI_USER_ROLE_USER', value => 'User'},
            { label=> 'I18N_OPENXPKI_UI_USER_ROLE_RAOP',value=> 'RA Operator'},
        ],
    );

    return $self;
}

=head2 init_search

    displays a raw search page with possibly preset search fields

=cut
sub init_search {

    my $self = shift;
    my $args = shift;

    $self->page->label('I18N_OPENXPKI_UI_USER_SEARCH_LABEL');
    # check if there are any preset values for the search fields
    my $preset;
    if (my $queryid = $self->param('query')) {
        my $result = $self->__load_query(users => $queryid);
        $preset = $result->{input};
    }

    $self->render_search_form({ preset => $preset });
    return $self;
}

__PACKAGE__->meta->make_immutable;
