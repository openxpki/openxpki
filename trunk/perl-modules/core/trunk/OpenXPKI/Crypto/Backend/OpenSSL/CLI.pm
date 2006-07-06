## OpenXPKI::Crypto::Backend::OpenSSL::CLI
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$
	
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
    $self->{SHELL} = $keys->{SHELL};;

    ##! 4: "check ENGINE"
    if (not exists $keys->{ENGINE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_MISSING_ENGINE");
    }
    $self->{ENGINE} = $keys->{ENGINE};;

    ##! 4: "check CONFIG"
    if (not exists $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_MISSING_CONFIG");
    }
    $self->{CONFIG} = $keys->{CONFIG};;

    ##! 2: "create output and stderr files"
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

    ##! 2: "handle parameter COMMAND"
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
    ##! 1: "start"
    my $self   = shift;
    my $keys   = shift;

    my $return = "";
    my $params;

    if (defined $keys) {
        $params = $keys->{PARAMS};
    }

    ##! 2: "set the configuration"
    $self->{CONFIG}->dump();
    $ENV{OPENSSL_CONF} = $self->{CONFIG}->get_config_filename();

    ##! 2: "execute commands"
    for (my $i=0; $i < scalar @{$self->{COMMAND}}; $i++)
    {
        my $cmd = $self->{COMMAND}->[$i];
        ##! 4: "command: $cmd"
        if (defined $params and
            exists $params->[$i] and
            ref $params->[$i] and ref $params->[$i] eq "HASH" and
            ($params->[$i]->{TYPE} eq "STDIN" or
             $params->[$i]->{TYPE} eq "STDOUT")
           )
        {
            if ($params->[$i]->{TYPE} eq "STDIN")
            {
                ## read data from STDIN
                if (not open FD, "|$cmd" or
                    not print FD $params->[$i]->{DATA} or
                    not close FD)
                {
                    OpenXPKI::Exception->throw (
                        message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_EXECUTE_PIPED_STDIN_FAILED",
                        params  => {"ERRVAL" => $EVAL_ERROR});
                }
            }
            else
            {
                ## capture STDOUT
                if (not open FD, "$cmd|")
                {
                    OpenXPKI::Exception->throw (
                        message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_EXECUTE_PIPED_STDOUT_FAILED",
                        params  => {"ERRVAL" => $EVAL_ERROR});
                }
                $params->[$i]->{STDOUT} = "";
                while (<FD>)
                {
                    $params->[$i]->{STDOUT} .= $_;
                }
                $return .= $params->[$i]->{STDOUT};
                close FD;
            }
        } else {
            ## simply execute the command
            `$cmd`;
        }
        if ($EVAL_ERROR)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_CLI_EXECUTE_FAILED",
                params  => {"ERRVAL" => $EVAL_ERROR});
        }
    }

    ##! 2: "try to detect other errors"
    $self->__find_error();

    ##! 1: "end"
    return $return;
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
    if ($ret =~ /error/i or
        $ret =~ /unable to load key/i)
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
    unlink ($self->{STDIN})  if (exists $self->{STDIN}  and -e $self->{STDIN});
    unlink ($self->{STDOUT}) if (exists $self->{STDOUT} and -e $self->{STDOUT});
    unlink ($self->{STDERR}) if (exists $self->{STDERR} and -e $self->{STDERR});
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

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::CLI

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

performs the commands. It throws an exception on error. The behaviour of
this function is a little bit difficult. The simplest way is that you
use the function without any arguments. This means that you have passed
all parameters via the command line parameters and you get the the
result via the function get_result or you used an explicit output
file.

Example: $cli->execute();

The function supports a little bit different way too. Sometimes it is
necessary to pass input directly or to read the output directly beause
it is critical data which should never be stored on a disk. You can use
the parameter PARAMS in this case. You have to specify for each
command which you specified via prepare a type and if necessary the data.

Example: $cli->prepare ({COMMAND => ["command1 -params ...",
                                     "command2 -params ...",
                                     "command3 -params ...",
                                     "command4 -params ..."]});
         my $params = [
                       {TYPE => "STDIN", DATA => "the input data"},
                       {TYPE => "STDOUT"},
                       {TYPE => "NOTHING"},
                       {TYPE => "STDOUT"},
                      ];
         my $result = $cli->execute ({PARAMS => $params});
 
The first command is an example for using STDIN. The specified data
will be passed via STDIN to the command. The second command passes the
result via STDOUT directly into the code. This means that $result
contains the result from the queries two and four. If you need the
results seperately the please look into $params->[1]->{STDOUT} and
$params->[3]->{STDOUT}. The third query simply enforce normal
behaviour via files.

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
