package OpenXPKI::Client::UI::Certificate;
use Moose;

extends 'OpenXPKI::Client::UI::Result';
with qw(
    OpenXPKI::Client::UI::Role::QueryCache
    OpenXPKI::Client::UI::Role::Pager
);

# Core modules
use Data::Dumper;
use Math::BigInt;

# CPAN modules
use URI::Escape;
use DateTime;

# Project modules
use OpenXPKI::DN;
use OpenXPKI::i18n qw( i18nGettext );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Util;

has __default_grid_head => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,

    default => sub { return [
        { sTitle => "I18N_OPENXPKI_UI_CERTIFICATE_SERIAL", sortkey => 'cert_key' },
        { sTitle => "I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT", sortkey => 'subject' },
        { sTitle => "I18N_OPENXPKI_UI_CERTIFICATE_STATUS", format => 'certstatus', sortkey => 'status' },
        { sTitle => "I18N_OPENXPKI_UI_CERTIFICATE_NOTBEFORE", format => 'timestamp', sortkey => 'notbefore' },
        { sTitle => "I18N_OPENXPKI_UI_CERTIFICATE_NOTAFTER", format => 'timestamp', sortkey => 'notafter' },
        { sTitle => "I18N_OPENXPKI_UI_CERTIFICATE_ISSUER", sortkey => 'issuer_dn'},
        { sTitle => "I18N_OPENXPKI_UI_CERTIFICATE_IDENTIFIER", sortkey => 'identifier'},
        { sTitle => 'identifier', bVisible => 0 },
        { sTitle => "_className"},
    ]; }
);

has __default_grid_row => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { return [
        { source => 'certificate', field => 'cert_key_hex' },
        { source => 'certificate', field => 'subject' },
        { source => 'certificate', field => 'status' },
        { source => 'certificate', field => 'notbefore' },
        { source => 'certificate', field => 'notafter' },
        { source => 'certificate', field => 'issuer_dn' },
        { source => 'certificate', field => 'identifier' },
        { source => 'certificate', field => 'identifier' },
        { source => 'certificate', field => 'status' },
    ]; }
);

