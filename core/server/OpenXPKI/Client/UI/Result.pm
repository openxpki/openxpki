package OpenXPKI::Client::UI::Result;

use Moose;
use namespace::autoclean;

# Core modules
use Data::Dumper;
use Digest::SHA qw(sha1_base64);
use MIME::Base64;
use Carp qw( confess );
use Encode;

# CPAN modules
use CGI 4.08 qw( -utf8 );
use HTML::Entities;
use JSON;
use Moose::Util::TypeConstraints; # PLEASE NOTE: this enables all warnings via Moose::Exporter
use Data::UUID;
use Crypt::JWT qw( encode_jwt );
use Crypt::PRNG;
use Type::Params qw( signature_for );

# Project modules
use OpenXPKI::i18n qw( i18n_walk );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Client::UI::Response;

use experimental 'signatures'; # should be done after imports to safely disable warnings in Perl < 5.36

# Attributes set via constructor

has req => (
    is => 'ro',
    isa => 'OpenXPKI::Client::UI::Request',
    predicate => 'has_req',
    required => 1,
);

# extra parameters appended to a call via xxx!param!value
has extra => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

# extra parameters from a secure JWT
has extra_secure => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

has _client => (
    is => 'ro',
    isa => 'OpenXPKI::Client::UI',
    init_arg => 'client',
    required => 1,
);

=head1 RESPONSE RELATED ATTRIBUTES AND METHODS

Most of the following methods are accessors to attributes. Except from those
starting with C<set_*> they can also be called without arguments to retrieve
the current value.

Please note that currently some of these attributes are of type I<Scalar>,
I<ArrayRef> or I<HashRef> while others are "data transfer objects" (DTOs) that
use L<OpenXPKI::Client::UI::Response::DTO> and encapsulate several values.
The DTOs have a C<resolve> method which recursively builds a I<HashRef> from
the encapsulated data. The I<HashRef> gets converted to JSON
(in L</_render_body_to_str>) and is sent to the web UI.

=head2 redirect

Enforce a client side redirect to the given page:

    $self->redirect->to('workflow!search');
    $self->redirect->external('https://...');

=head2 confined_response

Enforce response to a confined request, i.e. and autocomplete query. Returns
an arbitrary JSON structure to the web UI.

    $self->confined_response([1,2,3]);

=head2 main

Set the structure of the main contents.

    $self->main->add_section(...);
    $self->main->add_form(...);

C<add_form> receives constructor parameters for L<OpenXPKI::Client::UI::Response::Section::Form>.

=head2 infobox

Set the structure of the right hand side info box.

Usage equivalent to L</main>.

=head2 language

Set the language.

    $self->language('de');

=head2 menu

Set the menu structure.

    $self->menu->items([ ... ]);
    # or
    $self->menu->add_item({
        key => 'logout',
        label => 'I18N_OPENXPKI_UI_CLEAR_LOGIN',
    });

=head2 on_exception

Add an exception handler for HTTP codes.

    $self->on_exception->add_handler(
        status_code => [ 403, 401 ],
        redirect => $target,
    );

=head2 page and set_page

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

=head2 ping

Configure keepalive ping to an endpoint.

    $self->ping({ href => '...', timeout => 30 }); # timeout is in milliseconds

=head2 refresh and set_refresh

Configure a periodic page refresh timer.

    $self->refresh->uri("workflow!load!wf_id!$wf_id");
    $self->refresh->timeout(30);

    # set several attributes at once
    $self->set_refresh(
        uri => "workflow!load!wf_id!$wf_id",
        timeout => 30,
    );

=head2 rtoken

Set the request token.

    $self->rtoken($rtoken);

=head2 status

Set status or error message.

    $self->status->info('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_30SEC');
    $self->status->success('...');
    $self->status->warn('...');
    $self->status->error('...');

=head2 tenant

Set the tenant.

    $self->tenant($tenant);

=head2 user and set_user

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

=head2 add_header

Add one or more HTTP response headers.

    $response->add_header(-type => 'application/json; charset=UTF-8');

=head2 get_header_str

Return the string containing the HTTP headers.

    print $self->get_header_str($cgi);

=head2 raw_bytes and raw_bytes_callback

Set a raw byte output (i.e. no JSON response) to send files to the client.

    $self->add_header(-type => $data->{mime}, -attachment => $data->{attachment});
    $self->raw_bytes($data);

    # to avoid storing large data in memory
    $self->raw_bytes_callback(sub {
        my $consume = shift;
        open (my $fh, "<", $source) || die "Unable to open $source: $!";
        while (my $line = <$fh>) { $consume->($line) }
        close $fh;
    });

