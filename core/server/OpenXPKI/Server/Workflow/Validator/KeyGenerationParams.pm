package OpenXPKI::Server::Workflow::Validator::KeyGenerationParams;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Validator );
use Data::Dumper;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( validation_error configuration_error );

sub _preset_args {
    return [ qw(cert_profile key_alg key_gen_params enc_alg) ];
}

sub _validate {

    ##! 1: 'start'
    my ( $self, $wf, $cert_profile, $key_alg, $key_gen_params, $enc_alg ) = @_;

    if (!$key_alg) {
        ##! 8: 'skip - no algorithm'
        return 1;
    }

    # might be serialized
    if (!ref $key_gen_params) {
        $key_gen_params = OpenXPKI::Serialization::Simple->new()->deserialize( $key_gen_params );
    }

    my $key_params = {};

    if ($key_alg eq 'rsa') {
        $key_params = { key_length =>  $key_gen_params->{KEY_LENGTH} };
    } elsif ($key_alg eq 'dsa') {
        $key_params = { key_length =>  $key_gen_params->{KEY_LENGTH} };
    } elsif ($key_alg eq 'ec') {
        $key_params = { key_length =>  '_any', curve_name => $key_gen_params->{CURVE_NAME} };
        # not yet defined
    } else {
        validation_error('I18N_OPENXPKI_UI_VALIDATOR_KEY_PARAM_ALGO_NOT_SUPPORTED');
    }

    ##! 16: "Alg: $key_alg"
    ##! 16: 'Params ' . Dumper $key_params

    # get the list of allowed algorithms from the config
    my $algs = CTX('api')->get_key_algs({ PROFILE => $cert_profile, NOHIDE => 1 });

    ##! 32: 'Alg expected ' . Dumper $algs

    if (!grep(/\A$key_alg\z/, @{$algs})) {
        ##! 8: "KeyParam validation failed on algo $key_alg"
        CTX('log')->application()->error("KeyParam validation failed on algo $key_alg");

        validation_error('I18N_OPENXPKI_UI_VALIDATOR_KEY_PARAM_ALGO_NOT_ALLOWED');
    }

    my $params = CTX('api')->get_key_params({ PROFILE => $cert_profile, ALG => $key_alg, NOHIDE => 1 });

    ##! 32: 'Params expected ' . Dumper $params

    foreach my $param (keys %{$params}) {
        my $val = $key_params->{$param} || '';

        if ($val eq '_any') { next; }

        my @expect = @{$params->{$param}};
        ##! 32: "Validate param $param, $val, " . Dumper \@expect
        if (!grep(/$val/, @expect)) {
            ##! 32: 'Failed on ' . $val
            CTX('log')->application()->error("KeyParam validation failed on $param with value $val");

            validation_error("I18N_OPENXPKI_UI_VALIDATOR_KEY_PARAM_PARAM_NOT_ALLOWED ($param)");
        }
    }

    my $enc_algs = CTX('api')->get_key_enc({ PROFILE => $cert_profile, NOHIDE => 1 });
    if ($enc_alg && !grep(/\A$enc_alg\z/, @{$enc_algs})) {
        ##! 32: 'Failed on ' . $enc_alg
        CTX('log')->application()->error("KeyParam validation failed on enc_alg with value $enc_alg");

        validation_error("I18N_OPENXPKI_UI_VALIDATOR_KEY_PARAM_PARAM_NOT_ALLOWED (enc_alg)");
    }


    ##! 1: 'Validation succeeded'
    CTX('log')->application()->debug("KeyParam validation succeeded");


    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::KeyGenerationParams

=head1 Description

Check if the key specification passed fits the requirements of the profile.

=head1 Configuration

  global_validate_key_param:
      class: OpenXPKI::Server::Workflow::Validator::KeyGenerationParams
      arg:
       - $cert_profile
       - $key_alg
       - $key_gen_params
       - $enc_alg

=head2 Arguments

=over

=item cert_profile

Name of the certificate profile

=item key_alg

The selected key algorithm

=item key_gen_params

Hash holding the key generation params, must fit the list given in the
profile definition.

=item enc_alg

The encryption algorithm, can be emtpy.

=back
