package OpenXPKI::Server::Workflow::Validator::Regex;

use strict;
use warnings;
use base qw( Workflow::Validator );
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Serialization::Simple;

__PACKAGE__->mk_accessors(qw(regex error));

sub _init {
    my ( $self, $params ) = @_;
    $self->regex( $params->{regex} ) if ($params->{regex});
    $self->error( 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_REGEX_FAILED' );
    $self->error( $params->{error} ) if ($params->{error});
}

sub validate {
    my ( $self, $wf, $field, $regex ) = @_;

    ##! 1: 'start'

    my $value = $wf->context()->param($field);
    return 1 if (!defined $value || $value eq '');

    $regex = $self->regex() unless($regex);

    ##! 16: 'Value ' . $value
    ##! 16: 'Regex ' . $regex

    # replace named regexes
    if ($regex eq 'email') {
        $regex = qr/ \A [a-z0-9\.-]+\@([\w_-]+\.)+(\w+) \z /xi;
    # or quote the string if no named match
    } else {
        $regex = qr/$regex/x;
    }

    # Array Magic
    my @errors;
    if (ref $value eq 'ARRAY' || $value =~ /^ARRAY/) {
        if (!ref $value) {
            $value = OpenXPKI::Serialization::Simple->new()->deserialize( $value );
        }
        foreach my $val (@{$value}) {
            # skip empty
            next if (!defined $val || $val eq '');
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
