package OpenXPKI::Server::Workflow::Validator::KeyLength;

use strict;
use warnings;

use base qw( Workflow::Validator );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;

use Data::Dumper;

__PACKAGE__->mk_accessors( 'min' );
__PACKAGE__->mk_accessors( 'max' );
__PACKAGE__->mk_accessors( 'fail_on_unknown_algorithm' );

sub _init {
    my ( $self, $params ) = @_;
    # set up some options from validator configuration file

    # minimal key length for different algorithms, format
    # algorithm1: length in bits, algorithm2: length in bits, ...
    if (exists $params->{min}) {
        $self->min( $self->__parse_config_entry($params->{min}) );
    }
    else {
        # min is mandatory, throw exception if not present
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_KEYLENGTH_CONFIGURATION_ERROR_MIN_MISSING',
        );
    }

    # maximal key length
    if (exists $params->{max}) {
        # this is an optional parameter, if not specified, only minimal
        # length will be checked.
        $self->max( $self->__parse_config_entry($params->{max}) );
    }

    # optional parameter that defines whether we fail when encountering
    # an algorithm not specified in the config or not
    if (exists $params->{fail_on_unknown_algorithm} && $params->{fail_on_unknown_algorithm}) {
        $self->fail_on_unknown_algorithm(1);
    }
    else {
        $self->fail_on_unknown_algorithm(0);
    }
    return 1;
}

sub validate {
    ##! 1: 'start'
    my ( $self, $wf ) = @_;

    my $context  = $wf->context();
    my $csr_type = $context->param('csr_type');

    return 1 if (! $csr_type); # no csr_type (yet) specified, ignore

    ##! 16: 'csr_type: ' . $csr_type

    my $key_length;
    my $key_algorithm;
    my $data;

    if ($csr_type eq 'pkcs10') {
        $data = $context->param('pkcs10');
    }
    elsif ($csr_type eq 'spkac') {
        $data = $context->param('spkac');
    }
    else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_KEYLENGTH_INVALID_CSR_TYPE',
            params  => {
                CSR_TYPE => $csr_type,
            },
        );
    }

    return 1 if (! $data); # data is not available yet, ignore
    ##! 16: 'data: ' . $data

    my $csr_info = CTX('api')->get_csr_info_hash_from_data({
        DATA => $data,
    });
    ##! 16: 'csr_info: ' . Dumper $csr_info
    $key_length    = $csr_info->{BODY}->{KEYSIZE};
    ##! 16: 'key_length: ' . $key_length
    $key_algorithm = $csr_info->{BODY}->{PUBKEY_ALGORITHM};
    ##! 16: 'key_algorithm: ' . $key_algorithm

    if ($self->fail_on_unknown_algorithm && ! exists $self->min()->{$key_algorithm}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_KEYLENGTH_INVALID_ALGORITHM',
            params  => {
                ALGORITHM => $key_algorithm,
            },
        );
    }
    if (exists $self->min()->{$key_algorithm}) {
        ##! 16: 'min length: ' . $self->min()->{$key_algorithm}
        if ($key_length < $self->min()->{$key_algorithm}) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_KEYLENGTH_KEY_TOO_SHORT',
                params  => {
                    GIVEN_LENGTH => $key_length,
                    MIN_LENGTH   => $self->min()->{$key_algorithm},
                },
            );
        }
    }
    if (defined $self->max() && exists $self->max()->{$key_algorithm}) {
        ##! 16: 'max length: ' . $self->max()->{$key_algorithm}
        if ($key_length > $self->max()->{$key_algorithm}) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_KEYLENGTH_KEY_TOO_LONG',
                params  => {
                    GIVEN_LENGTH => $key_length,
                    MAX_LENGTH   => $self->max()->{$key_algorithm},
                },
            );
        }
    }
    
    return 1;
}

sub __parse_config_entry {
    my $self  = shift;
    my $entry = shift;
    ##! 64: 'entry: ' . $entry

    # the result will be a hashref consisting of algorithm -> length entries
    my $result = {};

    $entry =~ s/\s//g; # delete whitespace from entry
    my @pairs = split q{,}, $entry;

    foreach my $pair (@pairs) {
        my ($algorithm, $length) = split q{:}, $pair;
        if (! $algorithm || $length !~ m{ \A \d+ \z }xms) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_KEYLENGTH_CONFIGURATION_ERROR_INVALID_ALGORITHM_OR_LENGTH',
            );
        }
        ##! 16: 'algorithm: ' . $algorithm;
        ##! 16: 'length: ' . $length
        $result->{$algorithm} = $length;
    }

    ##! 64: 'result: ' . Dumper $result
    return $result;
}

1;
__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::KeyLength

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="KeyLength"
           class="OpenXPKI::Server::Workflow::Validator::KeyLength">
      <param name="min" value="rsaEncryption: 2048, dsaEncryption: 2048, id-ecPu
blicKey: 191"/>
      <param name="max" value="rsaEncryption: 4096, dsaEncryption: 2048, id-ecPu
blicKey: 800"/>
      <param name="fail_on_unknown_algorithm" value="1"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks the length of the public key in the CSR.
It can be configured to use both a minimum (required) and maximum (optional)
value for the key length in bits for different algorithm.

The example above would allow you to make sure that RSA keys are between
2048 and 4096 bits, DSA keys exactly 2048 bits and EC-DSA keys between
191 and 800 bits. The validator would fail on any other algorithm (this
can be used to force people to only use RSA keys, for example).
