## OpenXPKI::Server::Workflow::Validator::CertSubjectFields
##
package OpenXPKI::Server::Workflow::Validator::CertSubjectFields;

use strict;
use warnings;
use utf8;

use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use English;
use Template;

use Data::Dumper;
use Encode;

__PACKAGE__->mk_accessors( qw( section ) );

sub _init {
    
    my ( $self, $params ) = @_;            
    $self->section( exists $params->{'section'} ? $params->{'section'} : 'subject' );    
    return 1;
}

sub validate {
    
    my ( $self, $wf, $profile, $style, $subject_parts ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $api     = CTX('api');
    
    return if (not defined $profile);
    return if (not defined $style);
    return if (not defined $subject_parts);
    
    my $fields_with_error;

    ##! 16: 'wf->id(): ' . $wf->id()

    my $fields = $api->get_field_definition({
        PROFILE => $profile,
        STYLE   => $style,
        SECTION => $self->section(),
    });
    
    ##! 64: 'fields: ' . Dumper $fields

    Encode::_utf8_off ($subject_parts);
    my $ser = OpenXPKI::Serialization::Simple->new();
    $subject_parts = $ser->deserialize( $subject_parts );
        
    ##! 64: 'data: ' . Dumper $subject_parts        
    # check min/max and match from the input definition
    # match: \A [A-Za-z\d\-\.]+ \z
    # min: 0
    # max: 100
    FIELD:
    foreach my $field (@$fields) {
        
        my $name = $field->{ID};
        my $min = $field->{MIN};
        my $max = $field->{MAX};
        my $match = $field->{MATCH};
        
        my @value;
        if ( !defined $subject_parts->{ $name } ) {
            # noop
        } elsif (ref $subject_parts->{ $name } eq 'ARRAY') {            
            # clean empty values
            @value = grep { $_ ne '' } @{$subject_parts->{ $name }};
        } elsif ( $subject_parts->{ $name } ne '' ) {        
            @value = ( $subject_parts->{ $name } );
        }
        
        # remove from hash to see if all was check
        delete $subject_parts->{ $name };
        
        if (!@value) {
            if ($min > 0) {
                $fields_with_error->{ $name } = 'I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_FIELD_LESS_THAN_MIN_COUNT';                
            }
            next FIELD;
        }
        
        if ($max && $max < scalar @value) {
            $fields_with_error->{ $name } = 'I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_FIELD_MAX_COUNT_EXCEEDED';
        }
        
        if ($match) {
            foreach my $val (@value) {
                if ($val !~ m{$match}xs) {
                    # should be a bit smarter to highlight the right one
                    $fields_with_error->{ $name } = "I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_FIELD_FAILED_REGEX";    
                }    
            }
        }
        
    }
    
    foreach my $field (keys %$subject_parts) {               
        $fields_with_error->{ $field } = "I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_FIELD_NOT_DEFINED";
    }

    ## did we find any errors?
    if ($fields_with_error) {
	   CTX('log')->log(
    	    MESSAGE  => "Certificate subject validation error",
    	    PRIORITY => 'error',
    	    FACILITY => 'workflow',
    	);
        validation_error ('I18N_OPENXPKI_UI_VALIDATOR_CERT_SUBJECT_FIELD_HAS_ERRORS', { invalid_fields => $fields_with_error } );
    }
 
    return 1;
}

1;

__END__
 