has __validity_options => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { return [
        { value => 'valid_at', label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY_VALID_AT' },
        { value => 'valid_before', label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY_NOTBEFORE_LT' },
        { value => 'valid_after', label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY_NOTBEFORE_GT' },
        { value => 'expires_before', label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY_NOTAFTER_LT' },
        { value => 'expires_after', label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY_NOTAFTER_GT' },
        { value => 'revoked_before', label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY_REVOKED_LT' },
        { value => 'revoked_after', label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY_REVOKED_GT' },
        { value => 'invalid_before', label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY_INVALID_LT' },
        { value => 'invalid_after', label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY_INVALID_GT' },
    ]; }
);


sub BUILD {
    my $self = shift;
}

=head2 init_search

Render the search form
#TODO - preset parameters

=cut
sub init_search {

    my $self = shift;
    my $args = shift;

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_LABEL',
        breadcrumb => {
            is_root => 1,
            class => 'cert-search',
        },
    );

    my $form = $self->main->add_form(
        action => 'certificate!search',
        description => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_DESC',
        submit_label => 'I18N_OPENXPKI_UI_SEARCH_SUBMIT_LABEL',
    );

    my $profile = $self->send_command_v2( 'list_used_profiles' );

    # TODO Sorting / I18

    my @profile_list = sort { $a->{label} cmp $b->{label} } @{$profile};

    my $issuer = $self->send_command_v2( 'list_used_issuers', { format => 'label' } );
    my @issuer_list = sort { $a->{label} cmp $b->{label} } @{$issuer};

    my @states = (
        { label => 'I18N_OPENXPKI_UI_CERT_STATUS_ISSUED', value => 'ISSUED'},
        { label => 'I18N_OPENXPKI_UI_CERT_STATUS_VALID', value => 'VALID'},
        { label => 'I18N_OPENXPKI_UI_CERT_STATUS_EXPIRED', value => 'EXPIRED'},
        { label => 'I18N_OPENXPKI_UI_CERT_STATUS_REVOKED', value => 'REVOKED'},
        { label => 'I18N_OPENXPKI_UI_CERT_STATUS_CRL_ISSUANCE_PENDING', value => 'CRL_ISSUANCE_PENDING'},
    );

    my $preset;
    if ($args->{preset}) {
        $preset = $args->{preset};
    } elsif (my $queryid = $self->param('query')) {
        my $result = $self->__load_query(certificate => $queryid);
        $preset = $result->{input};
    } else {
        foreach my $key (('subject','san')) {
            if (my $val = $self->param($key)) {
                $preset->{$key} = $val;
            }
        }
    }

    $form->add_field(
        name => 'subject', label => 'I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT', placeholder => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_SUBJECT_PLACEHOLDER',
        type => 'text', is_optional => 1, value => $preset->{subject},
    )->add_field(
        name => 'san', label => 'I18N_OPENXPKI_UI_CERTIFICATE_SAN', placeholder => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_SAN_PLACEHOLDER',
        type => 'text', is_optional => 1, value => $preset->{san},
    )->add_field(
        name => 'status', label => 'I18N_OPENXPKI_UI_CERTIFICATE_STATUS',
        type => 'select', is_optional => 1, prompt => 'I18N_OPENXPKI_UI_SELECT_ALL', options => \@states, value => $preset->{status},
    )->add_field(
        name => 'profile', label => 'I18N_OPENXPKI_UI_CERTIFICATE_PROFILE',
        type => 'select', is_optional => 1, prompt => 'I18N_OPENXPKI_UI_SELECT_ALL', options => \@profile_list, value => $preset->{profile},
    )->add_field(
        name => 'issuer_identifier', label => 'I18N_OPENXPKI_UI_CERTIFICATE_ISSUER',
        type => 'select', is_optional => 1, prompt => 'I18N_OPENXPKI_UI_SELECT_ALL', options => \@issuer_list, value => $preset->{issuer_identifier},
    )->add_field(
        name => 'validity', label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY', placeholder => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_VALIDITY_PLACEHOLDER',
        type => 'datetime', is_optional => 1, clonable => 1,
        'keys' => $self->__validity_options(), value => $preset->{validity_options} || [ { key => 'valid_at', value => '' }],
    );

    my $attributes = $self->session_param('certsearch')->{default}->{attributes};
    my @meta_description;
    if (defined $attributes && (ref $attributes eq 'ARRAY')) {
        my @attrib;
        foreach my $item (@{$attributes}) {
            push @attrib, { value => $item->{key}, label=> $item->{label} };
            if ($item->{description}) {
                push @meta_description, { label=> $item->{label}, value => $item->{description}, format => 'raw' };
            }
        }
        $form->add_field(
            name => 'attributes',
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_METADATA',
            placeholder => 'I18N_OPENXPKI_UI_SEARCH_METADATA_PLACEHOLDER',
            'keys' => \@attrib,
            type => 'text',
            is_optional => 1,
            'clonable' => 1,
            'value' => $preset->{attributes} || [{ 'key' => $attrib[0]->{value}, value => ''}],
        ) if (@attrib);

        unshift @meta_description, { value => 'I18N_OPENXPKI_UI_CERTIFICATE_METADATA', format => 'head' } if (@meta_description);
    }

    $self->main->add_form(
        action => 'certificate!find',
        description => 'I18N_OPENXPKI_UI_CERTIFICATE_BY_IDENTIFIER_OR_SERIAL',
        submit_label => 'I18N_OPENXPKI_UI_SEARCH_SUBMIT_LABEL',
    )->add_field(
        name => 'cert_identifier', label => 'I18N_OPENXPKI_UI_CERTIFICATE_IDENTIFIER',
        type => 'text', is_optional => 1, value => $preset->{cert_identifier},
    )->add_field(
        name => 'cert_serial', label => 'I18N_OPENXPKI_UI_CERTIFICATE_SERIAL', placeholder => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_SERIAL_PLACEHOLDER',
        type => 'text', is_optional => 1, value => $preset->{cert_serial},
    );

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_FIELD_HINT_LIST',
            description => '',
            data => [
              { label => 'I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT', value => 'I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT_HINT', format => 'raw' },
              { label => 'I18N_OPENXPKI_UI_CERTIFICATE_SAN', value => 'I18N_OPENXPKI_UI_CERTIFICATE_SAN_HINT', format => 'raw' },
              { label => 'I18N_OPENXPKI_UI_CERTIFICATE_STATUS', value => 'I18N_OPENXPKI_UI_CERTIFICATE_STATUS_HINT', format => 'raw' },
              { label => 'I18N_OPENXPKI_UI_CERTIFICATE_PROFILE', value => 'I18N_OPENXPKI_UI_CERTIFICATE_PROFILE_HINT', format => 'raw' },
              { label => 'I18N_OPENXPKI_UI_CERTIFICATE_ISSUER',  value => 'I18N_OPENXPKI_UI_CERTIFICATE_ISSUER_HINT', format => 'raw' },
              { label => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY', value => 'I18N_OPENXPKI_UI_CERTIFICATE_VALIDITY_HINT', format => 'raw' },
              @meta_description,
            ]
        }
    });

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
    my $cache = $self->__load_query(certificate => $queryid)
        or return $self->init_search();

    # Add limits
    my $query = $cache->{query};
    $query->{limit} = $limit;
    $query->{start} = $startat;

    if (!$query->{order}) {
        $query->{order} = 'notbefore';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 1;
        }
    }

    $self->log->trace( "persisted query: " . Dumper $cache) if $self->log->is_trace;

    my $search_result = $self->send_command_v2( 'search_cert', $query );

    $self->log->trace( "search result: " . Dumper $search_result) if $self->log->is_trace;

    my $criteria = '<br>' . (join ", ", @{$cache->{criteria}});

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_RESULT_LABEL',
        description => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_RESULT_DESC' . $criteria ,
        breadcrumb => {
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_RESULT_TITLE',
            class => 'cert-search-result',
        },
    );

    my $pager = $self->__build_pager(
        pagename => 'certificate',
        id => $queryid,
        query => $query,
        count => $cache->{count},
        %{$cache->{pager_args} // {}},
        limit => $limit,
        startat => $startat,
    );

    my $body = $cache->{column};
    $body = $self->__default_grid_row() if(!$body);

    my $header = $cache->{header};
    $header = $self->__default_grid_head() if(!$header);

    my @result = $self->__render_result_list( $search_result, $body );

    $self->log->trace( "dumper result: " . Dumper @result) if $self->log->is_trace;

    $self->main->add_section({
        type => 'grid',
        className => 'certificate',
        content => {
            actions => [{
                page => 'certificate!detail!identifier!{identifier}',
                label => 'I18N_OPENXPKI_UI_DOWNLOAD_LABEL',
                icon => 'download',
                target => 'popup'
            }],
            columns => $header,
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            pager => $pager,
            buttons => [
                { label => 'I18N_OPENXPKI_UI_SEARCH_RELOAD_FORM',
                  page => 'certificate!search!query!' .$queryid,
                  format => 'expected'
                },
                { label => 'I18N_OPENXPKI_UI_SEARCH_REFRESH',
                  page => 'redirect!certificate!result!id!' .$queryid,
                  format => 'alternative'
                },
                { label => 'I18N_OPENXPKI_UI_SEARCH_NEW_SEARCH',
                  page => 'certificate!search',
                  format => 'failure'
                },
                { label => 'I18N_OPENXPKI_UI_SEARCH_EXPORT_RESULT',
                  href => $self->_client->script_url . '?page=certificate!export!id!'.$queryid,
                  target => '_blank',
                  format => 'optional'
                },
            ]
        }
    });

    return $self;

}


=head2 init_export

Like init_result but send the data as CSV download, default limit is 500!

=cut
sub init_export {

    my $self = shift;
    my $args = shift;

    my $queryid = $self->param('id');

    my $limit = $self->param('limit') || 500;
    my $startat = $self->param('startat') || 0;

    # Safety rule
    if ($limit > 500) {  $limit = 500; }


    # Load query from session
    my $result = $self->__load_query(certificate => $queryid)
        or return $self->init_search();

    # Add limits
    my $query = $result->{query};
    $query->{limit} = $limit;
    $query->{start} = $startat;

    if (!$query->{order}) {
        $query->{order} = 'certificate.notbefore';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 1;
        }
    }

    $self->log->trace( "persisted query: " . Dumper $result) if $self->log->is_trace;

    my $search_result = $self->send_command_v2( 'search_cert', $query );

    $self->log->trace( "search result: " . Dumper $search_result) if $self->log->is_trace;

    my $header = $result->{header};
    $header = $self->__default_grid_head() if(!$header);

    my @head;
    my @cols;

    my $ii = 0;
    foreach my $col (@{$header}) {
        # skip hidden fields
        if ((!defined $col->{bVisible} || $col->{bVisible}) && $col->{sTitle} !~ /\A_/)  {
            push @head, i18nGettext($col->{sTitle});
            push @cols, $ii;
        }
        $ii++;
    }

    my $buffer = join("\t", @head)."\n";

    my $body = $result->{column};
    $body = $self->__default_grid_row() if(!$body);

    foreach my $item (@{$search_result}) {

        $item->{status} = 'EXPIRED' if ($item->{status} eq 'ISSUED' && $item->{notafter} < time());

        my @line;
        foreach my $cc (@cols) {

            my $col = $body->[$cc];
            my $field = lc($col->{field}); # lowercase to ease migration from 1.0 syntax
            if ($field eq 'status') {
                push @line, i18nGettext('I18N_OPENXPKI_UI_CERT_STATUS_'.$item->{status});

            } elsif ($field =~ /(notafter|notbefore)/) {
                push @line,  DateTime->from_epoch( epoch => $item->{ $field } )->iso8601();

            } elsif ($field eq 'cert_key_hex') {
                push @line, unpack('H*', Math::BigInt->new( $item->{cert_key})->to_bytes );


            } else {
                push @line, $item->{ $field };
            }
        }
        $buffer .= join("\t", @line)."\n";
    }

    if (scalar @{$search_result} == $limit) {
        $buffer .= i18nGettext("I18N_OPENXPKI_UI_CERT_EXPORT_EXCEEDS_LIMIT")."\n";
    }

    print $self->cgi()->header(
        -type => 'text/tab-separated-values',
        -expires => "1m",
        -attachment => "certificate export " . DateTime->now()->iso8601() .  ".txt"
    );
    print $buffer;
    exit;

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
    my $result = $self->__load_query(certificate => $queryid)
        or return $self->init_search();

    # will be removed once inline paging works
    my $startat = $self->param('startat');

    my $limit = $self->param('limit') || 25;
    if ($limit > 500) {  $limit = 500; }

    $startat = int($startat / $limit) * $limit;

    # Add limits
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

    my $search_result = $self->send_command_v2( 'search_cert', $query );

    $self->log->trace( "search result: " . Dumper $search_result) if $self->log->is_trace;

    my $body = $result->{column};
    $body = $self->__default_grid_row() if(!$body);

    my @result = $self->__render_result_list( $search_result, $body );

    $self->log->trace( "dumper result: " . Dumper @result) if $self->log->is_trace;

    $self->confined_response({ data => \@result });

    return $self;
}
=head2 init_mine

my certificates view, finds certificates based on the current logged in userid

=cut
sub init_mine {

    my $self = shift;
    my $args = shift;

    my $limit = $self->param('limit') || 25;

    # Safety rule
    if ($limit > 500) {  $limit = 500; }

    # will be removed once inline paging works
    my $startat = $self->param('startat') || 0;

    my $query = {
        cert_attributes => {
            'system_cert_owner' => { '=', $self->session_param('user')->{name} }
        },
        order => 'notbefore',
        reverse => 1,
        $self->__tenant(),
    };

    $self->log->trace( "search query: " . Dumper $query) if $self->log->is_trace;

    my $search_result = $self->send_command_v2( 'search_cert', { %$query, limit => $limit, start => $startat } );

    my $result_count = scalar @{$search_result};
    my $pager;
    if ($result_count == $limit) {
        my %count_query = %{$query};
        delete $count_query{order};
        delete $count_query{reverse};

        $result_count = $self->send_command_v2( 'search_cert_count', \%count_query );

        my $_query = {
            pagename => 'certificate',
            count => $result_count,
            query => $query,
        };
        my $queryid = $self->__save_query($_query);

        $pager = $self->__build_pager(
            pagename => 'certificate',
            id => $queryid,
            query => $query,
            count => $result_count,
            limit => $limit,
            startat => $startat,
        );
    }

    $self->log->trace( "search result: " . Dumper $search_result) if $self->log->is_trace;

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_MINE_LABEL',
        description => 'I18N_OPENXPKI_UI_CERTIFICATE_MINE_DESC',
    );

    my @result = $self->__render_result_list( $search_result, $self->__default_grid_row() );

    $self->log->trace( "dumper result: " . Dumper @result) if $self->log->is_trace;

    $self->main->add_section({
        type => 'grid',
        className => 'certificate',
        content => {
            actions => [{
                page => 'certificate!detail!identifier!{identifier}',
                label => 'I18N_OPENXPKI_UI_DOWNLOAD_LABEL',
                icon => 'download',
                target => 'popup'
            }],
            columns => $self->__default_grid_head(),
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            pager => $pager,
        }
    });

    return $self;

}

=head2 init_detail

Show details on the certificate, includes basic certificate information,
status, issuer and links to download chains and related workflow. Designed to
be shown in a modal popup.

=cut

sub init_detail {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');

    # empty submission
    if (!$cert_identifier) {
        $self->redirect->to('certificate!search');
        return;
    }

    my $cert = $self->send_command_v2( 'get_cert', {
        identifier => $cert_identifier,
        format => 'DBINFO',
        attribute => 'subject_alt_name' }, 1);

    if (!$cert) {
        $self->set_page(
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_DETAIL_LABEL',
            shortlabel => 'I18N_OPENXPKI_UI_CERT_STATUS_UNKNOWN'
        );

        $self->main->add_section({
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => [
                    { label => 'I18N_OPENXPKI_UI_CERTIFICATE_IDENTIFIER', value => $cert_identifier },
                    { label => 'I18N_OPENXPKI_UI_CERTIFICATE_STATUS', value => { label => 'I18N_OPENXPKI_UI_CERT_STATUS_UNKNOWN' , value => 'unknown' }, format => 'certstatus' },
                ],
            }},
        );

        return;
    }

    $self->log->trace("result: " . Dumper $cert) if $self->log->is_trace;

    my $cert_attribute = $cert->{cert_attributes};
    $self->log->trace("result: " . Dumper $cert_attribute) if $self->log->is_trace;

    my %dn = OpenXPKI::DN->new( $cert->{subject} )->get_hashed_content();

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_DETAIL_LABEL',
        shortlabel => $dn{CN}[0] || $dn{emailAddress}[0] || $cert_identifier,
    );


    # check if this is a entity certificate from the current realm
    my $is_local_entity = 0;
    if ($cert->{req_key} && $cert->{pki_realm} eq $self->session_param('pki_realm')) {
        $self->log->debug("cert is local entity");
        $is_local_entity = 1;
    }

    my @fields;

    # Add search links to subject / SAN and profile only for local entity certificates
    if ($is_local_entity) {

        push @fields, {
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT',
            format => 'link',
            value => {
                page => 'certificate!search!subject!'.uri_escape_utf8($cert->{subject}),
                label => $self-> __prepare_dn_for_display($cert->{subject}),
                target => 'top',
                tooltip => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_SIMILAR_SUBJECT',
            },
        };

        if ($cert_attribute && $cert_attribute->{subject_alt_name}) {
            my @sanlist = map {
                {
                    page => 'certificate!search!san!'.uri_escape_utf8($_),
                    label => $_,
                    target => 'top',
                    tooltip => 'I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_SIMILAR_SAN',
                }
            } @{$cert_attribute->{subject_alt_name}};
            push @fields, {
                label => 'I18N_OPENXPKI_UI_CERTIFICATE_SAN',
                value => \@sanlist,
                format => 'linklist',
            };
        }

        my $cert_profile = $self->send_command_v2( 'get_profile_for_cert', { identifier => $cert_identifier }, 1) || 'I18N_OPENXPKI_UI_CERTIFICATE_PROFILE_UNKNOWN';
        push @fields, {
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_PROFILE',
            value => $cert_profile
        };

    # this is either from another realm or not an end-entity
    } else {

        push @fields, {
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT',
            value => $self-> __prepare_dn_for_display($cert->{subject}),
        };

        push @fields, {
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_SAN',
            value => $cert_attribute->{subject_alt_name},
            'format' => 'ullist'
        } if ($cert_attribute && $cert_attribute->{subject_alt_name});


        push @fields, {
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_PROFILE',
            value => ($cert->{req_key} ? 'I18N_OPENXPKI_UI_CERTIFICATE_PROFILE_FOREIGN_REALM' : 'I18N_OPENXPKI_UI_CERTIFICATE_PROFILE_NO_ENDENTITY'),
        };

    }

    my $status_label = 'I18N_OPENXPKI_UI_CERT_STATUS_'.$cert->{status};
    my $status_tooltip = '';
    if ($cert->{revocation_time}) {
        $status_tooltip = 'I18N_OPENXPKI_UI_CERT_STATUS_REVOKED_AT: '.DateTime->from_epoch( epoch => $cert->{revocation_time} )->iso8601();
        if ($cert->{revocation_id}) {
            $status_tooltip .= sprintf(' (#0x%02x)',$cert->{revocation_id} );
        }
    }
    if ($cert->{reason_code} && $cert->{reason_code} ne 'unspecified') {
        $status_label .= sprintf(' (I18N_OPENXPKI_UI_CERTIFICATE_REASON_CODE_%s)', uc($cert->{reason_code}));
    }

    #I18N_OPENXPKI_UI_CERTIFICATE_REASON_CODE_UNSPECIFIED
    #I18N_OPENXPKI_UI_CERTIFICATE_REASON_CODE_KEYCOMPROMISE
    #I18N_OPENXPKI_UI_CERTIFICATE_REASON_CODE_CACOMPROMISE
    #I18N_OPENXPKI_UI_CERTIFICATE_REASON_CODE_AFFILIATIONCHANGED
    #I18N_OPENXPKI_UI_CERTIFICATE_REASON_CODE_SUPERSEDED
    #I18N_OPENXPKI_UI_CERTIFICATE_REASON_CODE_CESSATIONOFOPERATION

    push @fields, (
        { label => 'I18N_OPENXPKI_UI_CERTIFICATE_SERIAL', format => 'ullist',
            value => [ $cert->{cert_key_hex}, $cert->{cert_key} ],
            className => 'certserial',
        },
        { label => 'I18N_OPENXPKI_UI_CERTIFICATE_IDENTIFIER', value => $cert_identifier },
        { label => 'I18N_OPENXPKI_UI_CERTIFICATE_NOTBEFORE', value => $cert->{notbefore}, format => 'timestamp'  },
        { label => 'I18N_OPENXPKI_UI_CERTIFICATE_NOTAFTER', value => $cert->{notafter}, format => 'timestamp' },
        { label => 'I18N_OPENXPKI_UI_CERTIFICATE_STATUS', format => 'certstatus', value => {
            label => $status_label,
            value => $cert->{status},
            tooltip => $status_tooltip,
        }},
        { label => 'I18N_OPENXPKI_UI_CERTIFICATE_ISSUER', format => 'link', value => {
            label => $self-> __prepare_dn_for_display($cert->{issuer_dn}),
            page => 'certificate!chain!identifier!'. $cert_identifier,
            tooltip => 'I18N_OPENXPKI_UI_CERTIFICATE_DETAIL_ISSUER_LINK',
        }},
    );

    # certificate metadata - show only for certificates from the current or empty realm
    sub {
        my $metadata_config = $self->session_param('certdetails')->{metadata};
        return unless ($metadata_config);
        return unless (!$cert->{pki_realm} || $cert->{pki_realm} eq $self->session_param('pki_realm'));
        my $cert_attrs = $self->send_command_v2( get_cert_attributes => {
                identifier => $cert_identifier,
                attribute => 'meta_%',
                $self->__tenant() }, 1);
        return unless $cert_attrs;
        my @metadata_lines;

        for my $cfg (@$metadata_config) {
            my $line;
            if ($cfg->{template}) {
                $line = $self->send_command_v2( render_template => {
                    template => $cfg->{template},
                    params => $cert_attrs,
                });
            }
            else {
                if (defined $cert_attrs->{ $cfg->{field} }) {
                    $line = sprintf '%s: %s', $cfg->{label}, join(',', @{ $cert_attrs->{ $cfg->{field} } }) // '-';
                }
            }
            push @metadata_lines, $line if ($line);
        }

        push @fields, (
            { label => 'I18N_OPENXPKI_UI_CERTIFICATE_METADATA', value => \@metadata_lines, format => "rawlist" },
        ) if (scalar @metadata_lines);
    }->();

    # for i18n parser I18N_OPENXPKI_CERT_ISSUED CRL_ISSUANCE_PENDING I18N_OPENXPKI_CERT_REVOKED I18N_OPENXPKI_CERT_EXPIRED

    # was in info, bullet list for downloads
    my $base =  $self->_client->script_url . "?page=certificate!download!identifier!$cert_identifier!format!";
    push @fields, { label => 'I18N_OPENXPKI_UI_DOWNLOAD_LABEL', value => [
        { page => "${base}pem", label => 'I18N_OPENXPKI_UI_DOWNLOAD_PEM',  format => 'extlink' },
        { page => "${base}der", label => 'I18N_OPENXPKI_UI_DOWNLOAD_DER', format => 'extlink' },
        { page => "${base}pkcs7", label => 'I18N_OPENXPKI_UI_DOWNLOAD_PKCS7', format => 'extlink' },
        { page => "${base}pkcs7!root!true", label => 'I18N_OPENXPKI_UI_DOWNLOAD_PKCS7_WITH_ROOT', format => 'extlink' },
        { page => "${base}bundle", label => 'I18N_OPENXPKI_UI_DOWNLOAD_BUNDLE',  format => 'extlink' },
        { page => "${base}install", label => 'I18N_OPENXPKI_UI_DOWNLOAD_INSTALL', format => 'extlink' },
        { page => "certificate!text!identifier!$cert_identifier", label => 'I18N_OPENXPKI_UI_DOWNLOAD_SHOW_PEM' },
        { page => "certificate!text!format!txtpem!identifier!$cert_identifier", label => 'I18N_OPENXPKI_UI_DOWNLOAD_SHOW_TEXT' },
        ],
        format => 'linklist'
    };

    if ($is_local_entity) {

        my $baseurl = 'workflow!index!cert_identifier!'.$cert_identifier.'!wf_type!';

        my @actions;
        my $reply = $self->send_command_v2 ( "get_cert_actions", { identifier => $cert_identifier });

        $self->log->trace("available actions for cert " . Dumper $reply) if $self->log->is_trace;

        if (defined $reply->{workflow} && ref $reply->{workflow} eq 'ARRAY') {
            foreach my $item (@{$reply->{workflow}}) {
                my $page;
                if ($item->{autorun} || $item->{param}) {
                    my $action = {
                        %{$item->{param} // {}},
                        page => 'workflow!' . ($item->{autorun} ? 'start' : 'index'),
                        cert_identifier => $cert_identifier,
                        wf_type => $item->{workflow},
                    };
                    $self->log->trace("compile token" . Dumper $action) if $self->log->is_trace;
                    my $token = $self->_encrypt_jwt($action);
                    $page = 'encrypted!'.$token;
                } else {
                    $page = $baseurl.$item->{workflow};
                }
                push @actions, { page => $page, label => $item->{label}, target => 'top' };
            }
        }

        push @fields, {
            label => 'I18N_OPENXPKI_UI_CERT_ACTION_LABEL',
            value => \@actions,
            format => 'linklist'
        } if (@actions);
    }


    # hide the related link if there is no data to display or cert is not from this realm
    if (($cert->{pki_realm} eq $self->session_param('pki_realm')) &&
        ($self->send_command_v2 ( "get_cert_attributes", {
            identifier => $cert_identifier,
            attribute => "system_workflow%",
            $self->__tenant()
        }))) {
        push @fields, {
            label => 'I18N_OPENXPKI_UI_CERT_RELATED_LABEL',
            format => 'link',
            value => {
                page => 'certificate!related!identifier!'.$cert_identifier,
                label => 'I18N_OPENXPKI_UI_CERT_RELATED_HINT',
            }
        };
    }

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => '',
            description => '',
            data => \@fields,
        }},
    );

}

