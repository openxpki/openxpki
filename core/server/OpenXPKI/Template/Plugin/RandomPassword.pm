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

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use Digest::SHA1;
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

    my $password = '';
    my $rv = '';

    if (! defined $args || ref $args ne 'HASH') {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_TEMPLATE_PASSWORD_GENERATE_MISSING_SCHEME_SPECIFICATION",
	    params  => {
	    },
	    );
    }

    if ($args->{scheme} eq 'plain') {
	my $pool = '';
	foreach my $cmd ('ps',
			 'netstat -na',
			 'date',
			 'openssl rand -base 64 128',
			 'vmstat',
			 'free',
			 'df',
	    ) {
	    $pool .= `$cmd 2>&1` || '';
	}
	my $ctx = Digest::SHA1->new();
	$ctx->add($pool);
	$password = substr($ctx->b64digest, 0, 8);
	$rv = "{PLAIN}$password";
    }
    
    if ($args->{scheme} eq 'sha') {
	$password = $self->generate(
	    {
		scheme => 'plain',
	    });
	$password = substr($password, 7);

	my $ctx = Digest::SHA1->new();
	$ctx->add($password);
	$rv = '{SHA}' . $ctx->b64digest;
    }

    if ($args->{scheme} eq 'ssha') {
	my $salt = $self->generate(
	    {
		scheme => 'plain',
	    });
	$salt = substr($salt, 7, 4);

	$password = $self->generate(
	    {
		scheme => 'plain',
	    });
	$password = substr($password, 7);

	my $ctx = Digest::SHA1->new();
	$ctx->add($password);
	$ctx->add($salt);
	$rv = '{SSHA}' . MIME::Base64::encode_base64($ctx->digest . $salt, '');
    }

    if ($args->{scheme} eq 'md5') {
	$password = $self->generate(
	    {
		scheme => 'plain',
	    });
	$password = substr($password, 7);

	my $ctx = Digest::MD5->new();
	$ctx->add($password);
	$rv = '{MD5}' . $ctx->b64digest;
    }

    if ($args->{scheme} eq 'smd5') {
	my $salt = $self->generate(
	    {
		scheme => 'plain',
	    });
	$salt = substr($salt, 7, 4);

	$password = $self->generate(
	    {
		scheme => 'plain',
	    });
	$password = substr($password, 7);

	my $ctx = Digest::MD5->new();
	$ctx->add($password);
	$ctx->add($salt);
	$rv = '{SMD5}' . MIME::Base64::encode_base64($ctx->digest . $salt, '');
    }

    if ($rv eq '') {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_TEMPLATE_PASSWORD_GENERATE_INVALID_SCHEME_SPECIFICATION",
	    params  => {
		SCHEME => $args->{scheme},
	    },
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

=head1 NAME

OpenXPKI::Template::Plugin::RandomPassword

=head1 DESCRIPTION

This module implements a Template Toolkit plugin that generates randomly
generated passwords in RFC2307 syntax.

=head2 USAGE

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

=head2 Constructor

=head3 new

Called by the Template toolkit when instantiating the plugin.

=head2 Methods

=head3 generate

Generates a random password and returns the encrypted value.

Named parameters:

=over 8

=item scheme

Required. Specifies the password scheme to use. Supported values are 'plain', 
'sha' (SHA1 hash), 'ssha' (seeded SHA1 hash), 'md5' (MD5 hash), 'ssha'
(seeded SHA1 hash) and 'smd5' (seeded MD5 hash).

The recommended scheme is 'ssha'.

=item callback

Optional. String containing a valid Perl closure subroutine. 
The closure is called after generating the password with two parameters. 
The first parameter is the unencrypted password, the second one is 
the encrypted value.

$_ will contain the unencrypted password.

=back
