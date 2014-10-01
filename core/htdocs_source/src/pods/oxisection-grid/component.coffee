`import Em from "vendor/ember"`
`import BootstrapContextmenu from 'vendor/bootstrap-contextmenu'`

Component = Em.Component.extend
    didInsertElement: ->
        @$()?.find(".context")
        .contextmenu
            target: @$().find(".dropdown")
            onItem: => @onItem.apply @, arguments
        .off "contextmenu"

    sortNum: -1
    columns: (->
        columns = @get "content.content.columns"
        res = []
        for column, i in columns
            continue if column.sTitle[0] is "_" or column.bVisible is 0
            res.pushObject Em.Object.create
                sTitle: column.sTitle
                isSorted: i is @get "sortNum"
                isInverted: false
    ).property "content.content.columns"

    data: (->
        data = @get "content.content.data"
        columns = @get "content.content.columns"

        col = 0
        res = []
        for row, y in data
            res[y] = []
            res[y].set "originalIndex", y
            for column, x in row
                break if x > columns.length-1
                if columns[x].sTitle in [ "_status", "_className" ]
                    Em.set res[y], "className", "gridrow-#{column}"
                continue if columns[x].sTitle[0] is "_" or columns[x].bVisible is 0
                col++
                res[y][x] =
                    format: columns[x].format
                    value: column
        res
    ).property "content.content.data"

    hasAction: (->
        not not @get "content.content.actions"
    ).property "content.content.actions"

    sortedData: (->
        data = @get "data"
        data = data.toArray()
        sortNum = @get "sortNum"

        if sortNum >= 0
            re = /^[0-9.]+$/
            data.sort (a,b) ->
                a = a[sortNum].value
                b = b[sortNum].value

                if re.test(a) and re.test(b)
                    a = parseFloat(a, 10)
                    b = parseFloat(b, 10)

                if a > b then 1 else -1

            if @get("columns")[sortNum].get "isInverted"
                data.reverseObjects()

        Em.run.scheduleOnce "afterRender", => @didInsertElement()

        data
    ).property "data", "sortNum", "columns.@each.isInverted"

    contextIndex: null

    onItem: (context, e) ->
        actions = @get "content.content.actions"
        if actions.length is 1
            action = actions[0]
        else
            action = (a for a in actions when a.label is $(e.target).text())[0]

        columns = @get "content.content.columns"
        index = @get("sortedData")[@get("contextIndex")].get "originalIndex"
        data = @get("content.content.data")[index]
        path = action.path
        for col, i in columns
            path = path.replace "{#{col.sTitle}}", data[i]

        @container.lookup("route:openxpki").sendAjax
            data:
                page:path
                target:action.target

    click: (event) ->
        tr = $(event.target).parents "tr"
        index = @$().find("tr").index(tr) - 1
        return if index < 0
        @set "contextIndex", index

        actions = @get "content.content.actions"
        return if not actions
        if actions.length is 1
            @onItem()
        else
            tr.contextmenu "show", event
            event.stopPropagation()
            event.preventDefault()

    actions:
        sort: (key) ->
            sortNum = @get "sortNum"
            newSortNum = @get("columns").indexOf key
            column = @get("columns")[sortNum]
            if newSortNum isnt sortNum
                column.set "isSorted", false if column
                column = @get("columns")[newSortNum]
                column.set "isInverted", false
                column.set "isSorted", true
                @set "sortNum", newSortNum
            else
                column.toggleProperty "isInverted"
        showContextmenu: (row) ->
            actions = @get "content.content.actions"
            @set "contextIndex", @get("sortedData").indexOf row
            if actions.length is 1
                @onItem()
            else
                event = window.event;
                $(@$().find("tr")[@get("contextIndex")+1]).contextmenu "show", event
                alert $(@$().find("tr")[@get("contextIndex")+1]).innerHTML
                event.returnValue = false;
                event.stopPropagation() if event.stopPropagation
                event.preventDefault() if event.preventDefault

`export default Component`
