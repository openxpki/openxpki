package OpenXPKI::Crypto::SecretRole;
use Moose::Role;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );


=head1 NAME

OpenXPKI::Server::API2::SecretRole - Base role for all types of 'secrets'

=cut

=head1 ATTRIBUTES

=head2 exportable

I<Bool> value indicating whether this secret value should be exposed outside
the crypto manager.

Default: 1

=cut
has exportable => (
    is => 'ro',
    isa => 'Bool',
    default => 1,
    reader => 'is_exportable',
);


=head1 REQUIRES

This role requires the consuming class to implement the following methods:

=head2 set_secret

Must sets (part of) the secret. The arguments are dependent on the type of
secret.

=cut

requires 'set_secret';

=head2 get_secret

Must return the secret if C<is_complete() == 1> or C<undef> otherwise.

=cut

requires 'get_secret';

=head2 clear_secret

Must delete all secret data stored in the object.

=cut

requires 'clear_secret';

=head2 required_part_count

Must return the number of required parts to complete this secret.

=cut

requires 'required_part_count';

=head2 inserted_part_count

Must return the number of parts that are already inserted / set.

=cut

requires 'inserted_part_count';

=head2 _get_parts

Must return an I<ArrayRef> with the current secret data of the object.

=cut

requires '_get_parts';

=head2 _set_parts

Must set the secret data of the object to the given I<ArrayRef>.

=cut

requires '_set_parts';


=head1 METHODS

=head2 is_exportable

Returns C<1> if this secret value should be exposed outside the crypto manager,
C<0> otherwise.

=cut

#
# reader method of attribute 'exportable' above
#

=head2 is_complete

Returns 1 if the secret is fully completed / known / set.

=cut

sub is_complete {
    my $self = shift;
    return $self->inserted_part_count >= $self->required_part_count ? 1 : 0;
}

=head2 freeze

Returns the serialized data attributes of this object or C<undef> if no secret
data has been set yet.

=cut

sub freeze {
    my $self = shift;
    ##! 1: "start"
    ##! 2: "serializing " . (scalar @{ $self->_get_parts }) . " parts"

    my $decoder = OpenXPKI::Serialization::Simple->new;
    my $dump = CTX('volatile_vault')->encrypt($decoder->serialize($self->_get_parts));
    ##! 2: "created " . (defined $dump ? length($dump) : 0) . " bytes dump data"

    return $dump;
}

=head2 thaw

Decodes the given serialized data and sets the data attributes of this object
accordingly.

=cut

sub thaw {
    my ($self, $dump) = @_;
    ##! 1: "start"
    ##! 2: "processing " . (defined $dump ? length($dump) : 0) . " bytes dump data"

    # FIXME fail with Exception?
    return unless defined $dump;
    return unless length $dump;

    $self->clear_secret; # don't leave old data in case the following throws an exception

    return unless CTX('volatile_vault')->can_decrypt($dump);
    my $decoder = OpenXPKI::Serialization::Simple->new;
    my $array_ref = $decoder->deserialize(CTX('volatile_vault')->decrypt($dump));
    ##! 2: "Deserialized " . (scalar @$array_ref) . " parts"

    $self->_set_parts($array_ref);

    return 1;
}

1;
