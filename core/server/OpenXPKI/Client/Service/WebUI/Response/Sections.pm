package OpenXPKI::Client::Service::WebUI::Response::Sections;
use OpenXPKI qw( -dto -typeconstraints );

# CPAN modules
use Moose::Util qw( does_role );

# Project modules
use OpenXPKI::Client::Service::WebUI::Response::Section::Form;


subtype 'HashRefOrSection',
    as 'Ref',
    where { ref($_) eq 'HASH' or does_role($_, 'OpenXPKI::Client::Service::WebUI::Response::SectionRole') };
# Could also be written as:
#   union 'HashRefOrSection' => [ 'HashRef', Moose::Util::TypeConstraints::create_role_type_constraint('OpenXPKI::Client::Service::WebUI::Response::SectionRole') ];

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


# overrides OpenXPKI::Client::Service::WebUI::Response::DTORole->is_set()
sub is_set { ! shift->_no_section }

sub add_section {
    my $self = shift;
    $self->_add_section(@_);
    return $self; # allows for method chaining
}

sub add_form {
    my $self = shift;
    my $s = OpenXPKI::Client::Service::WebUI::Response::Section::Form->new(@_);
    $self->add_section($s);
    return $s;
}


__PACKAGE__->meta->make_immutable;
