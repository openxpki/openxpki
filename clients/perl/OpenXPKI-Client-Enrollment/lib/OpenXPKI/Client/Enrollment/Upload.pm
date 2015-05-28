package OpenXPKI::Client::Enrollment::Upload;
use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;
use FindBin;
use IO::File;
use POSIX qw(tmpnam);
use Proc::SafeExec;

has 'sscep_conf' => ( lazy => 1, default => 'etc/sscep.conf' );

# Max size for upload
my $upload_max_size = 3 * 1024;

# this is for entire module so it is visible in END{}
my ( $csr_filename, $crt_filename );

# This action will render a template
sub upload {
    my $self   = shift;
    my $group  = $self->param('group');
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

    my $scep_params = {};

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

    # Uploaded image(Mojo::Upload object)
    my $data = $self->req->upload('csr');

    # Nothing uploaded
    unless ($data) {
        return $self->render(
            template => 'error',
            message  => 'Upload failed. No data was specified',
            details  => ''
        );
    }

    # Exceed max size
    if ( $data->size > $upload_max_size ) {
        return $self->render(
            template => 'error',
            message  => 'Upload failed. Data is too large.',
            details  => '',
        );
    }

    # Check file type
    my $data_type = $data->headers->content_type;

    my %valid_types = map { $_ => 1 } qw( application/octet-stream );

    # Create the temporary CSR file
    # try new temp filenames until we get one that didn't already exist
    my $csr_fh;
    do { $csr_filename = tmpnam() }
        until $csr_fh
        = IO::File->new( $csr_filename, O_RDWR | O_CREAT | O_EXCL );

    # Create the temporary Cert file (just in case the issuance for this CSR
    # # is already complete.
    # Try new temp filenames until we get one that didn't already exist
    my $crt_fh;
    do { $crt_filename = tmpnam() }
        until $crt_fh
        = IO::File->new( $crt_filename, O_RDWR | O_CREAT | O_EXCL );

    # install atexit-style handler so that when we exit or die,
    # we automatically delete these temporary files
    END {
        if ($csr_filename) {
            unlink($csr_filename) or die "Couldn't unlink $csr_filename: $!";
        }
        if ($crt_filename) {
            unlink($crt_filename) or die "Couldn't unlink $crt_filename: $!";
        }
    }

    $csr_fh->autoflush(1);
    print $csr_fh $data->slurp;
    seek( $csr_fh, 0, 0 );

    my $output;

    my @exec_args = (
        $sscep_cmd,
        '-c' => $sscep_cfg,
        '-w' => $crt_filename,
    );

    my $metadata = $config->{groups}->{$group}->{'metadata'};
    if ( ref($metadata) eq 'HASH' ) {
        my @meta = ();
        foreach my $key ( keys %{$metadata} ) {
            my $val = $metadata->{$key};
            if ( ref($val) eq 'HASH' ) {
                my @val_array = %{$val};

                if ( $val_array[0] eq 'env' ) {
                    push @meta,
                        $key . '='
                        . (
                        defined $ENV{ $val_array[1] }
                        ? $ENV{ $val_array[1] }
                        : ''
                        );
                }
            }
            elsif ( not ref($val) ) {
                push @meta, join( '=', $key, $val );
            }
            else {
                push @meta, join( '=', 'ERR_IGN_' . $key, ref($val) );
            }
        }
        push @exec_args, '-M', join( '&', @meta );
    }

    push @exec_args, 'enroll' => $csr_filename;
    warn "### DEBUG exec_args=", join( ', ', @exec_args );

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

    close $csr_fh;

    if ( $exit_status == 0 ) {
        seek( $crt_fh, 0, 0 );
        my $crt = join( '', <$crt_fh> );
        close $crt_fh;
        $self->render(

            #            template => 'upload',
            message => "Certificate has beeen issued.",
            certpem => $crt,
            details => 'The certificate for your request has been issued.',
        );
    }
    elsif ( $exit_status == 3 ) {
        $self->render(

            #            template => 'upload',
            message => "Accepted CSR for further processing. ",
            certpem => undef,
            details => <<EOF,
Your CSR has been accepted and submitted for approval and you will
be receiving an e-mail confirmation shortly. 
EOF
        );
    }
    elsif ( $exit_status == 93 ) {
        $self->render(
            template => 'error',
            message  => "Error processing CSR: ($exit_status) ",
            details  => <<EOF,
There was an error processing your request file.  Please check
its contents and file format.  Tip: The CSR file should begin
with the line '-----BEGIN CERTIFICATE REQUEST-----'.  If it
contains the string 'PRIVATE KEY', you uploaded the WRONG file.
EOF
        );
    }
    else {
        $self->render(
            template => 'error',
            message  => "Error processing CSR: ($exit_status) ",
            details  => join( '',
                "\nCOMMAND:\n", "\t",
                join(', ', @exec_args),
                "\n\nSTDERR:\n", @stderr,
                "\n\nSTDOUT:\n", @stdout),
        );
    }
}

1;
