## OpenXPKI::Crypto::CLI
## Written 2006 by Alexander Klink for the OpenXPKI project
## largely based on the (former) code of OpenXPKI::Crypto::Backend::
## OpenSSL::CLI by Michael Bell for the OpenXPKI project, 2005-2006
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$
package OpenXPKI::Crypto::CLI;
	
use strict;
use warnings;
use English;
use Class::Std;

use OpenXPKI::Debug;
#use OpenXPKI qw (read_file get_safe_tmpfile);
use OpenXPKI::FileUtils;
use OpenXPKI::Exception;
use Data::Dumper;

my %tmp_of    :ATTR( :init_arg<TMP>    ); # the tmp directory
my %shell_of  :ATTR( :init_arg<SHELL>  ); # the shell to be used
my %engine_of :ATTR( :init_arg<ENGINE> ); # the engine used
my %stdin_file_of  :ATTR; # STDIN  file (redirected input to command)
my %stdout_file_of :ATTR; # STDOUT file (redirected output from command)
my %stderr_file_of :ATTR; # STDERR file (redirected output from command)
my %command_of     :ATTR; # the command used

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

    ##! 2: "create output and stderr files in $arg_ref->{TMP}"
    my $fu = OpenXPKI::FileUtils->new();
    $stdin_file_of{$ident} = $fu->get_safe_tmpfile({
        TMP => $arg_ref->{TMP},
    });
    $stdout_file_of{$ident} = $fu->get_safe_tmpfile({
        TMP => $arg_ref->{TMP},
    });
    $stderr_file_of{$ident} = $fu->get_safe_tmpfile({
        TMP => $arg_ref->{TMP},
    });
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
    for (my $i=0; $i < scalar @{$command_of{$ident}}; $i++) {
        $command_of{$ident}->[$i] = $shell_of{$ident} . " "
                                    . $command_of{$ident}->[$i]
                                    . " 1>>" . $stdout_file_of{$ident}
                                    . " 2>>" . $stderr_file_of{$ident};
        ##! 4: "prepared command: " . $command_of{$ident}->[$i]
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
    }

    $self->set_environment();

    ##! 2: "execute commands"
    for (my $i=0; $i < scalar @{$command_of{$ident}}; $i++) {
        my $cmd = $command_of{$ident}->[$i];
        ##! 4: "command: $cmd"
        if (defined $params and
            exists $params->[$i] and
            ref $params->[$i] eq 'HASH' and
            ($params->[$i]->{TYPE} eq 'STDIN' or
             $params->[$i]->{TYPE} eq 'STDOUT')
           ) {
            if ($params->[$i]->{TYPE} eq 'STDIN') {
                ## read data from STDIN
                
                if (open my $FD, "|$cmd") {
                    print $FD $params->[$i]->{DATA};
                    close $FD;
                }
                else {
                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_CRYPTO_CLI_EXECUTE_PIPED_STDIN_FAILED',
                        params  => { 'ERRVAL' => $EVAL_ERROR,
                                   },
                    );
                }
            }
            else {
                ## capture STDOUT
                if (open my $FD, "$cmd|") {
                    $params->[$i]->{STDOUT} = '';
                    while (<$FD>) { # TODO: slurp, see #
                        $params->[$i]->{STDOUT} .= $_;
                    }
                    $return .= $params->[$i]->{STDOUT};
                    close $FD;
                }
                else {
                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_CRYPTO_CLI_EXECUTE_PIPED_STDOUT_FAILED',
                        params  => {
                            'ERRVAL' => $EVAL_ERROR,
                        },
                    );
                }
	    }
        } else {
            ## simply execute the command
            `$cmd`;
        }
        if ($EVAL_ERROR)
        {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_CLI_EXECUTE_FAILED',
                params  => { 'ERRVAL' => $EVAL_ERROR,
                           },
            );
        }
    }

    ##! 2: "try to detect other errors"
    $self->__find_error();

    ##! 1: "end"
    return $return;
}

sub __find_error : PRIVATE {
    my $self = shift;
    my $ident = ident $self;
    ##! 1: "start"

    ##! 2: "does stderr file exist?"
    if (not -e $stderr_file_of{$ident}) {
        return 1;
    }

    ##! 2: "open, read and delete the error log"
    my $fu = OpenXPKI::FileUtils->new();
    my $ret = '';
    $ret = $fu->read_file($stderr_file_of{$ident});
    if (my $exc = OpenXPKI::Exception->caught()) {
        if ($exc->message() =~ m{ I18N_OPENXPKI_READ_FILE_DOES_NOT_EXIST | I18N_OPENXPKI_READ_FILE_NOT_READABLE | I18N_OPENXPKI_READ_FILE_OPEN_FAILED }xms) {
            # read_file did not work ...
            unlink($stdout_file_of{$ident});
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_CLI_CANNOT_OPEN_ERRLOG',
                params  => { 'FILENAME' => $stderr_file_of{$ident},
                           },
            );
        }
    }

    unlink($stderr_file_of{$ident});

    ##! 4: "error log contains: $ret"
    $ret = $engine_of{$ident}->filter_stderr($ret);
    if ($self->error_ispresent($ret)) {
        ##! 8: "error detected - firing exception"
        unlink ($stdout_file_of{$ident});
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CRYPTO_CLI_ERROR',
            params  => { 'ERRVAL' => $ret,
                       },
        );
    }

    ##! 1: "end - no errors"
    return 0;
}

sub get_result {
    my $self = shift;
    my $ident = ident $self;
    ##! 1: "start"

    my $ret = 1;
    if (-e $stdout_file_of{$ident}) {
        ## there was an output
        my $fu = OpenXPKI::FileUtils->new();
        $ret = $fu->read_file($stdout_file_of{$ident});
        $ret = $engine_of{$ident}->filter_stdout($ret);
        if ($ret eq '') {
            $ret = 1;
        }
    }
    unlink ($stdout_file_of{$ident});

    ## WARNING: DO NOT OUTPUT ANYTHING HERE
    ## WARNING: THE OUTPUT MUST BE CHECKED BY THE CALLER FOR ITS SECURITY LEVEL

    ##! 1: "end"
    return $ret;
}

sub cleanup {
    ##! 1: "start"
    my $self = shift;
    my $ident = ident $self;

    if (exists $stdin_file_of{$ident}  and -e $stdin_file_of{$ident}) {
        unlink($stdin_file_of{$ident});
    }
    if (exists $stdout_file_of{$ident} and -e $stdout_file_of{$ident}) {
        unlink ($stdout_file_of{$ident});
    }
    if (exists $stderr_file_of{$ident} and -e $stderr_file_of{$ident}) {
        unlink ($stderr_file_of{$ident});
    }
    ##! 1: "end"
}

sub DEMOLISH {
    ##! 1: "start"
    my $self = shift;
    $self->cleanup();
    ##! 1: "end"
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
