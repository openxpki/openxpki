package OpenXPKI::Server::Workflow::Activity::Transfer::SCP;


use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;
use File::Temp;
use Proc::SafeExec;
use Workflow::Exception qw( configuration_error );

sub execute {

    ##! 1: 'execute'

    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    my $config_path = $self->param('transfer');

    ##! 16: 'using config at ' . $config_path

    if (!$config_path) {
        configuration_error( 'OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TRANSFER_SCP_NO_CONFIG_PATH' );
    }

    my $config = CTX('config')->get_hash( $config_path );

    ##! 32: 'Config is ' . Dumper $config

    if (!$config->{'target'}) {
        configuration_error( 'OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TRANSFER_SCP_NO_TARGET_SPEC' );
    }

    my $source_file = $self->param('source');

    if (!$source_file) {
        configuration_error( 'OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TRANSFER_SCP_NO_SOURCEFILE' );
    }

    if (! -f $source_file ) {
        OpenXPKI::Exception->throw (
            message => 'OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TRANSFER_SCP_SOURCEFILE_NOT_EXISTS',
            params => { SOURCE => $source_file }
        );
    }

    my $target_file = $self->param('target');

    my %filehandles;
    my $stdout = File::Temp->new();
    $filehandles{stdout} = \*$stdout;

    my $stderr = File::Temp->new();
    $filehandles{stderr} = \*$stderr;

    # compose the system command to execute
    my @cmd;

    push @cmd, ($config->{'command'} || '/usr/bin/scp');

    push @cmd, '-P'.$config->{'port'} if ($config->{'port'});
    push @cmd, '-F'.$config->{'sshconfig'} if ($config->{'sshconfig'});
    push @cmd, '-i'.$config->{'identity'} if ($config->{'identity'});

    push @cmd, $source_file;

    # If we have an explicit filename, we append this to the base target
    if ($target_file) {
        my $base = $config->{'target'};
        if ($base != /\/$/) {
            $base .= '/';
        }
        push @cmd, $base.$target_file;
    } else {
        push @cmd, $config->{'target'};
    }

    ##! 16: 'Command ' . join " ",@cmd

    my $command = Proc::SafeExec->new(
    {
        exec => \@cmd,
        %filehandles,
    });

    #TODO - improve handling of temporary errors
    eval{
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm ($config->{'timeout'} || 30);
        $command->wait();

        if ($command->exit_status() != 0) {
            OpenXPKI::Exception->throw (
                message => 'OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TRANSFER_SCP_EXEC_ERROR',
                params => { EXITSTATUS => $command->exit_status() }
            );
        }
    };
    if (my $eval_err = $EVAL_ERROR) {
        # possibly a temporary network error, pause and try again
        ##! 16: 'Eval said ' . $eval_err
        CTX('log')->application()->info('Transfer failed, do pause' );

        $self->pause('I18N_OPENXPKI_UI_PAUSED_TRANSFER_SCP_TIMEOUT');
    }

    alarm 0;

    if ($config->{'unlink'}) {
        unlink $source_file;
    }

    CTX('log')->application()->info('Transfer of file successful' );


    return 1;

}

1;

=head1 NAME

OpenXPKI::Server::Workflow::Activity::Transfer::SCP

=head1 Description

Copy a local file to a remote host using scp with key authentication
(without password). Calls the operating systems scp command using Proc::SafeExec.

=head1 Configuration

The configuration is twofold, you need to give some data in the action config

   class: OpenXPKI::Server::Workflow::Activity::Transfer::SCP
    param:
        retry_count: 5
        retry_interval: +0000000005
        _map_source: $sourcefile
        _map_target: $targetfile
        transfer: export.transfer

Transfer points to a datapoint of the config where the connection information
for scp is set (see below). Source is the name of the source file, target is
optional and appended to the target given in the transfer config.

The configuration of the transport layer is done via the config layer:

    target: upload@localhost:~/incoming/
    command: /my/local/version/of/bin/scp
    port: 22
    identity: /home/pkiadm/id_scp
    sshconfig: /home/pkiadm/ssh_copy_config
    timeout: 30

Target is mandatory and must contain the full target as expected by the scp command.
As default command /usr/bin/scp is used, you might give an alternative here.
All other options are optional and passed to the scp command using the
appropriate command line flags.
