package OpenXPKI::Client::Service::WebUI::Session;
use OpenXPKI qw( -class -nonmoose );

# Fix CGI::Session's error handling: turn "undef" return value into die()
use Mojo::Util qw( monkey_patch );
monkey_patch 'CGI::Session', new_patched => sub ($class, @args) {
    return $class->new(@args) // die 'Error creating webui session: ' . $class->errstr;
};

# The Moose constructor will also get the name "new_patched"!
extends 'CGI::Session' => { -constructor_name => 'new_patched' };

# Core modules
use Module::Load ();
use Carp;

# CPAN modules
use Log::Log4perl qw(:easy);

=head1 NAME

OpenXPKI::Client::Service::WebUI::Session

=head1 DESCRIPTION

A thin wrapper around L<CGI::Session> that disables C<use CGI> in the parent
class and any code where the CGI object is accessed afterwards.

The following methods of the parent class are not implemented (i.e. overwritten
with non-functional code):

=over

=item * C<query()>

=item * C<http_header()>

=item * C<cookie()>

=item * C<save_param()>

=item * C<load_param()>

=back

=head1 METHODS

=cut

# Enforce three-argument calling style to new()
around BUILDARGS => sub ($orig, $class, @args) {
    die __PACKAGE__."->new() expects exactly three arguments: (\$dsn, \$sid, \$dsn_args)\n"
        unless scalar @args == 3;
    die "Second argument to ".__PACKAGE__."->new() must be either a SID or undef\n"
        if (defined $args[1] and ref $args[1]);

    if (my $dsn = $args[0]) {
        my $dsn_args = $class->parse_dsn($dsn);
        if (my $driver = $dsn_args->{driver}) {
            Log::Log4perl->initialized or Log::Log4perl->easy_init($ERROR);
            my $log = Log::Log4perl->get_logger('openxpki.client.service.webui.session');
            $log->debug("Check frontend session driver '$driver' availability");
            try {
                Module::Load::load("CGI::Session::Driver::$driver");
            }
            catch ($err) {
                my $msg = "Could not load frontend session driver '$driver': $err";
                $log->error($msg); # logdie() would result in broadcast message on terminals
                die "$msg\n";
            }
        }
    }

    return $class->$orig(); # call Moose::Object->BUILDARGS
};

# Arguments to be passed to CGI::Session->new()
sub FOREIGNBUILDARGS ($class, @args) {
    # Convert second argument (SID): turn Undef into 0 so CGI::Session->load()
    # will find it's defined (= not attempt to fetch SID via CGI->cookie or CGI->param)
    # but also find it's not TRUE (which would make it try and load a session)
    return ($args[0], $args[1] // 0, $args[2]);
}

=head2 clone

Deletes old session data, flushes the session to the disk, then returns a new
object instance with the same settings but a new SID etc.

=cut
sub clone ($self) {
    Log::Log4perl->get_logger('openxpki.client.service.webui.session')->debug('Clone frontend session');

    $self->delete;  # delete old instance data
    $self->flush;   # write changes

    # now calling CGI::Session->new() as instance method generates a new object
    # with the same settings but a new SID etc.
    return $self->SUPER::new_patched();
}

# query() is used by CGI::Session->load() if the requested session ID is invalid.
# By returning a dummy we make sure the code in load() does not die too early.
sub query { bless { }, __PACKAGE__ . '::DummyQuery' }
sub http_header { confess __PACKAGE__."->http_header() is not implemented\n" }
sub cookie      { confess __PACKAGE__."->cookie() is not implemented\n" }
sub save_param  { confess __PACKAGE__."->save_param() is not implemented\n" }
sub load_param  { confess __PACKAGE__."->load_param() is not implemented\n" }

__PACKAGE__->meta->make_immutable;
