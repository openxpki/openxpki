`import Em from "vendor/ember"`

Component = Em.Component.extend
    textTypes: [
        "application/pkcs8"
        "application/pkcs10"
        "application/x-x509-ca-cert"
        "application/x-x509-user-cert"
        "application/x-pkcs7-crl"
        "application/x-pem-file"
        "application/x-pkcs12"
    ]

    canReadFile: (->
        !!window.FileReader
        false
    ).property()

    change: (evt) ->
        return if evt.target.type isnt "file"

        if @get "canReadFile"
            reader = new FileReader()
            reader.onload = (e) =>
                @$().find("textarea").val reader.result

            type = evt.target.files[0].type
            if /text\//.test(type) or type in @textTypes
                reader.readAsText(evt.target.files[0])
            else
                reader.readAsDataURL(evt.target.files[0])
        else
            iframe = @$().find "iframe"
            window.legacyUploadDone = =>
                resultStr = frames['upload_target'].document.body.innerText
                res = JSON.parse resultStr
                @$().find("textarea").val res.result

            file = @$().find "input[type=file]"
            clone = file.clone()

            url = @container.lookup("controller:config").get ".url"

            form = $ """
                <form method='post'
                      enctype='multipart/form-data'
                      action='#{url}'
                      target='upload_target'>
                    <input type="hidden" name="action" value="plain!upload">
                </form>
            """
            form.append clone
            form.appendTo "body"
            form.submit()
            form.remove()

`export default Component`
