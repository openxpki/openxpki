package OpenXPKI::Client::Service::WebUI::Role::PageHandler;
use OpenXPKI -role;
use namespace::autoclean;

requires 'log';
requires 'decrypt_jwt';
requires 'add_params';
requires 'add_secure_params';

# Core modules
use Module::Load ();
use Encode;

# CPAN modules
use Log::Log4perl::MDC;
use URI::Escape;

# Project modules
use OpenXPKI::Client::Service::WebUI::Page::Bootstrap;

signature_for handle_action => (
    method => 1,
    positional => [
        'Str',
    ],
);
sub handle_action ($self, $action_str) {
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
                $page = $self->handle_view($view_str, $method_args, $page->status);
            }
        } else {
            $error = 'I18N_OPENXPKI_UI_ACTION_NOT_FOUND';
        }
    }

    # Render a page only if there is no action or object instantiation failed
    $page //= $self->handle_view('home!welcome');
    $page->status->error($error) if $error;

    Log::Log4perl::MDC->put('wfid', undef);

    return $page;
}

signature_for handle_view => (
    method => 1,
    positional => [
        'Str',
        'HashRef' => { default => {} },
        'OpenXPKI::Client::Service::WebUI::Response::Status' => { optional => 1 },
    ],
);
sub handle_view ($self, $view_str, $args, $forced_status = undef) {
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
                $view_str = undef;
            }

        } else {
            $page = OpenXPKI::Client::Service::WebUI::Page::Bootstrap->new(client => $self)->page_not_found;
        }
    }

    return $page;
}

=head2 _load_page_class

Extracts the expected class and method name and extra params encoded in
the given parameter and tries to instantiate the class.

On success, the class instance and the extracted method name is returned (two
element list).

On error C<undef> is returned.

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
        my $decrypted = $self->decrypt_jwt($remainder) or return;
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
        $self->add_secure_params($secure_params->%*);
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
            $self->add_params($params->%*);
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
            my $obj = $pkg->new(client => $self);
            return ($obj, $fullmethod);
        }
    }

    $self->log->error(sprintf(
        'Could not find any handler class OpenXPKI::Client::Service::WebUI::%s::* containing %s()',
        ucfirst($class),
        $fullmethod
    ));
    return;
}

1;
