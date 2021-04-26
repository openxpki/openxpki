## OpenXPKI::Template::Plugin::RandomPassword
##
## Written by Martin Bartosch for the OpenXPKI project 2007
## Copyright (C) 2007 The OpenXPKI Project

package OpenXPKI::Template::Plugin::RandomPassword;

use strict;
use warnings;
use utf8;

use base qw( Template::Plugin );
use Template::Plugin;

use Data::Dumper;

use OpenXPKI::Random;
use OpenXPKI::Password;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use Digest::SHA;
use MIME::Base64;

sub new {
    my $class = shift;
    my $context = shift;

    return bless {
    _CONTEXT => $context,
    }, $class;
}

sub generate {
    my $self = shift;
    my $args = shift;

    if (! defined $args || ref $args ne 'HASH') {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_TEMPLATE_PASSWORD_GENERATE_MISSING_SCHEME_SPECIFICATION",
        );
    }

    my $password = OpenXPKI::Random->new()->get_random( $args->{bytes} || 9 );
    my $rv;
    if ($args->{scheme} eq 'none') {
        return $password;
    } else {
        $rv = OpenXPKI::Password::hash($args->{scheme}, $password);
    }

    if ($rv eq '') {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_TEMPLATE_PASSWORD_GENERATE_INVALID_SCHEME_SPECIFICATION",
            params  => { SCHEME => $args->{scheme} },
        );
    }

    if (defined $args->{callback}) {
        my $callback = eval "$args->{callback}";
        if (ref $callback eq 'CODE') {
            eval {
            $_ = $password;
            &$callback($password, $rv);
            };
        }
    }
    return $rv;
}

1;
__END__

=head1 OpenXPKI::Template::Plugin::RandomPassword

This module implements a Template Toolkit plugin that generates randomly
generated passwords in RFC2307 syntax. The used alphabet is Base64.

=head2 How to use

In your template, use the following line at the beginning of the file to
load the plugin:

  [% USE password = RandomPassword -%]

After doing so, you can use the class like this:

  ...
    <digest>[% password.generate(scheme => 'ssha', callback => 'sub { print STDERR "*** NOTE: Password for user <John Doe> is: $_\n" }') %]</digest>
  ...

This invocation will call the generate() method on the template's
password instance variable. It passes the named parameters 'scheme' and
'callback' to the function. The return value of the method is rendered
into the template output.

=head2 generate

Generates a random password and returns the encrypted value.

Named parameters:

=over 8

=item scheme

Required. Specifies the password scheme to use.

The special value I<none> outputs the generated password as is (without
a scheme prefix). Anything else will be handled by OpenXPKI::Password and
print the generated hashed password.

The recommended scheme is 'ssha'.

=item bytes

The number of random bytes, default is 9, which generates a 12 bas63
characters. Note: If this number is not a multiple of 3 you will have
padding characters to fill up to a valid base64 word.

=item callback

Optional. String containing a valid Perl closure subroutine.
The closure is called after generating the password with two parameters.
The first parameter is the unencrypted password, the second one is
the encrypted value.

$_ will contain the unencrypted password.

=back
