`import Em from "vendor/ember"`
`import BootstrapContextmenu from 'vendor/bootstrap-contextmenu'`

Component = Em.Component.extend
    pages: Em.computed "count", "limit", ->
        pager = @get "content.content.pager"
        return [] if not pager

        pager.count = parseInt pager.count, 10
        pager.limit = parseInt pager.limit, 10
        pager.startat = parseInt pager.startat, 10
        return [] if pager.count <= pager.limit

        pages = Math.ceil pager.count/pager.limit
        current = Math.floor pager.startat/pager.limit

        o = []
        for i in [0..pages-1]
            o.push
                num: i+1
                active: i is current
                startat: i * pager.limit
        o.prev =
            disabled: current is 0
            startat:  (current-1) * pager.limit
        o.next =
            disabled: current is pages-1
            startat:  (current+1) * pager.limit
        o

    initializeContextmenu: Em.on "didInsertElement", ->
        @$()?.find(".context")
        .contextmenu
            target: @$().find(".dropdown")
            onItem: => @onItem.apply @, arguments
        .off "contextmenu"

    sortNum: -1
    columns: Em.computed "content.content.columns", ->
        columns = @get "content.content.columns"
        res = []
        for column, i in columns
            continue if column.sTitle[0] is "_" or column.bVisible is 0
            res.pushObject Em.Object.create
                sTitle: column.sTitle
                isSorted: i is @get "sortNum"
                isInverted: false

    data: Em.computed "content.content.data", ->
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

    hasAction: Em.computed "content.content.actions", ->
        not not @get "content.content.actions"

    sortedData: Em.computed "data", "sortNum", "columns.@each.isInverted", ->
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

        Em.run.scheduleOnce "afterRender", => @initializeContextmenu()

        data

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
        changeStartat: (page) ->
            return if page.disabled or page.active
            pager = @get "content.content.pager"
            @container.lookup("route:openxpki").transitionTo
                queryParams:
                    limit: pager.limit
                    startat: page.startat

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
