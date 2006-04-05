## OpenXPKI::Crypto::Backend::OpenSSL::Shell
## Written 2005 by Michael for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision
	
use strict;
use warnings;

package OpenXPKI::Crypto::Backend::OpenSSL::Shell;

use OpenXPKI::Debug 'OpenXPKI::Crypto::Backend::OpenSSL::Shell';
use OpenXPKI qw (read_file);
use OpenXPKI::Exception;
# use Smart::Comments;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = { @_ };
    bless $self, $class;

    ## TMP, ENGINE and SHELL are required

    $self->{STDOUT} = $self->{TMP}."/${$}_stdout.log";
    $self->{STDERR} = $self->{TMP}."/${$}_stderr.log";

    return $self;
}

sub start
{
    my $self = shift;
    ##! 1: "start"
    my $keys = { @_ };

    return 1 if ($self->{OPENSSL_FD});

    my $open = "| ".$self->{SHELL}.
               " 1>".$self->{STDOUT}.
               " 2>".$self->{STDERR};
    ##! 2: $open
    if (not open $self->{OPENSSL_FD}, $open)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_START_OPEN_FAILED",
            params  => {"ERRVAL" => $!});
    }
    ## this is required to avoid:
    ##     1. warnings about printing wide characters
    ##     2. automatic iso8859-1 conversion if this is possible
    binmode  $self->{OPENSSL_FD}, ":utf8";
    ##! 2: "shell started"
    return 1;
}

sub init_engine
{
    my $self        = shift;
    $self->{ENGINE} = shift;

    ##! 1: "start"
    return 1 if (not $self->{ENGINE}->is_dynamic() and
                 not $self->{ENGINE}->get_engine_params());

    ##! 2: "initializing engine"
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

    ##! 2: "engine intialized"

    return 1;
}

sub stop
{
    my $self = shift;
    ##! 1: "start"

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
    ##! 1: "start"
    my $params = shift;

    my $cmds = $params->{COMMANDS};
    my $cmdref = $params->{CMDREF};

    if (! defined $cmds) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_RUN_CMD_CMDS_NOT_SPECIFIED",
	    );
    }

    if (! defined $cmdref) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_RUN_CMD_CMDREF_NOT_SPECIFIED",
	    );
    }


    foreach my $command (@{$cmds})
    {
	# scalar
	if (! ref $command) {
	    $command =~ s/\n*$//;
	    $command .= "\n";
	    ##! 8: "command: $command"
	    ### command: $command
	    if (not print {$self->{OPENSSL_FD}} $command)
	    {
		OpenXPKI::Exception->throw (
		    messages => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_RUN_CMD_FAILED",
		    params   => {"COMMAND" => $command,
				 "ERRVAL"  => $!});
	    }
	} else {
	    if (exists $command->{perl}) {
		eval $command->{perl};
	    }
	    if (exists $command->{method}) {
		my $method = $command->{method};
		$cmdref->$method($command->{arguments});
	    }
	}
    }
    ##! 2: "all executed"
    
    return 1;
}

sub __check_error
{
    my $self = shift;

    ## check for errors

    ##! 2: "check for errors"

    if (-e $self->{STDERR})
    {
        ##! 4: "detected error log"
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
        ##! 4: "stderr (".$self->{STDERR}.": $ret)"
        $ret = $self->{ENGINE}->filter_stderr($ret);
        if ($ret =~ /error/i)
        {
            unlink ($self->{STDOUT});
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_SHELL_COMMAND_ERROR",
                params  => {"ERRVAL" => $ret});
        }
    }
    ##! 2: "end - no errors"

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

=over

=item * CMDREF (Object reference to the original OpenSSL command instance)

=item * COMMANDS (Arrayref containing the commands to execute)

The ARRAY reference contains a sequence of OpenSSL commands. 

If the array entry is a normal scalar, the command is executed in the
OpenSSL shell.

If it is a hash reference, the presence of the key 'perl' indicates that
the value should be eval'ed literally.

If the key 'method' exists, the named method is called on the command
reference CMDREF with the arguments contained in the hash entry 'arguments'

Example from caller's perspective:

    my $cmdref = ...
    $self->{SHELL}->run_cmd (
    {
        COMMANDS => [ 'ca -batch ...', 'pkcs12 ...' ],
        CMDREF   => $cmdref,
    });

This runs 'ca -batch...' and 'pkcs12...' commands in the OpenSSL shell.

    my $cmdref = ...
    $self->{SHELL}->run_cmd (
    {
        COMMANDS => [ 
            'ca -batch ...', 
            {
                perl => 'print "Yohoo";',
            },
            'pkcs12 ...' ],
        CMDREF   => $cmdref,
    });

Prints "Yohoo" between the commands (probably not very useful).

    my $cmdref = ...
    $self->{SHELL}->run_cmd (
    {
        COMMANDS => [ 
            'ca -batch ...', 
            {
                method => 'my_method',
                arguments => {
                    foo => 'bar',
                    baz => 1234,
                },
            },
            'pkcs12 ...' ],
        CMDREF   => $cmdref,
    });

Runs $cmdref->my_method({foo => 'bar', baz => 1234}) between OpenSSL commands.


=back

=head2 get_result

returns the result of the commands which were executed with run_cmd.
If there was no output then 1 will be returned.
