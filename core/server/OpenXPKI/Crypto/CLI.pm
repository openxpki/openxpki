## OpenXPKI::Crypto::CLI
## Written 2006 by Alexander Klink for the OpenXPKI project
## largely based on the (former) code of OpenXPKI::Crypto::Backend::
## OpenSSL::CLI by Michael Bell for the OpenXPKI project, 2005-2006
## (C) Copyright 2005-2006 by The OpenXPKI Project
package OpenXPKI::Crypto::CLI;

use strict;
use warnings;
use English;
use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::FileUtils;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context;
use Data::Dumper;
use Proc::SafeExec;
use Log::Log4perl qw(:easy);

my %tmp_of    :ATTR( :init_arg<TMP>    ); # the tmp directory
my %shell_of  :ATTR( :init_arg<SHELL>  ); # the shell to be used
my %engine_of :ATTR( :init_arg<ENGINE> ); # the engine used
my %stdout_file_of :ATTR; # STDOUT file (redirected output from command)
my %stderr_file_of :ATTR; # STDERR file (redirected output from command)
my %command_of     :ATTR; # the command used
my %logger_of      :ATTR; # OpenXPKI logger
my %fu_of      :ATTR; # FileUtils

sub START {
    my ($self, $ident, $arg_ref) = @_;

    if (ref $self eq 'OpenXPKI::Crypto::CLI') {
        # somebody tried to instantiate us, but we are supposed to be abstract.
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_CLI_IS_ABSTRACT_CLASS',
        );
    }
    ##! 4: "check TMP"
    if (not exists $arg_ref->{TMP}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CLI_MISSING_TMP");
    }
    if (not -d $arg_ref->{TMP}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CLI_TMP_DOES_NOT_EXIST",
            params  => {"TMP" => $arg_ref->{TMP}});
    }

    ##! 4: "check SHELL"
    if (not exists $arg_ref->{SHELL}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CLI_MISSING_SHELL");
    }

    ##! 4: "check ENGINE"
    if (not exists $arg_ref->{ENGINE}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CLI_MISSING_ENGINE");
    }


    if(!Log::Log4perl->initialized()) {
        Log::Log4perl->easy_init($ERROR);
    }
    $logger_of{$ident} = Log::Log4perl->get_logger('system.crypto');

    $fu_of{$ident} = OpenXPKI::FileUtils->new({ TMP => $arg_ref->{TMP} });

    $stdout_file_of{$ident} = $fu_of{$ident}->get_tmp_handle();
    $stderr_file_of{$ident} = $fu_of{$ident}->get_tmp_handle();

}

sub prepare {
    my $self = shift;
    my $ident = ident $self;
    my $arg_ref = shift;
    ##! 1: "start"

    ##! 2: "handle parameter COMMAND"
    if (ref $arg_ref->{COMMAND} eq 'ARRAY') { # there are multiple commands
        $command_of{$ident} = [];
        foreach my $cmd (@{$arg_ref->{COMMAND}}) {
            push @{$command_of{$ident}}, $cmd;
        }
    }
    else {
        @{$command_of{$ident}} = ( $arg_ref->{COMMAND} );
    }
    ##! 1: "end"
}

sub set_environment { # This is empty, children can do (shell) environment
                      # specific things here, such as setting OPENSSL_CONF
                      # in the OpenSSL case.
                      # Executed right before the commands are executed.
}

sub error_ispresent { # This is empty, children can do specific error checking
                    # here. It gets passed the whole STDERR output of the command
                    # and should return true if an error is found in the output
}

sub execute {
    ##! 1: "start"
    my $self   = shift;
    my $ident = ident $self;
    my $arg_ref   = shift;

    my $return = '';
    my $params;

    if (defined $arg_ref) {
        $params = $arg_ref->{PARAMS};
        OpenXPKI::Exception->throw(
            message => 'Calling Crypto CLI with params is no longer supported',
            params  => $params
        );
    }

    $self->set_environment();

    ##! 2: "execute commands"
    for (my $i=0; $i < scalar @{$command_of{$ident}}; $i++) {
        my $cmd = $command_of{$ident}->[$i];
        ##! 4: "command: " . Dumper $cmd
        my @cmd;
        if (ref $cmd eq 'ARRAY') {
            @cmd = @{ $cmd };
        }
        else {
            @cmd = split q{ }, $cmd;
        }
        ##! 16: 'split cmd (was backticks): ' . Dumper \@cmd

        open my $STDOUT, '>', $stdout_file_of{$ident}->filename;
        open my $STDERR, '>', $stderr_file_of{$ident}->filename;
        my ($shell, @wrapper_cmd) =
            __deal_with_wrapper($shell_of{$ident}, @cmd);

        my $command = Proc::SafeExec->new({
            exec   => [ $shell, @wrapper_cmd ],
            stdin  => 'new',
            stdout => $STDOUT,
            stderr => $STDERR,
        });
        eval {
            $command->wait();
        };

        if ($EVAL_ERROR && $EVAL_ERROR ne "Child was already waited on without calling the wait method\n") {
            # the above may fail if the child has already exited,
            # we ignore that
            my $stderr = $self->get_stderr();

            $self->log()->error('OpenSSL error: ' . $stderr);

            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_CLI_EXECUTE_WAIT_FAILED',
                params  => {
                EVAL_ERROR => $EVAL_ERROR,
                },
            );
        }
        ##! 16: 'stdout_file: ' . $stdout_file_of{$ident}
        ##! 16: 'stderr_file: ' . $stderr_file_of{$ident}
        close($STDOUT);
        close($STDERR);
        if ($command->exit_status()) {
            my $stderr = $self->get_stderr();

            $self->log()->error('OpenSSL error: ' . $stderr);

            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_CLI_EXECUTE_FAILED',
                params  => {
                'EXIT_STATUS' => $command->exit_status(),
                },
            );
        }
    }

    ##! 1: "end"
    return $return;
}

