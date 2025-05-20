package OpenXPKI::Connector::DataPool;
use OpenXPKI -class;

extends 'Connector';

use OpenXPKI::Server::Context qw( CTX );

has key => (
    is  => 'ro',
    isa => 'Str',
    default => '',
);

has value => (
    is  => 'rw',
    isa => 'HashRef|Str',
);

has encrypt => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has noforce => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has nested => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

sub _get_node {

    my $self = shift;
    my $args = shift;
    my $params = shift // {};

    my @args = $self->_build_path( $args );

    my $datapool_key;
    # nested mode
    if ($self->nested()) {

        # do we have a fixed key
        if ($self->key() ne '') {
            $datapool_key = $self->key();
        } else {
            $datapool_key = shift @args;
        }

        $self->log->trace('Datapool key is '.$datapool_key.', path args . ' . Dumper \@args )
            if $self->log->is_trace;

        # enforce deserialize even for get with non-empty path
        $params->{try_deserialize} = 'simple' if (@args);

    # regular mode
    } else {

        my $ttarg = { ARGS => \@args };
        if (defined $params->{extra}) {
            $ttarg->{EXTRA} = $params->{extra};
        }

        $self->log->trace('Template args ' . Dumper $ttarg ) if $self->log->is_trace;

        # Process the key using template if necessary
        $datapool_key = OpenXPKI::Template->new()->render($self->key(), $ttarg);

    }

    # if we do not have a key, something went wrong
    die "datapool key is not set after input processing"
        unless ($datapool_key);


    # Time to load the content from the datapool
    my $result = CTX('api2')->get_data_pool_entry(
        'namespace' => $self->LOCATION(),
        'key' => $datapool_key,
        $params->{try_deserialize} ? ('try_deserialize' => $params->{try_deserialize}) : (),
    );

    if (!defined $result) {
        return $self->_node_not_exists();
    }

    # no post processing required
    if (!$self->nested() || !@args) {
        return $result->{value};
    }

    my $ptr = $result->{value};
    while ( scalar @args > 1 ) {
        my $entry = shift @args;
        if ( exists $ptr->{$entry} ) {
            if ( ref $ptr->{$entry} eq 'HASH' ) {
                $ptr = $ptr->{$entry};
            }
            else {
                return $self->_node_not_exists( ref $ptr->{$entry} );
            }
        } else {
            return $self->_node_not_exists($entry);
        }
    }

    return $ptr->{ shift @args };

}


sub get {

    my $self = shift;
    my $args = shift;
    my $params = shift // {};

    my $val = $self->_get_node($args, $params);

    return unless defined $val;

    if (ref $val ne '') {
        die "requested value is not a scalar";
    }
    return $val;

}

sub get_list {

    my $self = shift;
    my $args = shift;
    my $params = shift // {};
    $params->{try_deserialize} = 'simple';

    my $val = $self->_get_node($args, $params);

    return unless defined $val;

    if (ref $val ne 'ARRAY') {
        die "requested value is not a list";
    }
    return @{$val};

}

sub get_hash {

    my $self = shift;
    my $args = shift;
    my $params = shift // {};
    $params->{try_deserialize} = 'simple';

    my $val = $self->_get_node($args, $params);

    return unless defined $val;

    if (ref $val ne 'HASH') {
        die "requested value is not a hash";
    }
    return $val;

}

sub get_meta {

    my $self = shift;
    my $args = shift;
    my $params = shift // {};
    $params->{try_deserialize} = 'simple';

    my $val = $self->_get_node($args, $params);

    return unless defined $val;

    my $map = {
        '' => 'scalar',
        'ARRAY' => 'list',
        'HASH' => 'hash',
    };
    my $type = $map->{ref $val} or die "Unknown data structure";
    return { TYPE => $type };

}

sub set {

    my $self = shift;
    my $args = shift;
    my $value = shift;
    my $params = shift;

    my @args = $self->_build_path( $args );

    $self->log->trace('Set called on ' . Dumper \@args ) if $self->log->is_trace;

    my $template = Template->new({});

    my $ttarg = {
        ARGS => \@args
    };

    if (defined $params->{extra}) {
        $ttarg->{EXTRA} = $params->{extra};
    }

    $self->log->trace('Template args ' . Dumper $ttarg ) if $self->log->is_trace;
    # Process the key using template
    my $key = $self->key();
    my $parsed_key;
    $template->process(\$key, $ttarg, \$parsed_key) || die "Error processing argument template";

    # Parse values
    my $dpval;
    my $valmap = $self->value();
    my $serialize = 0;

    if (ref $valmap eq '') {
        $template->process(\$valmap, $ttarg, \$dpval);
    } elsif (ref $valmap eq 'HASH') {
        foreach my $key (keys %{$valmap}) {
            my $val;
            $template->process(\$valmap->{$key}, $ttarg, \$val);
            $dpval->{$key} = $val if ($val && $val ne '');
        }
        $serialize = 1;
    } else {
        die "Wrong value type: expected scalar or HASH ref, got: " . ref $valmap;
    }

    $self->log->trace("Namespace key = '$parsed_key', value = " . Dumper $dpval) if $self->log->is_trace;

    CTX('api2')->set_data_pool_entry(
        'namespace' => $self->LOCATION(),
        'key' => $parsed_key,
        'value' => $dpval,
        $serialize ? ('serialize' => 'simple') : (),
        'encrypt' => $self->encrypt(),
        'force' => not $self->noforce(),
    );

    return 1;

}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

OpenXPKI::Connector::DataPool;

=head1 DESCRIPTION

Connector to interact with the datapool, the LOCATION defines the namespace.
If you pass additional parameters (e.g. from workflow context) by setting
{ extra => ... } in the control parameter, those values are available in the
EXTRA hash inside all template operations.

=head1 Operation

=head2 get mode

Render the string used as datapool key from the connector arguments using
the value given to the I<key> parameter as template toolkit string.

The C<get> method returns the content found as scalar, serialized objects
are returned as serialized blob.

Using C<get_hash> and C<get_list> the connector tries to derserialize
the object found and returns it as hash/list in case the data type
matches. The connector dies if the data found is of a different type
or the content can not be deserialized at all.

=head2 get mode, nested

If the I<nested> flag is set, the connector arguments are used to find
items inside the serialized data structure.

If the I<key> value is set to a non-empty value, it is used as key to
load the payload from the datapool. If I<key> is not set, the first
argument given to the connector is used instead.

The value found in the datapool is deserialized, the arguments are used
to find a node in the resulting data structure, lists are not supported
at this stage.

The value found at the end of the path is returned if the data type
matches the request.

=head2 set mode

Generates the payload based on the connector arguments and the template
given to I<value>. If I<value> is a scalar, the result is a single scalar
item. If I<value> is a hash, the resulting value is also a hash where the
keys are used as is and each value is interpreted as a template string,
values that evaluate to the empty string are ignored.

The hash is stored using the internal serialization of the datapool.

=head1 Parameters

=over

=item key

Scalar, evaluated using template toolkit.

=item value (set only)

Template toolkit string used to render the datapool value from the given
connector arguments.

=item encrypt (set only)

boolean, weather to encrypt the datapool item.

=item noforce (set only)

boolean, by default the set command uses the I<force> flag to overwrite any
exitings items in the datapool. If this is true, the force will not be set
which causes the connector to die if the key already exists.

=item nested (get* only)

boolean, turn on nested mode.

=back

