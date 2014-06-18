`import Em from "vendor/ember"`
`import moment from "vendor/moment"`

Component = Em.Component.extend
    types:
        certstatus: (v) -> "<span class='certstatus-#{(v.value||v.label).toLowerCase()}'>#{v.label}</span>"
        link: (v) -> "<a href='#/openxpki/#{v.page}?target=modal'>#{v.label}</a>"
        timestamp: (v) -> moment.unix(v).format("dd, DD MMMM YYYY, HH:mm:ss z")
        text: (v) -> v

    formatedValue: (->
        @get("types")[@get("content.format")||"text"](@get "content.value")
    ).property "content.format", "content.value"

`export default Component`
