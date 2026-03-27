package OpenXPKI::Client::Service::WebUI::Dispatcher;
use OpenXPKI qw( -class -typeconstraints );

# Core modules
use Module::Load ();
use Encode;

# CPAN modules
use Log::Log4perl::MDC;
use URI::Escape;

# Project modules
use OpenXPKI::Client::Service::WebUI::JWT;
use OpenXPKI::Client::Service::WebUI::Page::Bootstrap;

=head1 ATTRIBUTES

=cut
has webui => (
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::WebUI',
    required => 1,
    weak_ref => 1,
);

=head2 log

A logger object, per default set to C<OpenXPKI::Log4perl-E<gt>get_logger>.

=cut
has log => (
    is => 'rw',
    isa => duck_type( [qw(
           trace    debug    info    warn    error    fatal
        is_trace is_debug is_info is_warn is_error is_fatal
    )] ),
    lazy => 1,
    default => sub { OpenXPKI::Log4perl->get_logger },
);

=head1 METHODS

=head2 action

Dispatches an action request identified by the given action string (e.g.
C<"workflow!handle">).

Parses the string, loads the appropriate page class, and calls the
C<action_*> method on it. If the handler issues an internal redirect, the
corresponding C<init_*> view is rendered instead. Falls back to
C<home!welcome> when no action string is supplied or no handler is found.

Returns the page object that should be serialised as the HTTP response.

=cut

signature_for action => (
    method => 1,
    positional => [
        'Str',
    ],
);
sub action ($self, $action_str) {
    my $page;
    my $error;

    if ($action_str) {
        $self->log->info("Handle action '$action_str'");
        my $method;
        ($page, $method) = $self->_load_page_class(call => $action_str, is_action => 1);

        if ($page) {
            $self->log->debug("Calling method: $method()");
            $page->$method();
            # Follow internal redirect to an init_* method
            if (my $target = $page->internal_redirect_target) {
                my ($view_str, $method_args) = $target->@*;
                $self->log->trace("Internal redirect to: $view_str") if $self->log->is_trace;
                $page = $self->view($view_str, $method_args, $page->status);
            }
        } else {
            $error = 'I18N_OPENXPKI_UI_ACTION_NOT_FOUND';
        }
    }

    # Render a page only if there is no action or object instantiation failed
    $page //= $self->view('home!welcome');
    $page->status->error($error) if $error;

    Log::Log4perl::MDC->put('wfid', undef);

    return $page;
}

=head2 view

Dispatches a page-view request identified by the given view string (e.g.
C<"workflow!index">).

Repeatedly resolves internal redirects (up to 10 hops) until a terminal
page is reached or the class lookup fails (in which case the 404 bootstrap
page is returned). An optional C<$forced_status> object is propagated to
the first rendered page and then cleared; subsequent redirect hops inherit
the status of the previous page.

Returns the page object that should be serialised as the HTTP response.

=cut

signature_for view => (
    method => 1,
    positional => [
        'Str',
        'HashRef' => { default => {} },
        'OpenXPKI::Client::Service::WebUI::Response::Status' => { optional => 1 },
    ],
);
sub view ($self, $view_str, $args, $forced_status = undef) {
    # Special page requests
    $view_str = 'home!welcome' if $view_str eq 'welcome';

    my $page;

    my $redirects = 0;
    while ($view_str) {
        die "Too many internal redirects" if $redirects++ > 10;

        $self->log->info("Handle page '$view_str'");
        my $method;
        ($page, $method) = $self->_load_page_class(call => $view_str);

        if ($page) {
            if ($forced_status) {
                $page->status($forced_status);
                $forced_status = undef;
            }

            # Call handler
            $self->log->debug("Calling method: $method()");
            $page->$method($args);

            # Carry over status to next page upon internal redirection
            $forced_status = $page->status if $page->status;

            # Follow internal redirect to another init_* method
            if (my $target = $page->internal_redirect_target) {
                ($view_str, $args) = $target->@*;
                $self->log->trace("Internal redirect to: $view_str") if $self->log->is_trace;
            } else {
                last;
            }

        } else {
            $page = OpenXPKI::Client::Service::WebUI::Page::Bootstrap->new(webui => $self->webui)->page_not_found;
            last;
        }
    }

    return $page;
}

=head2 _load_page_class

Parses a call string of the form C<Class!method!key1!val1!key2!val2> (or the
special C<encrypted!<jwt>> form), resolves the target Perl package, and
instantiates it.

For actions (C<is_action => 1>) the lookup order is:

  Page::<Class>::Action::<Method>
  Page::<Class>::<action_method>   (method name with prefix)
  Page::<Class>::<Method>
  Page::<Class>::Action
  Page::<Class>

