package OpenXPKI::Server::Workflow::Validator::KeyParams;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Validator );
use Data::Dumper;
use Crypt::PKCS10;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( validation_error configuration_error );


sub _preset_args {
    return [ qw(cert_profile pkcs10) ];
}


sub _validate {

    ##! 1: 'start'
    my ( $self, $wf, $cert_profile, $pkcs10 ) = @_;

    if (!$pkcs10) {
        ##! 8: 'skip - no data'
        return 1;
    }

    my $key_alg = 'unknown';
    my $key_params = {};

    Crypt::PKCS10->setAPIversion(1);
    my $decoded = Crypt::PKCS10->new( $pkcs10, ignoreNonBase64 => 1, verifySignature => 0);
    if (!$decoded) {
        validation_error('I18N_OPENXPKI_UI_VALIDATOR_KEY_PARAM_CAN_NOT_PARSE_PKCS10');
    }

    my $key_param;
    eval {
        $key_param = $decoded->subjectPublicKeyParams();
    };

    if (!$key_param || !$key_param->{keytype}) {
        CTX('log')->application()->warn("Unable to get key parameters from PKCS10");
        validation_error('I18N_OPENXPKI_UI_VALIDATOR_KEY_PARAM_ALGO_NOT_SUPPORTED');
    } elsif ($key_param->{keytype} eq 'RSA') {
        $key_alg = 'rsa';
        $key_params = { key_length =>  $key_param->{keylen} };
    } elsif ($key_param->{keytype} eq 'DSA') {
        $key_alg = 'dsa';
        $key_params = { key_length =>  $key_param->{keylen} };
    } elsif ($key_param->{keytype} eq 'ECC') {
        $key_alg = 'ec';
        $key_params = { key_length =>  $key_param->{keylen}, curve_name => $key_param->{curve} };
    } else {
        validation_error('I18N_OPENXPKI_UI_VALIDATOR_KEY_PARAM_ALGO_NOT_SUPPORTED');
    }

    ##! 16: "Alg: $key_alg"
    ##! 16: 'Params ' . Dumper $key_params

    # get the list of allowed algorithms from the config
    my $algs = CTX('api2')->get_key_algs( profile => $cert_profile, showall => 1 );

    ##! 32: 'Alg expected ' . Dumper $algs

    if (!grep(/\A$key_alg\z/, @{$algs})) {
        ##! 8: "KeyParam validation failed on algo $key_alg"
        CTX('log')->application()->error("KeyParam validation failed on algo $key_alg");
        validation_error('I18N_OPENXPKI_UI_VALIDATOR_KEY_PARAM_ALGO_NOT_ALLOWED');
    }

    my $params = CTX('api2')->get_key_params( profile => $cert_profile, alg => $key_alg, showall => 1 );

    ##! 32: 'Params expected ' . Dumper $params

    my $result = CTX('api2')->validate_key_params(
        key_params => $key_params,
        key_rules => $params,
    );

    if (@{$result}) {
        my $err = '';
        map { $err .=  $_.': '.($key_params->{$_} // '?') } @{$result};
        CTX('log')->application()->error("KeyParam validation failed: $err");
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_KEY_PARAM_PARAM_NOT_ALLOWED ($err)");
    }

    ##! 1: 'Validation succeeded'
    CTX('log')->application()->debug("KeyParam validation succeeded");


    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::KeyParams

=head1 Description

Extracts the key parameters form the passed PKCS10 and checks them
againstthe one of the profile.

=head1 Configuration

  global_validate_key_param:
      class: OpenXPKI::Server::Workflow::Validator::KeyParams
      arg:
       - $cert_profile
       - $pkcs10

=head2 Arguments

=over

=item cert_profile

Name of the certificate profile

=item pkcs10

PEM encoded PKCS10

=back
