package OpenXPKI::Server::Session::Data;
use Moose;
use utf8;

# CPAN modules
use Data::UUID;
use Digest::SHA qw( sha1_hex );

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::MooseParams;

=head1 NAME

OpenXPKI::Server::Session::Data - data object with some helper methods but no
application logic

=cut

################################################################################
# Attributes
#
has _is_persisted => ( is => 'rw', isa => 'Bool', init_arg => undef, default => 0);
has _is_empty     => ( is => 'rw', isa => 'Bool', init_arg => undef, default => 1);

# handler that gets triggered on attribute changes
sub _attr_change {
    my ($self, $val, $old_val) = @_;
    OpenXPKI::Exception->throw(message => "Attempt to modify session data after it has been persisted")
        if $self->_is_persisted;
    $self->_is_empty(0);
}

# automatically set for new (empty) sessions
has id => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { Data::UUID->new->create_b64 },
    trigger => sub { shift->_attr_change },
);

# create several Moose attributes
my %ATTR_TYPES = (
    user                 => { is => 'rw', isa => 'Str', },
    role                 => { is => 'rw', isa => 'Str', },
    pki_realm            => { is => 'rw', isa => 'Str', },
    challenge            => { is => 'rw', isa => 'Str', },
    authentication_stack => { is => 'rw', isa => 'Str', },
    language             => { is => 'rw', isa => 'Str', },
    status               => { is => 'rw', isa => 'Str', },
    ip_address           => { is => 'rw', isa => 'Str', },
    created              => { is => 'rw', isa => 'Int', },
    modified             => { is => 'rw', isa => 'Int', },
    _secrets             => { is => 'rw', isa => 'HashRef', default => sub { {} }, },
);
for my $name (keys %ATTR_TYPES) {
    my $type_def = $ATTR_TYPES{$name};
    has $name => (
        %$type_def,
        trigger => sub { shift->_attr_change },
    );
}

################################################################################
# Methods
#
# Please note that some method names are intentionally chosen to contain action
# prefixes like "get_" to distinct them from the accessor methods of the session
# attributes (data).
#

=head1 STATIC CLASS METHODS

=head2 get_attribute_names

Returns an ArrayRef containing the names of all session attributes.

=cut
sub get_attribute_names {
    return [ sort ("id", "modified", keys %ATTR_TYPES) ];
}

=head1 METHODS

=head2 get_attributes

Returns a HashRef containing names and values of all previously set session
attributes.

B<Parameters>

=over

=item * @attrs - optional: list of attribute names if only a subset shall be returned.

=back

=cut
sub get_attributes {
    my ($self, @attrs) = @_;
    my @names;
    # Check given attribute names
    if (scalar(@attrs)) {
        my %all_attrs = ( map { $_ => 1 } @{ get_attribute_names() } );
        for my $name (@attrs) {
            OpenXPKI::Exception->throw(
                message => "Unknown session attribute requested",
                params => { attr => $name },
            ) unless $all_attrs{$name};
        }
        @names = @attrs;
    }
    # or use all attributes per default
    else {
        @names = @{ get_attribute_names() };
    }

    return { map { $_ => $self->$_ } grep { $self->meta->find_attribute_by_name($_)->has_value($self) } @names };
}

=head2 secret

Set or get the secret of the given group (default group: "").

B<Named parameters>

=over

=item * group - optional: the secrets group

=item * secret - optional: the value to set

=back

=cut
sub secret {
    my ($self, %params) = named_args(\@_,   # OpenXPKI::MooseParams
        group => { isa => 'Str' },
        secret => { isa => 'Str' },
    );
    my $digest = sha1_hex($params{group} || "");

    # getter
    return $self->_secrets->{$digest} unless $params{secret};
    # setter
    $self->_secrets->{$digest} = $params{secret};
}

=head2 clear_secret

Clear (delete) the secret of the given group (default group: "").

B<Named parameters>

=over

=item * group - optional: the secrets group

=back

=cut
sub clear_secret {
    my ($self, %params) = named_args(\@_,   # OpenXPKI::MooseParams
        group => { isa => 'Str' },
    );
    my $digest = sha1_hex($params{group} || "");
    delete $self->_secrets->{$digest};
}

=head1 METHODS

=head2 freeze

Serializes the session attributes into a string. The first characters of the
string until the first colon indicate the type of serialization (encoder ID).

Returns a string with the serialized data.

=cut
sub freeze {
    my ($self, %params) = named_args(\@_,   # OpenXPKI::MooseParams
        except => { isa => 'ArrayRef', optional => 1 },
        only => { isa => 'ArrayRef', optional => 1 },
    );

    my $data_hash = $params{only}
        ? $self->get_attributes(@{ $params{only} })
        : $self->get_attributes;

    if ($params{except}) {
        delete $data_hash->{$_} for @{ $params{except} };
    }

    return "JSON:".encode_json($data_hash);
}

=head2 thaw

Deserializes the session attributes from a string and sets them. Attributes
which are not mentioned will not be touched.

The first characters of the string until the first colon must indicate the type
of serialization (encoder ID).

Returns the object instance (allows for method chaining).

=cut
sub thaw {
    my ($self, $frozen) = @_;

    # backwards compatibility
    if ($frozen =~ /^HASH\n/ ) {
        use OpenXPKI::Serialization::Simple;
        return OpenXPKI::Serialization::Simple->new->deserialize($frozen);
    }

    OpenXPKI::Exception->throw(message => "Unknown format of serialized data")
        unless $frozen =~ /^JSON:/;
    $frozen =~ s/^JSON://;

    my $data_hash = decode_json($frozen);
    # set session attributes via accessor methods
    $self->$_($data_hash->{$_}) for keys %$data_hash;

    return $self;
}

1;
