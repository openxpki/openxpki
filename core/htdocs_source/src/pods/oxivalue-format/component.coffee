`import $ from "vendor/jquery"`
`import Em from "vendor/ember"`
`import moment from "vendor/moment"`

Component = Em.Component.extend
    onAnchorClick: Em.on "click", (evt) ->
        target = evt.target

        if target.tagName is "A" and target.target isnt "_blank"
            evt.stopPropagation()
            evt.preventDefault()
            @container.lookup("route:openxpki").sendAjax
                data:
                    page:target.href.split("#")[1]
                    target:target.target

    types:
        certstatus: (v) -> "<span class='certstatus-#{(v.value||v.label).toLowerCase()}'>#{v.label}</span>"
        link: (v) -> "<a href='##{v.page}' target='#{v.target||"modal"}'>#{v.label}</a>"
        timestamp: (v) -> moment.unix(v).utc().format("YYYY-MM-DD HH:mm:ss UTC")
        datetime: (v) -> moment().utc(v).format("YYYY-MM-DD HH:mm:ss UTC")
        text: (v) -> v
        code: (v) -> "<code>#{v.replace(/(\r\n|\n|\r)/gm,"<br>")}</code>"
        raw: (v) -> v
        defhash: (v) -> "<dl>#{(for k, w of v then "<dt>#{k}</dt><dd>#{w}</dd>").join ""}</dl>"
        deflist: (v) -> "<dl>#{(for w in v then "<dt>#{w.label}</dt><dd>#{w.value}</dd>").join ""}</dl>"

    formatedValue: Em.computed "content.format", "content.value", ->
        @get("types")[@get("content.format")||"text"](@get "content.value")

`export default Component`
