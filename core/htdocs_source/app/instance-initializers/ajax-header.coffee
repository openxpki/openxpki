export initialize = (appInstance) ->
    # appInstance.inject('route', 'foo', 'service:foo');
    $.ajaxSetup
        beforeSend: (xhr) ->
            xhr.setRequestHeader "X-OPENXPKI-Client", "1"

export default {
    initialize
}
