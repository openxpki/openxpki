package OpenXPKI::Client::Service::WebUI::SessionCookie;
use OpenXPKI -class;

# Core modules
use MIME::Base64 qw( encode_base64 decode_base64 );

# CPAN modules
use Crypt::CBC;
use Data::UUID;
use Mojo::Cookie::Response;


=head1 NAME

OpenXPKI::Client::Service::WebUI::SessionCookie - manage the (optionally encrypted) session cookie

=head1 SYNOPSIS

    my $cookie = OpenXPKI::Client::Service::WebUI::SessionCookie->new(
        request => $mojo_request,
        cipher => Crypt::CBC->new(
            -key => $cipher_key,
            -pbkdf => 'opensslv2',
            -cipher => 'Crypt::OpenSSL::AES',
        ),
    );

    # decrypt cookie and fetch session ID
    my $sess_id = $cookie->fetch_id; # this might throw a decryption error

    # set session and create encrypted cookie
    $cookie->session($oxi_session); # OpenXPKI::Client::Service::WebUI::Session
    $cookie->path(...); # optionally

    my $cookies = $cookie->as_mojo_cookies; # ArrayRef of Mojo::Cookie::Response

=head1 CONSTRUCTOR

=head2 new

Constructor.

B<Parameters>

=over

=item * C<request> I<Mojo::Message::Request>

=cut
has 'request' => (
    required => 1,
    is => 'ro',
    isa => 'Mojo::Message::Request',
);

=item * C<cipher> I<Crypt::CBC> - encryption cipher for the session ID (optional, default: unencrypted session ID)

=cut
has 'cipher' => (
    is => 'ro',
    isa => 'Crypt::CBC',
    predicate => 'has_cipher',
);

=back

=head1 ATTRIBUTES

=head2 path

Cookie path (only relevant for L</build>).

=cut
has 'path' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_path',
);

=head2 insecure

Used in development environment to skip the "secure" option when creating the
cookie, so it will work with a HTTP (non-TLS) proxy that forwards requests to
the HTTPS backend.

=cut
has 'insecure' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

=head1 METHODS

=head2 as_mojo_cookies

Return an C<ArrayRef> of L<Mojo::Cookie::Response> cookies:

=over

=item * C<oxisess-webui> - encrypted session ID previously set via L</id> and the path set
via L</path>.

If no L<cipher> has been set the session ID will be stored unencrypted.

=item * C<oxi-login-timestamp> - "last login" timestamp

=item * C<oxi-extid>

=back

=cut
sub as_mojo_cookies ($self, $session) {
    my @result;

    # common attributes
    my %common = (
        $self->has_path ? (path => $self->path) : (),
        samesite => 'Strict',
        secure => (($self->request->is_secure and not $self->insecure) ? 1 : 0),
    );

    # session ID
    push @result, Mojo::Cookie::Response->new(
        name => 'oxisess-webui',
        value => $self->_encrypt($session->id),
        httponly => 1,
        %common,
    );

    # last login
    push @result, Mojo::Cookie::Response->new(
        name => 'oxi-login-timestamp',
        value => ($session->param('login_timestamp') // 0),
        %common,
    );

    # site global and non-strict cookie used with external authentication
    if (not $self->request->cookie('oxi-extid')) {
        push @result, Mojo::Cookie::Response->new(
            name => 'oxi-extid',
            value => Data::UUID->new->create_b64,
            samesite => 'Lax',
            secure => 1,
            httponly => 1,
        );
    }

    return \@result;
}

=head2 fetch_id

Reads the (encrypted) cookie from the C<CGI> instance, decrypts it and returns
the session ID.

Throws an error if the decryption fails.

Returns C<undef> if no cookie was found.

=cut
sub fetch_id ($self) {
    return unless my $cookie = $self->request->cookie('oxisess-webui');
    return $self->_decrypt($cookie->value);
}

=head2 _encrypt

Encrypt the given value.

Returns the encrypted value if a cipher was configured, or the plain input value
otherwise.

Returns an empty string if no value was given.

=cut
sub _encrypt ($self, $value) {
    return '' unless defined $value;
    return $value unless $self->has_cipher;

    return encode_base64($self->cipher->encrypt($value), '');
}

=head2 _decrypt

Decrypt the given value.

Returns the decrypted value if a cipher was configured, or the plain input value
otherwise.

=cut
sub _decrypt ($self, $enc_value) {
    return unless defined $enc_value;
    return $enc_value unless $self->has_cipher;

    my $plain;
    eval { $plain = $self->cipher->decrypt(decode_base64($enc_value)) };
    die "Unable to decrypt cookie ($EVAL_ERROR)" unless $plain;

    return $plain;
}

__PACKAGE__->meta->make_immutable;
