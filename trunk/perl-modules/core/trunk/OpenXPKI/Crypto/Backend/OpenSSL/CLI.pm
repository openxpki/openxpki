## OpenXPKI::Crypto::Backend::OpenSSL::CLI
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision
	
use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::CLI;

use OpenXPKI::Debug 'OpenXPKI::Crypto::Backend::OpenSSL::CLI';
use OpenXPKI qw (read_file get_safe_tmpfile);
use OpenXPKI::Exception;
use English;

sub new
{
    ##! 1: "start"
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};
    bless $self, $class;

    ##! 2: "read parameters"
    my $keys = shift;

    ##! 4: "check TMP"
    if (not exists $keys->{TMP})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_MISSING_TMP");
    }
    if (not -d $keys->{TMP})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_TMP_DOES_NOT_EXIST",
            params  => {"TMP" => $keys->{TMP}});
    }
    $self->{TMP} = $keys->{TMP};;

    ##! 4: "check SHELL"
    if (not exists $keys->{SHELL})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_MISSING_SHELL");
    }
    if (not -e $keys->{SHELL})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_SHELL_DOES_NOT_EXIST",
            params  => {"SHELL" => $keys->{SHELL}});
    }
    $self->{SHELL} = $keys->{SHELL};;

    ##! 4: "check ENGINE"
    if (not exists $keys->{ENGINE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_MISSING_ENGINE");
    }
    $self->{ENGINE} = $keys->{ENGINE};;

    ##! 2: "create input, output and stderr files"
    $self->{STDIN}  = $self->get_safe_tmpfile({TMP => $self->{TMP}});
    $self->{STDOUT} = $self->get_safe_tmpfile({TMP => $self->{TMP}});
    $self->{STDERR} = $self->get_safe_tmpfile({TMP => $self->{TMP}});

    ##! 1: "end"
    return $self;
}

sub prepare
{
    my $self = shift;
    my $keys = shift;
    ##! 1: "start"

    if (ref $keys->{COMMAND} and
        ref $keys->{COMMAND} eq "ARRAY")
    {
        $self->{COMMAND} = [];
        foreach my $cmd (@{$keys->{COMMAND}})
        {
            push @{$self->{COMMAND}}, $cmd;
        }
    }
    else
    {
        $self->{COMMAND} = $keys->{COMMAND};
    }
    for (my $i=0; $i < scalar @{$self->{COMMAND}}; $i++)
    {
        $self->{COMMAND}->[$i] = $self->{SHELL}."   ".$self->{COMMAND}->[$i].
                                                " 1>>".$self->{STDOUT}.
                                                " 2>>".$self->{STDERR};
        ##! 4: "prepared command: ".$self->{COMMAND}->[$i]
    }

    ##! 1: "end"
    return 1;
}

sub execute
{
    my $self = shift;
    ##! 1: "start"

    for (my $i=0; $i < scalar @{$self->{COMMAND}}; $i++)
    {
        my $cmd = $self->{COMMAND}->[$i];
        ##! 4: "command: $cmd"
        `$cmd`;
        if ($EVAL_ERROR)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_EXECUTE_FAILED",
                params  => {"ERRVAL" => $EVAL_ERROR});
        }
    }
    unlink ($self->{STDIN});

    ##! 2: "try to detect other errors"
    $self->__find_error();

    ##! 1: "end"
    return 1;
}

sub __find_error
{
    my $self = shift;
    ##! 1: "start"

    ##! 2: "does stderr file exist?"
    return 1 if (not -e $self->{STDERR});

    ##! 2: "open, read and delete the error log"
    my $ret = "";
    if (open FD, $self->{STDERR})
    {
        while ( <FD> ) {
            $ret .= $_;
        }
        close(FD);
    } else {
        unlink ($self->{STDOUT});
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_CANNOT_OPEN_ERRLOG",
            params  => {"FILENAME" => $self->{STDERR}});
    }
    unlink ($self->{STDERR});

    ##! 4: "error log contains: $ret"
    $ret = $self->{ENGINE}->filter_stderr($ret);
    if ($ret =~ /error/i)
    {
        ##! 8: "error detected - firing exception"
        unlink ($self->{STDOUT});
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_ERROR",
            params  => {"ERRVAL" => $ret});
    }

    ##! 1: "end - no errors"
    return 0;
}

sub get_result
{
    my $self = shift;
    ##! 1: "start"

    my $ret = 1;
    if (-e $self->{STDOUT})
    {
        ## there was an output
        $ret = $self->read_file($self->{STDOUT});
        $ret = $self->{ENGINE}->filter_stdout($ret);
        $ret = 1 if ($ret eq "");
    }
    unlink ($self->{STDOUT});

    ## WARNING: DO NOT OUTPUT ANYTHING HERE
    ## WARNING: THE OUTPUT MUST BE CHECKED BY THE CALLER FOR ITS SECURITY LEVEL

    ##! 1: "end"
    return $ret;
}

sub cleanup
{
    ##! 1: "start"
    my $self = shift;
    unlink ($self->{STDOUT}) if (exists $self->{STDOUT} and -e $self->{STDOUT});
    ##! 1: "end"
}

sub DESTROY
{
    ##! 1: "start"
    my $self = shift;
    $self->cleanup();
    ##! 1: "end"
}

1;
__END__

=head1 Desription

This module implements the handling of the OpenSSL shell. This
includes things like the initialization of the engines or the
detection of errors.

=head1 Functions

=head2 new

The new function creates a new instance of this class. There are
the following parameters:

=over

=item * SHELL (the OpenSSL binary)

=item * ENGINE (a reference to an OpenXPKI::Crypto::Backend::OpenSSL::Engine object)

=item * TMP (the temporary directory)

=back

=head2 prepare

This prepares a command array to be executed. The only parameter is
COMMAND which must contain an string or an array reference.

=head2 execute

performs the commands. It throws an exception on error.

=head2 get_result

returns the result of the commands which were executed with run_cmd.
If there was no output then 1 will be returned.

=head1 Example

my $cli = OpenXPKI::Crypto::Backend::OpenSSL::CLI->new
          ({
              TMP    => "/tmp",
              SHELL  => "/usr/local/ssl/bin/openssl",
              ENGINE => $engine
          });
$cli->prepare ({COMMAND => ['x509 -in cert.pem -outform DER -out cert.der']});
$cli->execute ();
## senseless here because the result is in cert.der
## $cli->get_result();
undef $cli;
## now do something with cert.der
