package OpenXPKI::Server::Session::Driver::File;
use Moose;
use utf8;
with "OpenXPKI::Server::Session::DriverRole";

=head1 NAME

OpenXPKI::Server::Session::Driver::File - Session implementation that
persists to files in a folder

=head1 DESCRIPTION

Please see L<OpenXPKI::Server::Session::DriverRole> for a description of the
available methods.

=cut

# Core modules
use English;
use Fcntl qw( :DEFAULT );
use File::Find;

# Project modules
use OpenXPKI::Server::Init;
use OpenXPKI::Exception;
use OpenXPKI::Debug;

################################################################################
# Attributes
#

has directory => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

################################################################################
# Methods required by OpenXPKI::Server::Session::DriverRole
#
sub _make_filepath {
    my ($self, $id) = @_;
    my $hex_str = join "", map { sprintf("%2.2x",ord($_)) } split //, $id;
    return sprintf("%s/openxpki_session_%s", $self->directory, $hex_str);
}

sub BUILD {
    my ($self) = @_;
    OpenXPKI::Exception->throw (
        message => "Specified directory for session data does not exist",
        params => { dir => $self->directory },
    ) unless -d $self->directory;

    OpenXPKI::Exception->throw (
        message => "Specified directory for session data is not writable for current user",
        params => { dir => $self->directory, user => getpwent() },
    ) unless -w $self->directory;
}

# DBI compliant driver name
sub save {
    my ($self, $data) = @_;
    ##! 8: "saving session #".$data->id

    my $id = $data->id or OpenXPKI::Exception->throw(message => "Cannot persist session: value 'id' is not set");
    my $filepath = $self->_make_filepath($id);

    my $mode = O_WRONLY | O_TRUNC;
    $mode |= O_EXCL | O_CREAT unless -e $filepath;

    my $fh;
    sysopen($fh, $filepath, $mode)
        or OpenXPKI::Exception->throw (
            message => 'Could not open file to write session data',
            params  => { file => $filepath, filemode => $mode, user => getpwent() },
        );

    print $fh $data->freeze;
    close $fh;

    utime(time, $data->modified, $filepath)
        or OpenXPKI::Exception->throw (
            message => 'Could not set modification time of session data file',
            params  => { file => $filepath, user => getpwent() },
        );
}

sub load {
    my ($self, $id) = @_;

    my $filepath = $self->_make_filepath($id);
    ##! 8: "loading session from ".$filepath

    (-e $filepath) or return;
    (-r $filepath)
        or OpenXPKI::Exception->throw (
            message => "File with session data is not readable by current user",
            params => { file => $filepath, user => getpwent() },
        );

    open my $fh, '<', $filepath
        or OpenXPKI::Exception->throw (
            message => 'Could not open file with session data',
            params  => { file => $filepath }
        );
    # slurp mode
    local $INPUT_RECORD_SEPARATOR;     # long version of $/
    my $frozen = <$fh>;

    return $self->data_factory->()->thaw($frozen);
}

sub delete {
    my ($self, $data) = @_;
    ##! 8: "deleting session #".$data->id

    my $id = $data->id or OpenXPKI::Exception->throw(message => "Cannot delete session: value 'id' is not set");
    my $filepath = $self->_make_filepath($id);
    return unless -f $filepath;
    unlink $filepath
        or OpenXPKI::Exception->throw (
            message => 'Failed to delete session data file',
            params  => { file => $filepath, error => $! }
        );
}

sub delete_all_before {
    my ($self, $epoch) = @_;
    ##! 8: "deleting all sessions where modified < $epoch"
    find(
        sub {
            return unless -f;
            return unless / openxpki_session_ \d+ $ /msxi;
            my $filepath = $_;
            my $modified = (stat($filepath))[9];
            if ($modified < $epoch) {
                unlink $filepath
                    or OpenXPKI::Exception->throw (
                        message => 'Could not delete old session data file',
                        params  => { file => $filepath, error => $! }
                    );
            }
        },
        $self->directory
    );
}

__PACKAGE__->meta->make_immutable;
