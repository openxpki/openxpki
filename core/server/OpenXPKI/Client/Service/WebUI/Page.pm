package OpenXPKI::Client::Service::WebUI::Page;
use OpenXPKI qw( -class -typeconstraints );
use namespace::autoclean;

# Core modules
use Digest::SHA qw(sha1_base64);
use MIME::Base64;
use Carp qw( confess );
use Encode;

# CPAN modules
use HTML::Entities;
use JSON;
use Data::UUID;

# Project modules
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Client::Service::WebUI::Response;


=pod

=head1 METHODS

=head2 log

L<Log::Log4perl::Logger> or L<OpenXPKI::Log4perl::MojoLogger>.

=cut

has log => (
    is => 'ro',
    isa => 'Object',
    init_arg => undef,
    lazy => 1,
    default => sub ($self) { return $self->webui->log },
);

=head2 REQUEST PARAMETERS

=head3 param

Returns a single input parameter value, i.e.

=over

=item * secure parameters passed in a (server-side) JWT encoded hash,

=item * those appended to the action name using C<!> and

=item * real GET/POST parameters.

=back

A parameter name will be looked up in the listed order.

If the input parameter is a list (multiple values) then only the first value is
returned.

B<Parameters>

=over

=item * I<Str> C<$key> - parameter name to retrieve.

=back

=head3 secure_param

Returns an input parameter that was encrypted via JWT and can thus be trusted.

Encryption might happen either by calling the special virtual page
C<encrypted!JWT_TOKEN> or with a form field of C<type: encrypted>.

C<undef> is returned if the parameter does not exist or it was not an encrypted
parameter.

B<Parameters>

=over

=item * I<Str> C<$key> - parameter name to retrieve.

=back

=head3 multi_param

Returns a list with an input parameters' values (multi-value field, most
likely a clonable field).

B<Parameters>

=over

=item * I<Str> C<$key> - parameter name to retrieve.

=back

=head2 OTHER

=head3 script_url

URL path of the script (i.e. self reference) from config.

=cut

has webui => (
    required => 1,
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::WebUI',
    handles => [ qw(
        param
        multi_param
        secure_param
        encrypt_jwt
        script_url
    ) ],
);

=pod

=head2 JSON RESPONSE

=head3 ui_response

L<OpenXPKI::Client::Service::WebUI::Response> object encapsulating the JSON response.

Most of the following methods are accessors to attributes of
L<OpenXPKI::Client::Service::WebUI::Response>. They can also be called without arguments to
retrieve the current value (except from those starting with C<set_*>).

Please note that currently some of these attributes are of type I<Scalar>,
I<ArrayRef> or I<HashRef> while others are "data transfer objects" (DTOs) that
use L<OpenXPKI::Client::Service::WebUI::Response::DTO> and encapsulate several values.
The DTOs have a C<resolve> method which recursively builds a I<HashRef> from
the encapsulated data. The I<HashRef> gets converted to JSON
(in L</_render_body_to_str>) and is sent to the web UI.

=head3 redirect

Enforce a client side redirect to the given page:

    $self->redirect->to('workflow!search');
    $self->redirect->external('https://...');

=head3 confined_response

Enforce response to a confined request, i.e. and autocomplete query. Returns
an arbitrary JSON structure to the web UI.

    $self->confined_response([1,2,3]);

=head3 main

Set the structure of the main contents.

    $self->main->add_section(...);
    $self->main->add_form(...);

C<add_form> receives constructor parameters for L<OpenXPKI::Client::Service::WebUI::Response::Section::Form>.

=head3 language

Set the language.

    $self->language('de');

=head3 menu

Set the menu structure.

    $self->menu->items([ ... ]);
    # or
    $self->menu->add_item({
        key => 'logout',
        label => 'I18N_OPENXPKI_UI_CLEAR_LOGIN',
    });

=head3 on_exception

Add an exception handler for HTTP codes.

    $self->on_exception->add_handler(
        status_code => [ 403, 401 ],
        redirect => $target,
    );

=head3 page and set_page

