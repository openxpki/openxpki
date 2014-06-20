# OpenXPKI::Client::UI::Result
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Result;

use HTML::Entities;
use Digest::SHA qw(sha1_base64);
use OpenXPKI::i18n qw( i18nGettext );
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

use Moose;

has cgi => (
    is => 'ro',
    isa => 'Object',
);

has extra => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { return {}; }
);

has _client => (
    is => 'ro',
    isa => 'Object',
    init_arg => 'client'
);

has _error => (
    is => 'rw',
    isa => 'HashRef|Undef',
);

has _page => (
    is => 'rw',
    isa => 'HashRef|Undef',
    lazy => 1,
    default => undef
);

has _status => (
    is => 'rw',
    isa => 'HashRef|Undef',
);

has _result => (
    is => 'rw',
    isa => 'HashRef|Undef',
    default => sub { return {}; }
);

has reload => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has redirect => (
    is => 'rw',
    isa => 'Str',
    default => '',
);

has serializer => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    default => sub { return OpenXPKI::Serialization::Simple->new(); }
);

has type => (
    is => 'ro',
    isa => 'Str',
    default => 'json',
);

sub BUILD {

    my $self = shift;
    # load global client status if set
    if ($self->_client()->_status()) {
        $self->_status(  $self->_client()->_status() );
    }

}
sub add_section {

    my $self = shift;
    my $arg = shift;

    push @{$self->_result()->{main}}, $arg;

    return $self;

}

sub set_status {

    my $self = shift;
    my $message = shift;
    my $level = shift || 'info';

    $self->_status({ level => $level, message => $message });

    return $self;

}


sub send_command {

    my $self = shift;
    my $command = shift;
    my $params = shift || {};

    my $backend = $self->_client()->backend();
    my $reply = $backend->send_receive_service_msg(
        'COMMAND', { COMMAND => $command, PARAMS => $params }
    );

    if ( $reply->{SERVICE_MSG} ne 'COMMAND' ) {
        $self->logger()->error("command $command failed ($reply->{SERVICE_MSG})");
        $self->set_status_from_error_reply( $reply );
        return undef;
    }

    return $reply->{PARAMS};

}

sub set_status_from_error_reply {

    my $self = shift;
    my $reply = shift;

    my $message = 'I18N_OPENXPKI_UI_UNKNOWN_ERROR';
    if ($reply->{'LIST'}
        && ref $reply->{'LIST'} eq 'ARRAY') {
        # Workflow errors
        if ($reply->{'LIST'}->[0]->{PARAMS} && $reply->{'LIST'}->[0]->{PARAMS}->{__ERROR__}) {
            $message = $reply->{'LIST'}->[0]->{PARAMS}->{__ERROR__};
        } elsif($reply->{'LIST'}->[0]->{LABEL}) {
            $message = $reply->{'LIST'}->[0]->{LABEL};
        }
        $self->logger()->error($message);
    }
    $self->_status({ level => 'error', message => i18nGettext($message) });

    return $self;
}

=head2 param

This method returns value from the input. It combines the real cgi parameters
with those encoded in the action name using "!". The method has multiple
personalities depending on the key you pass as argument. Parameters from the
actiion name have preceedence.

=item scalar

Return the value with the given key. Key can be a stringified hash/array
element, e.g. "key_param{curve_name}" (no quotation marks!). This will only
return scalar values and NOT try to resolve a group of params to a non scalar
return type!

=item arrayref

Give a list of keys to retrieve, return value is a hashref holding the value
for all your keys, set to undef if not found. Non-scalar keys will be combined
to hashref or arrayref but contain only the items listed in the input.

=item undef

Returns a complete hash of all values defined in extra and cgi->param.
Parameters with array or hash notation ([] or {} in their name), are converted
to hashref/arrayref.

