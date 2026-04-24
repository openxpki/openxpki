package OpenXPKI::Server::Workflow::Validator::Regex;
use OpenXPKI;

use parent qw( Workflow::Validator );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Util;
use Workflow::Exception qw( validation_error );
use OpenXPKI::Serialization::Simple;

__PACKAGE__->mk_accessors(qw(regex error modifier field));

sub init {
    my ( $self, $params ) = @_;

    $self->SUPER::init( $params );

    $self->regex( $params->{regex} // '' );

    # Default modifier is /xi
    $self->modifier( $params->{modifier} ? $params->{modifier} : 'xi') ;

    if ($params->{error}) {
        $self->error( $params->{error} );
    } elsif ($self->regex() eq 'email') {
        $self->error( 'I18N_OPENXPKI_UI_VALIDATOR_REGEX_EMAIL_FAILED' );
    } elsif ($self->regex() eq 'fqdn') {
        $self->error( 'I18N_OPENXPKI_UI_VALIDATOR_REGEX_FQDN_FAILED' );
    } elsif ($self->regex() eq 'href') {
        $self->error( 'I18N_OPENXPKI_UI_VALIDATOR_REGEX_HREF_FAILED' );
    } else {
        $self->error( 'I18N_OPENXPKI_UI_VALIDATOR_REGEX_FAILED' );
    }

    if ($params->{field}) {
        $self->field($params->{field});
    } else {
        $self->field('');
    }

}

sub validate {
    my ( $self, $wf, $value, $regex, $modifier ) = @_;

    ##! 1: 'start'

    if (!defined $value || $value eq '') {
         CTX('log')->application()->debug("Regex validator skipped - value is empty");

        return 1;
    }

    $regex = $self->regex() unless($regex);
    $modifier = $self->modifier() unless($modifier);

    ##! 16: 'Value ' . Dumper $value
    ##! 16: 'Regex ' . $regex

    # Build checker: named types delegate to OpenXPKI::Types via Util::validate,
    # custom patterns are compiled with the given modifier flags.
    my $check;

    my %named_types = map { (lc($_) => $_ ) }
        ('Email','FQDN','URI','IP','IPv4','IPv6','OID');
    # legacy name for http urls
    $named_types{href} = 'URI';

    if (my $type = $named_types{$regex}) {
        $check = sub { OpenXPKI::Util::validate($type, $_[0]) };
    } else {
        # Extended Pattern notation, see http://perldoc.perl.org/perlre.html#Extended-Patterns
        $modifier =~ s/\s//g;
        if ($modifier =~ /[^alupimsx]/) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_VALIDATOR_REGEX_INVALID_MODIFIER",
                params  => { MODIFIER => $modifier },
            );
        }
        $modifier = "(?$modifier)" if ($modifier);
        my $re = qr/$modifier$regex/;
        $check = sub { $_[0] =~ $re };
    }

    my @errors;
    ##! 32: 'ref of value ' . ref $value
    if (ref $value eq 'ARRAY' || OpenXPKI::Serialization::Simple::is_serialized($value)) {
        ##! 8: 'Array mode'
        if (!ref $value) {
            $value = OpenXPKI::Serialization::Simple->new()->deserialize($value);
        }
        foreach my $val (@{$value}) {
            next if (!defined $val || $val eq '');
            ##! 8: 'Failed on ' . $val
            push @errors, $val unless $check->($val);
        }
    } else {
        ##! 8: 'scalar mode'
        push @errors, $value unless $check->($value);
    }

    if (@errors) {
        # Need to implement this in New UI first
        #$wf->context()->param( '__error' => [ $self->error(), { FIELD => $field, VALUES => \@errors }]);
        ##! 32: 'Regex errors with regex ' . $regex. ', values '  . Dumper \@errors
        CTX('log')->application()->error("Regex validator failed on regex $regex");

        my @fields_with_error = ({ name => $self->field(), error => $self->error() });
        validation_error( $self->error(), { invalid_fields => \@fields_with_error } );

        return 0;
    }

    return 1;
}

1;


=head1 NAME

OpenXPKI::Server::Workflow::Validator::Regex

=head1 DESCRIPTION

Validates a workflow context value against a regular expression or a named
format type. The value is passed as the first validator argument; the regex
(or named type) may be passed as the second argument or set via the C<regex>
parameter — the argument takes precedence.

Empty and undefined values are silently skipped (use a separate presence
validator if the field is required).

Array values (native Perl array refs or OpenXPKI-serialized arrays) are
supported: every non-empty element is checked individually and all failing
values are collected before the error is raised.

=head1 Configuration

=head2 Example with argument (named type)

    class: OpenXPKI::Server::Workflow::Validator::Regex
    arg:
     - $email_address
     - email

=head2 Example with custom regex in parameters

    class: OpenXPKI::Server::Workflow::Validator::Regex
    arg:
     - $link
    param:
        regex: "\\A https?://[a-zA-Z0-9.-]+"
        modifier: xi
        error: Please provide a well-formed URL starting with http(s)://
        field: link

=head2 Parameters

=over

=item regex

Either a named format type (see below) or a bare regex pattern B<without>
delimiters or inline modifiers.  The default modifier is C<xi>
(case-insensitive, allow whitespace/comments); override with the C<modifier>
parameter.

B<Named types> — validated via L<OpenXPKI::Util/validate> against the
corresponding L<OpenXPKI::Types> constraint:

=over

=item email

Valid e-mail address syntax (C<Email> type).

=item fqdn

Fully qualified domain name with at least two labels (C<FQDN> type).

=item uri / href

URI with arbitrary scheme (C<URI> type).  C<href> is a legacy alias for
C<uri>.

=item ip

Any IP address — IPv4 or IPv6 (C<IP> type).

=item ipv4

IPv4 address in dotted-decimal notation (C<IPv4> type).

=item ipv6

IPv6 address (C<IPv6> type).

=item oid

ASN.1 object identifier (C<OID> type).

=back

=item modifier

Regex modifier flags applied when a custom pattern is used (not for named
types).  Allowed flags: C<a l u p i m s x>.  Whitespace is stripped before
processing.  Defaults to C<xi>.  See
L<perlre/Extended-Patterns> for details.

=item error

I18N key or plain text shown in the UI when validation fails.  Defaults to
a type-specific message for the built-in named types, or
C<I18N_OPENXPKI_UI_VALIDATOR_REGEX_FAILED> for custom patterns.

=item field

Name of the workflow input field that holds the value being validated.
When set, the UI highlights the offending field alongside the error message.

B<Note:> The value must still be passed explicitly as a validator argument;
the field name is used only for UI decoration.

=back
