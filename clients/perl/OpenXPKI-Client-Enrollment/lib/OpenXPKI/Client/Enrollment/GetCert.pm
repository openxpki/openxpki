package OpenXPKI::Client::Enrollment::GetCert;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use FindBin;
use IO::File;
use POSIX qw(tmpnam);
use Proc::SafeExec;

has 'sscep_conf' => ( lazy => 1, default => 'etc/sscep.conf' );

my $crt_filename;    # this is for entire module so it is visible in END{}

# This action will render a template
sub getcert {
    my $self   = shift;
    my $group  = $self->param('group');
    my $certid = $self->param('certid');
    my $config = $self->param('config');

    if ( not ref( $config->{groups} ) ) {
        $self->render(
            template => 'error',
            message  => 'System configuration error',
            details  => 'configuration file does not contain "groups" entry',
        );
        return;
    }

    if ( not exists $config->{groups}->{$group} ) {
        $self->render(
            template => 'error',
            message  => 'Unknown Group',
            details =>
                'Please consult your support contact for the correct URL',
        );
        return;
    }

    my $sscep_cmd
        = $ENV{ENROLL_FORWARD_CMD}
        || $config->{groups}->{$group}->{enroll_forward_cmd}
        || $config->{enroll_forward_cmd}
        || "$FindBin::Bin/../script/sscep-wrapper";

    my $sscep_cfg
        = $ENV{ENROLL_FORWARD_CFG}
        || $config->{groups}->{$group}->{enroll_forward_cfg}
        || $config->{enroll_forward_cfg}
        || "$FindBin::Bin/../etc/sscep-wrapper.cfg";

    my $output;

    # Create the temporary file for the cert to be fetched
    # (we really only need the filename)
    # Try new temp filenames until we get one that didn't already exist
    my $crt_fh;
    do { $crt_filename = tmpnam() }
        until $crt_fh = IO::File->new( $crt_filename, O_RDWR | O_CREAT | O_EXCL );

    # install atexit-style handler so that when we exit or die,
    # we automatically delete the temporary file
    END {
        if ($crt_filename) {
            unlink($crt_filename) or warn "Couldn't unlink $crt_filename: $!";
        }
    }

    my @exec_args = (
        $sscep_cmd,
        '-c' => $sscep_cfg,
        '-w' => $crt_filename,
        'getcert',
        $certid,
    );

    my $fwd = new Proc::SafeExec(
        {   exec   => \@exec_args,
            stdout => 'new',
            stderr => 'new'
        }
    );

    # Perl doesn't understand <$fwd->stdout()>
    my $fwd_stdout = $fwd->stdout();
    my $fwd_stderr = $fwd->stderr();
    my @stdout     = <$fwd_stdout>;
    my @stderr     = <$fwd_stderr>;

    $fwd->wait();
    my $exit_status = $fwd->exit_status() >> 8;

    close $fwd_stdout;
    close $fwd_stderr;

    if ( $exit_status == 0 ) {
        seek( $crt_fh, 0, 0 );
        my $crt = join( '', <$crt_fh> );
        close $crt_fh;
        $self->render(
            message => "Certificate has beeen issued.",
            certpem  => $crt,
            details => 'The certificate for your request has been issued.',
        );
    }
#    elsif ( $exit_status == 3 ) {
#        $self->render(
#            message => "Accepted CSR for further processing. ",
#            details => <<EOF,
#Your CSR has been accepted and submitted for approval and you will
#be receiving an e-mail confirmation shortly. 
#EOF
#        );
#    }
    else {
        $self->render(
            template => 'error',
            message  => "Error getting certificate: ($exit_status) ",
            details  => join( '',
                "\nCOMMAND:\n",  "\t",
                join(', ', @exec_args),
                "\nSTDERR:\n",   @stderr,
                "\n\nSTDOUT:\n", @stdout )
        );
    }
}


1;