=head2 init_text

Show the PEM block as text in a popup

=cut

sub init_text {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');

    my $format = uc($self->param('format') || '');

    if ($format !~ /\A(TXT|PEM|TXTPEM)\z/) {
        $format = 'PEM';
    }

    my $pem = $self->send_command_v2 ( "get_cert", {'identifier' => $cert_identifier, 'format' => $format });

    $self->log->trace("Cert data: " . Dumper $pem) if $self->log->is_trace;

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_DETAIL_LABEL',
        shortlabel => $cert_identifier,
        large => ($format ne 'PEM') ? 1 : 0,
    );

    $self->main->add_section({
        type => 'text',
        content => {
            label => '',
            description => '<pre>'  . $pem . '</pre>',
        }},
    );

    return $self;


}

=head2 init_chain

Show the full chain of a certificate (subjects only) with inline download
options for PEM/DER or browser install for each item of the chain.

=cut

sub init_chain {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');

    my $chain = $self->send_command_v2 ( "get_chain", { start_with => $cert_identifier, format => 'DBINFO', 'keeproot' => 1 });

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_CHAIN_LABEL',
        shortlabel => 'I18N_OPENXPKI_UI_CERTIFICATE_CHAIN_LABEL',
    );

    # Download links
    my $base =  $self->_client->script_url . "?page=certificate!download!identifier!%s!format!%s";
    my $pattern = '<li><a href="'.$base.'" target="_blank">%s</a></li>';

    foreach my $cert (@{$chain->{certificates}}) {

        my $dl = '<ul class="list-inline">'.
            sprintf ($pattern, $cert->{identifier}, 'pem', 'I18N_OPENXPKI_UI_DOWNLOAD_SHORT_PEM').
            sprintf ($pattern, $cert->{identifier}, 'der', 'I18N_OPENXPKI_UI_DOWNLOAD_SHORT_DER').
            sprintf ($pattern, $cert->{identifier}, 'install', 'I18N_OPENXPKI_UI_DOWNLOAD_SHORT_INSTALL').
            '</ul>';

        $self->main->add_section({
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => [
                    { label => 'I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT', format => 'link', 'value' => {
                       label => $cert->{subject}, page => 'certificate!detail!identifier!'.$cert->{identifier} } },
                    { label => 'I18N_OPENXPKI_UI_CERTIFICATE_NOTBEFORE', value => $cert->{notbefore}, format => 'timestamp' },
                    { label => 'I18N_OPENXPKI_UI_CERTIFICATE_NOTAFTER', value => $cert->{notafter}, format => 'timestamp' },
                    { label => 'I18N_OPENXPKI_UI_DOWNLOAD_LABEL', value => $dl, format => 'raw' },
                ],
            }},
        );
    }

    return $self;

}

