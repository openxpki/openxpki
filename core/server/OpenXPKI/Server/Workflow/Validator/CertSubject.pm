package OpenXPKI::Server::Workflow::Validator::CertSubject;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

sub validate {
    my ( $self, $wf, $profile_id, $style, $subject,  ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $api     = CTX('api');    
    my $errors  = $context->param ("__error");
       $errors  = [] if (not defined $errors);
    my $old_errors = scalar @{$errors};

    return if (not defined $profile_id);
    return if (not defined $style);
    return if (not defined $subject);

    ## check correctness of subject
    eval {
        my $object = OpenXPKI::DN->new ($subject);#
    };
    if ($EVAL_ERROR)
    {
        push @{$errors}, [$EVAL_ERROR];
        $context->param ("__error" => $errors);
	CTX('log')->log(
	    MESSAGE  => "Could not create DN object from subject '$subject'",
	    PRIORITY => 'error',
	    FACILITY => 'system',
	    );

        validation_error ($errors->[scalar @{$errors} -1]);
    }
 
    my $always = CTX('config')->get_hash("profile.$profile_id.style.$style.always");
 
    foreach my $label (keys %{$always}) {
        my $regex = $always->{$label};      
        if (not $subject =~ m{$regex}xs)
        {
            push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_FAILED_ALWAYS_REGEX',
                               {LABEL => $label,
                                REGEX => $regex,
                                SUBJECT => $subject} ];
        }
    }

    my $never = CTX('config')->get_hash("profile.$profile_id.style.$style.never");
 
    foreach my $label (keys %{$never}) {
        my $regex = $never->{$label};      
        if (not $subject !~ m{$regex}xs)
        {
            push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_CERT_SUBJECT_FAILED_NEVER_REGEX',
                               {LABEL => $label,
                                REGEX => $regex,
                                SUBJECT => $subject} ];
        }
    }

    ## did we find any errors?
    if (scalar @{$errors} and scalar @{$errors} > $old_errors)
    {
        $context->param ("__error" => $errors);
	CTX('log')->log(
	    MESSAGE  => "Certificate subject validation error for subject '$subject'",
	    PRIORITY => 'error',
	    FACILITY => 'system',
	    );

        validation_error ($errors->[scalar @{$errors} -1]->[0]);
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::CertSubject

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="CertSubject"
           class="OpenXPKI::Server::Workflow::Validator::CertSubject">
    <arg value="$cert_profile"/>
    <arg value="$cert_subject_style"/>
    <arg value="$cert_subject"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks a given subject according to the profile configuration.

B<NOTE>: If you pass an empty string (or no string) to this validator
it will not throw an error. Why? If you want a value to be defined it
is more appropriate to use the 'is_required' attribute of the input
field to ensure it has a value.
