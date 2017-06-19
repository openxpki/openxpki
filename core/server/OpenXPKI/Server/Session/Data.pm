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
has backend => ( is => 'ro', does => 'OpenXPKI::Server::Session::DriverRole' );
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
    # DO NOT use "lazy => 1" as Log::Log4perl::MDC->put would not be called immediately
    default => sub {
        my $id = Data::UUID->new->create_b64;
        Log::Log4perl::MDC->put('sid', substr($id,0,4));
        return $id;
    },
    trigger => sub {
        my ($self, $new, $old) = @_;
        Log::Log4perl::MDC->put('sid', substr($new,0,4));
        $self->_attr_change;
    },
);

# create several Moose attributes
my %ATTR_TYPES = (
    user                    => 'Str',
    role                    => 'Str',
    pki_realm               => 'Str',
    challenge               => 'Str',
    authentication_stack    => 'Str',
    language                => 'Str',
    state                   => 'Str',
    ip_address              => 'Str',
    created                 => 'Int',
    modified                => 'Int',
    _secrets                => 'HashRef',
);
for my $name (keys %ATTR_TYPES) {
    my $type = $ATTR_TYPES{$name};
    has $name => (
        is => 'rw',
        isa => $ATTR_TYPES{$name},
        trigger => sub { shift->_attr_change },
        $type eq "HashRef" ? (default => sub { {} }) : (),
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

Returns a HashRef containing all session attribute names and their value (which
might be undef).

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

    return { map { $_ => $self->$_ } @names };
}

=head2 check_attributes

Checks the given HashRef of attribute names/values to see if they are valid
session attributes (i.e. attributes specified in C<OpenXPKI::Server::Session::Data>).

Throws an exception on unknown attributes.

B<Parameters>

=over

=item * $attrs - attribute names and values (I<HashRef>)

=item * $expect_all - optional: additionally check that all attributes of
C<OpenXPKI::Server::Session::Data> are present in the HashRef (I<Bool>)

=back

=cut
sub check_attributes {
    my ($self, $attrs, $expect_all) = @_;
    my %all_attrs = ( map { $_ => 1 } @{ $self->get_attribute_names } );

    my $id = $attrs->{id} // undef;

    for my $name (keys %{ $attrs }) {
        OpenXPKI::Exception->throw(
            message => "Unknown attribute in session data",
            params => { $id ? (session_id => $id) : (), attr => $name },
        ) unless delete $all_attrs{$name};
    }

    # check if there are attributes missing
    OpenXPKI::Exception->throw(
        message => "Session data is incomplete",
        params => { $id ? (session_id => $id) : (), missing => join(", ", keys %all_attrs) },
    ) if ($expect_all and scalar keys %all_attrs);
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

1;