sub __deal_with_wrapper {
    # deals with a possible wrapper being included in the shell parameter
    # reduces the shell to the first argument, pushes the options of
    # the wrapper to the @options array and returns the pair
    ##! 1: 'start'
    my $shell = shift;
    my @cmd   = @_;

    ##! 64: 'shell: ' . $shell
    ##! 64: 'cmd: ' . Dumper \@cmd

    my @wrapper = split q{ }, $shell;
    my $new_shell = shift @wrapper;
    push @wrapper, @cmd;

    ##! 64: 'new_shell: ' . $new_shell
    ##! 64: 'wrapper: ' . Dumper \@wrapper;

    return ($new_shell, @wrapper);
}

sub get_result {
    my $self = shift;
    my $ident = ident $self;
    ##! 1: "start"

    my $ret = 1;
    if ($stdout_file_of{$ident}) {
        ## there was an output
        $ret = $fu_of{$ident}->read_file($stdout_file_of{$ident});
        $ret = $engine_of{$ident}->filter_stdout($ret);
        if ($ret eq '') {
            $ret = 1;
        }

    }

    ## WARNING: DO NOT OUTPUT ANYTHING HERE
    ## WARNING: THE OUTPUT MUST BE CHECKED BY THE CALLER FOR ITS SECURITY LEVEL

    ##! 1: "end"
    return $ret;
}

sub get_stderr {
    my $self = shift;
    my $ident = ident $self;
    ##! 1: "start"

    my $ret = 1;
    if ($stderr_file_of{$ident}) {
        ## there was an output
        $ret = $fu_of{$ident}->read_file($stderr_file_of{$ident});
        $ret = $engine_of{$ident}->filter_stderr($ret);
        if ($ret eq '') {
            $ret = 1;
        }
    }

    ##! 1: "end"
    return $ret;
}

sub cleanup {
    ##! 1: "start"
    # no more cleanup here as tmpfiles are removed now by File::Temp
    # we keep this as O::C::Toolkit calls cleanup on error and other
    # APIs might still need this
    return 1;
}

sub log {
    my $self = shift;
    my $ident = ident $self;
    return $logger_of{$ident};
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::CLI

=head1 Desription

This module is an ABSTRACT superclass that implements basic handling
of calling command line binarys. Note that it can not be instantiated.

=head1 Functions

=head2 START

The new function creates a new instance of this class. There are
the following parameters:

=over

=item * SHELL (the location of the binary to use)

=item * ENGINE (a reference to an Engine object)

=item * TMP (the temporary directory)

=back

=head2 prepare

This prepares a command array to be executed. The only parameter is
COMMAND which must either contain a string or an array reference.
The parameter is appended to the shell command.

=head2 execute

performs the commands. It throws an exception on error. The behaviour of
this function is a little bit difficult. The simplest way is that you
use the function without any arguments. This means that you have passed
all parameters via the command line parameters and you get the the
result via the function get_result or you used an explicit output
file.

Example: $cli->execute();

The function supports another way too. Sometimes it is
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
$params->[3]->{STDOUT}. The third query simply enforces normal
behaviour via files.

=head2 get_result

returns the result of the commands which were executed with run_cmd.
If there was no output then 1 will be returned.

=head2 set_environment

This function is to be implemented by children classes. It is executed right
before the command is executed, so shell environment variables that are
relevant for the command can be set here (e.g. OPENSSL_CONF in the
OpenSSL case).

=head2 error_ispresent

This function is to be implemented by the children classes. It gets the
STDERR output as a string, which it can parse for errors. Depending on
whether there are errors or not, it has to return true or false.

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

=head1 See also

OpenXPKI::Crypto::Backend::OpenSSL::CLI - The CLI class for OpenSSL
OpenXPKI::Crypto::Tool::SCEP::CLI       - The CLI class for openca-scep
