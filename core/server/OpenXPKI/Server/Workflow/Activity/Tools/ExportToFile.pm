package OpenXPKI::Server::Workflow::Activity::Tools::ExportToFile;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Template;
use OpenXPKI::Debug;
use Data::Dumper;
use File::Temp;
use MIME::Base64;
use Workflow::Exception qw(configuration_error);

sub execute {

    ##! 1: 'start'

    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();

    my $target_dir = $self->param('target_dir');
    my $target_name = $self->param('target_filename');
    my $umask = $self->param( 'target_umask' ) || "0640";
    my $value = $self->param( 'value' ) || '';
    my $b64 = $self->param( 'base64' ) || '';


    if (!defined $value || $value eq '') {
        CTX('log')->application()->debug("Nothing written - export data is empty");

        return 1;
    }

    if ($b64 eq 'encode') {
        $value = encode_base64($value);
    } elsif ($b64 eq 'decode') {
        $value = decode_base64($value);
    } elsif ($b64) {
        configuration_error('Invalid value given for the base64 parameter');
    }

    my $fh;
    if (!$target_name) {
        $fh = File::Temp->new( UNLINK => 0, DIR => $target_dir );
        $target_name = $fh->filename;
    } elsif ($target_name !~ m{ \A \/ }xms) {
        if (!$target_dir) {
            configuration_error('Full path for target_name or target_dir is required!');
        }
        $target_name = $target_dir.'/'.$target_name;

        if (-e $target_name) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_EXPORT_TO_FILE_FILE_EXISTS',
                params => { FILENAME => $target_name }
            );
        }
        open $fh, ">$target_name";
    }

    if (!$fh || !$target_name) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_EXPORT_TO_FILE_UNABLE_TO_WRITE_FILE',
            params => { FILENAME => $target_name, DIRNAME => $target_dir }
        );
    }

    print $fh $value;
    close $fh;

    chmod oct($umask), $target_name;

    $context->param( { export_filename => $target_name });

    my $bytes = length($value);

    CTX('log')->application()->debug("Wrote export ($bytes bytes) to $target_name");


    return 1;

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ExportToFile

=head1 Description

Write data from the context to a (temporary) file.

=head1 Configuration

=head2 Activity parameters

=over

=item value

The plain data to be written. Nothing is done if data is empty.

=item target_filename

Filename to write the report to, if relative (no slash), target_dir must
be set and will be prepended. If not given, a random filename is set. The
final export file name is always written to export_filename.

=item target_dir

Mandatory if target_filename is relative. If either one is set, the system
temp dir is used.

=item target_umask

The umask to set on the generated file, default is 640. Note that the
owner is the user/group running the socket, if you want to download
this file using the webserver, make sure that either the webserver has
permissions on the daemons group or set the umask to 644.

=item base64

Set to I<encode> if you want the content to encoded before written to the
file. Set to I<decode> if the input value is base64 encoded and you want to
have the binary value in the written file. If not set, the data is written
as is.

=back

=head2 Context parameters

After completion the following context parameters will be set:

=over 12

=item export_filename

absolute path of the written file.

=back



