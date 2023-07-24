package OpenXPKI::Client::UI::Role::Pager;
use Moose::Role;

# requires qw( );

# CPAN modules
use Type::Params qw( signature_for );
use Types::Standard;

use experimental 'signatures'; # should be done after imports to safely disable warnings in Perl < 5.36


=head2 __build_pager

Return a pager definition hash with default settings, requires the query
result hash as argument. Defaults can be overriden passing a hash as second
argument.

=cut
signature_for __build_pager => (
    method => 1,
    named => [
        pagename => 'Str',
        id => 'Str',
        query => 'Dict['.
            'order => Optional[Str],'.
            'reverse => Optional[Bool],'.
            'Slurpy[ HashRef ]'.
        ']',
        count => 'Int',
        limit => 'Int', { default => 50 },
        startat => 'Int', { default => 0 },
        pagesizes => Types::Standard::ArrayRef
            ->plus_coercions(Types::Standard::Str, sub { [ split /\s*,\s*/, $_ ] }),
            { default => sub { [ 25, 50, 100, 250, 500 ] } },
        pagersize => 'Int', { default => 20 },
    ],
);
sub __build_pager ($self, $arg) {
    my $limit = $arg->limit;
    $limit = 500 if $limit > 500; # safety rule

    my @pagesizes = $arg->pagesizes->@*;
    if (!grep (/^$limit$/, @pagesizes) ) {
        push @pagesizes, $limit;
        @pagesizes = sort { $a <=> $b } @pagesizes;
    }

    return {
        pagerurl => $arg->pagename.'!pager!id!'.$arg->id,
        count => $arg->count * 1, # enforce number for JSON encoding
        limit => $limit,
        startat => $arg->startat,
        pagesizes => \@pagesizes,
        pagersize => $arg->pagersize,
        order => $arg->query->{order} || '',
        reverse => $arg->query->{reverse} ? 1 : 0,
    }
}

1;
