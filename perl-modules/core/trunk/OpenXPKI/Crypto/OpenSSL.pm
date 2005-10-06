## OpenXPKI::Crypto::OpenSSL
## (C)opyright 2005 Michael Bell
## $Revision
	
use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL;

use OpenXPKI::Crypto::OpenSSL::Shell;
use OpenXPKI::Crypto::OpenSSL::Command;

our ($errno, $errval);

use OpenXPKI qw (i18nGettext debug set_error errno errval);

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {DEBUG => 0};
    bless $self, $class;

    my $keys = { @_ };
    $self->{DEBUG} = 1 if ($keys->{DEBUG});

    return undef if (not $self->init_engine (@_));
    return undef if (not $self->init_shell (@_));
    return undef if (not $self->init_command (@_));

    return $self;
}

sub init_engine
{
    my $self = shift;
    my $keys = { @_ };
    my $engine = "OpenXPKI::Crypto::OpenSSL::Engine::".$keys->{ENGINE};
    eval "use $engine;";
    if ($@)
    {
        my $msg = $@;
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_INIT_ENGINE_USE_FAILED",
                          "__ERRVAL__", $msg);
        return undef;
    }
    $self->{ENGINE} = eval ("$engine->new ( \@_ )");
    if ($@)
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_INIT_ENGINE_MODULE_FAILED",
                          "__ERRVAL__", $@);
        return undef;
    }
    if (not $self->{ENGINE})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_INIT_ENGINE_NEW_FAILED",
                          "__ERRVAL__", eval ("\$${engine}::errval"));
        return undef;
    }
    return 1;
}

sub init_shell
{
    my $self = shift;
    my $keys = { @_ };

    if (not -e $keys->{SHELL})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_MISSING_OPENSSL_BINARY");
        return undef;
    } else {
        $self->{OPENSSL} = $keys->{SHELL};
        $self->{SHELL}   = $keys->{SHELL};
    }
    my $wrapper = $self->{ENGINE}->get_wrapper();
    if ($wrapper)
    {
        $self->{SHELL} = $wrapper." ".$self->{OPENSSL};
    }

    $self->{SHELL} = OpenXPKI::Crypto::OpenSSL::Shell->new (
                         ENGINE => $self->{ENGINE},
                         DEBUG  => $self->{DEBUG},
                         SHELL  => $self->{SHELL},
                         TMP    => $keys->{TMPDIR});
    if (not $self->{SHELL})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_INIT_SHELL_FAILED",
                          "__ERRVAL__", $OpenXPKI::Crypto::OpenSSL::Shell::errval);
        return undef;
    }

    return 1;
}

sub init_command
{
    my $self = shift;
    my $keys = { @_ };

    foreach my $key (["CONFIG", "CONFIG"], ["TMPDIR", "TMP"], ["RANDFILE", "RANDOM_FILE"])
    {
        if (not exists $keys->{$key->[0]})
        {
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_MISSING_COMMAND_PARAM",
                              "__PARAM__", $key->[0]);
            return undef;
        }
        $self->{COMMAND_PARAMS}->{$key->[1]} = $keys->{$key->[0]};
    }

    return 1;
}

sub set_config
{
    my $self = shift;
    $self->{COMMAND_PARAMS}->{CONFIG} = shift;
    return 1;
}

sub command
{
    my $self = shift;
    my $cmd  = "OpenXPKI::Crypto::OpenSSL::Command::".shift;
    $self->debug ("Command: $cmd");

    my $cmdref = $cmd->new (%{$self->{COMMAND_PARAMS}}, @_,
                            ENGINE => $self);
    if (not $cmdref)
    {
        
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_NEW_FAILED",
                          "__COMMAND__", $cmd,
                          "__ERRVAL__", OpenXPKI::Crypto::OpenSSL::Command->errval());
        return undef;
    }
    my $cmds = $cmdref->get_command();
    if (not defined $cmds)
    {
        $self->set_error ($cmdref->errval());
        return undef;
    }

    $self->{SHELL}->start();
    $self->{SHELL}->init_engine($self->{ENGINE}) if ($self->{ENGINE}->get_engine());
    if (not defined $self->{SHELL}->run_cmd ($cmds))
    {
        $self->set_error ($self->{SHELL}->errval());
        $self->{SHELL}->stop();
        $cmdref->cleanup();
        return undef;
    }
    $self->{SHELL}->stop();
    if ($self->{SHELL}->is_error())
    {
        $self->set_error ($self->{SHELL}->errval());
        $cmdref->cleanup();
        return undef;
    }
    my $result = $self->{SHELL}->get_result();
    if (not defined $result)
    {
        $self->set_error ($self->{SHELL}->errval());
        $cmdref->cleanup();
        return undef;
    }
    $result = $cmdref->get_result ($result);
    if (not defined $result)
    {
        $self->set_error ($cmdref->errval());
        $cmdref->cleanup();
        return undef;
    }

    if ($cmdref->hide_output())
    {
        $self->debug ("successfully completed");
    } else {
        $self->debug ("successfully completed: $result");
    }

    $cmdref->cleanup();
    return $result;
}

