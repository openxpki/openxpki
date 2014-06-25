`import $ from "vendor/jquery"`
`import Em from "vendor/ember"`
`import moment from "vendor/moment"`

Component = Em.Component.extend
    types:
        certstatus: (v) -> "<span class='certstatus-#{(v.value||v.label).toLowerCase()}'>#{v.label}</span>"
        link: (v) -> "<a href='##{v.page}' target='#{v.target||"modal"}'>#{v.label}</a>"
        timestamp: (v) -> moment.unix(v).format("dd, DD MMMM YYYY, HH:mm:ss z")
        text: (v) -> v
        code: (v) -> "<code>#{v.replace(/(\r\n|\n|\r)/gm,"<br>")}</code>"
        raw: (v) -> v
        deflist: (v) -> "<dl>#{(for k, w of v then "<dt>#{k}</dt><dd>#{w}</dd>").join ""}</dl>"

    formatedValue: (->
        @get("types")[@get("content.format")||"text"](@get "content.value")
    ).property "content.format", "content.value"

`export default Component`
