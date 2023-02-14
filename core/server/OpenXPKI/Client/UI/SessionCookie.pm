package OpenXPKI::Client::UI::SessionCookie;
use Moose;
use English;

# Core modules
use MIME::Base64 qw( encode_base64 decode_base64 );

# CPAN modules
use Crypt::CBC;
use Moose::Util::TypeConstraints;

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

    # set session ID and create encrypted cookie
    $cookie->id($sess_id);
    $cookie->path(...); # optionally
    print $cgi->header(
        ...
        -cookie => $cookie->build,
    );

=head1 METHODS

=head2 new

Constructor.

B<Parameters>

=over

=item * C<cgi> I<CGI> - CGI instance

=cut
has 'cgi' => (
    is => 'ro',
    isa => duck_type( [qw( cookie )] ), # not "isa => 'CGI'" as we use CGIMock in tests
    required => 1,
);

=item * C<cipher> I<Crypt::CBC> - encryption cipher for the session ID (optional, default: unencrypted session ID)

=cut
has 'cipher' => (
    is => 'ro',
    isa => 'Crypt::CBC',
    predicate => 'has_cipher',
);

=back

=head1 METHODS

=head2 path

Set the cookie path (only relevant for L</build>).

=cut
has 'path' => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_path',
);

=head2 id

Set the session ID (only relevant for L</build>).

=cut
has 'id' => (
    is => 'rw',
    isa => 'Str',
);

=head2 build

Build the HTTP cookie string containing the encrypted session ID previously set
via L</id> and the path set via L</path>.

If no L<cipher> has been set the session ID will be stored unencrypted.

=cut
sub build {
    my $self = shift;

    # assemble cookie
    my $cookie = {
        -name => 'oxisess-webui',
        -value => $self->_encrypt($self->id),
        $self->has_path ? (-path => $self->path) : (),
        -SameSite => 'Strict',
        -Secure => ($ENV{'HTTPS'} ? 1 : 0),
        -HttpOnly => 1,
    };

    return $self->cgi->cookie($cookie);
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
