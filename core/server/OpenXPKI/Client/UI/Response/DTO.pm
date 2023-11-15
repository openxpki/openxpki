package OpenXPKI::Client::UI::Response::DTO;

# CPAN modules
use Moose ();
use MooseX::StrictConstructor ();
use Moose::Exporter;

# Project modules
use OpenXPKI::Client::UI::Response::DTORole;


=head1 DESCRIPTION

To define a new data transfer object (DTO) simply say:

    package OpenXPKI::Client::UI::Response::MyData;
    use OpenXPKI::Client::UI::Response::DTO;

    has 'message' => (
        is => 'rw',
        isa => 'Str',
    );

    has_dto 'menu' => (
        documentation => 'structure',
        class => 'OpenXPKI::Client::UI::Response::Menu',
    );

This will modify your package as follows:

=over

=item * import C<Moose> (i.e. adds "use Moose;" so you don't have to do it),

=item * provide the L</has_dto> keyword to define nested DTOs,

=item * apply the Moose role L<OpenXPKI::Client::UI::Response::DTORole>.

=back

=cut
Moose::Exporter->setup_import_methods(
    also => [ "Moose", "MooseX::StrictConstructor" ],
    with_meta => [ "has_dto" ],
    base_class_roles => [ "OpenXPKI::Client::UI::Response::DTORole" ],
);

=head2 has_dto

Static method: shortcut to define DTO attributes in Moose with less overhead:

    has_dto 'menu' => (
        documentation => 'structure', # key name in result hash will be "structure" instead of "menu"
        class => 'OpenXPKI::Client::UI::Response::Menu',
    );

is equivalent to:

    has 'menu'=> (
        documentation => 'structure',
        is => 'rw',
        isa => 'OpenXPKI::Client::UI::Response::Menu',
        default => sub { OpenXPKI::Client::UI::Response::Menu->new },
        lazy => 1,
    );

=cut
sub has_dto {
    my $meta = shift;
    my $name = shift;
    my %spec = @_;

    my $class = $spec{class}; delete $spec{class};
    die "has_dto() requires parameter 'class'" unless $class;

    # create attribute
    $meta->add_attribute($name => (
        is => 'rw',
        isa => $class,
        default => sub { $class->new },
        lazy => 1,
        %spec,
    ));
}

# No __PACKAGE__->meta->make_immutable: we said "use Moose ();" and thus did not enable Moose meta magic
1;
