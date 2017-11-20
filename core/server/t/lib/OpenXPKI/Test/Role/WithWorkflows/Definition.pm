package OpenXPKI::Test::Role::WithWorkflows::Definition;
use strict;
use warnings;

sub global_action {
    return {
        cancel => {
            class => "OpenXPKI::Server::Workflow::Activity::Noop",
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_GLOBAL_CANCEL_DESC",
            label => "I18N_OPENXPKI_UI_WORKFLOW_ACTION_GLOBAL_CANCEL_LABEL",
        },
        check_authorized_signer => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::EvaluateSignerTrust",
            param => {
                _map_rules =>
                    "[% context.interface %].[% context.server %].authorized_signer",
            },
        },
        check_for_revocation => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::NICE::CheckForRevocation",
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_NICE_CHECK_FOR_REVOCATION_DESC",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_NICE_CHECK_FOR_REVOCATION_LABEL",
            param => { retry_count => 10, retry_interval => "+0000000030" },
        },
        clear_error_code => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => { error_code => "" },
        },
        disconnect => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::Disconnect",
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_TOOLS_DISCONNECT_DESC",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_TOOLS_DISCONNECT_LABEL",
            param => {
                pause_info => "I18N_OPENXPKI_UI_WORKFLOW_MOVE_TO_BACKGROUND"
            },
        },
        get_next_cert_identifier => {
            class => "OpenXPKI::Server::Workflow::Activity::Tools::WFArray",
            input => ["tmp_queue"],
            param => {
                array_name  => "tmp_queue",
                context_key => "cert_identifier",
                function    => "shift",
            },
        },
        load_policy => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::LoadPolicy",
        },
        nice_fetch_certificate => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::NICE::FetchCertificate",
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_NICE_FETCH_CERTIFICATE_DESC",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_NICE_FETCH_CERTIFICATE_LABEL",
            param => { retry_count => 20, retry_interval => "+0000000003" },
        },
        nice_issue_certificate => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::NICE::IssueCertificate",
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_NICE_ISSUE_CERTIFICATE_DESC",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_NICE_ISSUE_CERTIFICATE_LABEL",
            param => {
                _map_cert_owner => "\$creator",
                pause_on_error  => 1,
                retry_count     => 10,
                retry_interval  => "+0000000005",
                retry_random    => 50,
            },
        },
        nice_issue_crl => {
            class => "OpenXPKI::Server::Workflow::Activity::NICE::IssueCRL",
            description => "I18N_OPENXPKI_UI_WORKFLOW_ACTION_ISSUE_CRL_DESC",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_ACTION_ISSUE_CRL_LABEL",
            param => { retry_count => 10, retry_interval => "+0000000030" },
        },
        nice_revoke_certificate => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::NICE::RevokeCertificate",
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_REVOKE_CERTIFICATE_DESC",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_ACTION_REVOKE_CERTIFICATE_LABEL",
            param => { retry_count => 10, retry_interval => "+0000000030" },
        },
        noop  => { class => "OpenXPKI::Server::Workflow::Activity::Noop" },
        noop2 => { class => "OpenXPKI::Server::Workflow::Activity::Noop" },
        noop3 => { class => "OpenXPKI::Server::Workflow::Activity::Noop" },
        relate_workflow => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::RelateWorkflow",
        },
        run_in_background => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::Disconnect",
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_STATE_CRL_ISSUE_BACKGROUND_DESC",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_STATE_CRL_ISSUE_BACKGROUND_LABEL",
            param => {
                pause_info =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CRL_ISSUE_BACKGROUND_REASON",
            },
        },
        set_error_export_private_key_failed => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => {
                error_code => "I18N_OPENXPKI_UI_EXPORT_PRIVATE_KEY_FAILED"
            },
        },
        set_error_not_approved => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => {
                error_code => "I18N_OPENXPKI_UI_ENROLLMENT_ERROR_NOT_APPROVED"
            },
        },
        set_error_not_authenticated => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => {
                error_code =>
                    "I18N_OPENXPKI_UI_ENROLLMENT_ERROR_NOT_AUTHENTICATED",
            },
        },
        set_error_policy_key_duplicate => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => {
                error_code =>
                    "I18N_OPENXPKI_UI_ENROLLMENT_ERROR_POLICY_KEY_DUPLICATE",
            },
        },
        set_error_policy_not_found => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => {
                error_code =>
                    "I18N_OPENXPKI_UI_ENROLLMENT_ERROR_POLICY_NOT_FOUND",
            },
        },
        set_error_policy_violated => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => {
                error_code =>
                    "I18N_OPENXPKI_UI_ENROLLMENT_ERROR_POLICY_VIOLATED",
            },
        },
        set_error_rejected => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => {
                error_code => "I18N_OPENXPKI_UI_ENROLLMENT_ERROR_REJECTED"
            },
        },
        set_error_search_has_no_matches => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param =>
                { error_code => "I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES" },
        },
        set_error_signer_expired => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => {
                error_code =>
                    "I18N_OPENXPKI_UI_ENROLLMENT_ERROR_SIGNER_EXPIRED",
            },
        },
        set_error_signer_not_authorized => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => {
                error_code =>
                    "I18N_OPENXPKI_UI_ENROLLMENT_ERROR_SIGNER_NOT_AUTHORIZED",
            },
        },
        set_error_signer_revoked => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetErrorCode",
            param => {
                error_code =>
                    "I18N_OPENXPKI_UI_ENROLLMENT_ERROR_SIGNER_REVOKED",
            },
        },
        skip  => { class => "OpenXPKI::Server::Workflow::Activity::Skip" },
        sleep => {
            class => "OpenXPKI::Server::Workflow::Activity::Sleep",
            label => "I18N_OPENXPKI_UI_WORKFLOW_ACTION_SLEEP_LABEL",
            param => { period => 15 },
        },
        uuid => {
            class =>
                "OpenXPKI::Server::Workflow::Activity::Tools::SetContext",
            param => { _map_uuid => "[% USE Utils %][% Utils.uuid() %]" },
        },
    };
}

