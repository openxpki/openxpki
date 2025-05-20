package OpenXPKI::Crypto::Backend::OpenSSL::CLI;
use OpenXPKI -class_std;

use parent qw( OpenXPKI::Crypto::CLI );

my %config_of :ATTR( :init_arg<CONFIG> ); # the config object

sub set_environment {
    my $self = shift;
    my $ident = ident $self;

    ##! 2: "set the configuration"
    $config_of{$ident}->dump();
    $ENV{OPENSSL_CONF} = $config_of{$ident}->get_config_filename();
    ##! 16: 'OPENSSL_CONF: ' . $ENV{OPENSSL_CONF}
}

sub error_ispresent {
    my $self = shift;
    my $ident = ident $self;
    my $stderr = shift;

    if ($stderr =~ m{ [eE]rror |
                      unable\ to\ load\ key |
                      No\ certificate\ matches\ private\ key |
                      unknown\ option |
                      Usage:\ pkcs12 |
                      invalid\ reason\ code |
                      invalid\ revocation\ date
                    }xms) {
        return 1;
    }
    else {
        return 0;
    }
}
1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::CLI

=head1 Desription

This module implements the handling of the OpenSSL shell. It is a child
of OpenXPKI::Crypto::CLI. As an extra parameter, it expects an
OpenXPKI::Crypto::Backend::OpenSSL::Config object in the named parameter
'CONFIG'.

=head1 Functions

=head2 set_environment

Sets the OPENSSL_CONF environment variable based on the Config object.

=head2 error_ispresent

Checks whether there is an error in the STDERR output.

=head1 See also:

OpenXPKI::Crypto::CLI
