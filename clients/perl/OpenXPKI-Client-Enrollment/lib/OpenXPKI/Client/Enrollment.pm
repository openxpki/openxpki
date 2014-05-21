package OpenXPKI::Client::Enrollment;
use Mojo::Base 'Mojolicious';

our $VERSION = 1.00;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc"
    #$self->plugin('PODRenderer');

    $self->helper(
        mywarn => sub {
            my $self = shift;
            warn(@_);
        }
    );

    my $shortname = `hostname -s`;
    chomp $shortname;
    my $cfgfile;
    foreach my $f ( '/etc/enroller-ui/enroller-' . $shortname . '.json',
        '/etc/enroller-ui/enroller.json' )
    {
        if ( -f $f ) {
            $cfgfile = $f;
            last;
        }
    }

    if ( not $cfgfile ) {
        die "Error: no configuration file (e.g. enroller.json) found";
    }
    warn "$0: reading config from $cfgfile";
    my $config = $self->plugin( 'JSONConfig', 'file' => $cfgfile );

    if ( my $templates_local = $config->{templates_local} ) {

        unshift @{ $self->renderer->paths }, $templates_local;
    }

    # Router
    my $r = $self->routes;

   # For development purposes, here are a couple of test routes to ensure that
   # error handling is done in an "end-user friendly" manner.
    $r->get('/dev_missing')
        ->to( controller => 'DevMissing', action => 'dev_missing' )
        ->name('dev_missing');
    $r->get('/dev_die')->to( controller => 'DevDie', action => 'dev_die' )
        ->name('dev_die');
    $r->get('/dev_err')->to( controller => 'DevErr', action => 'dev_err' )
        ->name('dev_err');

    # Normal route to controller
    $r->get('/')
        ->to( controller => 'welcome', action => 'welcome', group => '' )
        ->name('index');
    $r->get('/:group')->to(
        controller => 'welcome',
        action     => 'prompt',
        config     => $config
    )->name('index');

    # Upload
    $r->post('/:group/upload')
        ->to( controller => 'upload', action => 'upload', config => $config )
        ->name('upload');

    # Download (Get Cert)
    $r->get('/:group/getcert/:certid')->to(
        controller => 'getcert',
        action     => 'getcert',
        config     => $config
    )->name('getcert');

    # Contact
    $r->get('/:group/contact')->to(
        controller => 'contact',
        action     => 'contact',
        config     => $config
    )->name('contact');

}

1;
