package OpenXPKI::Server::Workflow::Validator::Regex;

use strict;
use warnings;
use base qw( Workflow::Validator );
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Serialization::Simple;

__PACKAGE__->mk_accessors(qw(regex error modifier));

sub _init {
    my ( $self, $params ) = @_;
    $self->regex( $params->{regex} ) if ($params->{regex});

    # Default modifier is /xi
    $self->modifier( $params->{modifier} ? $params->{modifier} : 'xi') ;
    $self->error( 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_REGEX_FAILED' );
    $self->error( $params->{error} ) if ($params->{error});
}

sub validate {
    my ( $self, $wf, $value, $regex, $modifier ) = @_;

    ##! 1: 'start'

    if (!defined $value || $value eq '') {
         CTX('log')->log(
            MESSAGE  => "Regex validator skipped - value is empty",
            PRIORITY => 'info',
            FACILITY => 'system',
        );
        return 1;
    }

    $regex = $self->regex() unless($regex);
    $modifier = $self->modifier() unless($modifier);

    ##! 16: 'Value ' . Dumper $value
    ##! 16: 'Regex ' . $regex

    # replace named regexes
    if ($regex eq 'email') {
        $regex = qr/ \A [a-z0-9\.-]+\@([\w_-]+\.)+(\w+) \z /xi;
    # or quote the string if no named match
    } else {
        # Extended Pattern notation, see http://perldoc.perl.org/perlre.html#Extended-Patterns
        $modifier =~ s/\s//g;
        if ($modifier =~ /[^alupimsx]/ ) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_VALIDATOR_REGEX_INVALID_MODIFIER",
                params => {
                    MODIFIER => $modifier,
                },
            );
        }
        $modifier = "(?$modifier)" if ($modifier);
        $regex = m{$modifier};
    }

    # Array Magic
    my @errors;
    if (ref $value eq 'ARRAY' || $value =~ /^ARRAY/) {
        ##! 8: 'Array mode'
        if (!ref $value) {
            $value = OpenXPKI::Serialization::Simple->new()->deserialize( $value );
        }
        foreach my $val (@{$value}) {
            # skip empty
            next if (!defined $val || $val eq '');
            ##! 8: 'Failed on ' . $val
            push @errors, $val if ($val !~ $regex);
        }
    } else {
        push @errors, $value if ($value !~ $regex);
    }

    if (@errors) {
        # Need to implement this in New UI first
        #$wf->context()->param( '__error' => [ $self->error(), { FIELD => $field, VALUES => \@errors }]);
        ##! 32: 'Regex errors on field ' . $field . ', values '  . Dumper \@errors
        CTX('log')->log(
            MESSAGE  => "Regex validator failed on regex $regex",
            PRIORITY => 'info',
            FACILITY => 'system',
        );
        validation_error( $self->error() );
        return 0;
    }

    return 1;
}

1;


=head1 NAME

OpenXPKI::Server::Workflow::Validator::Regex

=head1 SYNOPSIS

    <action name="..." class="...">
        <validator name="global_validate_regex">
            <arg>meta_email</arg>
            <arg>email</arg>
        </validator>
    </action>

=head1 DESCRIPTION

Validates the context value referenced by argument against a regex. The regex
can be given either as second argument inside the action definition as seen
above. If only one argument is given, the pattern is read from the param name
'regex' which must be set in the validator definition:

  <validator name="global_validate_regex"
      class="OpenXPKI::Server::Workflow::Validator::Regex">
      <param name="regex" value="email">
      <param name="error" value="email has invalid format">
  </validator>

The error parameter is optional, if set this is shown in the UI if the validator
fails.

The regex must be given as pattern without delimiters and modifiers.
Some common formats can also be referenced by name:

=over

=item email

Basic check for valid email syntax

=back