=cut
has resp => (
    is => 'ro',
    isa => 'OpenXPKI::Client::UI::Response',
    required => 1,
    handles => [ qw(
        redirect
        confined_response has_confined_response
        infobox
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
        add_header
        get_header_str
        raw_bytes has_raw_bytes raw_bytes_callback has_raw_bytes_callback
    ) ],
);

# Internal attributes

has _last_reply => (
    is => 'rw',
    isa => 'HashRef',
);

has _session => (
    is => 'ro',
    isa => 'CGI::Session',
    lazy => 1,
    builder => '_init_session',
);

has serializer => (
    is => 'ro',
    isa => duck_type( [qw( serialize deserialize )] ),
    lazy => 1,
    default => sub { OpenXPKI::Serialization::Simple->new() },
);

has type => (
    is => 'ro',
    isa => 'Str',
    default => 'json',
);

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

=head1 METHODS

=cut

sub _init_session {

    my $self = shift;
    return $self->_client->session;

}

sub cgi {

    my $self = shift;
    return unless ($self->has_req());
    return $self->req()->cgi;

}

=head2 internal_redirect

Internal redirection from an C<action_*> method to a page (C<init_*> method).

From within an C<action_*> method you may do this:

    return $self->internal_redirect('home!welcome' => { name => "OpenXPKI" });

=cut
sub internal_redirect {
    my $self = shift;
    $self->_internal_redirect_target([ @_ ]);
    return $self;
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

    my $backend = $self->_client->backend;
    my $reply = $backend->send_receive_service_msg(
        'COMMAND' => {
            COMMAND => $command,
            PARAMS => $params,
            API => 2,
            TIMEOUT => ($flags->{timeout} || 0),
            REQUEST_ID => $self->req->id,
        }
    );
    $self->_last_reply( $reply );

    $self->log->trace("Raw backend reply to '$command': ". Dumper $reply) if $self->log->is_trace;

    if ( $reply->{SERVICE_MSG} ne 'COMMAND' ) {
        $self->log->error("command $command failed ($reply->{SERVICE_MSG})");
        $self->log->trace("command reply ". Dumper $reply) if $self->log->is_trace;
        if (!$flags->{nostatus}) {
            $self->set_status_from_error_reply( $reply );
        }
        return undef;
    }

    return $reply->{PARAMS};

}

sub set_status_from_error_reply {

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
    $self->status->error($message);

    return $self;
}

=head2 param

Returns a single input parameter value, i.e.

=over

=item * secure parameters passed in a (serverside) JWT encoded hash,

=item * those appended to the action name using C<!> and

=item * real CGI parameters.

=back

A parameter name will be looked up in the listed order.

If the input parameter is a list (multiple values) then only the first value is
returned.

B<Parameters>

=over

=item * I<Str> C<$key> - parameter name to retrieve: a plain parameter name or
a stringified hash (e.g. C<key_param{curve_name}>).

Please note that passing an I<ArrayRef> is no longer supported - please use
L</param_from_fields> instead. Passing C<undef>is also no longer supported.

=back

=cut

sub param {

    my ($self, $key) = @_;

    confess 'param() must be called in scalar context' if wantarray; # die

    my @val = $self->__param($key);
    return $val[0];
}

=head2 secure_param

Returns a single input parameter that was passed inside an encrypted JWT.

B<Parameters>

=over

=item * I<Str> C<$key> - parameter name to retrieve.

=back

=cut

sub secure_param {

    my ($self, $key) = @_;

    my $val = $self->extra_secure->{$key};
    return $val if defined $val;

    $self->log->trace("Requested secure parameter '$key' was not found") if $self->log->is_trace;
    return;
}

=head2 multi_param

Returns a list with an input parameters' values (multi-value field, most
likely a clonable field).

B<Parameters>

=over

=item * I<Str> C<$key> - parameter name to retrieve: a plain parameter name or
a stringified hash (e.g. C<key_param{curve_name}>).

=back

=cut

sub multi_param {

    my ($self, $key) = @_;

    confess 'multi_param() must be called in list context' unless wantarray; # die

    my @val = $self->__param($key);
    return @val;
}

