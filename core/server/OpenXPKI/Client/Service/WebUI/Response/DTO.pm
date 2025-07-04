package OpenXPKI::Client::Service::WebUI::Response::DTO;
use strict;
use warnings;

# CPAN modules
use Moose::Exporter;

# Project modules
use OpenXPKI::Client::Service::WebUI::Response::DTORole;


=head1 DESCRIPTION

To define a new data transfer object (DTO) simply say:

    package OpenXPKI::Client::Service::WebUI::Response::MyData;
    use OpenXPKI -dto;

    has 'message' => (
        is => 'rw',
        isa => 'Str',
    );

    has_dto 'menu' => (
        documentation => 'structure',
        class => 'OpenXPKI::Client::Service::WebUI::Response::Menu',
    );

This will modify your package as follows:

=over

=item * add C<use Moose> and C<use MooseX::StrictConstructor>,

=item * apply the Moose role L<OpenXPKI::Client::Service::WebUI::Response::DTORole>.

=item * provide the L</has_dto> keyword to define nested DTOs,

=back

=cut
Moose::Exporter->setup_import_methods(
    with_meta => [ 'has_dto' ],
    base_class_roles => [ 'OpenXPKI::Client::Service::WebUI::Response::DTORole' ],
);

=head2 has_dto

Static method: shortcut to define DTO attributes in Moose with less overhead:

    has_dto 'menu' => (
        documentation => 'structure', # key name in result hash will be "structure" instead of "menu"
        class => 'OpenXPKI::Client::Service::WebUI::Response::Menu',
    );

is equivalent to:

    has 'menu'=> (
        documentation => 'structure',
        is => 'rw',
        isa => 'OpenXPKI::Client::Service::WebUI::Response::Menu',
        default => sub { OpenXPKI::Client::Service::WebUI::Response::Menu->new },
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