=cut
sub param {

    my $self = shift;
    my $key = shift;

    # Scalar requested, just return what we find
    if (defined $key && ref $key eq '') {

        $self->logger()->trace('Param request for scalar ' . $key );

        my $extra = $self->extra()->{$key};
        return $extra if (defined $extra);

        my $cgi = $self->cgi();
        return undef unless($cgi);

        return $cgi->param($key);
    }

    my $result;
    my $cgi = $self->cgi();
    my @keys;

    if (ref $key eq 'ARRAY') {
        $self->logger()->trace('Param request for keylist ' . join ":", @{$key} );
        my $extra = $self->extra();
        foreach my $p (@{$key}) {
            if (defined $extra->{$p}) {
                $result->{$p} = $extra->{$p};
            } elsif ($p !~ m{ \A wf_ }xms) {
                push @keys, $p;
            }
        }
    } else {
        $result = $self->extra();
        @keys = $cgi->param if ($cgi);
        $self->logger()->trace('Param request for full set - cgi keys ' . Dumper \@keys );
    }

    if (!(@keys && $cgi)) {
        return $result;
    }

    foreach my $name (@keys) {
        # for workflows - strip internal fields (start with wf_)
        next if ($name =~ m{ \A wf_ }xms);

        # autodetection of array and hashes
        if ($name =~ m{ \A (\w+)\[\] \z }xms) {
            my @val = $self->param($name);
            $result->{$name} = \@val;
        } elsif ($name =~ m{ \A (\w+){(\w+)}(\[\])? \z }xms) {
            # if $3 is set we have an array element of a named parameter
            # (e.g. multivalued subject_parts)
            $result->{$1} = {} unless( $result->{$1} );
            if ($3) {
                my @val = $self->param($name);
                $result->{$1}->{$2} = \@val;
            } else {
                $result->{$1}->{$2} = $self->param($name);
            }
        } else {
            my $val = $self->param($name);
            $result->{$name} = $val;
        }
    }
    return $result;

}

=head2 logger

Return the class logger (log4perl ref)

=cut

sub logger {

    my $self = shift;
    return $self->_client()->logger();
}

=head2 render

Assemble the return hash from the internal caches and send the result
to the browser.

=cut
sub render {

    my $self = shift;

    my $result = $self->_result();

    $result->{error} = $self->_error() if $self->_error();
    $result->{status} = $self->_status() if $self->_status();
    $result->{page} = $self->_page() if $self->_page();
    $result->{reloadTree} = 1 if $self->reload();
    $result->{goto} = $self->redirect() if $self->redirect();

    # Start output stream
    my $cgi = $self->cgi();
    print $cgi->header( -cookie=> $cgi->cookie(CGISESSID => $self->_client()->session()->id), -type => 'application/json' );

    my $json = new JSON();
    if ($result->{_raw}) {
        print $json->encode($result->{_raw});
    } else {
        $result->{session_id} = $self->_client()->session()->id;
        print $json->encode($result);
    }

    return $self;
}


=head2 _escape ( string )

Replacce html entities in string by their encoding

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
pushed onto the field list.

=cut

sub __register_wf_token {

    my $self = shift;
    my $wf_info = shift;
    my $token = shift;

    $token->{wf_id} = $wf_info->{WORKFLOW}->{ID};
    $token->{wf_type} = $wf_info->{WORKFLOW}->{TYPE};
    $token->{wf_last_update} = $wf_info->{WORKFLOW}->{LAST_UPDATE};

    # poor mans random id
    my $id = sha1_base64(time.$token.rand().$$);
    $self->logger()->debug('wf token id ' . $id);
    $self->logger()->trace('token info ' . Dumper  $token);
    $self->_client->session()->param($id, $token);
    return { name => 'wf_token', type => 'hidden', value => $id };
}


=head2 __register_wf_token_initial ( wf_type, token )

Create a token to init a new workflow, expects the name of the workflow
as string and an optional hash to pass as initial parameters to the
create method. Returns the full action target as string.

=cut

sub __register_wf_token_initial {

    my $self = shift;
    my $wf_info = shift;
    my $wf_param = shift || {};

    my $token = {
        wf_type => $wf_info,
        wf_param => $wf_param,
        redirect => 1, # initial create always forces a reload of the page
    };

    # poor mans random id
    my $id = sha1_base64(time.$token.rand().$$);
    $self->logger()->debug('wf token id ' . $id);
    $self->_client->session()->param($id, $token);
    return  "workflow!index!wf_token!$id";
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

    $self->logger()->debug( "load wf_token " . $id );

    my $token = $self->_client->session()->param($id);
    $self->_client->session()->clear($id) if($purge);
    return $token;

}

=head2 __purge_wf_token( wf_token )

Purge the token info from the session.

=cut
sub __purge_wf_token {

    my $self = shift;
    my $id = shift;

    $self->logger()->debug( "purge wf_token " . $id );
    $self->_client->session()->clear($id);

    return $self;

}

1;