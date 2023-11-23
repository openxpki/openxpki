package OpenXPKI::Client::UI::SessionCookie;
use Moose;
use English;

# Core modules
use MIME::Base64 qw( encode_base64 decode_base64 );

# CPAN modules
use Crypt::CBC;
use Moose::Util::TypeConstraints; # PLEASE NOTE: this enables all warnings via Moose::Exporter

=head1 NAME

OpenXPKI::Client::UI::SessionCookie - manage the (optionally encrypted) session cookie

=head1 SYNOPSIS

    my $cookie = OpenXPKI::Client::UI::SessionCookie->new(
        cgi => $cgi,
        cipher => Crypt::CBC->new(
            -key => $cipher_key,
            -pbkdf => 'opensslv2',
            -cipher => 'Crypt::OpenSSL::AES',
        ),
    );

    # decrypt cookie and fetch session ID
    my $sess_id = $cookie->fetch_id; # this might throw a decryption error

    # set session and create encrypted cookie
    $cookie->session($cgi_session);
    $cookie->path(...); # optionally
    print $cgi->header(
        ...
        -cookie => $cookie->render,
    );

=head1 CONSTRUCTOR

=head2 new

Constructor.

B<Parameters>

=over

=item * C<cgi> I<CGI> - CGI instance

=cut
has 'cgi' => (
    required => 1,
    is => 'ro',
    isa => duck_type( [qw( cookie )] ), # not "isa => 'CGI'" as we use CGIMock in tests
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

=head2 session

I<CGI::Session> instance.

=cut
has 'session' => (
    is => 'rw',
    isa => 'CGI::Session',
    predicate => 'has_session',
);

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

=head2 render

Render the strings for the HTTP cookies:

=over

=item * the encrypted session ID previously set via L</id> and the path set
via L</path>.

If no L<cipher> has been set the session ID will be stored unencrypted.

=item * the "last login"

=back

=cut
sub render {
    my $self = shift;

    die "Cannot create session cookie - session() must be set first\n"
      unless $self->has_session;

    my %common = (
        $self->has_path ? (-path => $self->path) : (),
        -SameSite => 'Strict',
        -Secure => (($ENV{'HTTPS'} and not $self->insecure) ? 1 : 0),
    );
    # session ID
    my $cookie_id = {
        %common,
        -name => 'oxisess-webui',
        -value => $self->_encrypt($self->session->id),
        -HttpOnly => 1,
    };
    # last login
    my $cookie_last_login = {
        %common,
        -name => 'oxi-login-timestamp',
        -value => ($self->session->param('login_timestamp') // 0),
    };
    # The result of this method is fed into $cgi->header(-cookie => $cookie->render)
    return [
        $self->cgi->cookie($cookie_id),
        $self->cgi->cookie($cookie_last_login),
    ];
}

=head2 fetch_id

Reads the (encrypted) cookie from the C<CGI> instance, decrypts it and returns
the session ID.

Throws an error if the decryption fails.

Returns C<undef> if no cookie was found.

=cut
sub fetch_id {
    my $self = shift;

    return $self->_decrypt($self->cgi->cookie('oxisess-webui'));
}

=head2 _encrypt

Encrypt the given value.

Returns the encrypted value if a cipher was configured, or the plain input value
otherwise.

Returns an empty string if no value was given.

=cut
sub _encrypt {
    my $self = shift;
    my $value = shift;

    return '' unless defined $value;
    return $value unless $self->has_cipher;

    return encode_base64($self->cipher->encrypt($value));
}

=head2 _decrypt

Decrypt the given value.

Returns the decrypted value if a cipher was configured, or the plain input value
otherwise.

=cut
sub _decrypt {
    my $self = shift;
    my $value = shift;

    return unless defined $value;
    return $value unless $self->has_cipher;

    my $plain;
    eval { $plain = $self->cipher->decrypt(decode_base64($value)) };
    die "Unable to decrypt cookie ($EVAL_ERROR)" unless $plain;

    return $plain;
}

__PACKAGE__->meta->make_immutable;
