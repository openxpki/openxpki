// prettier-ignore
export default [{
    type: "tiles",
    content: {
        label: "Tiles",
        description: "",
        maxcol: 4,
        border: 1,
        tiles: [
            {
                type: "text", colspan: 2, content: {
                    description: "Take a deep dive into masterly distilled information and mind-blowingly sustainable diagrams—the insights are absolutely game-changing.<br><i>#DataDriven #Innovation #ContinuousLearning</i>",
                }
            },
            {
                type: 'chart',
                className: 'test-chart',
                content: {
                    options: {
                        type: 'bar',
                        title: 'Bar',
                        legend_position: 'right',
                        series: [
                            {
                                label: 'Requested',
                                color: 'rgba(0, 100, 200, 0.9)',
                                scale: '%',
                            },
                            {
                                label: 'Renewed',
                                color: 'rgba(200, 200, 200, 1)',
                                scale: '%',
                            },
                            {
                                label: 'Revoked',
                                color: 'rgba(200, 30, 100, 0.9)',
                                scale: '%',
                            },
                        ],
                    },
                    data: [['2018','23.8','53.6','37.4'],['2019','19.6','43.3','63.4'],['2020','4.2','51.8','47.4']],
                }
            },
            {
                type: 'chart',
                className: 'test-chart',
                content: {
                    options: {
                        type: 'pie',
                        title: 'Pie',
                        legend_position: 'right',
                        series: [
                            {
                                label: 'Requested',
                            },
                            {
                                label: 'Renewed',
                            },
                            {
                                label: 'Revoked',
                            },
                            {
                                label: 'Unchanged',
                            },
                        ],
                    },
                    data: [['2019','14','44','30','12']],
                }
            },
            {
                type: "keyvalue", content: {
                    data: [
                        {
                            format: "timestamp",
                            label: "timestamp",
                            value: 1617495633,
                        },
                        {
                            format: "styled",
                            label: "styled",
                            value: "attention:hear my words",
                        },
                        {
                            format: "certstatus",
                            label: "certstatus",
                            value: {
                                value: "issued",
                                label: "<i>Issued</i>",
                                tooltip: "It's issued",
                            },
                        },
                        {
                            format: "link",
                            label: "link",
                            value: {
                                page: "workflow!load!wf_id!13567",
                                label: 13567,
                                target: "top",
                            },
                        },
                    ],
                },
            },
            'newline',
            {
                type: 'button', content: {
                    label: 'Request certificate',
                    image: 'img/request.png',
                    page: 'workflow!index!wf_type!certificate_signing_request_v2',
                },
            },
            {
                type: 'button', content: {
                    label: 'Revoke certificate',
                    image: 'img/revoke.png',
                    page: 'workflow!index!wf_type!certificate_revocation_request_v2',
                },
            },
            'newline',
            {
                type: 'button', content: {
                    label: 'SCEP Workflow Search',
                    image: 'img/transaction-id.png',
                    page: 'workflow!index!wf_type!search_scep_workflow',
                },
            },
            {
                type: 'button', content: {
                    label: 'My Certificates',
                    image: 'img/my-certificates.png',
                    page: 'certificate!mine',
                },
            },
            {
                type: 'button', content: {
                    label: 'Certificate Search',
                    image: 'img/certificate-search.png',
                    page: 'certificate!search',
                },
            },
            {
                type: 'button', content: {
                    label: 'CA Certificates',
                    image: 'img/get-issuers.png',
                    page: 'information!issuer',
                },
            },
            {
                type: 'button', content: {
                    label: 'Show Revocation Lists (CRL)',
                    image: 'img/get-crls.png',
                    page: 'crl!index',
                },
            },
            {
                type: 'button', content: {
                    label: 'PKI Operation',
                    icon: 'glyphicon-wrench',
                    page: 'info',
                },
            },
            {
                type: 'button', content: {
                    label: 'Mobile Devices',
                    icon: 'bi-phone-flip',
                    page: 'mobile',
                },
            },
        ],
    },
}]