=head2 init_related

Show information related to the certificate, renders a key/value table with
a list of related workflows, owner, and metadata

=cut
sub init_related {


    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');

    my $cert = $self->send_command_v2( 'get_cert', {
        identifier => $cert_identifier,
        format => 'DBINFO',
        attribute => 'system_workflow%'
    });
    $self->log->trace("result: " . Dumper $cert) if $self->log->is_trace;

    my %dn = OpenXPKI::DN->new( $cert->{subject} )->get_hashed_content();

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_CERTIFICATE_RELATIONS_LABEL',
        shortlabel => $dn{CN}[0] || $dn{emailAddress}[0] || $cert_identifier,
    );

    # run a workflow search using the given ids from the cert attributes
    my @wfid = values %{$cert->{cert_attributes}};

    $self->log->trace("related workflows " . Dumper \@wfid) if $self->log->is_trace;

    my @result;
    if (scalar @wfid) {
        my $cert_workflows = $self->send_command_v2( 'search_workflow_instances', {
            id => \@wfid, check_acl => 1, $self->__tenant() });
        $self->log->trace("workflow results" . Dumper $cert_workflows) if ($self->log->is_trace());;

        my $workflow_labels = $self->send_command_v2( 'get_workflow_instance_types');

        foreach my $line (@{$cert_workflows}) {
            my $label = $workflow_labels->{$line->{'workflow_type'}}->{label};
            push @result, [
                $line->{'workflow_id'},
                $label || $line->{'workflow_type'},
                $line->{'workflow_state'},
                $line->{'workflow_id'},
            ];
        }
    }

    $self->main->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            label => 'I18N_OPENXPKI_UI_CERTIFICATE_RELATED_WORKFLOW_LABEL',
            actions => [{
                page => 'workflow!info!wf_id!{serial}',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                icon => 'view',
                target => 'popup',
            }],
            columns => [
                { sTitle => "I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL" },
                { sTitle => "I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL"},
                { sTitle => "I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL"},
                { sTitle => "serial", bVisible => 0 },
            ],
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        }
    });
    return $self;


}