For views the same cascade is used with C<Init> instead of C<Action>.

Any extra C<!key!val> pairs appended to the call string are decoded (UTF-8,
URI-unescaped) and added to the request parameters via
C<< webui->add_params >>. Secure parameters embedded in an encrypted JWT are
added via C<< webui->add_secure_params >> instead.

Returns a two-element list C<($page_object, $method_name)> on success, or an
empty list (C<undef> in scalar context) when no matching class/method can be
found.

=cut

signature_for _load_page_class => (
    method => 1,
    named => [
        call => 'Str',
        is_action  => 'Bool', { default => 0 },
    ],
);
sub _load_page_class ($self, $arg) {
    $self->log->debug("Trying to load class for call: " . $arg->call);

    my ($class, $remainder) = ($arg->call =~ /\A (\w+)\!? (.*) \z/xms);
    my ($method, $param_raw);

    if (not $class) {
        $self->log->error("Failed to parse page load string: " . $arg->call);
        return;
    }

    # the request is encoded in an encrypted jwt structure
    if ($class eq 'encrypted') {
        # as the token has non-word characters the above regex does not contain the full payload
        # we therefore read the payload directly from call stripping the class name
        my $decrypted = OpenXPKI::Client::Service::WebUI::JWT->decrypt($self->webui->session, $remainder)
            or do { $self->log->debug("JWT encrypted parameter received but client session contains no decryption key"); return; };
        if ($decrypted->{page}) {
            $self->log->debug("Encrypted request with page " . $decrypted->{page});
            ($class, $method) = ($decrypted->{page} =~ /\A (\w+)\!? (\w+)? \z/xms);
        } else {
            $class = $decrypted->{class};
            $method = $decrypted->{method};
        }
        my $secure_params = $decrypted->{secure_param} // {};
        $self->log->debug("Encrypted request to $class / $method");
        $self->log->trace("Secure params: " . Dumper $secure_params) if ($self->log->is_trace and keys $secure_params->%*);
        $self->webui->request_params->add_secure_params($secure_params->%*);
    }
    else {
        ($method, $param_raw) = ($remainder =~ /\A (\w+)? \!?(.*) \z/xms);
        if ($param_raw) {
            my $params = {};
            my @parts = split /!/, $param_raw;
            while (my $key = shift @parts) {
                my $val = shift @parts // '';
                $params->{$key} = Encode::decode("UTF-8", uri_unescape($val));
            }
            $self->log->trace("Extra params appended to page call: " . Dumper $params) if $self->log->is_trace;
            $self->webui->request_params->add_params($params->%*);
        }
    }

    $method  = 'index' unless $method;
    my $fullmethod = $arg->is_action ? "action_$method" : "init_$method";

    my @variants;
    # action!...
    if ($arg->is_action) {
        @variants = (
            sprintf("OpenXPKI::Client::Service::WebUI::Page::%s::Action::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::Service::WebUI::Page::%s::%s", ucfirst($class), $fullmethod),
            sprintf("OpenXPKI::Client::Service::WebUI::Page::%s::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::Service::WebUI::Page::%s::Action", ucfirst($class)),
            sprintf("OpenXPKI::Client::Service::WebUI::Page::%s", ucfirst($class)),
        );
    }
    # init!...
    else {
        @variants = (
            sprintf("OpenXPKI::Client::Service::WebUI::Page::%s::Init::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::Service::WebUI::Page::%s::%s", ucfirst($class), $fullmethod),
            sprintf("OpenXPKI::Client::Service::WebUI::Page::%s::%s", ucfirst($class), ucfirst($method)),
            sprintf("OpenXPKI::Client::Service::WebUI::Page::%s::Init", ucfirst($class)),
            sprintf("OpenXPKI::Client::Service::WebUI::Page::%s", ucfirst($class)),
        );
    }

    for my $pkg (@variants) {
        try {
            Module::Load::load($pkg);
            $self->log->debug("$pkg loaded, testing method availability");
        }
        catch ($err) {
            next if $err =~ /^Can't locate/;
            die $err;
        }

        die "Package $pkg must inherit from OpenXPKI::Client::Service::WebUI::Page"
            unless $pkg->isa('OpenXPKI::Client::Service::WebUI::Page');

        # check class if method exists (faster than checking the instantiated object)
        if ($pkg->can($fullmethod)) {
            my $obj = $pkg->new(webui => $self->webui);
            return ($obj, $fullmethod);
        }
    }

    $self->log->error(sprintf(
        'Could not find any handler class OpenXPKI::Client::Service::WebUI::Page::%s::* containing %s()',
        ucfirst($class),
        $fullmethod
    ));
    return;
}

__PACKAGE__->meta->make_immutable;
