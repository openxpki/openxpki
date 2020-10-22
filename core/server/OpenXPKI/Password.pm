package OpenXPKI::Password;

use strict;
use warnings;
use utf8;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use MIME::Base64;
use Digest::SHA;
use Digest::MD5;
use Proc::SafeExec;
use MIME::Base64;
use Crypt::Argon2;
use POSIX;

sub hash {
    my $scheme=shift;
    my $passwd=shift;
    my $encrypted=shift;
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
        return undef;
    }
    return $prefix . $computed_secret;
}

sub check {
    my $passwd=shift;
    my $hash=shift;
    my $encrypted;
    my $scheme;

    if ($hash =~ m{ \{ (\w+) \} (.*) }xms) {
        # handle common case: RFC2307 password syntax
        $scheme = lc($1);
        $encrypted = $2;
    }elsif( rindex($hash, "\$argon2id", 0) ==0 ){
        # handle special case of argon2
        return Crypt::Argon2::argon2id_verify($hash,$passwd);
    }else{
        # digest is not recognized
        OpenXPKI::Exception->throw (
            message => "Given digest is without scheme",
            params  => {},
            log => {
                priority => 'fatal',
                facility => 'system',
        });
    }
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

    ##! 2: "ident user ::= $account and digest ::= $computed_secret"
    $computed_hash =~ s{ =+ \z }{}xms;
    $hash       =~ s{ =+ \z }{}xms;
    return $computed_hash eq $hash;
    
}
sub __create_salt {
    my $bytes = shift;
    my @exec = ('openssl', 'rand', '-base64', $bytes);
    my ($salt, undef) = Proc::SafeExec::backtick(@exec);
    chomp $salt;
    return $salt;
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