=head2 init_download

Handle download requests, required the cert_identifier and the expected format.
Redirects to init_detail if no format is given.

=cut
sub init_download {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('identifier');
    my $format = $self->param('format');

    # No format, call detail
    if (!$format) {
        return $self->init_detail();
    }

    my $cert_info = $self->send_command_v2 ( "get_cert", {'identifier' => $cert_identifier, 'format' => 'DBINFO' });
    if (!$cert_info) {
        $self->redirect->to('certificate!search');
        return;
    }

    $self->log->trace("cert info " . Dumper $cert_info ) if $self->log->is_trace;
    my %dn = OpenXPKI::DN->new( $cert_info->{subject} )->get_hashed_content();
    my $filename = $dn{CN}[0] || $dn{emailAddress}[0] || $cert_info->{identifier};

    my $content_type = 'application/octet-string';
    my $output = '';

    if ($format eq 'pkcs7') {

        my $keeproot = $self->param('root') ? 1 : 0;
        $output = $self->send_command_v2 ( "get_chain", { start_with => $cert_identifier, bundle => 1, keeproot => $keeproot });

        $filename .= ".p7b";
        $content_type = 'application/x-pkcs7-certificates';

    } elsif ($format eq 'bundle') {

        my $chain = $self->send_command_v2 ( "get_chain", { start_with => $cert_identifier, format => 'PEM', 'keeproot' => 1 });
        $self->log->trace("chain info " . Dumper $chain ) if $self->log->is_trace;

        for (my $i=0;$i<@{$chain->{certificates}};$i++) {
            $output .= $chain->{subject}->[$i]. "\n". $chain->{certificates}->[$i]."\n\n";
        }

        $filename .= ".bundle";

    } else {

        my $cert_format = 'DER';

        if ($format eq 'txt') {
            $content_type = 'text/plain';
            $cert_format = 'TXT';
            $filename .= '.txt';
        } elsif ($format eq 'pem') {
            $filename .= '.crt';
            $cert_format = 'PEM';
        } elsif ($format eq 'der') {
            $filename .= '.cer';
        } else {
            # Default is to send the certifcate for install in binary / der form
            $filename .= '.cer';
            if ($cert_info->{issuer_identifier} eq $cert_info->{identifier}) {
                $content_type = 'application/x-x509-ca-cert';
            } else {
                $content_type = 'application/x-x509-user-cert';
            }
        }

        $output = $self->send_command_v2 ( "get_cert", {'identifier' => $cert_identifier, 'format' => $cert_format});

    }

    print $self->cgi()->header( -type => $content_type, -expires => "1m", -attachment => $filename );
    print $output;
    exit;

}