sub global_condition {
    return {
        is_automated_request => {
            class => "Workflow::Condition::Evaluate",
            param => {
                test => "\$context->{flag_batch_mode} || \$context->{server}"
            },
        },
        is_batch_mode => {
            class => "Workflow::Condition::Evaluate",
            param => { test => "\$context->{flag_batch_mode}" },
        },
        is_cert_identifier_list_empty => {
            class => "OpenXPKI::Server::Workflow::Condition::WFArray",
            param => {
                array_name => "cert_identifier_list",
                condition  => "is_empty"
            },
        },
        is_certificate_owner => {
            class =>
                "OpenXPKI::Server::Workflow::Condition::IsCertificateOwner",
        },
        is_creator => {
            class => "OpenXPKI::Server::Workflow::Condition::WorkflowCreator",
        },
        is_false =>
            { class => "OpenXPKI::Server::Workflow::Condition::AlwaysFalse" },
        is_operator => {
            class => "OpenXPKI::Server::Workflow::Condition::HasRole",
            param => { roles => "CA Operator,RA Operator" },
        },
        is_signed_request => {
            class => "Workflow::Condition::Evaluate",
            param => { test => "\$context->{signer_cert}" },
        },
        is_tmp_queue_empty => {
            class => "OpenXPKI::Server::Workflow::Condition::WFArray",
            param => { array_name => "tmp_queue", condition => "is_empty" },
        },
        is_true =>
            { class => "OpenXPKI::Server::Workflow::Condition::AlwaysTrue" },
        run_in_background => {
            class => "Workflow::Condition::Evaluate",
            param => { test => "\$context->{run_in_background}" },
        },
    };
}

sub global_field {
    return {
        approval_count => {
            format   => "itemcnt",
            label    => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_APPROVALS_LABEL",
            name     => "approvals",
            required => 0,
            type     => "server",
        },
        cert_identifier => {
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_IDENTIFIER_DESC",
            label => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_IDENTIFIER_LABEL",
            name  => "cert_identifier",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_IDENTIFIER_PLACEHOLDER",
            required => 1,
            template =>
                "[% USE Certificate %][% value %]<br/>[% Certificate.body(value, 'subject') %]",
            tooltip =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_IDENTIFIER_TOOLTIP",
            type => "cert_identifier",
        },
        cert_info => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_INFO_DESC",
            format      => "cert_info",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_INFO_LABEL",
            name        => "cert_info",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_INFO_PLACEHOLDER",
            required => 0,
            template =>
                "[% IF key == \"requestor_email\" %] <a href=\"mailto:[% value %]\" target=\"_blank\">[% value %]</a> [% ELSE %] [% FILTER html %][% value %][% END %] [% END %]\n",
            tooltip => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_INFO_TOOLTIP",
            type    => "cert_info",
        },
        cert_profile => {
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_PROFILE_DESC",
            label => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_PROFILE_LABEL",
            name  => "cert_profile",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_PROFILE_PLACEHOLDER",
            required => 1,
            template => "[% USE Profile %][% Profile.name(value) %]",
            tooltip => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_PROFILE_TOOLTIP",
            type    => "select",
        },
        cert_subject => {
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_DESC",
            label => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_LABEL",
            name  => "cert_subject",
            type  => "cert_subject",
        },
        cert_subject_alt_name => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SAN_DESC",
            format      => "rawlist",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SAN_LABEL",
            name        => "cert_subject_alt_name",
            template =>
                "[% FOREACH san = value %][% san.0 %]:  [% IF san.0 == 'DNS' %] [% USE CheckDNS %][% CheckDNS.valid(san.1, '(FAIL)', '(ok)','(unknown)') %] [% ELSE %][% san.1 %][% END %] |  [% END %]\n",
            type => "cert_subject_alt_name",
        },
        check_policy_key_duplicate => {
            format => "rawlist",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_POLICY_CERTIFICATE_KEY_DUPLICATE",
            name => "check_policy_key_duplicate",
            template =>
                "[% USE Certificate %] [% IF value %] CN / Identifier | [% FOREACH identifier = value %] <a target=\"modal\" href=\"#certificate!detail!identifier![% identifier %]\"> [% Certificate.dn(identifier,'CN') %] / [% identifier %]</a>| [% END %] [% END %]\n",
        },
        check_policy_subject_duplicate => {
            format => "rawlist",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_POLICY_SUBJECT_DUPLICATE_LABEL",
            name => "check_policy_subject_duplicate",
            template =>
                "[% USE Certificate %] [% IF value %] Expiry / Identifier | [% FOREACH identifier = value %] <a target=\"modal\" href=\"#certificate!detail!identifier![% identifier %]\"> [% Certificate.notafter(identifier) %] / [% identifier %]</a>| [% END %] [% END %]\n",
        },
        comment => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_COMMENT_DESC",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_COMMENT_LABEL",
            name        => "comment",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_COMMENT_PLACEHOLDER",
            required => 0,
            tooltip  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_COMMENT_TOOLTIP",
            type     => "text",
        },
        csr_subject => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CSR_SUBJECT_DESC",
            label => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CSR_SUBJECT_LABEL",
            name  => "csr_subject",
            type  => "cert_subject",
        },
        email => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_EMAIL_DESC",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_EMAIL_LABEL",
            name        => "email",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_EMAIL_PLACEHOLDER",
            required => 0,
            tooltip  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_EMAIL_TOOLTIP",
            type     => "text",
        },
        error_code => {
            format   => "styled",
            label    => "I18N_OPENXPKI_UI_FIELD_ERROR_CODE",
            name     => "error_code",
            template => "failed:[% value %]",
        },
        flag_batch_mode => {
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_FLAG_BATCH_MODE_DESC",
            label => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_FLAG_BATCH_MODE_LABEL",
            name  => "flag_batch_mode",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_FLAG_BATCH_MODE_PLACEHOLDER",
            required => 0,
            tooltip =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_FLAG_BATCH_MODE_TOOLTIP",
            type => "server",
        },
        interface => {
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SERVER_INTERFACE_DESC",
            label => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SERVER_INTERFACE_LABEL",
            name  => "interface",
            required => 0,
            type     => "server",
        },
        invalidity_time => {
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_INVALIDITY_TIME_DESC",
            format => "timestamp",
            label  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_INVALIDITY_TIME_LABEL",
            name   => "invalidity_time",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_INVALIDITY_TIME_PLACEHOLDER",
            required => 0,
            tooltip =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_INVALIDITY_TIME_TOOLTIP",
            type => "datetime",
        },
        key_format => {
            description =>
                "I18N_OPENXPKI_UI_EXPORT_PRIVATEKEY_KEY_FORMAT_DESC",
            label  => "I18N_OPENXPKI_UI_EXPORT_PRIVATEKEY_KEY_FORMAT_LABEL",
            name   => "key_format",
            option => {
                item => [
                    "PKCS12",    "OPENSSL_PRIVKEY",
                    "PKCS8_PEM", "PKCS8_DER",
                    "JAVA_KEYSTORE",
                ],
                label => "I18N_OPENXPKI_UI_EXPORT_PRIVATEKEY_KEY_FORMAT",
            },
            required => 1,
            type     => "select",
        },
        notafter => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_NOTAFTER_DESC",
            format      => "timestamp",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_NOTAFTER_LABEL",
            name        => "notafter",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_NOTAFTER_PLACEHOLDER",
            required => 0,
            tooltip  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_NOTAFTER_TOOLTIP",
            type     => "datetime",
        },
        notbefore => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_NOTBEFORE_DESC",
            format      => "timestamp",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_NOTBEFORE_LABEL",
            name        => "notbefore",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_NOTBEFORE_PLACEHOLDER",
            required => 0,
            tooltip  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_NOTBEFORE_TOOLTIP",
            type     => "datetime",
        },
        password_retype => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PASSWORD_DESC",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PASSWORD_LABEL",
            name        => "_password",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PASSWORD_PLACEHOLDER",
            required => 1,
            tooltip  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PASSWORD_TOOLTIP",
            type     => "passwordverify",
        },
        pkcs10 => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PKCS10_DESC",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PKCS10_LABEL",
            name        => "pkcs10",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PKCS10_PLACEHOLDER",
            required => 1,
            tooltip  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PKCS10_TOOLTIP",
            type     => "uploadarea",
        },
        reason_code => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_REASON_CODE_DESC",
            label  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_REASON_CODE_LABEL",
            name   => "reason_code",
            option => {
                item => [
                    "unspecified",  "keyCompromise",
                    "CACompromise", "affiliationChanged",
                    "superseded",   "cessationOfOperation",
                ],
                label => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_REASON_CODE_OPTION",
            },
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_REASON_CODE_PLACEHOLDER",
            required => 1,
            tooltip  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_REASON_CODE_TOOLTIP",
            type     => "select",
        },
        renewal_cert_identifier => {
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_RENEWAL_CERT_IDENTIFIER_DESC",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_RENEWAL_CERT_IDENTIFIER_LABEL",
            name => "renewal_cert_identifier",
            placeholder =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_RENEWAL_CERT_IDENTIFIER_PLACEHOLDER",
            required => 0,
            template =>
                "[% IF value %][% USE Certificate %][% value %]<br/>[% Certificate.body(value, 'subject') %][% END %]",
            tooltip =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_RENEWAL_CERT_IDENTIFIER_TOOLTIP",
            type => "cert_identifier",
        },
        run_in_background => {
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_RUN_IN_BACKGROUND_DESC",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_RUN_IN_BACKGROUND_LABEL",
            name     => "run_in_background",
            required => 0,
            type     => "bool",
        },
        scep_tid => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SCEP_TID_DESC",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SCEP_TID_LABEL",
            name        => "scep_tid",
            required    => 1,
            type        => "text",
        },
        server => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SERVER_DESC",
            label       => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SERVER_LABEL",
            name        => "server",
            required    => 0,
            type        => "server",
        },
        signer_authorized => {
            format => "styled",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SIGNER_AUTHORIZED_LABEL",
            name => "signer_authorized",
            template =>
                "[% IF value %]I18N_OPENXPKI_UI_YES[% ELSE %]failed:I18N_OPENXPKI_UI_NO[% END %]",
        },
        signer_cert => {
            description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SIGNER_CERT_DESC",
            label    => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SIGNER_CERT_LABEL",
            name     => "signer_cert",
            required => 0,
            type     => "server",
        },
        signer_cert_identifier => {
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SIGNER_CERT_IDENTIFIER_LABEL",
            name => "signer_cert_identifier",
            type => "cert_identifier",
        },
        signer_revoked => {
            format => "styled",
            label  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SIGNER_REVOKED_LABEL",
            name   => "signer_revoked",
            template =>
                "[% IF value %]I18N_OPENXPKI_UI_YES[% ELSE %]failed:I18N_OPENXPKI_UI_NO[% END %]",
        },
        signer_signature_valid => {
            format => "styled",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SIGNER_SIGNATURE_VALID_LABEL",
            name => "signer_signature_valid",
            template =>
                "[% IF value %]I18N_OPENXPKI_UI_YES[% ELSE %]failed:I18N_OPENXPKI_UI_NO[% END %]",
        },
        signer_trusted => {
            format => "styled",
            label  => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SIGNER_TRUSTED_LABEL",
            name   => "signer_trusted",
            template =>
                "[% IF value %]I18N_OPENXPKI_UI_YES[% ELSE %]failed:I18N_OPENXPKI_UI_NO[% END %]",
        },
        signer_validity_ok => {
            format => "styled",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_FIELD_SIGNER_VALIDITY_OK_LABEL",
            name => "signer_validity_ok",
            template =>
                "[% IF value %]I18N_OPENXPKI_UI_YES[% ELSE %]failedI18N_OPENXPKI_UI_NO[% END %]",
        },
        tmp_queue      => { name => "tmp_queue", type => "text" },
        validity_years => {
            label  => "Validity",
            name   => "notafter",
            option => {
                item  => [ "1y", "2y", "3y" ],
                label => "I18N_OPENXPKI_UI_PROFILE_VALIDITY",
            },
            required => 1,
            type     => "select",
        },
    };
}

