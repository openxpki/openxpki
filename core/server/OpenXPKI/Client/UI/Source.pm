# OpenXPKI::Client::UI::Source
# class to wrap content from files on disk into the required json structure 

package OpenXPKI::Client::UI::Source;

=head1 OpenXPKI::Client::UI::Source

Load content from disk and output it. The path to the content files is 
created from the predefined source path plus the realm name. The basename
of the file must be passed as parameter I<file> in the query, the extension
is added by the class. Note that file names are sanitzed and must not 
contain characters other then I<a-zA-Z0-9_->

=cut

use Moose;
use JSON;
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

has _basepath => (
    is => 'rw',
    isa => 'Str',
    builder => '_init_path',
    lazy => 1,     
);

sub BUILD {
    my $self = shift;
    $self->_page ({'label' => ''});              
}


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
    open (FH, "$file");
    my @content = <FH>;
    close (FH);

    $self->logger()->debug('Got content ' . join("",@content));

    $self->add_section({
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
    open (FH, "$file");
    my @content = <FH>;
    close (FH);

    $self->logger()->debug('Got content ' . join("",@content));
    
    my $json = JSON->new->utf8->decode(join("",@content));

    $self->_result()->{_raw} = $json;
    return $self;
    
}

sub _init_path {
    
    my $self = shift;
    
    my $config = $self->_client()->_config();
    
    $self->logger()->debug('Got config ' . Dumper $config);
    
    if ($config->{staticdir}) {
        if (! -d $config->{staticdir}) {
            $self->logger()->error('Configured path for static content does not exist: ' . $config->{staticdir});
            die "Configuration broken - Path does not exist";        
        } else {
            return $config->{staticdir};
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
        $self->logger()->error('No file source given');        
        $self->_notfound();
        return $self;        
    }
    
    my $realm_path = $self->_session->param('pki_realm').'/';
    
    my $path = $self->_basepath(). $realm_path . $file. '.' . $ext;

    $self->logger()->debug('Try to source file from ' . $path);

    if (! -f $path) {
        $self->logger()->error('File to source not found: ' . $path);        
        $self->_notfound();
        return $self;        
    }
    
    return $path;    
    
}

sub _notfound {
    
    my $self = shift; 
    
    $self->set_status('No results','error');
    $self->add_section({
        type => 'text',
        content => {
            label => 'Not found!',
            description => 'The requested content was not found!'
        }
    });    
    
    return $self;
}


1;

__END__;    