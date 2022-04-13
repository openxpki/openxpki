package OpenXPKI::Server::Workflow::Field;

use strict;
use base qw( Workflow::Action::InputField );

sub init {
    my ( $self, $params ) = @_;

    $self->type($params->{type}) if defined $params->{type};

    $self->SUPER::init($params);
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Field

=head1 Description

Base class for OpenXPKI Workflow Action Fields.

=head1 Functions

=head2 init

Fixes a bug in L<Workflow::Action::InputField> where the C<type> parameter is
always overwritten with value "basic".