sub global_validator {
    return {
        cert_identifier_exists => {
            arg => ["\$cert_identifier"],
            class =>
                "OpenXPKI::Server::Workflow::Validator::CertIdentifierExists",
            param => { entity_only => 1, pki_realm => "_any" },
        },
        cert_info_parts => {
            arg =>
                [ "\$cert_profile", "\$cert_subject_style", "\$cert_info" ],
            class =>
                "OpenXPKI::Server::Workflow::Validator::CertSubjectFields",
            param => { basename => "cert_info", section => "info" },
        },
        cert_san_parts => {
            arg => [
                "\$cert_profile", "\$cert_subject_style",
                "\$cert_san_parts"
            ],
            class =>
                "OpenXPKI::Server::Workflow::Validator::CertSubjectFields",
            param => { basename => "cert_san_parts", section => "san" },
        },
        cert_subject_parts => {
            arg => [
                "\$cert_profile", "\$cert_subject_style",
                "\$cert_subject_parts",
            ],
            class =>
                "OpenXPKI::Server::Workflow::Validator::CertSubjectFields",
            param =>
                { basename => "cert_subject_parts", section => "subject" },
        },
        common_name_length => {
            arg => [
                "\$cert_profile", "\$cert_subject_style",
                "\$cert_subject_parts",
            ],
            class =>
                "OpenXPKI::Server::Workflow::Validator::CommonNameLength",
        },
        key_gen_params => {
            class =>
                "OpenXPKI::Server::Workflow::Validator::KeyGenerationParams",
        },
        key_params => {
            arg => [ "\$cert_profile", "\$pkcs10" ],
            class => "OpenXPKI::Server::Workflow::Validator::KeyParams",
        },
        key_reuse => {
            arg   => ["\$pkcs10"],
            class => "OpenXPKI::Server::Workflow::Validator::KeyReuse",
            param => { realm_only => 0 },
        },
        password_quality => {
            arg   => ["\$_password"],
            class => "OpenXPKI::Server::Workflow::Validator::PasswordQuality",
            param => {
                dictionary         => 4,
                following          => 3,
                following_keyboard => 3,
                groups             => 2,
                maxlen             => 64,
                minlen             => 8,
            },
        },
        pkcs10_valid => {
            arg   => ["\$pkcs10"],
            class => "OpenXPKI::Server::Workflow::Validator::PKCS10",
            param => { empty_subject => "0|1" },
        },
        reason_code => {
            arg   => ["\$reason_code"],
            class => "OpenXPKI::Server::Workflow::Validator::Regex",
            param => {
                error => "I18N_OPENXPKI_UI_REASON_CODE_NOT_SUPPORTED",
                regex =>
                    "\\A (unspecified|keyCompromise|CACompromise|affiliationChanged|superseded|cessationOfOperation) \\z",
            },
        },
        validity_window => {
            arg => [ "\$notbefore", "\$notafter" ],
            class => "OpenXPKI::Server::Workflow::Validator::ValidityWindow",
        },
    };
}

