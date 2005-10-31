## OpenXPKI::Crypto::Backend::OpenSSL
## (C)opyright 2005 Michael Bell
## $Revision
	
use strict;
use warnings;
use utf8; ## pack/unpack is too slow

package OpenXPKI::Crypto::Backend::OpenSSL;

use OpenXPKI::Crypto::Backend::OpenSSL::Shell;
use OpenXPKI::Crypto::Backend::OpenSSL::Command;

use OpenXPKI qw(debug);
use OpenXPKI::Exception;
use English;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {DEBUG => 0};
    bless $self, $class;

    my $keys = { @_ };
    $self->{DEBUG} = 1 if ($keys->{DEBUG});

    $self->__init_engine (@_);
    $self->__init_shell (@_);
    $self->__init_command (@_);

    return $self;
}

sub __init_engine
{
    my $self = shift;
    my $keys = { @_ };
    my $engine = "OpenXPKI::Crypto::Backend::OpenSSL::Engine::".$keys->{ENGINE};
    eval "use $engine;";
    if ($@)
    {
        my $msg = $@;
        OpenXPKI::Exception (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_INIT_ENGINE_USE_FAILED",
            params  => {"ERRVAL" => $msg});
    }
    $self->{ENGINE} = eval {$engine->new (@_)};
    if (my $exc = OpenXPKI::Exception->caught())
    {
        OpenXPKI::Exception (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_INIT_ENGINE_NEW_FAILED",
            child   => $exc);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }
    return 1;
}

sub __init_shell
{
    my $self = shift;
    my $keys = { @_ };

    if (not -e $keys->{SHELL})
    {
        OpenXPKI::Exception (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_MISSING_OPENSSL_BINARY");
    } else {
        $self->{OPENSSL} = $keys->{SHELL};
        $self->{SHELL}   = $keys->{SHELL};
    }
    my $wrapper = $self->{ENGINE}->get_wrapper();
    if ($wrapper)
    {
        $self->{SHELL} = $wrapper." ".$self->{OPENSSL};
    }

    eval
    {
        $self->{SHELL} = OpenXPKI::Crypto::Backend::OpenSSL::Shell->new (
                             ENGINE => $self->{ENGINE},
                             DEBUG  => $self->{DEBUG},
                             SHELL  => $self->{SHELL},
                             TMP    => $keys->{TMPDIR});
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        OpenXPKI::Exception (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_INIT_SHELL_FAILED",
            child   => $exc);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }

    return 1;
}

sub __init_command
{
    my $self = shift;
    my $keys = { @_ };

    foreach my $key (["CONFIG", "CONFIG"], ["TMPDIR", "TMP"], ["RANDFILE", "RANDOM_FILE"])
    {
        if (not exists $keys->{$key->[0]})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_MISSING_COMMAND_PARAM",
                params  => {"PARAM" => $key->[0]});
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
    my $cmd  = "OpenXPKI::Crypto::Backend::OpenSSL::Command::".shift;
    $self->debug ("Command: $cmd");

    my $ret = eval
    {
        my $cmdref = $cmd->new (%{$self->{COMMAND_PARAMS}}, @_,
                                ENGINE => $self);
        my $cmds = $cmdref->get_command();

        $self->{SHELL}->start();
        $self->{SHELL}->init_engine($self->{ENGINE}) if ($self->{ENGINE}->get_engine());
        $self->{SHELL}->run_cmd ($cmds);
        $self->{SHELL}->stop();
        my $result = $self->{SHELL}->get_result();
        $result = $cmdref->get_result ($result);

        if ($cmdref->hide_output())
        {
            $self->debug ("successfully completed");
        } else {
            $self->debug ("successfully completed: $result");
        }

        $cmdref->cleanup();
        return $result;
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        $self->{SHELL}->stop(); ## this is safe
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_COMMAND_FAILED",
            params  => {"COMMAND" => $cmd},
            child   => $exc);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    } else {
        return $ret;
    }
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
            $object = OpenXPKI::Crypto::Backend::OpenSSL::X509::_new_from_der ($data);
        } else {
            $object = OpenXPKI::Crypto::Backend::OpenSSL::X509::_new_from_pem ($data);
        }
    } elsif ($type eq "CSR")
    {
        if ($format eq "DER")
        {
            $object = OpenXPKI::Crypto::Backend::OpenSSL::PKCS10::_new_from_der ($data);
        }
        elsif ($format eq "SPKAC")
        {
            #$data =~ s/.*SPKAC\s*=\s*([^\s\n]*).*/$1/s;
            #$self->debug ("spkac is ".$data);
            #$self->debug ("length of spkac is ".length($data));
            #$self->debug ("data is ".$data);
            $object = OpenXPKI::Crypto::Backend::OpenSSL::SPKAC::_new ($data);
        } else {
            $object = OpenXPKI::Crypto::Backend::OpenSSL::PKCS10::_new_from_pem ($data);
        }
    } elsif ($type eq "CRL")
    {
        if ($format eq "DER")
        {
            $object = OpenXPKI::Crypto::Backend::OpenSSL::CRL::_new_from_der ($data);
        } else {
            $object = OpenXPKI::Crypto::Backend::OpenSSL::CRL::_new_from_pem ($data);
        }
    } else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_GET_OBJECT_UNKNOWN_TYPE",
            params  => {"TYPE" => $type});
    }
    if (not $object)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_GET_OBJECT_NO_REF");
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
    ## use utf8;
    my $result = $object->$func();
    ## pack/unpack is much too slow
    #my $result = pack "U0C*", unpack "C*", $object->$func();

    ## fix proprietary "DirName:" of OpenSSL
    if (defined $result and $func eq "extensions")
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
                my $dn = OpenXPKI::DN::convert_openssl_dn ($value);
                $result .= $name.$dn."\n";
            }
        }
    }

    return $result;
}

sub free_object
{
    my $self   = shift;
    my $object = shift;
    $object->free();
    return 1;
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
        return  $self->{ENGINE}->$AUTOLOAD (@_);
    }
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_OPENSSL_AUTOLOAD_MISSING_FUNCTION",
        params  => {"FUNCTION" => $AUTOLOAD});
}

1;
__END__

=head1 Description

=head1 Functions
