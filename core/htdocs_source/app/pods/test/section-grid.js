function additionalGridRows() {
    let result = [];
    // add some more grid rows
    for (let i=0; i<50; i++) {
        result.push([
            334455 + i,
            [ `CN=client-${i}`, "DC=Test Deployment", "DC=OpenXPKI", "DC=org" ],
            {
                value: "ISSUED",
                label: "Issued"
            },
            1585959633 + 60*60*24*i,
            `${1585959633 + 60*60*24*i}`,
            `ID-IS-${i}`,
            `id-${i}`,
            {
                label: "Issued",
                value: "ISSUED"
            }
        ]);
    }
    return result;
}

export default {
    type: "grid",
    className: "certificate",
    content: {
        label: "oxi-section/grid",
        empty: "No data available",
        buttons: [
            {
                section: "Some",
            },
            {
                format: "expected",
                page: "certificate!search!query!rJdrIbg1P6xsE6b9RtQCXp291SE",
                label: "Reload Search Form",
                description: "Button 1",
            },
            {
                format: "alternative",
                page: "redirect!certificate!result!id!rJdrIbg1P6xsE6b9RtQCXp291SE",
                label: "Refresh Result",
                description: "Button 2",
            },
            {
                section: "Others",
            },
            {
                label: "New Search",
                format: "failure",
                page: "certificate!search"
            },
            {
                label: "Export Result",
                format: "optional",
                target: "_blank",
                href: "/cgi-bin/webui.fcgi?page=certificate!export!id!rJdrIbg1P6xsE6b9RtQCXp291SE"
            }
        ],
        actions: [
            {
                label: "Download",
                icon: "download",
                path: "certificate!detail!identifier!{identifier}",
                target: "popup"
            },
            {
                label: "Check",
                icon: "download",
                path: "certificate!detail!identifier!{identifier}",
                target: "popup"
            }
        ],
        columns: [
            {
                sTitle: "Certificate Serial",
                sortkey: "cert_key"
            },
            {
                sTitle: "Subject",
                sortkey: "subject",
                format: "subject",
            },
            {
                format: "certstatus",
                sortkey: "status",
                sTitle: "Status"
            },
            {
                sTitle: "not before",
                sortkey: "notbefore",
                format: "timestamp"
            },
            {
                format: "raw",
                sortkey: "notafter",
                sTitle: "raw"
            },
            {
                sortkey: "identifier",
                sTitle: "Certificate Identifier"
            },
            {
                sTitle: "identifier",
                bVisible: 0
            },
            {
                sTitle: "_className"
            },
        ],
        data: [
            [
                "0x3ff536fff8da93943aa",
                [ "CN=e.d.c:pkiclient", "DC=Test Deployment", "DC=OpenXPKI", "DC=org" ],
                {
                    value: "ISSUED",
                    label: "Issued"
                },
                "1585959633",
                "1617495633",
                "0qLkfCTwwj-8SoSOTtlRQLqS20o",
                "0qLkfCTwwj-8SoSOTtlRQLqS20o",
                {
                    label: "Issued",
                    value: "ISSUED"
                }
            ],
            [
                "0x2ff8fa8ee5590e2553a",
                [ "CN=e.d.c:pkiclient", "DC=Test Deployment", "DC=OpenXPKI", "DC=org" ],
                {
                    label: "Issued",
                    value: "ISSUED"
                },
                "1585434533",
                "<a href=\"test\" onclick=\"alert('huh')\">test</a>",
                "fPF_JVAco7Eg0d3kANRFLYRPu5o",
                "fPF_JVAco7Eg0d3kANRFLYRPu5o",
                {
                    label: "Issued",
                    value: "ISSUED"
                }
            ],

            ...additionalGridRows(),
        ]
    },
}
