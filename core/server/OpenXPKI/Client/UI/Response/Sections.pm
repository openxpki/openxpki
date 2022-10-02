package OpenXPKI::Client::UI::Response::Sections;

use Moose;

with 'OpenXPKI::Client::UI::Response::DTORole';

use Moose::Util::TypeConstraints;
use Moose::Util qw( does_role );

subtype 'HashRefOrSection',
    as 'Ref',
    where { ref($_) eq 'HASH' or does_role($_, 'OpenXPKI::Client::UI::Response::SectionRole') };
# Could also be written as:
#   union 'HashRefOrSection' => [ 'HashRef', Moose::Util::TypeConstraints::create_role_type_constraint('OpenXPKI::Client::UI::Response::SectionRole') ];

has 'sections' => (
    is => 'rw',
    isa => 'ArrayRef[HashRefOrSection]',
    traits => ['Array'],
    handles => {
        _add_section => 'push',
        _no_section => 'is_empty',
    },
    default => sub { [] }, # without default 'is_empty' would fail if no value has been set yet
    documentation => 'ROOT',
);


sub is_set { ! shift->_no_section }

sub add_section {
    my $self = shift;
    $self->_add_section(@_);
    return $self; # allows for method chaining
}

__PACKAGE__->meta->make_immutable;
