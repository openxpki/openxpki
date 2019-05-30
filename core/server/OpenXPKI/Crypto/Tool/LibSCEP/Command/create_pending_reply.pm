## OpenXPKI::Crypto::Tool::LibSCEP::Command::create_pending_reply
## Written 2015-2018 by Gideon Knocke and Martin Bartosch for the OpenXPKI project
## (C) Copyright 2015-2018 by The OpenXPKI Project
package OpenXPKI::Crypto::Tool::LibSCEP::Command::create_pending_reply;

use strict;
use warnings;
use English;

use Class::Std;

use OpenXPKI::Debug;
use Crypt::LibSCEP;
use OpenXPKI::FileUtils;
use MIME::Base64;

my %scep_handle_of   :ATTR;
my %engine_of  :ATTR;
my %enc_alg_of  :ATTR;
my %hash_alg_of  :ATTR;
my %fu_of      :ATTR;

sub START {
    my ($self, $ident, $arg_ref) = @_;
    $fu_of{$ident} = OpenXPKI::FileUtils->new();
    $engine_of{$ident} = $arg_ref->{ENGINE};
    $scep_handle_of {$ident} = $arg_ref->{SCEP_HANDLE};
    $enc_alg_of {$ident} = $arg_ref->{ENCRYPTION_ALG};
    $hash_alg_of {$ident} = $arg_ref->{HASH_ALG};
}

sub get_result
{
    my $self = shift;
    my $ident = ident $self;

    if (! defined $engine_of{$ident}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_CREATE_PENDING_REPLY_NO_ENGINE',
        );
    }
    ##! 64: 'engine: ' . Dumper($engine_of{$ident})
    my $keyfile  = $engine_of{$ident}->get_keyfile();
    if (! defined $keyfile || $keyfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_CREATE_PENDING_REPLY_KEYFILE_MISSING',
        );
    }
    my $certfile = $engine_of{$ident}->get_certfile();
    if (! defined $certfile || $certfile eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_TOOL_LIBSCEP_COMMAND_CREATE_PENDING_REPLY_CERTFILE_MISSING',
        );
    }
    my $pwd    = $engine_of{$ident}->get_passwd();
    my $cert = $fu_of{$ident}->read_file($certfile);
    my $key = $fu_of{$ident}->read_file($keyfile);
    my $encalg = $enc_alg_of{$ident};
    my $sigalg = $hash_alg_of{$ident};
    my $config = {passin=>"pass", passwd=>$pwd, sigalg=>$sigalg, encalg=>$encalg};
    my $transid;
    my $senderNonce;
    my $pending_reply;
    eval {
        $transid = $scep_handle_of{$ident}->get_transaction_id;
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    eval {
        $senderNonce = $scep_handle_of{$ident}->get_senderNonce;
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    eval{
        $pending_reply = Crypt::LibSCEP::create_pending_reply_wop7($config, $key, $cert, $transid, $senderNonce);
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => $EVAL_ERROR,
        );
    }
    #PEM TO DER
    $pending_reply =~ s/\n?\z/\n/;
    $pending_reply =~ s/^(?:.*\n){1,1}//;
    $pending_reply =~ s/(?:.*\n){1,1}\z//;
    return decode_base64($pending_reply);
}

sub cleanup {

    my $self = shift;
    my $ident = ident $self;

    $fu_of{$ident}->cleanup();
}

1;
__END__
