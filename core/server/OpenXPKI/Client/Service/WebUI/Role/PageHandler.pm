package OpenXPKI::Client::Service::WebUI::Role::PageHandler;
use OpenXPKI -role;
use namespace::autoclean;

requires 'ui_response';
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


signature_for handle_page => (
    method => 1,
    positional => [
        'Str',
        'Str', { optional => 1 },
    ],
);
sub handle_page ($self, $page, $action) {
    # Action is only valid within a post request
    my $result;
    my @page_method_args;
    my $redirected_from;

    if ($action) {
        $self->log->info("Handle action '$action'");
        my $method;
        ($result, $method) = $self->_load_class(call => $action, is_action => 1);

        if ($result) {
            $self->log->debug("Calling method: $method()");
            $result->$method();
            # Follow an internal redirect to an init_* method
            if (my $target = $result->internal_redirect_target) {
                ($page, @page_method_args) = $target->@*;
                $redirected_from = $result;
                $self->log->trace("Internal redirect to: $page") if $self->log->is_trace;
            }
        } else {
            $self->ui_response->status->error('I18N_OPENXPKI_UI_ACTION_NOT_FOUND');
        }
    }

    die "'page' is not set" unless $page;

    # Render a page only if there is no action or object instantiation failed
    if (not $result or $redirected_from) {
        # Special page requests
        $page = 'home!welcome' if $page eq 'welcome';

        $self->log->info("Handle page '$page'");
        my $method;
        ($result, $method) = $self->_load_class(call => $page);

        if ($result) {
            $self->log->debug("Calling method: $method()");
            $result->status($redirected_from->status) if $redirected_from;
            $result->$method(@page_method_args);

        } else {
            $result = OpenXPKI::Client::Service::WebUI::Page::Bootstrap->new(client => $self)->page_not_found;
        }
    }

    Log::Log4perl::MDC->put('wfid', undef);

    return $result;
}

=head2 _load_class

Expect the page/action string and a reference to the cgi object
Extracts the expected class and method name and extra params encoded in
the given parameter and tries to instantiate the class. On success, the
class instance and the extracted method name is returned (two element
array). On error, both elements in the array are set to undef.

=cut

signature_for _load_class => (
    method => 1,
    named => [
        call => 'Str',
        is_action  => 'Bool', { default => 0 },
    ],
);
sub _load_class ($self, $arg) {
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

        my $obj = $pkg->new(client => $self);

        return ($obj, $fullmethod) if $obj->can($fullmethod);
    }

    $self->log->error(sprintf(
        'Could not find any handler class OpenXPKI::Client::Service::WebUI::%s::* containing %s()',
        ucfirst($class),
        $fullmethod
    ));
    return;
}

1;