Set page related information.

    $self->page->label('I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE');
    $self->page->shortlabel('I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE');
    $self->page->description('I18N_OPENXPKI_UI_WORKFLOW_BULK_DESCRIPTION');
    $self->page->breadcrumb([...]);
    $self->page->css_class('important');
    $self->page->large(1);

    # set several attributes at once
    $self->set_page(
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_DESCRIPTION',
    );

=head3 ping

Configure keepalive ping to an endpoint.

    $self->ping({ href => '...', timeout => 30 }); # timeout is in milliseconds

=head3 refresh and set_refresh

Configure a periodic page refresh timer.

    $self->refresh->uri("workflow!load!wf_id!$wf_id");
    $self->refresh->timeout(30);

    # set several attributes at once
    $self->set_refresh(
        uri => "workflow!load!wf_id!$wf_id",
        timeout => 30,
    );

=head3 rtoken

Set the request token.

    $self->rtoken($rtoken);

=head3 status

Set status or error message.

    $self->status->info('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_30SEC');
    $self->status->success('...');
    $self->status->warn('...');
    $self->status->error('...');

=head3 tenant

Set the tenant.

    $self->tenant($tenant);

=head3 user and set_user

Set user related information.

    $self->user->name(...);
    $self->user->role(...);
    $self->user->realname(...);
    $self->user->role_label(...);
    $self->user->pki_realm(...);
    $self->user->pki_realm_label(...);
    $self->user->checksum(...);
    $self->user->sid(...);
    $self->user->last_login($timestamp);
    $self->user->tenants([...]);

    # set several attributes at once
    $self->set_user(%{ $user });

=head3 pki_realm

Set the current PKI realm.

    $self->pki_realm($realm);

=cut

has ui_response => (
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::WebUI::Response',
    init_arg => undef,
    lazy => 1,
    default => sub ($self) { return $self->webui->ui_response },
    handles => [ qw(
        redirect
        confined_response has_confined_response
        language
        main
        menu
        on_exception
        page set_page
        ping
        refresh set_refresh
        rtoken
        status
        tenant
        user set_user
        pki_realm
    ) ],
);

=head3 raw_bytes

Raw byte string to be sent back.

Should be set via L</attachment>.

=cut
has raw_bytes => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_raw_bytes',
);

=head3 raw_bytes_callback

Callback that passes chunks of raw bytes to a given subroutine.

Should be set via L</attachment>.

=cut
has raw_bytes_callback => (
    is => 'rw',
    isa => 'CodeRef',
    predicate => 'has_raw_bytes_callback',
);

has last_reply => (
    is => 'rw',
    isa => 'HashRef',
);

has session => (
    is => 'ro',
    isa => 'OpenXPKI::Client::Service::WebUI::Session',
    init_arg => undef,
    lazy => 1,
    default => sub ($self) { $self->webui->session },
);

has serializer => (
    is => 'ro',
    isa => duck_type( [qw( serialize deserialize )] ),
    lazy => 1,
    default => sub { OpenXPKI::Serialization::Simple->new },
);

# PRIVATE

# Redirection (from an action_* method) to an init_* method that may live
# in another class.
# The ArrayRef holds the page call (e.g. "home!welcome") plus additional
# arguments that shall be passed to the method.
has _internal_redirect_target => (
    is => 'rw',
    isa => 'ArrayRef',
    reader => 'internal_redirect_target',
    init_arg => undef,
);

=head2 REDIRECT AND URL HELPERS

=head3 internal_redirect

Internal redirection from an action (C<action_*>) or view (C<init_*>) to another
view (C<init_*>).

    return $self->internal_redirect('home!welcome' => { name => "OpenXPKI" });

=cut

signature_for internal_redirect => (
    method => 1,
    positional => [
        'Str',
        'HashRef' => { default => {} },
    ],
);
sub internal_redirect ($self, $call, $args) {
    $self->_internal_redirect_target([$call, $args]);
    return $self;
}

=head3 attachment

Specify an attachment (file download).