sub get_object
{
    my $self = shift;
    my $keys = { @_ };

    my $format = ($keys->{FORMAT} or "PEM");
    my $data   = $keys->{DATA};
    my $type   = $keys->{TYPE};

    $self->debug ("format: $format") if($format);
    $self->debug ("data:   $data");
    $self->debug ("type:   $type");

    my $object = undef;
    if ($type eq "X509")
    {
        if ($format eq "DER")
        {
            $object = OpenXPKI::Crypto::OpenSSL::X509::_new_from_der ($data);
        } else {
            $object = OpenXPKI::Crypto::OpenSSL::X509::_new_from_pem ($data);
        }
    } elsif ($type eq "CSR")
    {
        if ($format eq "DER")
        {
            $object = OpenXPKI::Crypto::OpenSSL::PKCS10::_new_from_der ($data);
        }
        elsif ($format eq "SPKAC")
        {
            #$data =~ s/.*SPKAC\s*=\s*([^\s\n]*).*/$1/s;
            #$self->debug ("spkac is ".$data);
            #$self->debug ("length of spkac is ".length($data));
            #$self->debug ("data is ".$data);
            $object = OpenXPKI::Crypto::OpenSSL::SPKAC::_new ($data);
        } else {
            $object = OpenXPKI::Crypto::OpenSSL::PKCS10::_new_from_pem ($data);
        }
    } elsif ($type eq "CRL")
    {
        if ($format eq "DER")
        {
            $object = OpenXPKI::Crypto::OpenSSL::CRL::_new_from_der ($data);
        } else {
            $object = OpenXPKI::Crypto::OpenSSL::CRL::_new_from_pem ($data);
        }
    } else {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_GET_OBJECT_UNKNOWN_TYPE",
                          "__TYPE__", $type);
        return undef;
    }
    if (not $object)
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_GET_OBJECT_NO_REF");
        return undef;
    }

    $self->debug ("returning object");

    return $object;
}

sub get_object_function
{
    my $self   = shift;
    my $keys   = { @_ };
    my $object = $keys->{OBJECT};
    my $func   = $keys->{FUNCTION};

    return $object->free() if ($func eq "free");

    ## unicode handling
    my $result = pack "U0C*", unpack "C*", $object->$func();

    ## fix proprietary "DirName:" of OpenSSL
    if ($func eq "extensions")
    {
        my @lines = split /\n/, $result;
        $result = "";
        foreach my $line (@lines)
        {
            if ($line !~ /^\s*DirName:/)
            {
                $result .= $line."\n";
            } else {
                my ($name, $value) = ($line, $line);
                $name  =~ s/^(\s*DirName:).*$/$1/;
                $value =~ s/^\s*DirName:(.*)$/$1/;
                my $dn = OpenXPKI::DN->new ($value);
                $result .= $name.$dn->get_rfc_2253_dn()."\n";
            }
        }
    }

    return $result;
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;
    $AUTOLOAD =~ s/^.*://;
    return if ($AUTOLOAD eq "DESTROY");
    if ($AUTOLOAD eq "online" or
        $AUTOLOAD eq "login" or
        $AUTOLOAD eq "get_mode" or
        $AUTOLOAD eq "get_keyfile" or
        $AUTOLOAD eq "get_certfile" or
        $AUTOLOAD eq "get_chainfile" or
        $AUTOLOAD eq "get_engine" or
        $AUTOLOAD eq "get_keyform" or
        $AUTOLOAD eq "get_passwd")
    {
        my $result = $self->{ENGINE}->$AUTOLOAD (@_);
        if (not defined $result)
        {
            $self->set_error ($self->{ENGINE}->errval());
            return undef;
        } else {
            return $result;
        }
    }
    $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_AUTOLOAD_MISSING_FUNCTION",
                      "__FUNCTION__", $AUTOLOAD);
    return undef;
}

1;