sub __param {

    my ($self, $key) = @_;

    confess "param() / multi_param() expect a single key (string) as argument\n" if (not $key or ref $key); # die

    my @queries = (
        # Try extra parameters from a secure JWT
        sub { return $self->extra_secure->{$key} },
        # Try extra parameters appended to a call via xxx!param!value
        sub { return $self->extra->{$key} },
        # Try parameter via request object
        sub { return $self->req->multi_param($key) },
    );

    for my $q (@queries) {
        my @val = $q->();
        return @val if defined $val[0];
    }

    $self->log->trace("Requested parameter '$key' was not found") if $self->log->is_trace;
    return;
}

# return a list/hash (tenant => $tenant)_from_env to be directly included
# in any api call. Returns an empty list if tenant is not set
sub __tenant {
    my $self = shift;
    my $tenant = $self->param('_tenant');
    return (tenant => $tenant) if ($tenant);
    return ();
}

=head2 session_param

Read or write a CGI session parameter, a shortcut to L<CGI::Session/param>.

Specify only a C<$key> to read a parameter and an additional value to write it.

B<Parameters>

=over

=item * I<Str> C<$key> - parameter name to read or write

=item * I<Str> C<$value> - optional parameter value to write

=back

=cut
sub session_param {
    my $self = shift;
    return $self->_session->param(@_);
}

sub __persist_status {
    my $self = shift;
    my $status = shift;

    my $session_key = $self->__generate_uid();
    $self->session_param($session_key, $status);
    $self->_session->expire($session_key, 15);

    return '_status_id!' . $session_key;
}

sub __fetch_status {
    my $self = shift;

    my $session_key = $self->param('_status_id');
    return unless $session_key;

    my $status = $self->session_param($session_key);
    return unless ($status && ref $status eq 'HASH');

    $self->log->debug("Set persisted status: " . $status->{message});
    return $status;
}

=head2 log

Return the class logger (log4perl ref).

=cut
sub log {
    my $self = shift;
    return $self->_client->log;
}

=head2 logger

Deprecated alias for L</log>.

=cut
sub logger {
    my $self = shift;
    return $self->_client->log;
}

=head2 _render_body_to_str

Assemble the return hash from the internal caches and return the result as a
string.

=cut
sub _render_body_to_str {
    my $self = shift;

    my $status = $self->status->is_set ? $self->status->resolve : $self->__fetch_status;

    #
    # A) page redirect
    #
    if ($self->redirect->is_set) {
        if ($status) {
            # persist status and append to redirect URL
            my $url_param = $self->__persist_status($status);
            $self->redirect->to($self->redirect->to . '!' . $url_param);
        }
        return encode_json({
            %{ $self->redirect->resolve },
            session_id => $self->_session->id
        });
    }

    #
    # B) response to a confined request, i.e. no page update (auto-complete etc.)
    #
    if ($self->has_confined_response) {
        return encode_json(i18n_walk($self->confined_response));
    }

    #
    # C) regular response
    #
    my $result = $self->resp->resolve;

    # show message of the day if we have a page section (may overwrite status)
    if ($self->page->is_set && (my $motd = $self->session_param('motd'))) {
        $self->session_param('motd', undef);
        $result->{status} = $motd;
    }
    # add session ID
    $result->{session_id} = $self->_session->id;

    return encode_json(i18n_walk($result));
}

=head2 render

Assemble the return hash from the internal caches and send the result
to the browser.

=cut
sub render {
    my $self = shift;
    my $cgi = $self->cgi;

    if (not ref $cgi) {
        $self->log->error("Cannot render result - CGI object not available");
        return;
    }

    # helper to print HTTP headers
    my $print_headers = sub {
        my $headers = $self->get_header_str($cgi);
        $self->log->trace("Response headers:\n$headers") if $self->log->is_trace;
        print $headers;
    };

    # File download
    if ($self->has_raw_bytes or $self->has_raw_bytes_callback) {
        $print_headers->();
        # A) raw bytes in memory
        if ($self->has_raw_bytes) {
            $self->log->debug("Sending raw bytes (in memory)");
            print $self->raw_bytes;
        }
        # B) raw bytes retrieved by callback function
        elsif ($self->has_raw_bytes_callback) {
            $self->log->debug("Sending raw bytes (via callback)");
            # run callback, passing a printing function as argument
            $self->raw_bytes_callback->(sub { print @_ });
        }

    # Standard JSON response
    } elsif ($cgi->http('HTTP_X-OPENXPKI-Client')) {
        $print_headers->();
        $self->log->debug("Sending JSON response");
        print $self->_render_body_to_str;

    # Redirects
    } else {
        my $url = '';
        # redirect to given page
        if ($self->redirect->is_set) {
            $url = $self->redirect->to;

        # redirect to downloads / result pages
        } elsif (my $body = $self->_render_body_to_str) {
            $url = $self->__persist_response( { data => $body } );
        }

        # if url does not start with http or slash, prepend baseurl + route name
        if ($url !~ m{\A http|/}x) {
            my $baseurl = $self->session_param('baseurl');
            $url = sprintf("%sopenxpki/%s", $baseurl, $url);
        }

        # HTTP redirect
        $self->log->debug("Sending HTTP redirect to: $url");
        print $cgi->redirect($url);
    }
}

