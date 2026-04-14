// prettier-ignore
export default [{
    type: "tiles",
    label: "Tiles",
    description: "",
    content: {
        maxcol: 4,
        border: 1,
        tiles: [
            {
                type: "text", colspan: 2, content: {
                    description: "Take a deep dive into masterly distilled information and mind-blowingly sustainable diagrams—the insights are absolutely game-changing.<br><i>#DataDriven #Innovation #ContinuousLearning</i>",
                }
            },
            'newline',
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
            {
                type: 'button', content: {
                    label: 'Terra',
                    description: 'Also called Old Earth. A realm made for those who were born on the blue planet. The Bene Gesserit drew patterns of Old Earth on many planets.',
                    footer: 'Auto-Login',
                    image: 'data:image/webp;base64,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',
                    page: 'mobile',
                },
            },
            'newline',
            {
                type: 'chart',
                cssClass: 'test-chart',
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
                cssClass: 'test-chart',
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
        ],
    },
}]
