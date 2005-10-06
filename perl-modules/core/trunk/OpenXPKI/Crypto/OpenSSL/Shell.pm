## OpenXPKI::Crypto::OpenSSL::Shell
## (C)opyright 2005 Michael Bell
## $Revision
	
use strict;
use warnings;

package OpenXPKI::Crypto::OpenSSL::Shell;

our ($errno, $errval);

use OpenXPKI qw (i18nGettext debug set_error errno errval read_file);

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = { @_ };
    bless $self, $class;

    ## DEBUG, TMP, ENGINE and SHELL are required

    $self->{STDOUT} = $self->{TMP}."/${$}_stdout.log";
    $self->{STDERR} = $self->{TMP}."/${$}_stderr.log";
    #$self->{DEBUG}  = 1;

    return $self;
}

sub start
{
    my $self = shift;
    $self->debug ("try to start shell");
    my $keys = { @_ };

    return 1 if ($self->{OPENSSL_FD});

    my $open = "| ".$self->{SHELL}.
               " 1>".$self->{STDOUT}.
               " 2>".$self->{STDERR};
    $self->debug ($open);
    if (not open $self->{OPENSSL_FD}, $open)
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_START_OPEN_FAILED",
                          "__ERRVAL__", $!);
        return undef;
    }
    $self->debug ("shell started");
    return 1;
}

sub init_engine
{
    my $self        = shift;
    $self->{ENGINE} = shift;

    $self->debug ("start");
    return 1 if (not $self->{ENGINE}->is_dynamic() and
                 not $self->{ENGINE}->get_engine_params());

    $self->debug ("initializing engine");
    my $command;
    if ($self->{ENGINE}->is_dynamic()) {
        $command = "engine dynamic -pre ID:".$self->{ENGINE}->get_engine();
    } else {
        $command = "engine ".$self->{ENGINE}->get_engine();
    }
    $command .= $self->{ENGINE}->get_engine_params();

    $command .= "\n";
    if (not print {$self->{OPENSSL_FD}} $command)
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_INIT_ENGINE_SHELL_PRINT_FAILED",
                          "__ERRVAL__", $!);
        return undef;
    }

    $self->debug ("engine intialized");

    return 1;
}

sub stop
{
    my $self = shift;
    $self->debug ("try to stop shell");

    return 1 if (not $self->{OPENSSL_FD});

    print {$self->{OPENSSL_FD}} "exit\n";
    close $self->{OPENSSL_FD};
    delete $self->{OPENSSL_FD};

    return 1;
}

sub run_cmd
{
    my $self = shift;
    $self->debug ("start");
    my $cmds = shift;

    foreach my $command (@{$cmds})
    {
        $command =~ s/\n*$//;
        $command .= "\n";
        $self->debug ("command: $command");
        if (not print {$self->{OPENSSL_FD}} $command)
        {
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_RUN_CMD_FAILED",
                              "__COMMAND__", $command,
                              "__ERRVAL__", $!);
            return undef;
        }
    }
    $self->debug ("all executed");

    return 1;
}

sub is_error
{
    my $self = shift;

    ## check for errors

    $self->debug ("check for errors");

    if (-e $self->{STDERR})
    {
        $self->debug ("detected error log");
        ## there was an error
        my $ret = "";
        if (open FD, $self->{STDERR})
        {
            while ( <FD> ) {
                $ret .= $_;
            }
            close(FD);
        } else {
            unlink ($self->{STDOUT});
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_CANNOT_OPEN_ERRLOG",
                              "__FILENAME__", $self->{STDERR});
            $self->debug ("error detected");
            return 1;
        }
        unlink ($self->{STDERR});
        $self->debug ("stderr (".$self->{STDERR}.": $ret)");
        $ret = $self->{ENGINE}->filter_stderr($ret);
        if ($ret =~ /error/i)
        {
            unlink ($self->{STDOUT});
            $self->set_error ("I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_COMMAND_ERROR",
                              "__ERRVAL__", $ret);
            $self->debug ("error detected");
            return 1;
        }
    }
    $self->debug ("no errors");

    return 0;
}

sub get_result
{
    my $self = shift;
    $self->debug ("start");

    my $ret = 1;
    if (-e $self->{STDOUT})
    {
        ## there was an output
        $ret = $self->read_file($self->{STDOUT});
        return undef if (not defined $ret);
        $ret = $self->{ENGINE}->filter_stdout($ret);
        $ret =~ s/^(OpenSSL>\s)*//s;
        $ret =~ s/OpenSSL>\s$//s;
        $ret = 1 if ($ret eq "");
    }
    unlink ($self->{STDOUT});

    ## WARNING: DO NOT OUTPUT ANYTHING HERE
    ## WARNING: THE OUTPUT MUST BE CHECKED BY THE CALLER FOR ITS SECURITY LEVEL

    return $ret;
}

sub DESTROY
{
    my $self = shift;
    $self->stop() if ($self->{OPENSSL_FD});
}

1;