=head2 _escape ( string )

Replace html entities in string by their encoding

=cut
sub _escape {

    my $self = shift;
    my $arg = shift;
    return encode_entities($arg);

}

=head2 __register_wf_token( wf_info, token )

Generates a new random id and stores the passed workflow info, expects
a wf_info and the token info to store as parameter, returns a hashref
with the definiton of a hidden field which can be directly
pushed onto the field list. wf_info can be undef / empty string.

=cut
sub __register_wf_token {

    my $self = shift;
    my $wf_info = shift;
    my $token = shift;

    if (ref $wf_info) {
        $token->{wf_id} = $wf_info->{workflow}->{id};
        $token->{wf_type} = $wf_info->{workflow}->{type};
        $token->{wf_last_update} = $wf_info->{workflow}->{last_update};
    }
    my $id = $self->__generate_uid();
    $self->log->debug('wf token id ' . $id);
    $self->log->trace('token info ' . Dumper  $token) if $self->log->is_trace;
    $self->session_param($id, $token);
    return { name => 'wf_token', type => 'hidden', value => $id };
}

=head2 __fetch_wf_token( wf_token, purge )

Return the hashref stored by __register_wf_token for the given
token id. If purge is set to a true value, the info is purged
from the session context.

=cut
sub __fetch_wf_token {

    my $self = shift;
    my $id = shift;
    my $purge = shift || 0;

    return {} unless $id;

    $self->log->debug( "load wf_token " . $id );

    my $token = $self->session_param($id);
    $self->_session->clear($id) if($purge);
    return $token;

}

=head2 __purge_wf_token( wf_token )

Purge the token info from the session.

=cut
sub __purge_wf_token {

    my $self = shift;
    my $id = shift;

    $self->log->debug( "purge wf_token " . $id );
    $self->_session->clear($id);

    return $self;

}

=head2 __persist_response

Persist the given response data to retrieve it after an HTTP roundtrip.
Used to break out of the JavaScript app for downloads or to reroute result
pages.

Returns the page call URI for L<OpenXPKI::Client::UI::Cache/init_fetch>.

=cut

sub __persist_response {

    my $self = shift;
    my $data = shift // die "Attempt to persist empty response data";
    my $expire = shift // '+5m';

    my $id = $self->__generate_uid;
    $self->log->debug('persist response ' . $id);

    $self->session_param('response_'.$id, $data );
    $self->_session->expire('response_'.$id, $expire) if $expire;

    return  "cache!fetch!id!$id";

}


=head2 __fetch_response

Get the data for the persisted response.

=cut

sub __fetch_response {

    my $self = shift;
    my $id = shift;

    $self->log->debug('fetch response ' . $id);
    my $response = $self->session_param('response_'.$id);
    if (!$response) {
        $self->log->error( "persisted response with id $id does not exist" );
        return;
    }
    return $response;

}

=head2 __generate_uid

Generate a random uid (RFC 3548 URL and filename safe base64)

=cut
sub __generate_uid {
    my $self = shift;
    my $uid = sha1_base64(time.rand().$$);
    ## RFC 3548 URL and filename safe base64
    $uid =~ tr/+\//-_/;
    return $uid;
}

=head2 __build_attribute_subquery

Expects an attribtue query definition hash (from uicontrol), returns arrayref
to be used as attribute subquery in certificate and workflow search.

=cut
sub __build_attribute_subquery {

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

=head2 __build_attribute_preset

Expects an attribtue query definition hash (from uicontrol), returns arrayref
to be used as preset when reloading the search form

=cut
sub __build_attribute_preset {

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
            push @attr,  { key => $key, value => $val };
        }
    }

    return \@attr;

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

=head2 decrypted_param

Return a decrypted JWT input parameter (whose only allowed type is I<HashRef>).

C<undef> is returned if the parameter does not exist or if it was not encrypted.

