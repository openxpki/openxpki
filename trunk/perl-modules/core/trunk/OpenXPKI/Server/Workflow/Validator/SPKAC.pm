package OpenXPKI::Server::Workflow::Validator::SPKAC;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Server::Context qw( CTX );
use English;

sub validate {
    my ( $self, $wf ) = @_;

    ## prepare the environment
    my $context = $wf->context();
    my $spkac   = $context->param("spkac");
    my $errors = $context->param ("__errors");
       $errors = [] if (not defined $errors);
    my $old_errors = scalar @{$errors};

    return if (not defined $spkac);

    ## check that it is clean
    if ($spkac =~ /^[A-Za-z\-_=]*$/ or ## RFC 3548 URL and filename safe
        $spkac =~ /^[A-Za-z+\/=]*$/ or ## RFC 1421,2045 and 3548
       )
    {
        ## SPKAC is base64 and this is no base64
        push @{$errors}, [ 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_SPKAC_NO_BASE64' ];
        $context->param ("__errors" => $errors);
        validation_error ($errors->[scalar @{$errors} -1]);
    }

    ## FIXME: theoretically we could parse it to validate it...

    ## return true is senselesse because only exception will be used
    ## but good style :)
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::SPKAC

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="SPKAC"
           class="OpenXPKI::Server::Workflow::Validator::SPKAC">
  </validator>
</action>

=head1 DESCRIPTION

This validator checks a SPKAC string. The only implemented check today
is a base64 validation. The validator does not check the SPKAC
structure actually.

B<NOTE>: If you pass an empty string (or no string) to this validator
it will not throw an error. Why? If you want a value to be defined it
is more appropriate to use the 'is_required' attribute of the input
field to ensure it has a value.
