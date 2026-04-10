export default [
    {
        type: 'button', content: {
            label: 'Button',
            format: 'primary',
            page: 'test',
        },
    },
    {
        type: 'button', content: {
            label: 'Submit',
            format: 'submit',
            action: 'test!submit',
        },
    },
    {
        type: 'button', content: {
            label: 'External link',
            format: 'optional',
            href: 'https://www.openxpki.org',
            target: '_blank',
        },
    },
    {
        type: 'button', content: {
            label: 'Request certificate',
            image: 'img/request.png',
            page: 'workflow!index!wf_type!certificate_signing_request_v2',
        },
    },
]
