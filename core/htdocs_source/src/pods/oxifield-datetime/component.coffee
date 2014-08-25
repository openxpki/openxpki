`import Em from "vendor/ember"`
`import moment from "vendor/moment"`

Component = Em.Component.extend
    format: "MM/DD/YYYY hh:mm A"

    options: {}

    setup: (->
        value = @get "content.value"
        if value is "now"
            @set "content.pickvalue", moment().format @get "format"
        else if value
            @set "content.pickvalue", moment.unix(value).format @get "format"
        Em.run.next =>
            @$().find(".date").datetimepicker
                format: @get "format"
    ).on "didInsertElement"

    propagate: Em.observer "content.pickvalue", ->
        if @get("content.pickvalue")
            datetime = moment(@get("content.pickvalue"), @get("format")).unix()
        else
            dateimte = ""
        @set "content.value", datetime

`export default Component`
