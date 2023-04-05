package OpenXPKI::Client::UI::Source;
use Moose;

extends 'OpenXPKI::Client::UI::Result';

=head1 NAME

OpenXPKI::Client::UI::Source - load content from disk and output it.

=head1 DESCRIPTION

The path to the content files is
created from the predefined source path plus the realm name. If you want
to reuse content for multiple realms, create a folder _global which is
always checked if there is no dedicated folder for the current realm.
The basename of the file must be passed as parameter I<file> in the query,
the extension is added by the class. Note that file names are sanitzed and
must not contain characters other then I<a-zA-Z0-9_->

=cut

use JSON;
use Data::Dumper;

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
sub init_html {

    my $self = shift;
    my $args = shift;

    my $file = $self->_build_path('html');

    # slurp the file
    open (FH, "<:encoding(UTF-8)", "$file");
    my @content = <FH>;
    close (FH);

    $self->log->debug('Got content ' . join("",@content));

    $self->main->add_section({
        type => 'text',
        content => {
            label => '',
            description => join ("", @content),
        }
    });

    return $self;

}

=head2 init_json

Load a file from disk that contains JSON. The content is send "as is" to the
client, its up to you to make sure that the ui can handle it! The source
file must end on .json.

=cut
sub init_json {

    my $self = shift;
    my $args = shift;

     my $file = $self->_build_path('json');

    # slurp the file
    open (FH, "<:encoding(UTF-8)", "$file");
    my @content = <FH>;
    close (FH);

    $self->log->debug('Got content ' . join("",@content));

    my $json = decode_json(join("",@content));

    $self->confined_response($json);
    return $self;

}

sub _init_path {

    my $self = shift;
    my $dir = $self->_client->static_dir;

    if ($dir) {
        if (! -d $dir) {
            $self->log->error('Configured path for static content does not exist: ' . $dir);
            die "Configuration broken - Path does not exist";
        } else {
            return $dir;
        }
    } else {
        return '/var/www/';
    }

}


sub _build_path {

    my $self = shift;
    my $ext = shift;

    my $file = $self->param('file');
    $file =~ s/[^a-zA-Z0-9_-]//g;

    if (!$file) {
        $self->log->error('No file source given');
        $self->_notfound();
        return $self;
    }

    my $realm_path = $self->_session->param('pki_realm') || 'default';

    my $path = $self->_basepath();
    # Check if there is a directory for this realm
    if (-d $path.$realm_path) {
        $path .= $realm_path;
    } elsif (-d $path.'_global') {
        $path .= '_global'
    } else {
        $self->log->error('No realm and also no global directory found');
        $self->_notfound();
        return $self;
    }

    $path .= "/$file.$ext";
    $self->log->debug('Try to source file from ' . $path);

    if (! -f $path) {
        $self->log->error('File to source not found: ' . $path);
        $self->_notfound();
        return $self;
    }

    return $path;

}

sub _notfound {

    my $self = shift;

    $self->status->error('No results');
    $self->main->add_section({
        type => 'text',
        content => {
            label => 'Not found!',
            description => 'The requested content was not found!'
        }
    });

    return $self;
}

__PACKAGE__->meta->make_immutable;

__END__;
