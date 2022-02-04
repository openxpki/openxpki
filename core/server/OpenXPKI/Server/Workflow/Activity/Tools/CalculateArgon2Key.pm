package OpenXPKI::Server::Workflow::Activity::Tools::CalculateArgon2Key;

use warnings;
use strict;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Password;
use Workflow::Exception qw(configuration_error workflow_error);

use base qw( OpenXPKI::Server::Workflow::Activity );

sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    my $target_key = $self->param('target_key') || '_argon2key';
    my $password = $self->param('password') || $context->param('_password');
    my $salt = $self->param('salt');

    configuration_error('No password found')  unless ($password);

    my $memory = $self->param('memory_cost') || '32M';
    configuration_error('Memory cost parameter has invalid format') unless ($memory =~ m{\A\d+[kMG]\z});

    my $key = OpenXPKI::Password::hash('argon2', $password, { salt => $salt, memory => $memory });

    workflow_error('Unable to generate Argon2 key') unless($key);
    $context->param( $target_key  => $key  );

}

1;

__END__;


=head1 OpenXPKI::Server::Workflow::Activity::Tools::CalculateArgon2Key

Derive key from given password using the Argon2 algorithm.

=head1 Configuration

=head2 Parameters

=over

=item password

The password to use, if not set the context key I<_password> is read.

=item salt

The salt to use, if not set a 16 byte random value is generated.

=item memory_cost

@see Crypt::Argon2, default is 32M

=item target_key

context item to write the result to, default is _argon2key

=back
