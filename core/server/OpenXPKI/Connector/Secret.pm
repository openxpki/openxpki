package OpenXPKI::Connector::Secret;

use strict;
use warnings;
use English;
use Moose;
use OpenXPKI::Server::Context qw( CTX );

extends 'Connector';

sub get {

    my $self = shift;

    my $group;
    if ($self->LOCATION()) {
        $group = $self->LOCATION();
    } else {
        my @args = $self->_build_path( shift );
        $group = shift @args;
    }

    my $secret = CTX('crypto_layer')->get_secret( $group );

    if (!defined $secret) {
        return $self->_node_not_exists();
    }

    return $secret;

}


sub get_meta {

    my $self = shift;
    my $arg = shift;

    if (!$arg) {
        return {TYPE  => "connector" };
    }

    return {TYPE  => "scalar" };

}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

OpenXPKI::Connector::Secret;

=head1 DESCRIPTION

Connector to load secrets from the OpenXPKI secret module as defined
in I<crypto.secret>. Note that you need set the attribute I<export: 1>
in the secret's 'definition to use this connector.

=head2 Configuration

=over

=item LOCATION

The name of the secret group to load. If set to the empty string, the name
of the group is expected as path argument.

=back

=head2 Example

=head3 Static secret group

When accessing I<certificate_key_password>, the argument string empty and
the location attribute is used as group name.

  certificate_key_password@: connector:secret

  secret:
     class: OpenXPKI::Connector::Secret
     LOCATION: my-secret-group


=head3 Dynamic secret group

Use to determine the secret group by the path argument, to get the same
result as above, you need to call C<get('my-secret-group')>.

  passwords@: connector:secret

  secret:
     class: OpenXPKI::Connector::Secret
     LOCATION: ''


