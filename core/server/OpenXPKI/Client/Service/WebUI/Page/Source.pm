package OpenXPKI::Client::Service::WebUI::Page::Source;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Result';

=head1 NAME

OpenXPKI::Client::Service::WebUI::Page::Source - load content from disk and output it

=head1 DESCRIPTION

The path to the content files is created from the predefined source path plus
the realm name. If you want to reuse content for multiple realms, create a
folder I<_global> which is always checked if there is no dedicated folder for
the current realm.

The basename of the file must be passed as parameter I<file> in the query,
the extension is added by the class. Note that file names are sanitzed and
must not contain characters other then I<a-zA-Z0-9_->

=cut

use JSON;

has _basepath => (
    is => 'rw',
    isa => 'Str',
    builder => '_init_path',
    lazy => 1,
);

=head2 init_html

Load a file from disk that contains HTML. The content of the file is rendered
as is into a single text section, the page level is left empty. The source
file must end on .html.

=cut
sub init_html ($self, $args) {
    my $file = $self->_build_path('html') or return;

    # slurp the file
    open my $fh, '<:encoding(UTF-8)', $file;
    my @content = <$fh>;
    close $fh;

    $self->log->trace('Sending HTML content: ' . join('', @content)) if $self->log->is_trace;

    $self->main->add_section({
        type => 'text',
        content => {
            label => '',
            description => join ('', @content),
        }
    });

    return $self;
}

=head2 init_json

Load a file from disk that contains JSON. The content is send "as is" to the
client, its up to you to make sure that the ui can handle it! The source
file must end on .json.

=cut
sub init_json ($self, $args) {
    my $file = $self->_build_path('json') or return;

    # slurp the file
    open my $fh, '<:encoding(UTF-8)', $file;
    my @content = <$fh>;
    close $fh;

    $self->log->trace('Sending JSON content: ' . join("", @content)) if $self->log->is_trace;

    my $json = decode_json(join('', @content));

    $self->confined_response($json);
}

sub _init_path ($self) {
    my $dir = $self->webui->static_dir;

    if (not -d $dir) {
        $self->log->error('Configured path for static content does not exist: ' . $dir);
        die "Configuration broken - Path does not exist";
    }

    return $dir;
}

sub _build_path ($self, $ext) {
    my $file = $self->param('file');
    $file =~ s/[^a-zA-Z0-9_-]//g;

    if (not $file) {
        return $self->_notfound('No file source given');
    }

    my $realm_path = $self->session_param('pki_realm') || 'default';

    my $path = $self->_basepath;
    # Check if there is a directory for this realm
    if (-d $path.$realm_path) {
        $path .= $realm_path;
    } elsif (-d $path.'_global') {
        $path .= '_global'
    } else {
        return $self->_notfound('No realm and also no global directory found');
    }

    $path .= "/$file.$ext";
    $self->log->debug('Try to source file from ' . $path);

    if (not -f $path) {
        return $self->_notfound('File to source not found: ' . $path);
    }

    return $path;
}

sub _notfound ($self, $logmsg) {
    $self->log->error($logmsg);
    $self->status->error('No results');
    $self->main->add_section({
        type => 'text',
        content => {
            label => 'Not found!',
            description => 'The requested content was not found!'
        }
    });
}

__PACKAGE__->meta->make_immutable;
