package OpenXPKI::Server::Workflow::Condition::ValidateRuleset;

use strict;
use warnings;
use English;

use base qw( OpenXPKI::Server::Workflow::Condition );

use Data::Dumper;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::Helpers;
use Workflow::Exception qw( condition_error configuration_error );

sub _evaluate
{
    ##! 64: 'start'
    my ( $self, $wf ) = @_;

    my $input = $self->param('input');
    my $ruleset = $self->param('ruleset');

    if (!$ruleset) {
        my $rules_path = OpenXPKI::Server::Workflow::Helpers::get_service_config_path( $self, $self->param('ruleset_name') );
        ##! 32: 'Loading from path ' . join(".",@{$rules_path})
        $ruleset = CTX('config')->get_hash($rules_path);
    }

    ##! 32: $input
    ##! 32: $ruleset
    configuration_error('Ruleset is not a hashref') unless(ref $ruleset eq 'HASH');
    configuration_error('Input is not a hashref') unless(ref $input eq 'HASH');


    my $result = CTX('api2')->validate_ruleset(
        input => $input,
        ruleset => $ruleset,
    );
    ##! 16: $result

    if (@{$result}) {
        my $err = '';
        map { $err .=  $_.': '.($input->{$_} // '?') } @{$result};
        CTX('log')->application()->debug("Ruleset validation failed: $err");
        condition_error("Invalid parameters used: $err");
    }

    ##! 1: 'Validation succeeded'
    CTX('log')->application()->debug("Ruleset validation succeeded");

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::ValidateRuleset

=head1 Description

Validate the given parameters against the given ruleset

=head1 Configuration

  is_param_valid:
      class: OpenXPKI::Server::Workflow::Condition::ValidateRuleset
      param:
       _map_input: $csr_key_params
       _map_ruleset:
            digest_alg: sha2

=head2 Arguments

=over

=item input

The input data to validate.

=item ruleset

The ruleset, as expected by validate_ruleset API method.

=back