B<NOTE>: This will override any GUI data previously set for a JSON response.

    $self->attachment(
        mimetype => 'application/x-pkcs7-crl',
        filename => 'crl.pem',
        expires => '1m',
        bytes => $data,
    );

    # or with a callback for "streaming" output:

    $self->attachment(
        mimetype => 'application/x-pkcs7-crl',
        filename => 'crl.pem',
        expires => '1m',
        bytes_callback => sub {
            my $consume = shift;
            open (my $fh, '<', $source) || die "Unable to open '$source': $!";
            while (my $line = <$fh>) { $consume->($line) }
            close $fh;
        },
    );

B<Named parameters>

=over

=item * I<Str> C<mimetype> - value for L<Content-Type> header

=item * I<Str> C<filename> - L<Content-Disposition> will be set to C<attachment; filename="$filename">

=item * I<Str> C<bytes> - file data as raw byte string

=item * I<CodeRef> C<bytes_callback> - handler subroutine that will receive an
"output" subroutine and must pass raw bytes to it (e.g. in chunks).

=item * I<Str> C<expires> - optional: value for L<Expires> header

=back

=cut
signature_for attachment => (
    method => 1,
    named => [
        mimetype => 'Str',
        filename => 'Str',
        bytes => 'Str', { optional => 1 },
        bytes_callback => 'CodeRef', { optional => 1 },
        expires => 'Str', { optional => 1 },
    ],
);
sub attachment ($self, $arg) {
    die "attachment(): one of 'bytes' or 'bytes_callback' must be given"
        unless (defined $arg->bytes or $arg->bytes_callback);

    $self->webui->response->add_header(
        'content-type' => $arg->mimetype,
        'content-disposition' => sprintf('attachment; filename="%s"', $arg->filename),
        $arg->expires ? ('expires' => '1m') : (),
    );

    $self->raw_bytes($arg->bytes) if (defined $arg->bytes);
    $self->raw_bytes_callback($arg->bytes_callback) if $arg->bytes_callback;
}

=head3 call_persisted_response

Persist the given response data to retrieve it after an HTTP roundtrip.
Used to break out of the JavaScript app for downloads.

Returns the page call URI that will result in a call to
L<OpenXPKI::Client::Service::WebUI::Page::Cache/init_fetch>.

=cut

sub call_persisted_response ($self, $data, $expire = '+5m') {
    die "Attempt to persist empty response data" unless $data;

    my $id = OpenXPKI::Util->generate_uid;
    $self->log->debug('persist response ' . $id);

    $self->session->param('response_'.$id, $data );
    $self->session->expire('response_'.$id, $expire) if $expire;

    return "cache!fetch!id!$id";
}

=head3 fetch_response

Get the data for the persisted response.

=cut

sub fetch_response ($self, $id) {
    $self->log->debug('fetch response ' . $id);
    my $response = $self->session->param('response_'.$id);
    if (not $response) {
        $self->log->error( "persisted response with id '$id' does not exist" );
        return;
    }
    return $response;
}

=head3 call_encrypted

Encrypt the given page and parameters using a JWT.

Returns the page call URI consisting of the pseudo page named C<encrypted> and
the JWT as single parameter that will be decoded in
L<OpenXPKI::Client::Service::WebUI::Role::PageHandler/_load_page_class>.

B<Named parameters>

=over

=item * I<Str> C<page> - page to call.

=item * I<HashRef> C<secure_param> - additional secure parameters that will be available via L</secure_param>.

=back

=cut

signature_for call_encrypted => (
    method => 1,
    named => [
        page => 'Str',
        secure_param  => 'HashRef | Undef', { default => {} },
    ],
);
sub call_encrypted ($self, $arg) {
    my $token = $self->encrypt_jwt({
        page => $arg->page,
        secure_param => $arg->secure_param // {},
    });

    return "encrypted!${token}";
}

=head3 wf_token_extra_param( wf_info, more_args )

Create a workflow token that represents a C<HashRef> with data from the given
workflow info and additional arguments.

The generated C<HashRef> will be stored in the session.

B<Parameters>

=over

=item * C<$wf_info> I<HashRef> - workflow info as returned by API command
L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info>. Optional

