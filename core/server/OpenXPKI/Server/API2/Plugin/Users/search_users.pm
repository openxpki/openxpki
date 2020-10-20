package OpenXPKI::Server::API2::Plugin::Users::search_users;
use OpenXPKI::Server::API2::EasyPlugin;
=head1 NAME

OpenXPKI::Server::API2::Plugin::Users::search_users

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

# parameters common for search_users and search_users_count
my %common_params = (
    pki_realm => { isa => 'AlphaPunct' },
    username                  => { isa => 'Str' },
    realname   => { isa => 'Str' },
    mail   => { isa => 'Str' },
    role   => { isa => 'Str' },
);

command "search_users" => {
    %common_params,
    limit                    => { isa => 'Int' },
    order                    => { isa => 'Str' },
    reverse                  => { isa => 'Bool' },
    start                    => { isa => 'Int' },
} => sub {
 my ($self, $params) = @_;
    # assemble sql query
    my $sql_params =$self->_make_db_query($params);
    if ( $params->has_limit ) {
        $sql_params->{limit} = $params->limit;
        $sql_params->{offset} = $params->start if $params->has_start;
    }
    # Custom ordering
    my $desc = "-"; # not set or 0 means: DESCENDING, i.e. "-"
    $desc = "" if $params->has_reverse and $params->reverse == 0;

    if ($params->has_order) {
        if ($params->order) {
            my $col = lc($params->order);
            $sql_params->{order_by} =  $desc.$col;
        }
    }
    # execute sql query and return results
    my $result = CTX('dbi')->select_hashes(
       %{$sql_params}
    );

    return $result;

};

command "search_users_count" => {
    %common_params
} => sub {
    my ($self, $params) = @_;
    # get base sql query and count rows
    my $sql_params = $self->_make_db_query($params);
    return CTX('dbi')->count(
        %{$sql_params}
    );
};


sub _make_db_query {
    my ($self, $po) = @_;
    my $where = {};
    my $params = {
        from => 'users',
        columns =>  [ '*' ],
        where => $where,
    };
    # fuzzy search for username, mail and realname if provided
    $where->{'username'} = { -like => $po->username} if ( $po->has_username );
    $where->{'mail'} = { -like => $po->mail} if ( $po->has_mail ) ;
    $where->{'realname'} = { -like => $po->realname} if ( $po->realname );
    # exact search for role if provided
    $where->{'role'} = $po->role if ( $po->role );
    # if pki_realm is not set explicitly: set to current pki_realm
    if (not $po->has_pki_realm) {
        $where->{'pki_realm'} = CTX('session')->data->pki_realm;
    } elsif ($po->pki_realm !~ /_any/i) {
        $where->{'pki_realm'} = $po->pki_realm;
    }

    return $params;
};

__PACKAGE__->meta->make_immutable;
