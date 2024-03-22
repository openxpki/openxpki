package OpenXPKI::DTO::Message;

use Moose::Role;

=head1 Attributes

=head2 session_id

ID of the backend session that should be used to run this command.

=cut

has session_id => (
    is => 'ro',
    isa => 'Str',
    required => 0,
    predicate => 'has_session_id',
);

=head2 pki_realm

The pki_realm to run this command

=cut

has pki_realm => (
    is => 'ro',
    isa => 'Str',
    required => 0,
    predicate => 'has_pki_realm',
);


=head2 params

A HashRef holding the parameters to be used with the command/method.

=cut

has params => (
    is => 'ro',
    isa => 'HashRef',
    required => 0,
    predicate => 'has_params',
    default => sub {{}}
);


=head1 Methods

=head2 to_hash

Returns a HashRef that can be used to serialize the object for transfer.

=cut

sub to_hash {

    my $self = shift;
    my $class = ref $self;

    my @all_attrs = $self->meta->get_all_attributes;
    my $data = {};
    for my $attr (@all_attrs) {
        # check which attributes are set
        next unless $attr->has_value($self);

        next unless($attr->type_constraint->is_a_type_of('Value')
            || $attr->type_constraint->is_a_type_of('ArrayRef')
            || $attr->type_constraint->is_a_type_of('HashRef'));

        $data->{$attr->name} = $attr->get_value($self);
    }

    return {
        class => substr($class,24),
        data => $data,
    };

}

# this is a static method !
sub from_hash {

    my $hash = shift;

    my $class = $hash->{class};
    my $data = $hash->{data};
    $class = 'OpenXPKI::DTO::Message::'.$class;
    eval "use $class;1";
    return $class->new($data);

}

1;