=head2 init_parse

not implemented

receive a PEM encoded x509/pkcs10/pkcs7 block and output information.

=cut
sub init_parse {

    my $self = shift;
    my $args = shift;

    my $pem = $self->param('body');

    my @fields = ({
        label => 'Body',
        value => $pem
    });

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => 'Parsed Content',
            description => '',
            data => \@fields,
        }},
    );

    return $self;

}

=head2 action_autocomplete

Handle searches via autocomplete, shows only entity certificates

=cut

sub action_autocomplete {

    my $self = shift;
    my $args = shift;

    my $term = $self->param('cert_identifier') || '';
    my $params = $self->fetch_autocomplete_params; # from OpenXPKI::Client::UI::Result

    $self->log->trace( "autocomplete query: $term") if $self->log->is_trace;


    my @result;
    # If we see a string with length of 25 to 27 with only base64 chars
    # we assume it is a cert identifier - this might fail in few cases
    # Note - we replace + and / by - and _ in our base64 strings!
    if ($term =~ /[a-zA-Z0-9-_]{25,27}/) {
        $self->log->debug( "search for identifier: $term ");
        my $search_result = $self->send_command_v2( 'get_cert', {
            identifier => $term,
            format => 'DBINFO',
        });

        if (!$search_result) {

        } elsif ($search_result->{pki_realm} ne $self->session_param('pki_realm')) {
            # silently swallow this result and stop searching
            $term = "";
        } else {
            push @result, {
                value => $search_result->{identifier},
                label => $self->_escape($search_result->{subject}),
                notbefore => $search_result->{notbefore},
                notafter => $search_result->{notafter}
            };
        }
    }

    # do not search with less then 3 letters
    if (!@result && (length($term) >= 3)) {
        my $search_result = $self->send_command_v2( 'search_cert', {
            subject => "%$term%",
            valid_before => time(),
            expires_after => time(),
            status => 'ISSUED',
            entity_only => 1,
            %$params,
            $self->__tenant(),
        });

        foreach my $item (@{$search_result}) {
            push @result, {
                value => $item->{identifier},
                label => $self->_escape($item->{subject}),
                notbefore => $item->{notbefore},
                notafter => $item->{notafter}
            };
        }
    }

    $self->log->trace( "search result: " . Dumper \@result) if $self->log->is_trace;

    $self->confined_response(\@result);

    return $self;

}

