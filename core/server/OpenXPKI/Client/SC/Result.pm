# OpenXPKI::Client::SC::Result
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::SC::Result;

use Encode;
use English;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;
use Crypt::CBC;
use MIME::Base64;

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

has config => (
    is => 'rw',
    isa => 'HashRef',
    required => 1,
);

has cardData => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    builder => '_init_carddata'
);

has _client => (
    is => 'ro',
    isa => 'Object',
    init_arg => 'client'
);

has _error => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { return []; }
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

has _last_reply => (
    is => 'rw',
    isa => 'HashRef',
);

has _session => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    builder => '_init_session',
);

has _result => (
    is => 'rw',
    isa => 'HashRef|Undef',
    default => sub { return {}; }
);

has serializer => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    default => sub { return OpenXPKI::Serialization::Simple->new(); }
);

sub _init_session {

    my $self = shift;
    return $self->_client()->session();

}

sub _add_error {

    my $self = shift;
    my $msg = shift;
    $self->logger()->error($msg);
    push @{$self->_error}, $msg;
    return $self;

}

sub has_errors {
    my $self = shift;
    return (scalar @{$self->_error}) > 0;
}


sub _init_carddata {

    my $self = shift;

    my $cardID = $self->param('cardID');
    my $cardType = $self->param('cardtype');
    my $ChipSerial = $self->param('ChipSerial');

    my $session = $self->_session();

    my $cardData = {};
    if ($session->param('cardData')) {
        $cardData = $session->param('cardData');
        $self->logger()->trace('Restore card data from session: ' . Dumper $cardData);
    }

    if ( ! defined $cardID ) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_MISSING_CARDID");

    } elsif ( $cardData->{'cardID'} && $cardData->{'cardID'} ne $cardID ) {

        $session->clear();
        $session->flush();
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CARDID_NOTACCEPTED");
        die "I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CARDID_NOTACCEPTED";

    } elsif ($cardID) {

        $cardData->{'cardID'} = $cardID;
        $session->param('cardID', $cardID);

    }

    if ( ! $cardType ) {

        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_MISSING_PARAMETER_CARDTYPE");

    } elsif ($cardType) {

        $cardData->{'cardtype'} = $cardType;

        my $card_id_prefix = $self->config()->{'cardtypeids'}->{ $cardType };
        if ( defined $card_id_prefix ) {
            $cardData->{'id_cardID'} = $card_id_prefix . $cardData->{'cardID'};

        } else {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CARDTYPE_INVALID");

        }
    }

    if ($ChipSerial) {
        $cardData->{'ChipSerial'} = $ChipSerial;
    }

    $self->logger()->trace('Card Data ' . Dumper $cardData);

    $session->param('cardData', $cardData );

    return $cardData;

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
    my $output  = shift;

    my $json = new JSON()->utf8;

    my %result = %{$self->_result};

    # auto add those card data items from the card data
    #my $cardData = $self->_session();
    #foreach my $key (qw(id_cardID cardtype cardID)) {
    #    $result{$key} = $session->param($key);
    #}

    # add error handling
    if (scalar @{$self->_error} && !$result{error}) {
        $result{error} = 'error';
        $result{errors} = $self->_error;
    }

    # Start output stream
    my $cgi = $self->cgi();


    my $body = $json->encode( \%result );

    # Return the output into the given pointer
    if ($output && ref $output eq 'SCALAR') {
        $$output = $body;
    } else {
        # Start output stream
        my $cgi = $self->cgi();

        print $cgi->header( @main::header );
        print $body;
    }

    return $self;
}



=head2 session_encrypt

Expects the cleartext as parameter and aes encrypts the data using the aeskey
stored in the session. Will return empty string if input is empty, will die
if session key is not set or encryption fails for any other reason.

=cut

sub session_encrypt {

    my $self  = shift;
    my $data = shift;

    if (!$data) { return ''; }

    my $session = $self->_session();

    if (!$session->param('aeskey')) {
        $self->logger()->error("No session secret defined!");
        die "No session secret defined!";
    }

    my $b64enc;

    eval{
        my $cipher = Crypt::CBC->new( -key => pack('H*', $session->param('aeskey')),
            -cipher => 'Crypt::OpenSSL::AES' );

        my $enc = $cipher->encrypt($data);
        $b64enc = encode_base64($enc);
    };

    if($EVAL_ERROR || !$b64enc) {
        $self->logger()->error('Unable to do encryption!');
        $self->logger()->debug($EVAL_ERROR);
        die "Unable to do encryption!";
    }

    return $b64enc ;

}


=head2 param

This method returns values from the input. Its a wrapper around the
cgi->param method.

=over

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

=back

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

        # We need to fetch from cgi as array for multivalues
        if (wantarray) {
            my @raw = $cgi->param($key);
            @raw = map { $_ =~ s/^\s+|\s+$//g; decode utf8 => $_ } @raw if(defined $raw[0]);
            return @raw;
        }

        my $str = $cgi->param($key);
        $str =~ s/^\s+|\s+$//g if (defined $str);
        return $str;

    }

    my $result;
    my $cgi = $self->cgi();
    my @keys;

    if (ref $key eq 'ARRAY') {
        $self->logger()->trace('Param request for keylist ' . join ":", @{$key} );
        my $extra = $self->extra();
        foreach my $p (@{$key}) {
            $self->logger()->trace('Fetch ' . $p );
            # Resolve wildcard keys used in dynamic key fields
            if ($p =~ m{ \A (\w+)\{\*\}(\[\])? \z }xs) {
                my $pattern = '^'.$1.'{\w+}';
                $self->logger()->debug('Wildcard pattern found ' . $p . ' - search : ' . $pattern);
                foreach my $wc ($cgi->param) {
                    push @keys, $wc if ($wc =~ /$pattern/);
                }
                $self->logger()->debug('Wildcard pattern found, keys ' . join ",", @keys);
            # Paramater is in extra attributes
            } elsif (defined $extra->{$p}) {
                $result->{$p} = $extra->{$p};

            # queue the key to get it from cgi later
            } elsif ($p !~ m{ \A wf_ }xms) {
                push @keys, $p;
            }
        }
    } else {
        $result = $self->extra();
        @keys = $cgi->multi_param if ($cgi);
        $self->logger()->trace('Param request for full set - cgi keys ' . Dumper \@keys );
    }

    if (!(@keys && $cgi)) {
        return $result;
    }

    foreach my $name (@keys) {
        # for workflows - strip internal fields (start with wf_)
        next if ($name =~ m{ \A wf_ }xms);

        if (ref $name) {
            # This happens only with broken CGI implementations
            die "Got reference where name was expected";
        }

        # autodetection of array and hashes
        if ($name =~ m{ \A (\w+)\[\] \z }xms) {
            my @val = $self->param($name);
            $result->{$1} = \@val;
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

1;
