package OpenXPKI::Workflow::Field;
use OpenXPKI -class;

# Project modules
use OpenXPKI::Server::Context qw( CTX );

has 'config' => (
    is => 'rw',
    isa => 'Connector',
    lazy => 1,
    default => sub { CTX('config') },
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

has 'is_profile_field' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has 'log' => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    default => sub { CTX('log')->workflow },
);


# B<Please note>: this will modify the given C<$field> I<HashRef> in-place!
sub process ($class, @args) {
    my $self = $class->new(@args);

    # default "type"
    $self->field->{type} //= 'text';

    # attributes after transformation (only profile fields): "renew", "preset"
    $self->transform_profile_field if $self->is_profile_field;

    # set "clonable" attribute
    # ("min:0" is legacy syntax for "optional" and does NOT indicate a clonable field)
    $self->field->{clonable} = (
        $self->field->{clonable} or
        $self->field->{min} or
        $self->field->{max}
    ) ? 1 : 0;

    # process select options
    if ($self->field->{type} eq 'select') {
        $self->legacy_options or $self->resolve_options;
    }

    $self->resolve_keys;

    # create "ecma_match"
    $self->perlre_to_ecma;

    return $self->field;
}

# TODO - Backward compatibility: up to v3.1 select fields in form elements only had a list directly attached
sub legacy_options ($self) {
    return 0 unless ref $self->field->{option} eq 'ARRAY';
    my @items = $self->field->{option}->@*;

    # treat empty first item as flag for placeholder for required fields
    if ($items[0] =~ /^\s*$/ and $self->field->{required} and not $self->field->{placeholder}) {
        shift @items;
        $self->field->{placeholder} = '_default'; # magic value processed in htdocs_source/app/components/oxi-section/form/field/select/index.js
    }

    $self->field->{option} = [
        map { { label => $_, value => $_ } } @items
    ];
    return 1;
}

# "option" attribute: do explicit calls to ensure recursive config resolving.
sub resolve_options ($self) {
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

# "keys" attribute: do explicit calls to ensure recursive config resolving.
# (e.g. for SAN fields with dynamic key/value assignment)
sub resolve_keys ($self) {
    return unless $self->field->{keys};

    my @keys;
    my $size = $self->config->get_size([ @{$self->path}, 'keys' ]);
    for (my $i=0; $i<$size; $i++) {
        my $key = $self->config->get_hash([ @{$self->path}, 'keys', $i ]);
        push @keys, { value => $key->{value}, label => $key->{label} };
    }

    $self->field->{keys} = \@keys;
}

# Tries to convert the Perl RegEx in 'match' into an ECMA compatible version.
# Returns nothing if the Perl RegEx contains special sequences that cannot be
# translated.
sub perlre_to_ecma ($self) {
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

=head2 _transform_profile_field

Translate legacy and profile-only field attributes (e.g. C<keep>, C<default>
for placeholder, etc.) to get a definition that matches workflow fields.

=cut
sub transform_profile_field ($self) {

    my $name = $self->field->{name} // $self->field->{id};

    $self->log->trace("Field '$name': profile spec = " . Dumper $self->field) if $self->log->is_trace;

    # type "freetext" -> "text"
    $self->field->{type} = 'text' if ($self->field->{type} // '') eq 'freetext';

    # id -> name
    $self->field->{name} ||= $self->field->{id};
    delete $self->field->{id};

    # renewal option
    $self->field->{renew} //= 'preset';

    # default to "required" unless explicitely set or...
    $self->field->{required} //= 1 unless (
        (defined $self->field->{min} && $self->field->{min} == 0) or
        ($self->field->{type} eq 'static')
    );

    # support legacy name "default" for "placeholder"
    $self->field->{placeholder} //= $self->field->{default} if $self->field->{default};
    delete $self->field->{default};

    # support legacy usage of "description" for "tooltip"
    $self->field->{tooltip} //= $self->field->{description} if $self->field->{description};

    $self->log->trace("Field '$name': transformed to wf spec = " . Dumper $self->field) if $self->log->is_trace;
}

=head2 validate

Expect a value for the field which can be either a scalar or a list ref.

The method checks if the number of arguments matches min/max/required and
validates the values against a given regex (via match)

=cut
sub validate($self, $value) {

    my $field = $self->field;
    my $name = $field->{name};
    my $min = $field->{min} || 0;
    my $max = $field->{max} || 0;
    my $required = $field->{required} || 0;
    my $match = $field->{match} || '';

    my @value;
    if ( !defined $value ) {
        # noop
    } elsif (ref $value eq 'ARRAY') {
        @value = @{$value};
    } elsif ( $value ne '' ) {
        @value = ( $value );
    }

    my @fields_with_error;

    my @nonempty = grep { (defined $_ && $_ ne '') } @value;

    if (@nonempty < $min) {
        push @fields_with_error, { name => $name, min => $min,
            error => 'I18N_OPENXPKI_UI_VALIDATOR_INPUT_FIELD_LESS_THAN_MIN_COUNT' };

    } elsif ($max && $max < scalar @nonempty) {
        # push an error to the fields that need to be removed
        my $ii = scalar @nonempty;
        do {
            push @fields_with_error, { name => $name, max => $max, index => --$ii,
                error => 'I18N_OPENXPKI_UI_VALIDATOR_INPUT_FIELD_MAX_COUNT_EXCEEDED' };
        } while ($ii > $max);
    }

    if ($required && @nonempty == 0) {
        push @fields_with_error, { name => $name,
            error => 'I18N_OPENXPKI_UI_VALIDATOR_INPUT_FIELD_REQUIRED_BUT_EMPTY' };
    }

    if ($match) {
        my $ii = 0;
        foreach my $val (@nonempty) {
            if ($val ne '' && $val !~ m{$match}xs) {
                # should be a bit smarter to highlight the right one
                push @fields_with_error, { name => $name,
                    error => 'I18N_OPENXPKI_UI_VALIDATOR_INPUT_FIELD_FAILED_REGEX', index => $ii };
            }
            $ii++;
        }
    }

    return @fields_with_error;
}

__PACKAGE__->meta->make_immutable;
