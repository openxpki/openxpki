## OpenXPKI::Crypto::Backend::OpenSSL::Command::list_algorithms
## Written 2007 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2007 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Command::list_algorithms;

use base qw(OpenXPKI::Crypto::Backend::OpenSSL::Command);

sub get_command
{
    my $self = shift;
    OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_LIST_ALGS_NO_FORMAT" 
        )
        if ( not exists $self->{FORMAT} );

    my $engine = $self->{ENGINE}->get_engine();

    my $command = "engine ";
    $command .= "$engine " if ($engine);
    $command .= "-c -t";

    return [ $command ];
}

sub hide_output
{
    return 0;
}

sub key_usage
{
    return 0;
}

sub get_result
{
    my $self   = shift;
    my $result = shift;
    
    my %standard_algs = map { $_ => 1 } qw( RSA DSA EC );

    my $supported_algs =  {
                     "RSA" =>
                         {"ENC_ALG" =>
                            [ "__undef", "aes256", "aes192", "aes128", "idea", "des3", "des" ],
                          "KEY_LENGTH" =>
                            [512, 768, 1024, 2048, 4096 ]
                         },
                     "DSA" =>
                         {"ENC_ALG" =>
                            [ "__undef", "aes256", "aes192", "aes128", "idea", "des3", "des" ],
                          "KEY_LENGTH" =>
                            [512, 768, 1024, 2048, 4096 ]
                         },
                     "EC" =>
                         {"ENC_ALG" =>
                            [ "__undef", "aes256", "aes192", "aes128", "idea", "des3", "des" ],
                          "CURVE_NAME" =>
                            ["prime192v1", "c2tnb191v1", "prime239v1", "sect571r1" ]
                         },
                     "GOST94" =>
                         {"ENC_ALG" =>
                            [ "__undef", "aes256", "aes192", "aes128", "idea", "des3", "des" ]
                         },
                     "GOST2001" =>
                         {"ENC_ALG" =>
                            [ "__undef", "aes256", "aes192", "aes128", "idea", "des3", "des" ]
                         },
                     "GOST94CP" =>
                         {"ENC_ALG" =>
                            [ "__undef", "aes256", "aes192", "aes128", "idea", "des3", "des" ]
                         },
                     "GOST2001CP" =>
                         {"ENC_ALG" =>
                            [ "__undef", "aes256", "aes192", "aes128", "idea", "des3", "des" ],
                          "PARAMSET" =>
                            ["0", "A", "B", "C", "XA", "XB" ]
                         },
    };
 
    my ($alg, $param) = (undef, undef);    
    $alg = $self->{ALG};
    $param = $self->{PARAM};

    my $key = "";
    foreach $key (keys(%{$supported_algs})) {
        if ( !exists($standard_algs{$key}) ) {
            my $lc_key = lc($key);                                                                                                                                                 
            if ( $result !~ m{ ${lc_key}\W }xms ) {
                 delete($supported_algs->{$key});
            }
        }
    }

    my $format = $self->{FORMAT}; 
 
    if ( $format eq 'all_data' ) {
        return $supported_algs;
    }
    elsif ( $format eq 'alg_names' ) {
        my %alg_names = map { $_ => 1 } keys(%{$supported_algs});
        return \%alg_names;
    }
    else { # param names or values needed
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_LIST_ALGS_NO_ALGORITMN" ) 
                if ( !$alg );
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_LIST_ALGS_UNSUPPORTED_ALGORITHM",
            params => { ALG => $alg }
        )
                if ( !($supported_algs->{$alg}) );

        if ( $format eq 'param_names' ) {
            my $alg_info = $supported_algs->{$alg};
            my %param_names = map { $_ => 1 } keys(%{$alg_info});
            return \%param_names;
        }
        elsif ( $format eq 'param_values' ) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_LIST_ALGS_NO_PARAM_NAME" ) 
                    if ( !$param );
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_LIST_ALGS_UNSUPPORTED_PARAM_NAME",
                params => { PARAM => $param }
            )
                    if ( !($supported_algs->{$alg}->{$param}));

            my %param_values = map { $_ => 1 } @{$supported_algs->{$alg}->{$param}};
            delete($param_values{'__undef'}) if (exists($param_values{'__undef'}));

            return \%param_values;
        }
        else {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_LIST_ALGS_ILLEGAL_FORMAT",
                params => {
                    FORMAT => $format,
                },
            );
        } # else - illegal format
    } # else - param names or values needed
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::Command::list_algorithms

=head1 Functions

=head2 get_command

Forms command for openssl which answers the question: Do you support non-standard 
public-key crypto algorithms, that is anything beyond usual set of RSA, DSA and EC?

=head2 hide_output

returns false

=head2 key_usage

returns false

=head2 get_result

Return lists of supported public key algorithms and parameters.