B<Parameters>

=over

=item * I<Str> C<$key> - parameter name to retrieve.

=back

=cut

sub decrypted_param {

    my $self = shift;
    my $param_name = shift;

    my $item = $self->param($param_name)
        or return;

    if ($item->{__jwt_key} ne $self->session_param('jwt_encryption_key')) {
        $self->log->debug("Parameter '".$param_name."'' was not JWT encrypted");
        return;
    }
    delete $item->{__jwt_key};
    return $item;

}

# encrypt given data
sub _encrypt_jwt {
    my ($self, $value) = @_;

    die "Only values of type HashRef are supported for encrypted input fields\n"
      unless ref $value eq 'HASH';

    my $key = $self->session_param('jwt_encryption_key');
    if (not $key) {
        $key = Crypt::PRNG::random_bytes(32);
        $self->session_param('jwt_encryption_key', $key);
    }

    my $token = encode_jwt(
        payload => $value,
        enc => 'A256CBC-HS512',
        alg => 'PBES2-HS512+A256KW', # uses "HMAC-SHA512" as the PRF and "AES256-WRAP" for the encryption scheme
        key => $key, # can be any length for PBES2-HS512+A256KW
        extra_headers => {
            p2c => 8000, # PBES2 iteration count
            p2s => 32,   # PBES2 salt length
        },
    );

    return $token
}

=head2 secure_call

Encrypt the given page and parameters using a JWT.

Returns a string consisting of the pseudo page named C<encrypted> and the JWT
as single parameter.

B<Named parameters>

=over

=item * I<Str> C<page> - page to call.

=item * I<HashRef> C<secure_param> - additional secure parameters that will be available via L</secure_param>.

=back

=cut

signature_for secure_call => (
    method => 1,
    named => [
        page => 'Str',
        secure_param  => 'HashRef | Undef', { default => {} },
    ],
);
sub secure_call ($self, $arg) {

    my $token = $self->_encrypt_jwt({
        page => $arg->page,
        secure_param => $arg->secure_param // {},
    });

    return "encrypted!${token}";
}

=head2 make_autocomplete_query

Create the autocomplete config for a UI text field from the given workflow
field configuration C<$wf_field>.

Also returns an additional hidden, to-be-encrypted UI field definition.

Text input fields with autocompletion are configured as follows:

    type: text
    autocomplete:
        action: certificate!autocomplete
        params:
            user:
                param_1: field_name_1
                param_2: field_name_1
            persist:
                query:
                    status: { "-like": "%done" }

Parameters below C<user> are filled from the referenced form fields.

Parameters below C<persist> may contain data structures (I<HashRefs>, I<ArrayRefs>)
as they are backend-encrypted and sent to the client as a JWT token. They can
be considered safe from user manipulation.

B<Parameters>

=over

=item * I<HashRef> C<$wf_field> - workflow field config

=back

=cut

sub make_autocomplete_query {

    my $self = shift;
    my $wf_field = shift;

    return unless $wf_field->{autocomplete};

    # $wf_field = {
    #     type: "text",
    #     autocomplete: {
    #         action: "text!autocomplete",
    #         params: {
    #             user: {
    #                 reference_1: "comment",
    #             },
    #             persist: {
    #                 static_a: "deep",
    #                 sql_query: { "-like": "$key_id:%" },
    #             },
    #         },
    #     },
    # }

    my $p = $wf_field->{autocomplete}->{params} // {};
    my $p_user = $p->{user} // {};
    my $p_persist = $p->{persist} // {};

    my $enc_field_name = Data::UUID->new->create_str; # name for additional input field

    my $ac_query_params = {  # the wf config param from the UI param
        %$p_user,
        __encrypted => $enc_field_name,
    };

    # additional input field with encrypted data (protected from frontend modification)
    my $enc_field = {
        name => $enc_field_name,
        type => 'encrypted',
        value => {
            persistent_params => $p_persist,
            user_param_whitelist => [ sort keys %$p_user ], # allowed in subsequent request from frontend
        },
    };

    return ($ac_query_params, $enc_field)

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

    my $data = $self->decrypted_param('__encrypted')
        or return {};

    my %params = %{ $data->{persistent_params} };
    $params{$_} = $self->param($_) for @{ $data->{user_param_whitelist} };

    $self->log->trace("Autocomplete params: " . Dumper \%params) if $self->log->is_trace;

    return \%params;

}

__PACKAGE__->meta->make_immutable;
