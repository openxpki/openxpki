## OpenXPKI::Crypto::Tool::LibSCEP::Command::unwrap
## Written 2015-2018 by Gideon Knocke and Martin Bartosch for the OpenXPKI project
## (C) Copyright 2015-2018 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::LibSCEP::Command::unwrap;

use strict;
use warnings;
use English;

use Class::Std;

use OpenXPKI::FileUtils;
use OpenXPKI::Debug;
use Crypt::LibSCEP;

my %pkcs7_of :ATTR;
my %engine_of  :ATTR;
my %fu_of      :ATTR;

my %encalg_of    :ATTR;
my %hashalg_of :ATTR;


sub START {
    my ($self, $ident, $arg_ref) = @_;

    $fu_of{$ident} = OpenXPKI::FileUtils->new();
    $pkcs7_of{$ident} = $arg_ref->{PKCS7};
    $engine_of{$ident} = $arg_ref->{ENGINE};

    $encalg_of{$ident}    = $arg_ref->{ENCRYPTION_ALG};
    $hashalg_of{$ident}   = $arg_ref->{HASH_ALG};
}

sub get_result
{
    my $self = shift;
    my $ident = ident $self;

    my $enc_alg    = $encalg_of{$ident}  || 'aes256';
    my $hash_alg   = $hashalg_of{$ident} || 'sha256';

    if ($enc_alg eq '3des') {
	# make OpenSSL happy...
	$enc_alg = 'des3';
    }

    my $pwd    = $engine_of{$ident}->get_passwd();

    ##! 16: "LibSCEP config"
    ##! 16: "encryption algorithm: $enc_alg"
    ##! 16: "digest algorithm: $hash_alg"

    my $config = {
	passin => "pass", 
	passwd => $pwd,
	encalg => $enc_alg,
	sigalg => $hash_alg,
    };

    # keyfile, signcert, password for keyfile
    if (! defined $engine_of{$ident}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_UNWRAP_NO_ENGINE',
        );
    }

    my $keyfile  = $engine_of{$ident}->get_keyfile();
    if (! defined $keyfile || $keyfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_UNWRAP_KEYFILE_MISSING',
        );
    }
    my $certfile = $engine_of{$ident}->get_certfile();
    if (! defined $certfile || $certfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_UNWRAP_CERTFILE_MISSING',
        );
    }
    my $cert = $fu_of{$ident}->read_file($certfile);
    my $key = $fu_of{$ident}->read_file($keyfile);

    my $pkcs7 = $pkcs7_of{$ident};
    my $scep_handle;
    ##! 16: "unwrapping SCEP message"
    eval {
        $scep_handle = Crypt::LibSCEP::unwrap($config, $pkcs7, $cert, $cert, $key);
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    ##! 16: "unwrapped SCEP message"
    return $scep_handle;

}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Tool::LibSCEP::Command::unwrap - parses a pkiMessage

=head1 Description

This is used for creating a SCEP handle which contains every
information extracted from the pkiMessage.
