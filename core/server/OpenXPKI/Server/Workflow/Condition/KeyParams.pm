package OpenXPKI::Server::Workflow::Condition::KeyParams;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;
use OpenXPKI::Debug;
use English;

sub _evaluate
{
    ##! 64: 'start'
    my ( $self, $wf ) = @_;

    my $key_alg = $self->param('key_alg');
    my $key_params = $self->param('key_params');
    my $cert_profile = $self->param('cert_profile');
    my $key_rules = $self->param('key_rules');


    if (!$key_alg || !$key_params || ref $key_params ne 'HASH') {
        configuration_error('Key algorithm and/or key parameter not found!');
    }

    ##! 16: "Alg: $key_alg"
    ##! 16: 'Params ' . Dumper $key_params

    if ($key_rules) {

        # for explicit key rules we expect the algorithms on the first level
        if (!$key_rules->{$key_alg}) {
            condition_error('Used key algorithm is not allowed');
        }
        $key_rules = $key_rules->{$key_alg};

    } else {

        if (!$cert_profile) {
            configuration_error('You must pass either the profile name or the key_rules directly');
        }

        # get the list of allowed algorithms from the config
        my $algs = CTX('api2')->get_key_algs( profile => $cert_profile, nohide => 1 );

        ##! 32: 'Alg expected ' . Dumper $algs

        if (!grep(/\A$key_alg\z/, @{$algs})) {
            ##! 8: "KeyParam validation failed on algo $key_alg"
            CTX('log')->application()->error("KeyParam validation failed on algo $key_alg");
            condition_error('Used key algorithm is not allowed');
        }

        $key_rules = CTX('api2')->get_key_params( profile => $cert_profile, alg => $key_alg, showall => 1 );

    }

    ##! 32: 'Params expected ' . Dumper $params

    my $result = CTX('api2')->validate_key_params(
        key_params => $key_params,
        key_rules => $key_rules,
    );

    if (@{$result}) {
        my $err = '';
        map { $err .=  $_.': '.($key_params->{$_} // '?') } @{$result};
        CTX('log')->application()->error("KeyParam validation failed: $err");
        condition_error("Invalid key parameters used: $err");
    }

    ##! 1: 'Validation succeeded'
    CTX('log')->application()->debug("KeyParam validation succeeded");


    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::KeyParams

=head1 Description

Validate the given key parameters against the definitions read from
the profile or from the key_rules parameter.

=head1 Configuration

  is_key_param_valid:
      class: OpenXPKI::Server::Workflow::Condition::KeyParams
      param:
       _map_cert_profile: $cert_profile
       _map_key_params: $csr_key_params
       _map_key_alg: $csr_key_alg

=head2 Arguments

=over

=item cert_profile

Name of the certificate profile

=item pkcs10

PEM encoded PKCS10

=back
