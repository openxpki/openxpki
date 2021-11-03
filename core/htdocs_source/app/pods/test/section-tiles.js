export default {
    type: "tiles",
    content: {
        label: "oxi-section/tiles",
        description: "",
        maxcol: 4,
        align: 'left',
        tiles: [
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
            { type: 'newline' },
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
}