=head2 action_find

Handle search requests for a single certificate by its identifier

=cut

sub action_find {

    my $self = shift;
    my $args = shift;

    my $cert_identifier = $self->param('cert_identifier');
    if ($cert_identifier) {
        my $cert = $self->send_command_v2( 'get_cert', {  identifier => $cert_identifier, format => 'DBINFO' });
        if (!$cert) {
            $self->status->error('I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_NO_SUCH_IDENTIFIER');
            return $self->init_search();
        }
    } elsif (my $serial = $self->param('cert_serial')) {

        if ($serial =~ /[a-f]/i && substr($serial,0,2) ne '0x') {
            $serial =~ s/://g;
            $serial = '0x' . $serial;
        }
        if (substr($serial,0,2) eq '0x') {
            # strip whitespace
            $serial =~ s/\s//g;
            my $sn = Math::BigInt->new( $serial );
            $serial = $sn->bstr();
        }
        my $search_result = $self->send_command_v2( 'search_cert', {
            return_columns => 'identifier',
            cert_serial => $serial,
            entity_only => 1,
            $self->__tenant(),
        });
        if (!$search_result || @{$search_result} == 0) {
            $self->status->error('I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_NO_SUCH_SERIAL');
            return $self->init_search();

        } elsif (scalar @{$search_result} == 1) {
            $cert_identifier = $search_result->[0]->{"identifier"};

        } else {
            # found more than one item with serial
            # this is a legal use case when using external CAs
            my $spec = $self->session_param('certsearch')->{default};
            my $queryid = $self->__save_query({
                pagename => 'certificate',
                count => scalar @{$search_result},
                query => { cert_serial => $serial, entity_only => 1, $self->__tenant() },
                input => { cert_serial => scalar $self->param('cert_serial') },
                header => $self->__default_grid_head,
                column => $self->__default_grid_row,
                criteria => [ sprintf '<nobr><b>I18N_OPENXPKI_UI_CERTIFICATE_SERIAL:</b> <i>%s</i></nobr>', $self->param('cert_serial') ]
            });

            return $self->redirect->to("certificate!result!id!${queryid}");
        }
    } else {
        $self->status->error('I18N_OPENXPKI_UI_CERTIFICATE_SEARCH_MUST_PROIVDE_IDENTIFIER_OR_SERIAL');
        return $self->init_search();
    }

    $self->redirect->to('certificate!detail!identifier!'.$cert_identifier);

}

=head2 action_search

Handle search requests and display the result as grid

=cut

