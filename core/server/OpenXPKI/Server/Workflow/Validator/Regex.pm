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
    $self->error( 'I18N_OPENXPKI_UI_VALIDATOR_REGEX_FAILED' );
    $self->error( $params->{error} ) if ($params->{error});
}

sub validate {
    my ( $self, $wf, $value, $regex, $modifier ) = @_;

    ##! 1: 'start'

    if (!defined $value || $value eq '') {
         CTX('log')->log(
            MESSAGE  => "Regex validator skipped - value is empty",
            PRIORITY => 'info',
            FACILITY => 'application',
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

    } elsif ($regex eq 'fqdn') {
        $regex = qr/ \A (([\w\-]+\.)+)[\w\-]{2,} \z /xi;        
        
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
        $regex = qr/$modifier$regex/;
    }

    # Array Magic
    my @errors;
    ##! 32: 'ref of value ' . ref $value
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
        ##! 8: 'scalar mode'
        push @errors, $value if ($value !~ $regex);
    }

    if (@errors) {
        # Need to implement this in New UI first
        #$wf->context()->param( '__error' => [ $self->error(), { FIELD => $field, VALUES => \@errors }]);
        ##! 32: 'Regex errors with regex ' . $regex. ', values '  . Dumper \@errors
        CTX('log')->log(
            MESSAGE  => "Regex validator failed on regex $regex",
            PRIORITY => 'error',
            FACILITY => 'application',
        );
        my @fields_with_error = ({ name => 'link', error => $self->error() }); 
        validation_error( $self->error(), { invalid_fields => \@fields_with_error } );
        
        return 0;
    }

    return 1;
}

1;


=head1 NAME

OpenXPKI::Server::Workflow::Validator::Regex

=head1 SYNOPSIS

    class: OpenXPKI::Server::Workflow::Validator::Regex
    arg: 
     - $link
    param:
        regex: "\\A http(s)?://[a-zA-Z0-9-\\.]+"
        modifier: xi
        error: Please provide a well-formed URL starting with http://
            
=head1 DESCRIPTION

Validates the context value referenced by argument against a regex. The regex
can be passed either as second argument or specified in the param section.
The value given as argument is always preferred.

    class: OpenXPKI::Server::Workflow::Validator::Regex
    arg: 
     - $link
     - email

The error parameter is optional, if set this is shown in the UI if the validator
fails instead of the default message.

The regex must be given as pattern without delimiters and modifiers. The 
default modifier is "xi" (case-insensitive, whitespace pattern), you can 
override it using the key "modifier" in the param section. (@see 
http://perldoc.perl.org/perlre.html#Modifiers).

Some common formats can also be referenced by name:

=over

=item email

Basic check for valid email syntax

=item fqdn

A fully qualified domain name, must have at least one dot, all "word" 
characters are accepted for the domain parts. Last domain part must have
at least two characters

=back
