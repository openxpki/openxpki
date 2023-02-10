package OpenXPKI::Workflow::Field;
use Moose;

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::MooseParams;
use OpenXPKI::Workflow::Factory;

has 'config' => (
    is => 'rw',
    isa => 'Connector',
    required => 1,
);

has 'path' => (
    is => 'rw',
    isa => 'ArrayRef',
    required => 1,
);

has 'field' => (
    is => 'rw',
    isa => 'HashRef',
    required => 1,
);


sub process {
    my $class = shift;
    my $self = $class->new(@_);

    # "type" default
    $self->field->{type} //= 'text';

    # set "clonable" attribute
    $self->field->{clonable} = (defined $self->field->{min} || $self->field->{max}) ? 1: 0;

    # process select options
    if ($self->field->{type} eq 'select') {
        $self->legacy_options or $self->resolve_options;
    }

    # create "ecma_match"
    $self->perlre_to_ecma;

    return $self->field;
}

# TODO - Backward compatibility: up to v3.1 select fields in form elements only had a list directly attached
sub legacy_options {
    my $self = shift;

    return 0 unless ref $self->field->{option} eq 'ARRAY';

    $self->field->{option} = [
        map {
            { label => $_, value => $_ }
        } @{$self->field->{option}}
    ];
    return 1;
}

# Check for option tag and do explicit calls to ensure recursive resolving.
sub resolve_options {
    my $self = shift;

    my $mode = $self->config->get( [ @{$self->path}, 'option', 'mode' ] ) || 'list';
    my @options;

    if ($mode eq 'keyvalue') {
        @options = $self->config->get_list( [ @{$self->path}, 'option', 'item' ] );
        if (my $label = $self->config->get( [ @{$self->path}, 'option', 'label' ] )) {
            @options = map { { label => sprintf($label, $_->{label}, $_->{value}), value => $_->{value} } } @options;
        }
    } else {
        my @item;
        if ($mode eq 'keys' || $mode eq 'map') {
            @item = sort $self->config->get_keys( [ @{$self->path}, 'option', 'item' ] );
        } else {
            # option.item holds the items as list, this is mandatory
            @item = $self->config->get_list( [ @{$self->path}, 'option', 'item' ] );
        }

        if ($mode eq 'map') {
            # Expects 'item' to be a link to a deeper hash structure where each
            # hash item has a key "label" set. Hides items with an empty label.
            foreach my $key (@item) {
                my $label = $self->config->get( [ @{$self->path}, 'option', 'item', $key, 'label' ] );
                next unless ($label);
                push @options, { value => $key, label => $label };
            }
        }
        # if "label" is set, we generate the values from option.label + key
        elsif (my $label = $self->config->get( [ @{$self->path}, 'option', 'label' ] )) {
            @options = map { { value => $_, label => $label.'_'.uc($_) } } @item;
        }
        # the minimum default - use keys as labels
        else {
            @options = map { { value => $_, label => $_  } } @item;
        }
    }

    $self->field->{option} = \@options;
}

# Tries to convert the Perl RegEx in 'match' into an ECMA compatible version.
# Returns nothing if the Perl RegEx contains special sequences that cannot be
# translated.
sub perlre_to_ecma {
    my $self = shift;

    my $perl_re = $self->field->{match}
        or return;

    # stop if Perl RegEx contains non-translatable sequences
    return if (
        $perl_re =~ / (?<!\\) (\\\\)* \\([luLUxpPNoQEraevhGXK]|[04]\d+)/x # special escape sequences
        or $perl_re =~ / ^\[:[^\:\]]+:\] /x # character classes
    );

    my $ecma_re = $perl_re;
    $ecma_re =~ s/ (?<!\\) (\\\\)* \s+ /$1 || ''/gxe; # remove whitespace after even number of backslashes (or none)
    $ecma_re =~ s/ \\ (\s+) /$1/gx;            # remove backslash of escaped whitespace
    $ecma_re =~ s/^\\A/^/;                     # \A -> ^
    $ecma_re =~ s/\\[zZ]$/\$/;                 # \z -> $

    $self->field->{ecma_match} = $ecma_re;
}

__PACKAGE__->meta->make_immutable;
