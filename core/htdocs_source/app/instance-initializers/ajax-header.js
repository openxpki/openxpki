export const initialize = function(appInstance) {
    // appInstance.inject('route', 'foo', 'service:foo');
    return $.ajaxSetup({
        beforeSend: function(xhr) {
            return xhr.setRequestHeader("X-OPENXPKI-Client", "1");
        }
    });
};

export default {initialize};