sub action_search {

    my $self = shift;
    my $args = shift;

    $self->log->trace("input params: " . Dumper $self->cgi()->param()) if $self->log->is_trace;

    my $query = { entity_only => 1, $self->__tenant() };
    my $input = {}; # store the input data the reopen the form later
    my $verbose = {};
    foreach my $key (qw(subject issuer_dn)) {
        my $val = $self->param($key);
        $self->log->trace("$key: " . ($val//''));
        if (defined $val && $val ne '') {
            $query->{$key} = '%'.$val.'%';
            $input->{$key} = $val;
            $verbose->{$key} = $val;
        }
    }

    foreach my $key (qw(profile issuer_identifier)) {
        my $val = $self->param($key);
        if (defined $val && $val ne '') {
            $input->{$key} = $val;
            $query->{$key} = $val;
            if ($key eq 'profile') {
                $verbose->{$key} = $self->send_command_v2( 'render_template', {
                    template => '[% USE Profile %][% Profile.name(value) %]', params => { value => $val }
                });
            } elsif ($key eq 'issuer_identifier') {
                $verbose->{$key} = $self->send_command_v2( 'render_template', {
                    template => '[% USE Certificate %][% Certificate.body(value, "subject") %]', params => { value => $val }
                });
            }
        }
    }

    if (my $status = $self->param('status')) {
        $input->{'status'} = $status;
        $verbose->{'status'} = 'I18N_OPENXPKI_UI_CERT_STATUS_'.uc($status);
        $query->{status} = $status;
    }

    # Validity
    $input->{validity_options} = [];
    foreach my $key (qw(valid_before valid_after expires_before expires_after
        revoked_before revoked_after invalid_before invalid_after valid_at)) {
        my $val = $self->param($key);
        next unless ($val);
        if ($val =~ /[^0-9]/) {
            $self->log->warn('skipping non-numeric value for validity option ' .$key);
            next;
        }
        push @{$input->{validity_options}}, { key => $key, value => $val };

        $verbose->{$key} = DateTime->from_epoch( epoch => $val )->iso8601();

        if ($key eq 'valid_at') {
            if (!$query->{valid_before} || $query->{valid_before} > $val) {
                $query->{valid_before} = $val;
            }
            if (!$query->{expires_after} || $query->{expires_after} < $val) {
                $query->{expires_after} = $val;
            }
        } else {
            $query->{$key} = $val;
        }
    }

    # Read the query pattern for extra attributes from the session
    my $spec = $self->session_param('certsearch')->{default};
    my $attr = $self->__build_attribute_subquery( $spec->{attributes} );

    if ($attr) {
        $input->{attributes} = $self->__build_attribute_preset( $spec->{attributes} );
    }

    # Add san search to attributes
    if (my $val = $self->param('san')) {
        $input->{'san'} = $val;
        # The serialization format was extended in v3.5 from a simple join
        # to use OXI::Serialize - currently this is used only for dirName
        # search needs to be fixed to find dirName items, see #755
        # if the san type was given by the user, strip it
        my $type = '%';
        if ($val =~ m{\A(\w+):(.*)}) {
            $type = $1;
            $val = $2;
        }
        $val = $self->transate_sql_wildcards($val);
        $attr->{subject_alt_name} = { -like => "$type:$val" };
    }

    if ($attr) {
        $query->{cert_attributes} = $attr;
    }

    $self->log->trace("query : " . Dumper $query) if $self->log->is_trace;


    my $result_count = $self->send_command_v2( 'search_cert_count', $query  );

    if (not defined $result_count) {
        return $self;
    }

    # No results founds
    if (!$result_count) {
        $self->status->error('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES');
        return $self->init_search({ preset => $input });
    }

    # check if there is a custom column set defined
    my ($header,  $body, $cols);
    if ($spec->{cols} && ref $spec->{cols} eq 'ARRAY') {
        ($header, $body, $cols) = $self->__render_list_spec( $spec->{cols} );
    } else {
        $body = $self->__default_grid_row;
        $header = $self->__default_grid_head;
    }

    if ($cols) {
        $query->{return_attributes} = $cols;
    }

    my %rcols;
    foreach my $ff (@{$body}) {
        next unless ($ff->{source} eq 'certificate');
        if ($ff->{field} eq 'statusclass') {
            $rcols{'status'} = 1;
        } elsif ($ff->{field} eq 'cert_key_hex') {
            $rcols{'cert_key'} = 1;
        } else {
            $rcols{ $ff->{field} } = 1;
        }
    }
    $query->{return_columns} = [ keys %rcols ];

    my @criteria;
    foreach my $item ((
        { name => 'subject', label => 'I18N_OPENXPKI_UI_CERTIFICATE_SUBJECT' },
        { name => 'san', label => 'I18N_OPENXPKI_UI_CERTIFICATE_SAN' },
        { name => 'status', label => 'I18N_OPENXPKI_UI_CERTIFICATE_STATUS'  },
        { name => 'profile', label => 'I18N_OPENXPKI_UI_CERTIFICATE_PROFILE' },
        { name => 'issuer_identifier', label => 'I18N_OPENXPKI_UI_CERTIFICATE_ISSUER' }
        )) {

        my $val = $verbose->{ $item->{name} };
        next unless ($val);
        $val =~ s/[^\w\s*\,\-\=]//g;
        push @criteria, sprintf '<nobr><b>%s:</b> <i>%s</i></nobr>', $item->{label}, $val;
    }

    foreach my $item (@{$self->__validity_options()}) {
        my $val = $verbose->{ $item->{value} };
        next unless ($val);
        push @criteria, sprintf '<nobr><b>%s:</b> <i>%s</i></nobr>', $item->{label}, $val;
    }

    my $queryid = $self->__save_query({
        pagename => 'certificate',
        count => $result_count,
        query => $query,
        input => $input,
        header => $header,
        column => $body,
        pager_args => OpenXPKI::Util::filter_hash($spec->{pager}, qw(limit pagesizes pagersize)),
        criteria => \@criteria,
    });

    $self->redirect->to('certificate!result!id!'.$queryid);

    return $self;

}

=head2 __render_result_list

Helper to render the output result list from a sql query result.


=cut
sub __render_result_list {

    my $self = shift;
    my $search_result = shift;
    my $colums = shift;

    my @result;
    foreach my $item (@{$search_result}) {

        $item->{status} = 'EXPIRED' if ($item->{status} eq 'ISSUED' && $item->{notafter} < time());

        # if you add patterns you also need to add those in init_export!
        my @line;
        foreach my $col (@{$colums}) {
            if ($col->{field} eq 'status') {
                push @line, { label => 'I18N_OPENXPKI_UI_CERT_STATUS_'.$item->{status} , value => $item->{status} };
            } elsif ($col->{field} eq 'statusclass') {
                push @line, lc($item->{status});
            } elsif ($col->{field} eq 'cert_key_hex') {
                push @line, unpack('H*', Math::BigInt->new( $item->{cert_key})->to_bytes );
            } else {
                push @line, $item->{  $col->{field} };
            }
        }
        push @result, \@line;

    }

    return @result;

}


=head2 __render_list_spec

Create array to pass to UI from specification in config file

=cut

sub __render_list_spec {

    my $self = shift;
    my $cols = shift;

    my @header;
    my @column;
    my @attrib;

    for (my $ii = 0; $ii < scalar @{$cols}; $ii++) {

        # we must create a copy as we change the hash in the session info otherwise
        my %col = %{$cols->[$ii]};
        my $head = { sTitle => $col{label} };
        if ($col{sortkey}) {
            $head->{sortkey} = $col{sortkey};
        }
        if ($col{format}) {
            $head->{format} = $col{format};
        }
        push @header, $head;

        if ($col{template}) {

        } elsif ($col{field} =~ m{\A (csr|attribute)\.(\S+) }xi) {
            # we use this later to avoid the pattern match
            $col{source} = $1;
            $col{field} = $2;

            push @attrib, $2 if ($1 eq 'attribute');
        } else {
            $col{source} = 'certificate';
            $col{field} = $col{field}

        }
        push @column, \%col;
    }

    push @header, { sTitle => 'identifier', bVisible => 0 };
    push @header, { sTitle => "_className"};

    push @column, { source => 'certificate', field => 'identifier' };
    push @column, { source => 'certificate', field => 'statusclass' };

    return ( \@header, \@column, \@attrib );
}

sub __prepare_dn_for_display {

    my $self = shift;
    my $dn = shift;
    my @dn = OpenXPKI::DN->new( $dn )->get_rdns();
    for (my $ii=1; $ii < @dn; $ii++ ) {
        $dn[$ii-1] .= ',';
    }
    return \@dn;
}

__PACKAGE__->meta->make_immutable;
