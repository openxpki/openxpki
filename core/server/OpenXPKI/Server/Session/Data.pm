package OpenXPKI::Server::Session::Data;
use Moose;
use utf8;

# CPAN modules
use Data::UUID;
use Digest::SHA qw( sha1_hex );
use JSON;

# Project modules
use OpenXPKI::Exception;
use OpenXPKI::MooseParams;
use OpenXPKI::Debug;

=head1 NAME

OpenXPKI::Server::Session::Data - data object with some helper methods but no
application logic

=cut

################################################################################
# Attributes
#
has is_dirty => ( is => 'rw', isa => 'Bool', init_arg => undef, default => 0);
has _is_empty => ( is => 'rw', isa => 'Bool', init_arg => undef, default => 1);

# handler that gets triggered on attribute changes
sub _attr_change {
    my ($self, $val, $old_val) = @_;
    $self->_is_empty(0);
    $self->is_dirty(1);
}

# create several Moose attributes
my %ATTR_TYPES = (
    # ID is automatically set for new (empty) sessions
    id                   => { isa => 'Str', lazy => 1, default => sub { Data::UUID->new->create_b64 }, },
    created              => { isa => 'Int', default => sub { time } },
    modified             => { isa => 'Int', }, # will be set before session is persisted
    user                 => { isa => 'Str', },
    role                 => { isa => 'Str', },
    pki_realm            => { isa => 'Str', },
    challenge            => { isa => 'Str', },
    authentication_stack => { isa => 'Str', },
    language             => { isa => 'Str', },
    status               => { isa => 'Str', },
    is_valid             => { isa => 'Bool', default => 0 },
    ip_address           => { isa => 'Str', },
    ui_session           => { isa => 'Str', },
    _secrets => {
        # we do not use "default => sub { {} }" as this would confuse code that
        # detects if this Moose attribute was set.
        isa => 'HashRef',
        traits => ['Hash'],
        handles => {
            _set_secret => 'set',
            _get_secret => 'get',
            _delete_secret => 'delete',
        },
    },
);
for my $name (keys %ATTR_TYPES) {
    my $type_def = $ATTR_TYPES{$name};
    has $name => (
        %$type_def,
        is => 'rw',
        trigger => sub { shift->_attr_change },
        documentation => 'session',
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

=cut

sub BUILD {
    my $self = shift;
    # Install methods modifiers to set is_dirty whenever one of the clearers
    # built by Moose is called.
    # (we do that here to allow for easy subclassing and addition of attributes)
    for my $attr (@{ $self->get_attribute_names }) {
        ##! 16: "creating method clear_$attr"
        $self->meta->add_method("clear_$attr" => sub {
            my $inner_self = shift;
            $inner_self->is_dirty(1);
            $inner_self->meta->find_attribute_by_name($attr)->clear_value($inner_self);
        });
    }
}

=head1 METHODS

=head2 get_attribute_names

Returns an ArrayRef containing the names of all session attributes.

=cut
sub get_attribute_names {
    my $self = shift;
    my $meta = $self->meta;

    return [
        map { $_->name }
        grep { $_->documentation and $_->documentation eq "session" }
        sort $meta->get_all_attributes
    ];
}

=head2 Session attributes

The following methods are available to access the session attributes:

    getter/setter           clearer
    --------------------------------------------------
    id                      clear_id
    user                    clear_user
    role                    clear_role
    pki_realm               clear_pki_realm
    challenge               clear_challenge
    authentication_stack    clear_authentication_stack
    language                clear_language
    status                  clear_status
    ip_address              clear_ip_address
    created                 clear_created
    modified                clear_modified
    ui_session              clear_ui_session


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
        my %all_attrs = ( map { $_ => 1 } @{ $self->get_attribute_names } );
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
        @names = @{ $self->get_attribute_names };
    }

    return { map { $_ => $self->$_ } grep { $self->meta->find_attribute_by_name($_)->has_value($self) } @names };
}

=head2 secret

Set or get the secret of the given group (default group: "").

B<Named parameters>

=over

=item * group - optional: the secrets group

=item * value - optional: the value to set

=back

=cut
sub secret {
    my ($self, %params) = named_args(\@_,   # OpenXPKI::MooseParams
        group => { isa => 'Str' },
        value => { isa => 'Str' },
    );
    my $digest = sha1_hex($params{group} || "");

    # getter
    return $self->_get_secret($digest) unless $params{value};
    # setter
    $self->_set_secret($digest => $params{value});
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
    $self->_delete_secret($digest);
}

=head1 METHODS

=head2 freeze

Serializes the session attributes into a string. The first characters of the
string until the first colon indicate the type of serialization (encoder ID).

Returns a string with the serialized data.

B<Named parameters>

=over

=item * only - C<ArrayRef> of attributes that shall be included (optional,
default: all attributes)

=item * except - C<ArrayRef> of attributes that shall be excluded (optional)

=back

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

    my $data_hash;
    # backwards compatibility
    if ($frozen =~ /^HASH\n/ ) {
        use OpenXPKI::Serialization::Simple;
        $data_hash = OpenXPKI::Serialization::Simple->new->deserialize($frozen);
    }
    else {
        OpenXPKI::Exception->throw(message => "Unknown format of serialized data")
            unless $frozen =~ /^JSON:/;
        $frozen =~ s/^JSON://;
        $data_hash = decode_json($frozen);
    }

    # set session attributes via accessor methods
    $self->$_($data_hash->{$_}) for keys %$data_hash;

    return $self;
}

# this Moose instance MUST NOT be made immutable as we add methods in BUILD()
1;
