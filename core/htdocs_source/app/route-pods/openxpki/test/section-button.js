export default [
    {
        type: 'button',
        description: 'Button',
        content: {
            format: 'primary',
            page: 'test',
        },
    },
    {
        type: 'button',
        description: 'Submit',
        content: {
            format: 'submit',
            action: 'test!submit',
        },
    },
    {
        type: 'button',
        description: 'External link',
        content: {
            format: 'optional',
            href: 'https://www.openxpki.org',
            target: '_blank',
        },
    },
    {
        type: 'button',
        description: 'Request certificate',
        content: {
            image: 'img/request.png',
            page: 'workflow!index!wf_type!certificate_signing_request_v2',
        },
    },
]
