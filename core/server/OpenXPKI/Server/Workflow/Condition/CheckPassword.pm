
package OpenXPKI::Server::Workflow::Condition::CheckPassword;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Password;
use English;

sub _evaluate {
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    my $context  = $workflow->context();

    my $plain = $self->param('password') || $context->param('_password');
    condition_error('No password was given') unless($plain);

    my $encoded = $self->param('encoded');
    configuration_error('Nothing to compare against found') unless($encoded);

    ##! 64: $plain
    ##! 32: $encoded

    my $res;
    eval{$res = OpenXPKI::Password::check($plain, $encoded);};
    if ($EVAL_ERROR) {
        configuration_error($EVAL_ERROR);
    }

    condition_error('Passwords do not match') unless($res);

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CheckPassword

=head1 DESCRIPTION

Compare if a plain text password matches a given password hash.

The class forwards the data to OpenXKI::Password::check.

=head2 Paramaters

=over

=item encoded

The hashed password in any format understood by OpenXKI::Password::check

=item password

The plain text password to match against encoded, if not given the
context item I<_password> is used.

=back
