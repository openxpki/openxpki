`import Em from "vendor/ember"`
`import moment from "vendor/moment"`

Component = Em.Component.extend
    format: "MM/DD/YYYY hh:mm A"

    options: {}

    setup: (->
        @set "content.value", "now"
        if "now" is @get "content.value"
            @set "content.pickvalue", moment().format(@get "format")
        Em.run.next =>
            @$().find(".date").datetimepicker()
    ).on "didInsertElement"

    propagate: Em.observer "content.pickvalue", ->
        if @get("content.pickvalue")
            datetime = moment(@get("content.pickvalue"), @get("format")).unix()
        else
            dateimte = ""
        @set "content.value", datetime

`export default Component`
