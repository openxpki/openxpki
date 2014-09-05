# OpenXPKI::Client::UI::Workflow::Translations
#
# This module enables translations for the stuff retrieved from old *.xml
# configuration. I suggest to keep and use this module until the *.xml is
# used by any people, but no longer.


package OpenXPKI::Client::UI::Workflow::Translations;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(&i18n_action);

sub i18n_action {
    my $name = shift;
    my $actions = {
        changemeta_load_data => 'I18N_OPENXPKI_WF_ACTION_CHANGEMETA_LOAD_DATA',
        changemeta_load_form => 'I18N_OPENXPKI_WF_ACTION_CHANGEMETA_LOAD_FORM',
        changemeta_persist => 'I18N_OPENXPKI_WF_ACTION_CHANGEMETA_PERSIST',
        changemeta_terminate => 'I18N_OPENXPKI_WF_ACTION_CHANGEMETA_TERMINATE',
        changemeta_update_context => 'I18N_OPENXPKI_WF_ACTION_CHANGEMETA_UPDATE_CONTEXT',
        create_csr => 'I18N_OPENXPKI_WF_ACTION_CREATE_CSR',
        crr_edit_request => 'I18N_OPENXPKI_WF_ACTION_CRR_EDIT_REQUEST',
        crr_flag_pending_notification_send => 'I18N_OPENXPKI_WF_ACTION_CRR_FLAG_PENDING_NOTIFICATION_SEND',
        crr_send_pending_notification => 'I18N_OPENXPKI_WF_ACTION_CRR_SEND_PENDING_NOTIFICATION',
        crr_update_request => 'I18N_OPENXPKI_WF_ACTION_CRR_UPDATE_REQUEST',
        csr_approve_csr => 'I18N_OPENXPKI_WF_ACTION_CSR_APPROVE_CSR',
        csr_ask_client_password => 'I18N_OPENXPKI_WF_ACTION_CSR_ASK_CLIENT_PASSWORD',
        csr_cancel_approvals => 'I18N_OPENXPKI_WF_ACTION_CSR_CANCEL_APPROVALS',
        csr_cleanup_key_password => 'I18N_OPENXPKI_WF_ACTION_CSR_CLEANUP_KEY_PASSWORD',
        csr_edit_cert_info => 'I18N_OPENXPKI_WF_ACTION_CSR_EDIT_CERT_INFO',
        csr_edit_san => 'I18N_OPENXPKI_WF_ACTION_CSR_EDIT_SAN',
        csr_edit_subject => 'I18N_OPENXPKI_WF_ACTION_CSR_EDIT_SUBJECT',
        csr_edit_validity => 'I18N_OPENXPKI_WF_ACTION_CSR_EDIT_VALIDITY',
        csr_eval_eligibility => 'I18N_OPENXPKI_WF_ACTION_CSR_EVAL_ELIGIBILITY',
        csr_flag_pending_notification_send => 'I18N_OPENXPKI_WF_ACTION_CSR_FLAG_PENDING_NOTIFICATION_SEND',
        csr_generate_key => 'I18N_OPENXPKI_WF_ACTION_CSR_GENERATE_KEY',
        csr_generate_key_client => 'I18N_OPENXPKI_WF_ACTION_CSR_GENERATE_KEY_CLIENT',
        csr_generate_pkcs10 => 'I18N_OPENXPKI_WF_ACTION_CSR_GENERATE_PKCS10',
        csr_load_key_password => 'I18N_OPENXPKI_WF_ACTION_CSR_LOAD_KEY_PASSWORD',
        csr_move_key_to_dp => 'I18N_OPENXPKI_WF_ACTION_CSR_MOVE_KEY_TO_DP',
        csr_notify_approval => 'I18N_OPENXPKI_WF_ACTION_CSR_NOTIFY_APPROVAL',
        csr_notify_issued => 'I18N_OPENXPKI_WF_ACTION_CSR_NOTIFY_ISSUED',
        csr_notify_rejected => 'I18N_OPENXPKI_WF_ACTION_CSR_NOTIFY_REJECTED',
        csr_persist_csr => 'I18N_OPENXPKI_WF_ACTION_CSR_PERSIST_CSR',
        csr_persist_key_password => 'I18N_OPENXPKI_WF_ACTION_CSR_PERSIST_KEY_PASSWORD',
        csr_persist_metadata => 'I18N_OPENXPKI_WF_ACTION_CSR_PERSIST_METADATA',
        csr_provide_server_key_params => 'I18N_OPENXPKI_WF_ACTION_CSR_PROVIDE_SERVER_KEY_PARAMS',
        csr_publish_certificate => 'I18N_OPENXPKI_WF_ACTION_CSR_PUBLISH_CERTIFICATE',
        csr_put_request_on_hold => 'I18N_OPENXPKI_WF_ACTION_CSR_PUT_REQUEST_ON_HOLD',
        csr_reject_request => 'I18N_OPENXPKI_WF_ACTION_CSR_REJECT_REQUEST',
        csr_release_on_hold => 'I18N_OPENXPKI_WF_ACTION_CSR_RELEASE_ON_HOLD',
        csr_rename_private_key => 'I18N_OPENXPKI_WF_ACTION_CSR_RENAME_PRIVATE_KEY',
        csr_render_subject => 'I18N_OPENXPKI_WF_ACTION_CSR_RENDER_SUBJECT',
        csr_retype_server_password => 'I18N_OPENXPKI_WF_ACTION_CSR_RETYPE_SERVER_PASSWORD',
        csr_select_profile => 'I18N_OPENXPKI_WF_ACTION_CSR_SELECT_PROFILE',
        csr_send_pending_notification => 'I18N_OPENXPKI_WF_ACTION_CSR_SEND_PENDING_NOTIFICATION',
        csr_submit => 'I18N_OPENXPKI_WF_ACTION_CSR_SUBMIT',
        csr_upload_pkcs10 => 'I18N_OPENXPKI_WF_ACTION_CSR_UPLOAD_PKCS10',
        enroll_add_authentication => 'I18N_OPENXPKI_WF_ACTION_ENROLL_ADD_AUTHENTICATION',
        enroll_allow_retry => 'I18N_OPENXPKI_WF_ACTION_ENROLL_ALLOW_RETRY',
        enroll_calc_approvals => 'I18N_OPENXPKI_WF_ACTION_ENROLL_CALC_APPROVALS',
        enroll_clear_approvals => 'I18N_OPENXPKI_WF_ACTION_ENROLL_CLEAR_APPROVALS',
        enroll_continue_issuance => 'I18N_OPENXPKI_WF_ACTION_ENROLL_CONTINUE_ISSUANCE',
        enroll_deny_authentication => 'I18N_OPENXPKI_WF_ACTION_ENROLL_DENY_AUTHENTICATION',
        enroll_disapprove => 'I18N_OPENXPKI_WF_ACTION_ENROLL_DISAPPROVE',
        enroll_eval_challenge => 'I18N_OPENXPKI_WF_ACTION_ENROLL_EVAL_CHALLENGE',
        enroll_eval_eligibility => 'I18N_OPENXPKI_WF_ACTION_ENROLL_EVAL_ELIGIBILITY',
        enroll_eval_signer_trust => 'I18N_OPENXPKI_WF_ACTION_ENROLL_EVAL_SIGNER_TRUST',
        enroll_extract_csr => 'I18N_OPENXPKI_WF_ACTION_ENROLL_EXTRACT_CSR',
        enroll_fail => 'I18N_OPENXPKI_WF_ACTION_ENROLL_FAIL',
        enroll_fetch_group_policy => 'I18N_OPENXPKI_WF_ACTION_ENROLL_FETCH_GROUP_POLICY',
        enroll_fork_publish => 'I18N_OPENXPKI_WF_ACTION_ENROLL_FORK_PUBLISH',
        enroll_get_cert_profile => 'I18N_OPENXPKI_WF_ACTION_ENROLL_GET_CERT_PROFILE',
        enroll_initialize => 'I18N_OPENXPKI_WF_ACTION_ENROLL_INITIALIZE',
        enroll_invalidate_challenge_pass => 'I18N_OPENXPKI_WF_ACTION_ENROLL_INVALIDATE_CHALLENGE_PASS',
        enroll_issue_cert => 'I18N_OPENXPKI_WF_ACTION_ENROLL_ISSUE_CERT',
        enroll_load_recent_certificate => 'I18N_OPENXPKI_WF_ACTION_ENROLL_LOAD_RECENT_CERTIFICATE',
        enroll_modify_metadata => 'I18N_OPENXPKI_WF_ACTION_ENROLL_MODIFY_METADATA',
        enroll_next_cert_to_revoke => 'I18N_OPENXPKI_WF_ACTION_ENROLL_NEXT_CERT_TO_REVOKE',
        enroll_notify_cert_issued => 'I18N_OPENXPKI_WF_ACTION_ENROLL_NOTIFY_CERT_ISSUED',
        enroll_notify_pending_approval => 'I18N_OPENXPKI_WF_ACTION_ENROLL_NOTIFY_PENDING_APPROVAL',
        enroll_null1 => 'I18N_OPENXPKI_WF_ACTION_ENROLL_NULL1',
        enroll_null2 => 'I18N_OPENXPKI_WF_ACTION_ENROLL_NULL2',
        enroll_persist_cert_metadata => 'I18N_OPENXPKI_WF_ACTION_ENROLL_PERSIST_CERT_METADATA',
        enroll_persist_csr => 'I18N_OPENXPKI_WF_ACTION_ENROLL_PERSIST_CSR',
        enroll_revoke_cert => 'I18N_OPENXPKI_WF_ACTION_ENROLL_REVOKE_CERT',
        enroll_revoke_cert_after_replace => 'I18N_OPENXPKI_WF_ACTION_ENROLL_REVOKE_CERT_AFTER_REPLACE',
        enroll_revoke_existing_certs => 'I18N_OPENXPKI_WF_ACTION_ENROLL_REVOKE_EXISTING_CERTS',
        generate_key => 'I18N_OPENXPKI_WF_ACTION_GENERATE_KEY',
        global_null => 'I18N_OPENXPKI_WF_ACTION_GLOBAL_NULL',
    };
    return $actions->{$name} || $name;
}