sub def_certificate_signing_request_v2 {
    return {
        acl => {
            "Anonymous"   => { creator => "self" },
            "CA Operator" => { creator => "any" },
            "RA Operator" => {
                context => 1,
                creator => "any",
                fail    => 1,
                history => 1,
                resume  => 1,
                techlog => 1,
                wakeup  => 1,
            },
            "System" => { creator => "self" },
            "User"   => { creator => "self" },
        },
        action => {
            approve_csr => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::Approve",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_APPROVE_CSR_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_APPROVE_CSR_LABEL",
                param => { check_creator => 0, multi_role_approval => 0 },
            },
            ask_client_password => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_ASK_CLIENT_PASSWORD_DESC",
                input => ["password_retype"],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_ASK_CLIENT_PASSWORD_LABEL",
                validator => ["global_password_quality"],
            },
            cancel_approvals => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::CancelApprovals",
            },
            check_policy_dns => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicyDNS",
                param => { check_san => "AC" },
            },
            check_policy_key_duplicate => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicyKeyDuplicate",
            },
            check_policy_subject_duplicate => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::CSR::CheckPolicySubjectDuplicate",
                param => { allow_renewal_period => "+0003" },
            },
            cleanup_key_password => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::Datapool::DeleteEntry",
                param => {
                    ds_key_param => "workflow_id",
                    ds_namespace => "workflow.csr.keygen_password",
                },
            },
            edit_cert_info => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetSource",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_CERT_INFO_DESC",
                input => ["cert_info"],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_CERT_INFO_LABEL",
                param => { source => "USER" },
                uihandle =>
                    "OpenXPKI::Client::UI::Handle::Profile::render_subject_form",
                validator => ["global_cert_info_parts"],
            },
            edit_san => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetSource",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_SAN_DESC",
                input => ["cert_san_parts"],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_SAN_LABEL",
                param => { source => "USER" },
                uihandle =>
                    "OpenXPKI::Client::UI::Handle::Profile::render_subject_form",
                validator => ["global_cert_san_parts"],
            },
            edit_subject => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetSource",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_SUBJECT_DESC",
                input => ["cert_subject_parts"],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_SUBJECT_LABEL",
                param => { source => "USER" },
                uihandle =>
                    "OpenXPKI::Client::UI::Handle::Profile::render_subject_form",
                validator => [
                    "global_cert_subject_parts",
                    "global_common_name_length"
                ],
            },
            edit_validity => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetSource",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_VALIDITY_DESC",
                input => [ "notbefore", "notafter" ],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_VALIDITY_LABEL",
                param     => { source => "USER" },
                validator => ["global_validity_window"],
            },
            enter_policy_violation_comment => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_POLICY_VIOLATION_COMMENT_DESC",
                input => ["policy_comment"],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_POLICY_VIOLATION_COMMENT_LABEL",
            },
            eval_eligibility =>
                { class => "OpenXPKI::Server::Workflow::Activity::Noop" },
            flag_pending_notification_send => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetContext",
                param => { flag_pending_notification_send => 1 },
            },
            generate_key => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::GenerateKey",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_GENERATE_KEY_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_GENERATE_KEY_LABEL",
                param => {
                    _map_enc_alg        => "\$enc_alg",
                    _map_key_alg        => "\$key_alg",
                    _map_key_gen_params => "\$key_gen_params",
                    _map_password       => "\$_password",
                },
            },
            generate_pkcs10 => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::CSR::GeneratePKCS10",
            },
            initialize_duplicate_key_check => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetContext",
                param => {
                    _map__request_subject_key_identifier =>
                        "[% USE PKCS10 %][% PKCS10.subject_key_identifier(context.pkcs10) %]",
                    check_policy_key_duplicate_certificate => "",
                    check_policy_key_duplicate_workflow    => "",
                },
            },
            load_key_password => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry",
                param => {
                    _map_key   => "\$workflow_id",
                    namespace  => "workflow.csr.keygen_password",
                    target_key => "_password",
                },
            },
            move_key_to_dp => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry",
                param => {
                    ds_encrypt             => 1,
                    ds_force               => 1,
                    ds_key_param           => "workflow_id",
                    ds_namespace           => "certificate.privatekey",
                    ds_unset_context_value => 1,
                    ds_value_param         => "private_key",
                },
            },
            notify_approval => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
#                class => "OpenXPKI::Server::Workflow::Activity::Tools::Notify",
#                param => { message => "csr_notify_approval" },
            },
            notify_issued => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
#                class => "OpenXPKI::Server::Workflow::Activity::Tools::Notify",
#                param => { message => "cert_issued" },
            },
            notify_rejected => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
#                class => "OpenXPKI::Server::Workflow::Activity::Tools::Notify",
#                param => { message => "csr_rejected" },
            },
            persist_csr => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::CSR::PersistRequest",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_PERSIST_CSR_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_PERSIST_CSR_LABEL",
            },
            persist_key_password => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry",
                param => {
                    ds_encrypt             => 1,
                    ds_force               => 1,
                    ds_key_param           => "workflow_id",
                    ds_namespace           => "workflow.csr.keygen_password",
                    ds_unset_context_value => 1,
                    ds_value_param         => "_password",
                },
            },
            persist_metadata => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::PersistCertificateMetadata",
            },
            provide_server_key_params => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetSource",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_PROVIDE_SERVER_KEY_PARAMS_DESC",
                input => [
                    "key_alg",        "enc_alg",
                    "key_gen_params", "password_type",
                    "csr_type",
                ],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_PROVIDE_SERVER_KEY_PARAMS_LABEL",
                param => { source => "USER" },
                uihandle =>
                    "OpenXPKI::Client::UI::Handle::Profile::render_key_select",
                validator => ["global_key_gen_params"],
            },
            publish_certificate => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
