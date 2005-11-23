## OpenXPKI::Crypto::Backend::OpenSSL::Shell
## (C)opyright 2005 Michael Bell
## $Revision
	
use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Shell;

use OpenXPKI qw (debug read_file);
use OpenXPKI::Exception;

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
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_START_OPEN_FAILED",
            params  => {"ERRVAL" => $!});
    }
    ## this required to avoid:
    ##     1. warnings about printing wide characters
    ##     2. automatic iso8859-1 conversion if this is possible
    binmode  $self->{OPENSSL_FD}, ":utf8";
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
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_INIT_ENGINE_SHELL_PRINT_FAILED",
            params  => {"ERRVAL" => $!});
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

    $self->__check_error();

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
            OpenXPKI::Exception->throw (
            messages => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_RUN_CMD_FAILED",
            params   => {"COMMAND" => $command,
                         "ERRVAL"  => $!});
        }
    }
    $self->debug ("all executed");

    return 1;
}

sub __check_error
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
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_CANNOT_OPEN_ERRLOG",
                params  => {"FILENAME" => $self->{STDERR}});
        }
        unlink ($self->{STDERR});
        $self->debug ("stderr (".$self->{STDERR}.": $ret)");
        $ret = $self->{ENGINE}->filter_stderr($ret);
        if ($ret =~ /error/i)
        {
            unlink ($self->{STDOUT});
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_COMMAND_ERROR",
                params  => {"ERRVAL" => $ret});
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

=item * DEBUG

=item * SHELL (the OpenSSL binary)

=item * ENGINE (a reference to an OpenXPKI::Crypto::Backend::OpenSSL::Engine object)

=item * TMP (the temporary directory)

=back

=head2 start

This opens a new shell session.

=head2 init_engine

is used to initialize the engine which is used by this cryptographic token.

=head2 stop

This kills a shell session.

=head2 run_cmd

The functions expects an ARRAY reference which includes
a sequence of OpenSSL commands. All commands are executed.

=head2 get_result

returns the result of the commands which were executed with run_cmd.
If there was no output then 1 will be returned.