=item * C<$more_args> I<HashRef> - additional parameters to store. Optional

=back

Returns a string C<"wf_token!$token"> which can be added to e.g. a button action.

=cut
sub wf_token_extra_param {

    my $self = shift;
    my $wf_info = shift;
    my $more_args = shift;

    my $id = $self->__wf_token_id($wf_info, $more_args);
    return "wf_token!${id}";
}

=head3 resolve_wf_token( wf_token )

Return the C<HashRef> that was associated with the given token via
L<wf_token_extra_param> or L<wf_token_field>.

=cut
sub resolve_wf_token {
    my $self = shift;

    my $id = $self->param('wf_token');
    if (not $id) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_ACTION_WITHOUT_TOKEN!');
        return;
    }

    $self->log->debug("load wf_token: $id");
    my $wf_args = $self->session_param($id);
    $self->log->trace('token content = ' . Dumper $wf_args) if $self->log->is_trace;

    return $wf_args;
}

=head3 purge_wf_token

Purge the C<HashRef> associated with the current token from the session.

=cut
sub purge_wf_token {
    my $self = shift;

    my $id = $self->param('wf_token');

    $self->log->debug("purge wf_token: $id");
    $self->session->clear($id);

    return $self;
}

=head3 wf_token_field( wf_info, more_args )

Create a workflow token that represents a C<HashRef> with data from the given
workflow info and additional arguments.

The generated C<HashRef> will be stored in the session.

B<Parameters>

=over

=item * C<$wf_info> I<HashRef> - workflow info as returned by API command
L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info>. Optional

=item * C<$more_args> I<HashRef> - additional parameters to store. Optional

=back

Returns a I<HashRef> with the definiton of a hidden field named C<"wf_info">
which can be directly pushed onto the field list.

=cut
sub wf_token_field {

    my $self = shift;
    my $wf_info = shift;
    my $more_args = shift;

    my $id = $self->__wf_token_id($wf_info, $more_args);
    return {
        name => 'wf_token',
        type => 'hidden',
        value => $id,
    };
}

sub __wf_token_id {

    my $self = shift;
    my $wf_info = shift;
    my $wf_args = shift // {};

    if (ref $wf_info) {
        $wf_args->{wf_id} = $wf_info->{workflow}->{id};
        $wf_args->{wf_type} = $wf_info->{workflow}->{type};
        $wf_args->{wf_last_update} = $wf_info->{workflow}->{last_update};
    }
    my $id = OpenXPKI::Util->generate_uid;
    $self->log->debug("save wf_token: $id");
    $self->log->trace('token content = ' . Dumper $wf_args) if $self->log->is_trace;
    $self->session_param($id, $wf_args);

    return $id;
}

=head2 send_command_v2

Sends the given command to the backend and returns the result.

If an error occurs while executing the command (e.g. validation error from a
workflow action), the global status is set in the response sent to the client,
so the UI can show the error. This can be suppressed by setting the third
parameter to C<1>.

B<Parameters>

=over

=item * I<Str> C<$command> - command

=item * I<HashRef> C<$params> - parameters to the command

=item * I<Bool> C<$nostatus> - Set to C<1> to prevent setting the global status in case of errors. Default: 0

=back

=cut
sub send_command_v2 {

    my $self = shift;
    my $command = shift;
    my $params = shift || {};

    my $flags = shift || { nostatus => 0 };
    # legacy - third argument was boolean "nostatus"
    if (!ref $flags && $flags) {
        $flags = { nostatus => 1 };
    }

    my $reply = $self->webui->client->send_receive_service_msg(
        'COMMAND' => {
            COMMAND => $command,
            PARAMS => $params,
            API => 2,
            TIMEOUT => ($flags->{timeout} || 0),
            REQUEST_ID => $self->webui->request->request_id,
        }
    );
    $self->last_reply($reply);

    $self->log->trace("Raw backend reply to '$command': ". Dumper $reply) if $self->log->is_trace;

    if ( $reply->{SERVICE_MSG} ne 'COMMAND' ) {
        $self->log->error("Command '$command' failed ($reply->{SERVICE_MSG})");
        $self->log->trace("Command reply = ". Dumper $reply) if $self->log->is_trace;
        $self->status->error($self->message_from_error_reply($reply)) unless $flags->{nostatus};
        return;
    }

    return $reply->{PARAMS};

}