#                class => "OpenXPKI::Server::Workflow::Activity::Tools::TriggerCertificatePublish",
            },
            put_request_on_hold => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_PUT_REQUEST_ON_HOLD_DESC",
                input => ["onhold_comment"],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_PUT_REQUEST_ON_HOLD_LABEL",
            },
            reject_request => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_REJECT_REQUEST_DESC",
                input => ["reject_comment"],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_REJECT_REQUEST_LABEL",
            },
            release_on_hold => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_RELEASE_ON_HOLD_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_RELEASE_ON_HOLD_LABEL",
            },
            remove_public_key_identifier => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetAttribute",
                param => { subject_key_identifier => "" },
            },
            rename_private_key => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::Datapool::ModifyEntry",
                param => {
                    ds_key       => "\$workflow_id",
                    ds_namespace => "certificate.privatekey",
                    ds_newkey    => "\$cert_identifier",
                },
            },
            render_subject => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::RenderSubject",
            },
            retype_server_password => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_RETYPE_SERVER_PASSWORD_DESC",
                input => ["password_retype"],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_RETYPE_SERVER_PASSWORD_LABEL",
                uihandle =>
                    "OpenXPKI::Client::UI::Handle::Profile::render_server_password",
            },
            search_key_duplicate_certificate => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SearchCertificates",
                param => {
                    _map_subject_key_identifier =>
                        "\$_request_subject_key_identifier",
                    realm      => "_any",
                    target_key => "check_policy_key_duplicate_certificate",
                },
            },
            search_key_duplicate_workflow => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SearchWorkflow",
                param => {
                    _map_attr_subject_key_identifier =>
                        "\$_request_subject_key_identifier",
                    mode       => "list",
                    realm      => "_any",
                    target_key => "check_policy_key_duplicate_workflow",
                },
            },
            select_profile => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetSource",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_SELECT_PROFILE_DESC",
                input => [ "cert_profile", "cert_subject_style" ],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_SELECT_PROFILE_LABEL",
                param => { source => "USER" },
                uihandle =>
                    "OpenXPKI::Client::UI::Handle::Profile::render_profile_select",
            },
            send_pending_notification => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
