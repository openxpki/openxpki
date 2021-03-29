package OpenXPKI::Password;

use strict;
use warnings;
use utf8;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Random;
use OpenXPKI::Server::Context qw( CTX );
use MIME::Base64;
use Digest::SHA;
use Digest::MD5;
use Proc::SafeExec;
use MIME::Base64;
use Crypt::Argon2;
use POSIX;

sub hash {

    ##! 1: 'start'

    my $scheme = shift;
    my $passwd = shift;
    ##! 16: "$scheme / $passwd"
    my $encrypted = shift;
    my $prefix = sprintf '{%s}', $scheme;
    my $computed_secret;
    if ($scheme eq 'sha') {
        my $ctx = Digest::SHA->new();
        $ctx->add($passwd);
        $computed_secret = $ctx->b64digest();

    } elsif ($scheme eq 'md5') {
        my $ctx = Digest::MD5->new();
        $ctx->add($passwd);
        $computed_secret = $ctx->b64digest();

    } elsif ($scheme eq 'ssha') {
        my $ctx = Digest::SHA->new();
        my $salt = $encrypted ? substr(decode_base64($encrypted), 20) : __create_salt(3);
        $ctx->add($passwd);
        $ctx->add($salt);
        $computed_secret = encode_base64( $ctx->digest() . $salt, '');

    } elsif ($scheme eq 'smd5') {
        my $ctx = Digest::MD5->new();
        my $salt = $encrypted ? substr(decode_base64($encrypted), 16) : __create_salt(3);
        $ctx->add($passwd);
        $ctx->add($salt);
        $computed_secret = encode_base64($ctx->digest() . $salt, '');

    } elsif ($scheme eq 'crypt') {
        my $salt = $encrypted ? $encrypted : __create_salt(3);
        $computed_secret = crypt($passwd, $salt);

    } elsif ($scheme eq 'argon2') {
        $computed_secret = Crypt::Argon2::argon2id_pass($passwd, __create_salt(16), 3, '32M', 1, 16);
        $prefix = '';
    }
    if (!$computed_secret){
        ##! 4: 'unable to hash password'
        return undef;
    }
    return $prefix . $computed_secret;
}

sub check {

    my $passwd = shift;
    my $hash = shift;
    ##! 16:  $hash
    ##! 64: "Given password is $passwd"

    my $encrypted;
    my $scheme;

    if ($hash =~ m{ \{ (\w+) \} (.*) }xms) {
        # handle common case: RFC2307 password syntax
        $scheme = lc($1);
        $encrypted = $2;
    } elsif ( rindex($hash, "\$argon2id", 0) ==0 ){
        # handle special case of argon2
        return Crypt::Argon2::argon2id_verify($hash,$passwd);
    } elsif ($hash =~ m{\$[156]\$}) {
        # native format of openssl passwd, same as {crypt}
        $scheme = 'crypt';
        $encrypted = $hash;
        # prepend the old scheme to not break the equality check at the end
        $hash = "{crypt}$hash";
    } else {
        # digest is not recognized
        OpenXPKI::Exception->throw (
            message => "Given digest is without scheme",
            params  => {},
            log => {
                priority => 'fatal',
                facility => 'system',
        });
    }

    ##! 16: $scheme
    if ($scheme !~ /^(sha|ssha|md5|smd5|crypt)$/) {
        OpenXPKI::Exception->throw (
            message => "Given scheme is not supported",
            params  => {
                SCHEME => $scheme,
            },
            log => {
                priority => 'fatal',
                facility => 'system',
        });
    }
    

    my $computed_hash = hash($scheme,$passwd,$encrypted);

    if (! defined $computed_hash) {
        OpenXPKI::Exception->throw (
            message => "Unable to check password against hash",
            params  => {
              SCHEME => $scheme,
            },
        );
    }

    ##! 32: "$computed_hash ?= $hash"
    $computed_hash =~ s{ =+ \z }{}xms;
    $hash       =~ s{ =+ \z }{}xms;
    return $computed_hash eq $hash;
    
}
sub __create_salt {

    my $bytes = shift;
    return OpenXPKI::Random->new()->get_random($bytes);

}
1;

__END__;

=head1 Name

OpenXPKI::Password - password hashing and checking

=head1 Description

Provides utility functions for hashing passwords and checking passwords against a hash

=head1 Functions

=head2 hash

hashes a password according to the provided scheme.

SCHEME is one of sha (SHA1), md5 (MD5), crypt (Unix crypt), smd5 (encrypted
MD5), ssha (encrypted SHA1) or argon2.

It returns a hash in the format C<{SCHEME}encrypted_string>, C<$argon...> or undef if no hash could be computed

=head2 check

checks if a password matches the provided digest.

The digest must have the format: C<{SCHEME}encrypted_string> or must start with C<$argon2>

SCHEME is one of sha (SHA1), md5 (MD5), crypt (Unix crypt), smd5 (encrypted
MD5) or ssha (encrypted SHA1).

It returns 1 if the password matches the digest, 0 otherwise.