sub message_from_error_reply {

    my $self = shift;
    my $reply = shift;

    my $message = 'I18N_OPENXPKI_UI_UNKNOWN_ERROR';
    if ($reply->{'ERROR'}) {
        # Workflow errors
        if ($reply->{'ERROR'}->{PARAMS} && $reply->{'ERROR'}->{PARAMS}->{__ERROR__}) {
            $message = $reply->{'ERROR'}->{PARAMS}->{__ERROR__};
        } elsif($reply->{'ERROR'}->{LABEL}) {
            $message = $reply->{'ERROR'}->{LABEL};
        }

        $self->log->error($message);

        if ($message !~ /I18N_OPENXPKI_UI_/) {
            if ($message =~ /I18N_OPENXPKI_([^\s;]+)/) {
                my $ve = lc($1);
                $ve =~ s/_/ /g;
                $message = "I18N_OPENXPKI_UI_UNKNOWN_ERROR ($ve)";
            } else {
                $message = 'I18N_OPENXPKI_UI_UNKNOWN_ERROR';
            }
        }

    } else {
        $self->log->trace(Dumper $reply) if $self->log->is_trace;
    }

    return $message;
}

# Reads the query parameter "_tenant" and returns a list (tenant => $tenant) to
# be directly included in any API call that supports the parameter "tenant".
# Returns an empty list if no tenant is set.
sub tenant_param {
    my $self = shift;

    confess 'tenant_param() must be called in list context' unless wantarray; # die

    my $tenant = $self->param('_tenant');
    return (tenant => $tenant) if ($tenant);
    return ();
}

=head2 session_param

Read or write a session parameter, a shortcut to L<CGI::Session/param>.

Specify only a C<$key> to read a parameter and an additional value to write it.

B<Parameters>

=over

=item * I<Str> C<$key> - parameter name to read or write

=item * I<Str> C<$value> - optional parameter value to write

=back

=cut
sub session_param {
    my $self = shift;
    return $self->session->param(@_);
}

=head2 build_attribute_subquery

Expects an attribtue query definition hash (from uicontrol), returns arrayref
to be used as attribute subquery in certificate and workflow search.

=cut
sub build_attribute_subquery {

    my $self = shift;
    my $attributes = shift;

    if (!$attributes || ref $attributes ne 'ARRAY') {
        return {};
    }

    my $attr;

    foreach my $item (@{$attributes}) {
        my $key = $item->{key};
        my $pattern = $item->{pattern} || '';
        my $operator = uc($item->{operator} || 'IN');
        my $transform = $item->{transform} || '';
        my @val = $self->multi_param($key);

        my @preprocessed;

        while (my $val = shift @val) {
            # embed into search pattern from config
            $val = sprintf($pattern, $val) if ($pattern);

            # replace asterisk and question mark as wildcard for like fields
            if ($operator =~ /LIKE/i) {
                $val =~ s/\*/%/g;
                $val =~ s/\?/_/g;
            }

            if ($transform =~ /lower/) {
                $val = lc($val);
            } elsif ($transform =~ /upper/) {
                $val = uc($val);
            }

            $self->log->debug( "Query: $key $operator $val" );
            push @preprocessed, $val;
        }

        if (!@preprocessed) {
            next;
        }

        if ($operator eq 'IN') {
            $attr->{$key} = { '=', \@preprocessed };

        } elsif ($operator eq 'INLIKE' ) {
            $attr->{$key} = { -like => \@preprocessed };
        } else {
            # and'ed together - very tricky syntax...
            my @t = map { { $operator, $_ } } @preprocessed;
            unshift @t, '-and';
            $attr->{$key} = \@t;
        }
    }

    $self->log->trace('Attribute subquery ' . Dumper $attr) if $self->log->is_trace;

    return $attr;

}

=head2 build_attribute_preset

