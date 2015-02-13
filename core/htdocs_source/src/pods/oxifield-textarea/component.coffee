`import Em from "vendor/ember"`

Component = Em.Component.extend
    cols: Em.computed "content.textAreaSize.width", ->
        @get("content.textAreaSize.width") || 150

    rows: Em.computed "content.textAreaSize.height", ->
        @get("content.textAreaSize.height") || 10

`export default Component`
