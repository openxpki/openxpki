## OpenXPKI::Client::HTML::Mason::CRR
##
## Written 2007 by Alexander Klink for the OpeNXPKI project
## (C) Copyright 2007 by The OpenXPKI Project

package OpenXPKI::Client::HTML::Mason::CRR;

use Class::Std;
use OpenXPKI::Exception;
use DateTime;

my %workflow_type_of   :ATTR( :init_arg<workflow_type> :get<workflow_type> );
my %revoc_reason_of    :ATTR( :init_arg<revocation_reason> :get<revocation_reason> );
my %comment_of         :ATTR( :init_arg<comment> :get<comment> );
my %cert_identifier_of :ATTR( :init_arg<cert_identifier> :get<cert_identifier>);
my %client_of          :ATTR( :init_arg<client> );
my %invalidity_date_of :ATTR;
my %errors_of          :ATTR( :get<errors> );
my %workflow_id_of     :ATTR( :get<workflow_id> );
my %ignore_errors_of   :ATTR( :init_arg<ignore_errors> :default<0>);

sub START {
    my ($self, $ident, $arg_ref) = @_;

    eval {
        $invalidity_date_of{$ident} = DateTime->new(
            year   => $arg_ref->{invalidity_year},
            month  => $arg_ref->{invalidity_month},
            day    => $arg_ref->{invalidity_day},
            hour   => $arg_ref->{invalidity_hour},
            minute => $arg_ref->{invalidity_minute},
        );
    };
    if ($EVAL_ERROR && ! $ignore_errors_of{$ident} ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_COULD_NOT_CREATE_DATETIME_OBJECT',
        );
    }
}

sub create_workflow {
    my $self  = shift;
    my $ident = ident $self;

    my $msg = $client_of{$ident}->send_receive_command_msg(
        'create_workflow_instance',
        {
            WORKFLOW => $workflow_type_of{$ident},
            PARAMS   => {
                'cert_identifier' => $cert_identifier_of{$ident},
                'reason_code'     => $revoc_reason_of{$ident},
                'comment'         => $comment_of{$ident},
                'invalidity_time' => $invalidity_date_of{$ident}->epoch(),
            },
        },
    );
    if (! ref $msg) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_CREATE_WORKFLOW_MSG_SCALAR',
            params => {
                'MESSAGE' => $msg,
            },
        );
    }
    elsif (exists $msg->{SERVICE_MSG} && $msg->{SERVICE_MSG} eq 'ERROR') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_CREATE_WORKFLOW_ERROR_CREATING_WORKFLOW',
            params => {
                'MESSAGE' => $msg,
            },
        );
    }
    else {
        $workflow_id_of{$ident} = $msg->{PARAMS}->{WORKFLOW}->{ID};
    }
    return 1;
}

sub validate {
    my $self  = shift;
    my $ident = ident $self;

    $self->validate_invalidity_date();
    $self->validate_workflow_type();
    $self->validate_revocation_reason();

    if (scalar %{ $errors_of{$ident} }) {
        # errors encountered, throw an exception
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_VALIDATION_ERROR',
        );
    }
    return 1;
}

sub validate_revocation_reason : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;
    
    my @valid_reasons = $self->get_possible_revocation_reasons;

    if (! grep { $_->{VALUE} eq $revoc_reason_of{$ident}} @valid_reasons) {
        $errors_of{$ident}->{'revocation_reason'} = 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_INVALID_REASON_CODE';
    }
    return 1;
}

sub validate_workflow_type : PRIVATE {
    my $self  = shift;
    my $ident = ident $self;

    if ($workflow_type_of{$ident} ne 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST' &&
        $workflow_type_of{$ident} ne 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST_OFFLINE_CA') {
        $errors_of{$ident}->{'workflow_type'} = 'I18N_OPENXPKI_HTML_MASON_CRR_INVALID_WORKFLOW_TYPE';
    }
    return 1;
}

sub validate_invalidity_date : PRIVATE {
    # for now, validate only that it is not in the future.
    # validation that it is not before certificate issuance will
    # be done by the workflow
    my $self  = shift;
    my $ident = ident $self; 

    my $now = DateTime->now();
    if (DateTime->compare($invalidity_date_of{$ident}, $now) > 0) {
        # invalidity date is later then 'now', this is an error
        $errors_of{$ident}->{'invalidity_date'} = 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_INVALIDITY_DATE_IN_FUTURE';
    }

    return 1;
}

sub get_possible_wf_types {
    my $self  = shift;
    my $ident = ident $self;

    my $msg = $client_of{$ident}->send_receive_command_msg(
        'list_workflow_titles',
    );
    my @types;
    if (ref $msg->{PARAMS} eq 'HASH') {
        @types = keys %{ $msg->{PARAMS} };
    }
    my @result;
    foreach my $type (@types) {
        if ($type =~ /I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST/) {
            push @result, {
                VALUE => $type,
                LABEL => $type,
            };
        }
    }
    return @result;
}

sub get_possible_revocation_reasons {
    my $self = shift;
    return (
        {
            VALUE => 'unspecified',
            LABEL => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_REVOCATION_REASON_UNSPECIFIED',
        },
        {
            VALUE => 'keyCompromise',
            LABEL => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_REVOCATION_REASON_KEYCOMPROMISE',
        },
        {
            VALUE => 'CACompromise',
            LABEL => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_REVOCATION_REASON_CACOMPROMISE',
        },
        {
            VALUE => 'affiliationChanged',
            LABEL => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_REVOCATION_REASON_AFFILIATION_CHANGED',
        },
        {
            VALUE => 'superseded',
            LABEL => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_REVOCATION_REASON_SUPERSEDED',
        },
        {
            VALUE => 'cessationOfOperation',
            LABEL => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_REVOCATION_REASON_CESSATION_OF_OPERATION',
        },
        {
            VALUE => 'certificateHold',
            LABEL => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_REVOCATION_REASON_CERTIFICATE_HOLD',
        },
        {
            VALUE => 'removeFromCRL',
            LABEL => 'I18N_OPENXPKI_CLIENT_HTML_MASON_CRR_REVOCATION_REASON_REMOVE_FROM_CRL',
        },
    );
}

1;
__END__

=head1 Name

OpenXPKI::Client::HTML::Mason::CRR

=head1 Description

This class is meant to save CRR data from a form and create a
corresponding workflow, once all form data has been acquired.

=head1 Functions

=head2 START

is the constructor. Validates the given arguments and throws an
exception if one of them is invalid. The argument and a corresponding
error message are saved in the attribute 'errors_of'.

=head2 create_workflow

Tries to create a workflow from the attributes. Saveas the workflow
id in the attribute 'workflow_id_of' if successful.

=head2 validate

Calls validate_invalidity_date(), validate_workflow_type() and
validate_revocation_reason() to do input validation. If one of
them fails, it puts the error in the corresponding attribute
and throws an exception.

=head2 validate_invalidity_date

Validates the given invalidity date by checking that it is not in
the future (note that the server will later check that it is within
the certificate validity time as well).

=head2 validate_workflow_type

Validates that a correct workflow type has been chosen.

=head2 validate_revocation_reason

Validates that a valid revocation reason has been chosen.

=head2 get_possible_wf_types

Lists the possible workflow types

=head2 get_possible_revocation_reasons

Lists the possible revocation reasons with label and value
(for select.mhtml).
