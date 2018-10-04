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

    cols: Em.computed "content.textAreaSize.width", ->
        @get("content.textAreaSize.width") || 150

    rows: Em.computed "content.textAreaSize.height", ->
        @get("content.textAreaSize.height") || 10

    canReadFile: Em.computed ->
        !!window.FileReader
        false

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
            window.legacyUploadDone = =>
                body = frames['upload_target'].document.body
                resultStr = body.textContent || body.innerText
                res = JSON.parse resultStr
                @set "content.value", res.result

            file = @$().find "input[type=file]"
            fence = $("<div></div>")
            fence.insertAfter file

            url = @container.lookup("controller:config").get "url"
            rtoken = @container.lookup("route:openxpki").get "source.rtoken"

            form = $ """
                <form method='post'
                      enctype='multipart/form-data'
                      action='#{url}'
                      target='upload_target'>
                    <input type="hidden" name="action" value="plain!upload">
                    <input type="hidden" name="_rtoken" value="#{rtoken}">
                </form>
            """
            form.append file
            form.appendTo "body"
            form.submit()
            file.insertAfter fence
            fence.remove()
            form.remove()

`export default Component`