#                class => "OpenXPKI::Server::Workflow::Activity::Tools::Notify",
#                param => { message => "csr_created" },
            },
            set_public_key_identifier => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetAttribute",
                param => {
                    _map_subject_key_identifier =>
                        "\$_request_subject_key_identifier",
                },
            },
            set_workflow_attributes => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::SetAttribute",
                param => {
                    _map_cert_subject => "\$cert_subject",
                    _map_requestor =>
                        "[% context.cert_info.requestor_email %]",
                },
            },
            submit => {
                class => "OpenXPKI::Server::Workflow::Activity::Noop",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_SUBMIT_DESC",
                label => "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_SUBMIT_LABEL",
            },
            upload_pkcs10 => {
                class =>
                    "OpenXPKI::Server::Workflow::Activity::Tools::ParsePKCS10",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_UPLOAD_PKCS10_DESC",
                input => [ "pkcs10", "csr_type" ],
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_UPLOAD_PKCS10_LABEL",
                validator => [ "global_pkcs10_valid", "global_key_params" ],
            },
        },
        condition => {
            acl_can_approve => {
                class => "Workflow::Condition::LazyAND",
                param => { condition1 => "global_is_operator" },
            },
            acl_can_reject => {
                class => "Workflow::Condition::LazyAND",
                param => { condition1 => "global_is_operator" },
            },
            can_use_client_key => {
                class =>
                    "OpenXPKI::Server::Workflow::Condition::KeyGenerationMode",
                param => { generate => "client" },
            },
            can_use_server_key => {
                class =>
                    "OpenXPKI::Server::Workflow::Condition::KeyGenerationMode",
                param => { generate => "server" },
            },
            has_duplicate_key_certificate => {
                class => "Workflow::Condition::Evaluate",
                param => {
                    test =>
                        "\$context->{check_policy_key_duplicate_certificate}"
                },
            },
            has_duplicate_key_workflow => {
                class => "Workflow::Condition::Evaluate",
                param => {
                    test => "\$context->{check_policy_key_duplicate_workflow}"
                },
            },
            has_password_in_context => {
                class => "Workflow::Condition::Evaluate",
                param => { test => "\$context->{_password}" },
            },
            has_policy_violation => {
                class => "Workflow::Condition::Evaluate",
                param => {
                    test =>
                        "\$context->{check_policy_dns} || \$context->{check_policy_subject_duplicate} || \$context->{check_policy_key_duplicate}",
                },
            },
            is_approved => {
                class => "OpenXPKI::Server::Workflow::Condition::Approved",
                param => { role => "RA Operator" },
            },
            is_certificate_issued => {
                class =>
                    "OpenXPKI::Server::Workflow::Condition::NICE::IsCertificateIssued",
            },
            key_password_server => {
                class => "Workflow::Condition::Evaluate",
                param => { test => "\$context->{password_type} eq 'server'" },
            },
            pending_notification_send => {
                class => "Workflow::Condition::Evaluate",
                param =>
                    { test => "\$context->{flag_pending_notification_send}" },
            },
            profile_has_info_section => {
                class =>
                    "OpenXPKI::Server::Workflow::Condition::Connector::Exists",
                param => {
                    _map_config_path =>
                        "profile.[% context.cert_profile %].style.[% context.cert_subject_style %].ui.info",
                },
            },
            profile_has_san_section => {
                class =>
                    "OpenXPKI::Server::Workflow::Condition::Connector::Exists",
                param => {
                    _map_config_path =>
                        "profile.[% context.cert_profile %].style.[% context.cert_subject_style %].ui.san",
                },
            },
            server_key_generation => {
                class => "Workflow::Condition::Evaluate",
                param => { test => "defined \$context->{key_gen_params}" },
            },
        },
        field => {
            cert_profile => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_PROFILE_DESC",
                label => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_PROFILE_LABEL",
                name  => "cert_profile",
                placeholder =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_PROFILE_PLACEHOLDER",
                required => 1,
                template => "[% USE Profile %][% Profile.name(value) %]",
                tooltip =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_PROFILE_TOOLTIP",
                type => "select",
            },
            cert_san_parts => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SAN_PARTS_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SAN_PARTS_LABEL",
                name => "cert_san_parts",
                placeholder =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SAN_PARTS_PLACEHOLDER",
                required => 0,
                tooltip =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SAN_PARTS_TOOLTIP",
                type => "cert_san",
            },
            cert_subject_parts => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_PARTS_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_PARTS_LABEL",
                name => "cert_subject_parts",
                placeholder =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_PARTS_PLACEHOLDER",
                required => 0,
                tooltip =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_PARTS_TOOLTIP",
                type => "cert_subject",
            },
            cert_subject_style => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_STYLE_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_STYLE_LABEL",
                name => "cert_subject_style",
                placeholder =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_STYLE_PLACEHOLDER",
                required => 0,
                tooltip =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CERT_SUBJECT_STYLE_TOOLTIP",
                type => "select",
            },
            check_policy_dns => {
                format => "rawlist",
                label  => "Failed Policy Check DNS",
                name   => "check_policy_dns",
                template =>
                    "[% IF value %] [% USE CheckDNS %] [% FOREACH fqdn = value %] [% CheckDNS.valid(fqdn, '(FAIL)', '(ok)','(unknown)') %] [% END %] [% END %]\n",
            },
            csr_type => {
                default => "pkcs10",
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CSR_TYPE_DESC",
                label => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CSR_TYPE_LABEL",
                name  => "csr_type",
                placeholder =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CSR_TYPE_PLACEHOLDER",
                required => 0,
                tooltip => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_CSR_TYPE_TOOLTIP",
                type    => "hidden",
            },
            enc_alg => {
                description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_ENC_ALG_DESC",
                label    => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_ENC_ALG_LABEL",
                name     => "enc_alg",
                required => 1,
                type     => "select",
            },
            key_alg => {
                description => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_KEY_ALG_DESC",
                label    => "I18N_OPENXPKI_UI_WORKFLOW_FIELD_KEY_ALG_LABEL",
                name     => "key_alg",
                required => 1,
                type     => "select",
            },
            key_duplicate_certificate => {
                format => "rawlist",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_POLICY_CERTIFICATE_KEY_DUPLICATE",
                name => "check_policy_key_duplicate_certificate",
                template =>
                    "[% USE Certificate %] [% IF value %] I18N_OPENXPKI_UI_CERTIFICATE_COMMON_NAME / I18N_OPENXPKI_UI_CERTIFICATE_IDENTIFIER / I18N_OPENXPKI_UI_PKI_REALM_LABEL | [% FOREACH identifier = value %] <a target=\"modal\" href=\"#certificate!detail!identifier![% identifier %]\"> [% Certificate.dn(identifier,'CN') %] / [% identifier %] / [% Certificate.realm(identifier) %]</a>| [% END %] [% END %]\n",
            },
            key_duplicate_workflow_id => {
                format => "rawlist",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_POLICY_WORKFLOW_ID_KEY_DUPLICATE_ID",
                name => "check_policy_key_duplicate_workflow",
                template =>
                    "[% USE Workflow %] [% IF value %] I18N_OPENXPKI_UI_WORKFLOW_ID_LABEL / I18N_OPENXPKI_UI_WORKFLOW_CREATOR_LABEL / I18N_OPENXPKI_UI_PKI_REALM_LABEL | [% FOREACH wf_id = value %] [% wf_id %] / [% Workflow.creator(wf_id) %] / [% Workflow.realm(wf_id) %] | [% END %] [% END %]\n",
            },
            key_gen_params => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_KEY_GEN_PARAMS_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_KEY_GEN_PARAMS_LABEL",
                name     => "key_gen_params",
                required => 1,
                type     => "text",
            },
            onhold_comment => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_ONHOLD_COMMENT_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_ONHOLD_COMMENT_LABEL",
                name => "onhold_comment",
                placeholder =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_ONHOLD_COMMENT_PLACEHOLDER",
                required => 1,
                tooltip =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_ONHOLD_COMMENT_TOOLTIP",
                type => "textarea",
            },
            password_type => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PASSWORD_TYPE_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PASSWORD_TYPE_LABEL",
                name   => "password_type",
                option => {
                    item  => [ "server", "client" ],
                    label => "I18N_OPENXPKI_UI_KEY_ENC_PASSWORD",
                },
                placeholder =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PASSWORD_TYPE_PLACEHOLDER",
                required => 1,
                tooltip =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_PASSWORD_TYPE_TOOLTIP",
                type => "select",
            },
            policy_comment => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_POLICY_COMMENT_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_POLICY_COMMENT_LABEL",
                name => "policy_comment",
                placeholder =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_POLICY_COMMENT_PLACEHOLDER",
                required => 1,
                type     => "textarea",
            },
            reject_comment => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_REJECT_COMMENT_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_REJECT_COMMENT_LABEL",
                name => "reject_comment",
                placeholder =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_REJECT_COMMENT_PLACEHOLDER",
                required => 0,
                tooltip =>
                    "I18N_OPENXPKI_UI_WORKFLOW_FIELD_REJECT_COMMENT_TOOLTIP",
                type => "text",
            },
        },
        head => {
            description =>
                "I18N_OPENXPKI_UI_WORKFLOW_TYPE_CERTIFICATE_SIGNING_REQUEST_DESC",
            label =>
                "I18N_OPENXPKI_UI_WORKFLOW_TYPE_CERTIFICATE_SIGNING_REQUEST_LABEL",
            prefix => "csr",
        },
        state => {
            APPROVED => {
                action => [
                    "load_key_password > KEY_PASSWORD_LOADED ? server_key_generation",
                    "global_noop > REQUEST_COMPLETE ?  !server_key_generation",
                ],
                autorun => 1,
            },
            BUILD_SUBJECT => {
                action => [
                    "render_subject set_workflow_attributes check_policy_dns check_policy_subject_duplicate check_policy_key_duplicate > SUBJECT_COMPLETE",
                ],
                autorun => 1,
            },
            CANCELED => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_CANCELED_DESC",
                label => "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_CANCELED_LABEL",
                output => [ "cert_subject", "cert_profile", "cert_info" ],
            },
            CHECK_APPROVALS => {
                action => [
                    "global_noop > NOTIFY_APPROVAL ? is_approved",
                    "global_noop2 > NOTIFY_CSR_PENDING ?  !is_approved",
                ],
                autorun => 1,
            },
            CHECK_DUPLICATE_KEY_POLICY => {
                action => [
                    "global_noop > KEY_DUPLICATE_ERROR_CERTIFICATE ? has_duplicate_key_certificate",
                    "global_noop2 > KEY_DUPLICATE_ERROR_WORKFLOW ? has_duplicate_key_workflow !has_duplicate_key_certificate",
                    "global_noop3 > ENTER_SUBJECT ? !has_duplicate_key_workflow !has_duplicate_key_certificate",
                ],
                autorun => 1,
            },
            CHECK_FOR_DUPLICATE_KEY => {
                action =>
                    "initialize_duplicate_key_check set_public_key_identifier search_key_duplicate_workflow search_key_duplicate_certificate > CHECK_DUPLICATE_KEY_POLICY",
                autorun => 1,
            },
            CHECK_POLICY_VIOLATION => {
                action => [
                    "global_noop > PENDING ? !has_policy_violation",
                    "global_noop2 > PENDING_POLICY_VIOLATION ? has_policy_violation",
                ],
                autorun => 1,
            },
            CLEANUP_BEFORE_CANCEL => {
                action  => "remove_public_key_identifier > CANCELED",
                autorun => 1
            },
            CLEANUP_KEY_PASSWORD => {
                action  => ["cleanup_key_password > NICE_SEND_NOTIFICATION"],
                autorun => 1,
            },
            ENTER_CERT_INFO => {
                action => [
                    "edit_cert_info > BUILD_SUBJECT ? profile_has_info_section",
                    "global_skip  > BUILD_SUBJECT ? !profile_has_info_section",
                ],
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_ENTER_CERT_INFO_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_ENTER_CERT_INFO_LABEL",
            },
            ENTER_KEY_PASSWORD => {
                action => [
                    "retype_server_password > PERSIST_KEY_PASSWORD ? key_password_server",
                    "ask_client_password > PERSIST_KEY_PASSWORD ? !key_password_server",
                ],
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_ENTER_KEY_PASSWORD_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_ENTER_KEY_PASSWORD_LABEL",
            },
            ENTER_SAN => {
                action => [
                    "edit_san > ENTER_CERT_INFO ? profile_has_san_section",
                    "global_skip > ENTER_CERT_INFO ? !profile_has_san_section",
                ],
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_ENTER_SAN_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_ENTER_SAN_LABEL",
            },
            ENTER_SUBJECT => {
                action => ["edit_subject > ENTER_SAN"],
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_ENTER_SUBJECT_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_ENTER_SUBJECT_LABEL",
            },
            EVAL_ELIGIBILITY => {
                action  => ["eval_eligibility > CHECK_APPROVALS"],
                autorun => 1
            },
            FAILURE => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_FAILURE_DESC",
                label => "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_FAILURE_LABEL",
            },
            FLAG_NOTIFY_SEND => {
                action => [
                    "flag_pending_notification_send > CHECK_POLICY_VIOLATION"
                ],
                autorun => 1,
            },
            INITIAL => {
                action => ["select_profile > SETUP_REQUEST_TYPE"],
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_INITIAL_DESC",
                label => "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_INITIAL_LABEL",
            },
            KEY_DUPLICATE_ERROR_CERTIFICATE => {
                action => [
                    "upload_pkcs10 > CHECK_FOR_DUPLICATE_KEY",
                    "global_cancel > CLEANUP_BEFORE_CANCEL",
                ],
                button => {
                    global_cancel => { format => "failure" },
                    upload_pkcs10 => { format => "expected" },
                },
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_KEY_DUPLICATE_ERROR_CERTIFICATE_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_KEY_DUPLICATE_ERROR_CERTIFICATE_LABEL",
                output => ["key_duplicate_certificate"],
            },
            KEY_DUPLICATE_ERROR_WORKFLOW => {
                action => [
                    "upload_pkcs10 > CHECK_FOR_DUPLICATE_KEY",
                    "global_noop > CHECK_FOR_DUPLICATE_KEY",
                    "global_cancel > CLEANUP_BEFORE_CANCEL",
                ],
                button => {
                    global_cancel => { format => "failure" },
                    global_noop   => {
                        format => "alternative",
                        label =>
                            "I18N_OPENXPKI_UI_WORKFLOW_BUTTON_POLICY_VIOLATION_RECHECK_LABEL",
                    },
                    upload_pkcs10 => { format => "expected" },
                },
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_KEY_DUPLICATE_ERROR_WORKFLOW_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_KEY_DUPLICATE_ERROR_WORKFLOW_LABEL",
                output => ["key_duplicate_workflow_id"],
            },
            KEY_GENERATED => {
                action  => ["generate_pkcs10 > PKCS10_GENERATED"],
                autorun => 1
            },
            KEY_PASSWORD_LOADED => {
                action =>
                    ["generate_key > KEY_GENERATED ? server_key_generation"],
                autorun => 1,
            },
            NICE_CERTIFICATE_ISSUED => {
                action  => ["persist_metadata > NICE_METADATA_PERSISTED"],
                autorun => 1,
            },
            NICE_ISSUE_CERTIFICATE => {
                action => [
                    "global_nice_issue_certificate > NICE_PICKUP_CERTIFICATE"
                ],
                autorun => 1,
            },
            NICE_METADATA_PERSISTED => {
                action => [
                    "rename_private_key > CLEANUP_KEY_PASSWORD ? server_key_generation",
                    "global_noop > NICE_SEND_NOTIFICATION ?  !server_key_generation",
                ],
                autorun => 1,
            },
            NICE_PICKUP_CERTIFICATE => {
                action => [
                    "global_noop > NICE_CERTIFICATE_ISSUED ? is_certificate_issued",
                    "global_nice_fetch_certificate > NICE_CERTIFICATE_ISSUED ? !is_certificate_issued",
                ],
                autorun => 1,
            },
            NICE_PUBLISH_CERTIFICATE =>
                { action => ["publish_certificate > SUCCESS"], autorun => 1 },
            NICE_SEND_NOTIFICATION => {
                action  => ["notify_issued > NICE_PUBLISH_CERTIFICATE"],
                autorun => 1,
            },
            NOTIFY_APPROVAL =>
                { action => ["notify_approval > APPROVED"], autorun => 1 },
            NOTIFY_CSR_PENDING => {
                action => [
                    "global_noop > CHECK_POLICY_VIOLATION ? pending_notification_send",
                    "send_pending_notification > CHECK_POLICY_VIOLATION ?  !pending_notification_send",
                ],
                autorun => 1,
            },
            NOTIFY_REJECT =>
                { action => ["notify_rejected > REJECTED"], autorun => 1 },
            ONHOLD => {
                action => [
                    "release_on_hold > CHECK_POLICY_VIOLATION ? acl_can_approve",
                    "put_request_on_hold > ONHOLD ? acl_can_approve",
                ],
                button => {
                    put_request_on_hold => {
                        format => "alternative",
                        label =>
                            "I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_ON_HOLD_LABEL",
                    },
                    release_on_hold => { format => "expected" },
                },
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_ONHOLD_DESC",
                label  => "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_ONHOLD_LABEL",
                output => [
                    "onhold_comment",
                    "cert_subject",
                    "cert_subject_alt_name",
                    "policy_comment",
                    "check_policy_dns",
                    "check_policy_subject_duplicate",
                    "check_policy_key_duplicate",
                    "notbefore",
                    "notafter",
                    "cert_profile",
                    "cert_info",
                ],
            },
            PENDING => {
                action => [
                    "edit_subject > UPDATE_REQUEST ? acl_can_approve",
                    "edit_san > UPDATE_REQUEST ? profile_has_san_section acl_can_approve",
                    "edit_cert_info > UPDATE_REQUEST ? profile_has_info_section acl_can_approve",
                    "edit_validity > UPDATE_REQUEST  ? acl_can_approve",
                    "global_noop > RUN_POLICY_CHECKS ? acl_can_approve",
                    "approve_csr > CHECK_APPROVALS ? acl_can_approve",
                    "put_request_on_hold > ONHOLD ? acl_can_approve",
                    "reject_request > NOTIFY_REJECT ? acl_can_reject",
                ],
                button => {
                    approve_csr    => { format => "expected" },
                    edit_cert_info => { format => "optional" },
                    edit_san       => { format => "optional" },
                    edit_subject   => { format => "optional" },
                    edit_validity  => { format => "optional" },
                    global_noop    => {
                        format => "alternative",
                        label =>
                            "I18N_OPENXPKI_UI_WORKFLOW_BUTTON_POLICY_VIOLATION_RECHECK_LABEL",
                    },
                    put_request_on_hold => { format => "alternative" },
                    reject_request      => { format => "failure" },
                },
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_PENDING_DESC",
                label  => "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_PENDING_LABEL",
                output => [
                    "cert_subject",
                    "cert_subject_alt_name",
                    "policy_comment",
                    "check_policy_dns",
                    "check_policy_subject_duplicate",
                    "check_policy_key_duplicate",
                    "notbefore",
                    "notafter",
                    "cert_profile",
                    "cert_info",
                ],
            },
            PENDING_POLICY_VIOLATION => {
                action => [
                    "edit_subject > UPDATE_REQUEST ? acl_can_approve",
                    "edit_san > UPDATE_REQUEST ? profile_has_san_section acl_can_approve",
                    "edit_cert_info > UPDATE_REQUEST ? profile_has_info_section acl_can_approve",
                    "edit_validity > UPDATE_REQUEST  ? acl_can_approve",
                    "global_noop > RUN_POLICY_CHECKS ? has_policy_violation acl_can_approve",
                    "approve_csr > CHECK_APPROVALS ? acl_can_approve",
                    "put_request_on_hold > ONHOLD ? acl_can_approve",
                    "reject_request > NOTIFY_REJECT ? acl_can_reject",
                ],
                button => {
                    approve_csr    => { format => "alternative" },
                    edit_cert_info => { format => "optional" },
                    edit_san       => { format => "optional" },
                    edit_subject   => { format => "optional" },
                    edit_validity  => { format => "optional" },
                    global_noop    => {
                        format => "expected",
                        label =>
                            "I18N_OPENXPKI_UI_WORKFLOW_BUTTON_POLICY_VIOLATION_RECHECK_LABEL",
                    },
                    put_request_on_hold => { format => "alternative" },
                    reject_request      => { format => "failure" },
                },
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_POLICY_VIOLATION_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_POLICY_VIOLATION_LABEL",
                output => [
                    "cert_subject",
                    "cert_subject_alt_name",
                    "policy_comment",
                    "check_policy_dns",
                    "check_policy_subject_duplicate",
                    "check_policy_key_duplicate",
                    "notbefore",
                    "notafter",
                    "cert_profile",
                    "cert_info",
                ],
            },
            PERSIST_KEY_PASSWORD => {
                action => [
                    "persist_key_password > ENTER_SUBJECT ? has_password_in_context",
                    "global_noop > ENTER_KEY_PASSWORD ? !has_password_in_context",
                ],
                autorun => 1,
            },
            PKCS10_GENERATED => {
                action  => ["move_key_to_dp > REQUEST_COMPLETE"],
                autorun => 1
            },
            REJECTED => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_REJECTED_DESC",
                label => "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_REJECTED_LABEL",
                output => [
                    "cert_subject", "cert_profile",
                    "cert_info",    "reject_comment"
                ],
            },
            REQUEST_COMPLETE => {
                action  => ["persist_csr > NICE_ISSUE_CERTIFICATE"],
                autorun => 1
            },
            RUN_POLICY_CHECKS => {
                action => [
                    "check_policy_dns check_policy_subject_duplicate check_policy_key_duplicate > CHECK_POLICY_VIOLATION",
                ],
                autorun => 1,
            },
            SETUP_REQUEST_TYPE => {
                action => [
                    "provide_server_key_params > ENTER_KEY_PASSWORD ? can_use_server_key",
                    "upload_pkcs10 > CHECK_FOR_DUPLICATE_KEY ? can_use_client_key",
                    "select_profile > SETUP_REQUEST_TYPE",
                ],
                button => {
                    _head =>
                        "I18N_OPENXPKI_UI_WORKFLOW_HINT_SELECT_TO_PROCEED",
                    provide_server_key_params => {
                        description =>
                            "I18N_OPENXPKI_UI_WORKFLOW_HINT_SERVER_KEY_PARAMS",
                        format => "expected",
                    },
                    select_profile => {
                        description =>
                            "I18N_OPENXPKI_UI_WORKFLOW_HINT_CHANGE_PROFILE",
                        format => "optional",
                        label =>
                            "I18N_OPENXPKI_UI_WORKFLOW_HINT_CHANGE_PROFILE_LABEL",
                    },
                    upload_pkcs10 => {
                        description =>
                            "I18N_OPENXPKI_UI_WORKFLOW_HINT_PKCS10_UPLOAD",
                        format => "expected",
                    },
                },
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_SETUP_REQUEST_TYPE_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_SETUP_REQUEST_TYPE_LABEL",
                output => [ "cert_profile", "cert_subject_style" ],
            },
            SUBJECT_COMPLETE => {
                action => [
                    "submit > EVAL_ELIGIBILITY ? !has_policy_violation",
                    "enter_policy_violation_comment send_pending_notification > PENDING_POLICY_VIOLATION ? has_policy_violation",
                    "global_noop > BUILD_SUBJECT ? has_policy_violation",
                    "edit_subject > BUILD_SUBJECT",
                    "edit_san > BUILD_SUBJECT ? profile_has_san_section",
                    "edit_cert_info > BUILD_SUBJECT ? profile_has_info_section",
                    "global_cancel > CLEANUP_BEFORE_CANCEL",
                ],
                button => {
                    edit_cert_info => { format => "optional" },
                    edit_san       => { format => "optional" },
                    edit_subject   => { format => "optional" },
                    enter_policy_violation_comment => {
                        format => "alternative",
                        label =>
                            "I18N_OPENXPKI_UI_WORKFLOW_BUTTON_POLICY_VIOLATION_PROCEED_LABEL",
                    },
                    global_cancel => { format => "failure" },
                    global_noop   => {
                        format => "expected",
                        label =>
                            "I18N_OPENXPKI_UI_WORKFLOW_BUTTON_POLICY_VIOLATION_RECHECK_LABEL",
                    },
                    submit => { format => "expected" },
                },
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_SUBJECT_COMPLETE_DESC",
                label =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_SUBJECT_COMPLETE_LABEL",
                output => [
                    "cert_subject",
                    "cert_subject_alt_name",
                    "check_policy_dns",
                    "check_policy_subject_duplicate",
                    "check_policy_key_duplicate",
                    "cert_profile",
                    "cert_info",
                ],
            },
            SUCCESS => {
                description =>
                    "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_SUCCESS_DESC",
                label  => "I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_SUCCESS_LABEL",
                output => [
                    "cert_identifier",       "cert_subject",
                    "cert_subject_alt_name", "notbefore",
                    "notafter",              "cert_profile",
                    "cert_info",
                ],
            },
            UPDATE_REQUEST => {
                action => [
                    "cancel_approvals render_subject set_workflow_attributes > RUN_POLICY_CHECKS",
                ],
                autorun => 1,
            },
        },
    };
}

1;
