## OpenXPKI::Crypto::Tool::LibSCEP::Command::create_crl_reply
## Written 2015-2018 by Gideon Knocke and Martin Bartosch for the OpenXPKI project
## (C) Copyright 2015-2018 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::LibSCEP::Command::create_crl_reply;

use strict;
use warnings;
use English;

use Class::Std;
use Data::Dumper;

use OpenXPKI::FileUtils;
use OpenXPKI::Debug;
use Crypt::LibSCEP;
use MIME::Base64;

my %scep_handle_of   :ATTR;
my %engine_of        :ATTR;
my %crl_of           :ATTR;
my %pkcs7_of         :ATTR;
my %enc_alg_of       :ATTR;
my %hash_alg_of      :ATTR;
my %fu_of            :ATTR;


sub START {
    my ($self, $ident, $arg_ref) = @_;

    $fu_of     {$ident}     = OpenXPKI::FileUtils->new();
    $engine_of {$ident}     = $arg_ref->{ENGINE};
    $scep_handle_of{$ident} = $arg_ref->{SCEP_HANDLE};
    $pkcs7_of{$ident}       = $arg_ref->{PKCS7};
    $crl_of    {$ident}     = $arg_ref->{CRL};
    $enc_alg_of{$ident}     = $arg_ref->{ENCRYPTION_ALG};
    $hash_alg_of {$ident}   = $arg_ref->{HASH_ALG};

}

sub get_result
{
    my $self = shift;
    my $ident = ident $self;

    if (! defined $engine_of{$ident}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_CREATE_CRL_REPLY_NO_ENGINE',
        );
    }
    ##! 64: 'engine: ' . Dumper($engine_of{$ident})
    my $keyfile  = $engine_of{$ident}->get_keyfile();
    if (! defined $keyfile || $keyfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_CREATE_CRL_REPLY_KEYFILE_MISSING',
        );
    }
    my $certfile = $engine_of{$ident}->get_certfile();
    if (! defined $certfile || $certfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_CREATE_CRL_REPLY_CERTFILE_MISSING',
        );
    }
    my $pwd    = $engine_of{$ident}->get_passwd();

    my $cert = $fu_of{$ident}->read_file($certfile);
    my $key = $fu_of{$ident}->read_file($keyfile);

    my $encalg = $enc_alg_of{$ident};
    if($encalg eq '3DES') {
        $encalg = 'des3';
    }
    my $sigalg = $hash_alg_of{$ident};

    my $crl_content_base64 = $crl_of{$ident};

    my $getcrl_message = $pkcs7_of{$ident};


    my $transid;
    eval {
        $transid = $scep_handle_of{$ident}->get_transaction_id;
    };
    if($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }

    my $senderNonce;
    eval {
        $senderNonce = $scep_handle_of{$ident}->get_senderNonce;
    };
    if($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }

    my $enc_cert;
    eval {
        $enc_cert = $scep_handle_of{$ident}->get_signer_cert;
    };
    if($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }

    my $crl_reply;
    eval {
      # FIXME: Crypt::LibSCEP has a bug in create_crl_reply_wop7 (missing error checking on several internal
      # bio operations, leading to a segment violation on attempted free of unallocated memory)
      # workaround: fall back to create_crl_reply - but this command needs the raw input data
      #$crl_reply = Crypt::LibSCEP::create_crl_reply_wop7({passin=>"pass", passwd=>$pwd, sigalg=>$sigalg, encalg=>$encalg}, $key, $cert, $transid, $senderNonce, $enc_cert, $crl_content_base64);
      $crl_reply = Crypt::LibSCEP::create_crl_reply({passin=>"pass", passwd=>$pwd, sigalg=>$sigalg, encalg=>$encalg}, $key, $cert, $getcrl_message, $crl_content_base64);
      ##! 64: 'created crl reply'
    };
    if($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }

    $crl_reply =~ s/\n?\z/\n/;
    $crl_reply =~ s/^(?:.*\n){1,1}//;
    $crl_reply =~ s/(?:.*\n){1,1}\z//;
    return decode_base64($crl_reply);
}

sub cleanup {

    my $self = shift;
    my $ident = ident $self;

    $fu_of{$ident}->cleanup();
}

1;
__END__
