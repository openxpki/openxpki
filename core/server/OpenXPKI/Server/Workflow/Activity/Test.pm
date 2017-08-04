
package OpenXPKI::Server::Workflow::Activity::Test;

use Proc::SafeExec;
use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::DateTime;
use English;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;

    ##! 1: 'start'


    my $name = CTX('config')->get('system.test');

    ##! 1: "STDOUT: " . $name

    return 1;

    my $shell = '/usr/bin/openssl';
    my @wrapper_cmd = (
      'x509',
      '-out',
      '/var/tmp/convert.'.$$,
      '-in',
      '/var/tmp/temp4aaIe.tmp',
      '-inform',
      'PEM',
      '-outform',
      'DER');

    $shell = '/home/openxpki/procexec/fourtytwo';

        open my $stdout, ">", '/var/tmp/stdout.'.$$;
        open my $stderr, ">", '/var/tmp/stderr.'.$$;

        my $command = Proc::SafeExec->new({
            exec   => [ $shell, @wrapper_cmd ],
            stdin  => 'new',
            stdout => $stdout,
            stderr => $stderr,
        });

        close($stdout);
        close($stderr);

        $command->wait();

        my $stdout_content = do {
            open my $fh, '<', '/var/tmp/stdout.'.$$;
            local $INPUT_RECORD_SEPARATOR;
            <$fh>;
        };

        ##! 1: "STDOUT: " . $stdout_content;
        ##! 1: "CLI Exit: " . $command->exit_status();

        return 1;
}
1;