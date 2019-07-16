`import Em from "vendor/ember"`
`import types from "../oxivalue-format/types"`

Component = Em.Component.extend
    items: Em.computed "content.content.data", ->
        items = @get "content.content.data"
        for i in items
            i.isHead = 1 if i.format is 'head'
        items.filter (item) =>
            types[item.format||'text'](item.value) isnt ''

    actions:
        buttonClick: (button) -> @sendAction "buttonClick", button

`export default Component`
