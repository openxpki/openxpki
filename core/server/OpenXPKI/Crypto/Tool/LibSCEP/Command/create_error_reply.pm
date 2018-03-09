## OpenXPKI::Crypto::Tool::LibSCEP::Command::create_error_reply
## Written 2015-2018 by Gideon Knocke and Martin Bartosch for the OpenXPKI project
## (C) Copyright 2015-2018 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::LibSCEP::Command::create_error_reply;

use strict;
use warnings;
use English;

use Class::Std;

use OpenXPKI::Debug;
use Crypt::LibSCEP;
use MIME::Base64;

my %scep_handle_of   :ATTR;
my %engine_of  :ATTR;
my %error_of   :ATTR;
my %hash_alg_of  :ATTR;
my %enc_alg_of  :ATTR;
my %fu_of      :ATTR;


sub START {
    my ($self, $ident, $arg_ref) = @_;

    $fu_of{$ident}           = OpenXPKI::FileUtils->new();
    $engine_of{$ident}       = $arg_ref->{ENGINE};
    $scep_handle_of {$ident} = $arg_ref->{SCEP_HANDLE};
    $error_of {$ident}       = $arg_ref->{'ERROR_CODE'};
    $hash_alg_of {$ident}    = $arg_ref->{HASH_ALG};
    $enc_alg_of {$ident}     = $arg_ref->{ENCRYPTION_ALG};
}

sub get_result
{
    my $self = shift;
    my $ident = ident $self;

    if (! defined $engine_of{$ident}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_CREATE_ERROR_REPLY_NO_ENGINE',
        );
    }
    ##! 64: 'engine: ' . Dumper($engine_of{$ident})
    my $keyfile  = $engine_of{$ident}->get_keyfile();
    if (! defined $keyfile || $keyfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_CREATE_ERROR_REPLY_KEYFILE_MISSING',
        );
    }
    my $certfile = $engine_of{$ident}->get_certfile();
    if (! defined $certfile || $certfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_CREATE_ERROR_REPLY_CERTFILE_MISSING',
        );
    }
    my $pwd    = $engine_of{$ident}->get_passwd();

    my $cert = $fu_of{$ident}->read_file($certfile);
    my $key = $fu_of{$ident}->read_file($keyfile);

    if ($error_of{$ident} !~ m{ badAlg | badMessageCheck | badRequest | badTime | badCertId }xms) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_CREATE_ERROR_REPLY_INVALID_ERROR_CODE',
            params => {
                'ERROR_CODE' => $error_of{$ident},
            }
        );
    }

    my $sigalg = $hash_alg_of{$ident};
    my $encalg = $enc_alg_of{$ident};
    my $error_code = $error_of{$ident};
    my $transid;
    my $senderNonce;
    my $error_reply;
    eval {
        $transid = Crypt::LibSCEP::get_transaction_id($scep_handle_of{$ident});
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    eval {
        $senderNonce = Crypt::LibSCEP::get_senderNonce($scep_handle_of{$ident});
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    eval {
        $error_reply = Crypt::LibSCEP::create_error_reply_wop7({passin=>"pass", passwd=>$pwd, sigalg=>$sigalg, encalg => $encalg}, $key, $cert, $transid, $senderNonce, $error_code);
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    $error_reply =~ s/\n?\z/\n/;
    $error_reply =~ s/^(?:.*\n){1,1}//;
    $error_reply =~ s/(?:.*\n){1,1}\z//;
    return decode_base64($error_reply);
}

sub cleanup {

    my $self = shift;
    my $ident = ident $self;

    $fu_of{$ident}->cleanup();
}

1;
__END__
