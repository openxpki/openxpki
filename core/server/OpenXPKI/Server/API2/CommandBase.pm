package OpenXPKI::Server::API2::CommandBase;
=head1 Name

OpenXPKI::Server::API2::CommandBase - Base class for API commands

=cut
use Moose;

__PACKAGE__->meta->make_immutable;

sub get_param_object {
    my ($self, $api_method) = @_;
    my $param_metaclass = $self->meta->api_param_classes->{$api_method};
    die "API method $api_method is not managed by __PACKAGE__\n" unless $param_metaclass;
    return $param_metaclass->new_object;
}