Expects an attribtue query definition hash (from uicontrol), returns arrayref
to be used as preset when reloading the search form

=cut
sub build_attribute_preset {

    my $self = shift;
    my $attributes = shift;

    if (!$attributes || ref $attributes ne 'ARRAY') {
        return [];
    }

    my @attr;

    foreach my $item (@{$attributes}) {
        my $key = $item->{key};
        my @val = $self->multi_param($key);
        while (my $val = shift @val) {
            push @attr,  { key => $key, value => $val, label => $item->{label}//'' };
        }
    }

    return \@attr;

}

=head2 build_autocomplete_query

Create the autocomplete config for a UI text field from the given autocomplete
workflow field configuration C<$ac_config>.

Also returns an additional hidden, to-be-encrypted UI field definition.

Text input fields with autocompletion are configured as follows:

    type: text
    autocomplete:
        action: certificate!autocomplete
        params:
            user:
                param_1: field_name_1
                param_2: field_name_1
            secure:
                query:
                    status: { "-like": "%done" }

Parameters below C<user> are filled from the referenced form fields.

Parameters below C<secure> may contain data structures (I<HashRefs>, I<ArrayRefs>)
as they are backend-encrypted and sent to the client as a JWT token. They can
be considered safe from user manipulation.

B<Parameters>

=over

=item * I<HashRef> C<$ac_config> - autocomplete workflow field config

=back

=cut

sub build_autocomplete_query {

    my $self = shift;
    my $ac_config = shift;

    # $ac_config = {
    #     action => "text!autocomplete",
    #     params => {
    #         user => {
    #             reference_1 => "comment",
    #         },
    #         secure => {
    #             static_a => "deep",
    #             sql_query => { "-like" => "$key_id:%" },
    #         },
    #     },
    # }

    my $p = $ac_config->{params} // {};
    my $p_user = $p->{user} // {};
    my $p_secure = $p->{secure} // {};
    my $needs_encryption = scalar keys $p_secure->%*;
    die 'Autocomplete option "persist" was renamed to "secure"' if $p->{persist};

    my $enc_field_name = Data::UUID->new->create_str; # name for additional input field

    # additional input field with encrypted data (protected from frontend modification)
    my $enc_field = $needs_encryption
        ? {
            type => 'encrypted',
            name => $enc_field_name,
            value => {
                data => $p_secure,
                param_whitelist => [ sort keys %$p_user ], # allowed in subsequent request from frontend
            },
        }
        : ();

    return (
        {
            action => $ac_config->{action},
            params => { # list of field names whose values the UI will append to the query
                %$p_user,
                $needs_encryption ? (__encrypted => $enc_field_name) : (),
            },
        },
        $enc_field
    );
}

=head2 fetch_autocomplete_params

Uses the C<__encrypted> request parameter to re-assemble the full hash of
autocomplete parameters by decoding the encrypted static values and querying
the whitelisted dynamic values.

B<Parameters>

=over

=item * I<HashRef> C<$input_field> - input field definition

=back

B<Returns> a I<HashRef> of query parameters
=cut

sub fetch_autocomplete_params {
    my $self = shift;

    my $data = $self->secure_param('__encrypted') or return {};

    # add secure parameters
    my %params = %{ $data->{data} };
    # add whitelisted user input parameters
    $params{$_} = $self->param($_) for @{ $data->{param_whitelist} };

    $self->log->trace("Autocomplete params: " . Dumper \%params) if $self->log->is_trace;
    return \%params;
}

=head2 transate_sql_wildcards

Replace "literal" wildcards asterisk and question mark by percent and
underscore for SQL queries.

=cut

sub transate_sql_wildcards  {

    my $self = shift;
    my $val = shift;

    return $val if (ref $val);

    $val =~ s/\*/%/g;
    $val =~ s/\?/_/g;

    return $val;
}

__PACKAGE__->meta->make_immutable;

=pod

=head2 encrypt_jwt

Encrypt the given data into a JWT using the encryption key stored in session
parameter C<jwt_encryption_key> (key will be set to random value if it does not
exist yet).
