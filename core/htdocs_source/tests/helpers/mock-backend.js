import Service from '@ember/service';

function mockOk(data) {
    return Promise.resolve({
        ok: true,
        status: 200,
        json: () => Promise.resolve(data),
    });
}

const SESSION = {
    ANON: 'mock-anon-session',
    AUTH: 'mock-auth-session',
    LOGGEDOUT: 'mock-loggedout-session',
};

const HANDLER_SELECT_FORM = {
    type: 'form',
    action: 'login!stack',
    content: {
        fields: [
            {
                name: 'auth_stack',
                label: 'Authentication Handler',
                type: 'select',
                // Two options so isStatic=false and a real <select> is rendered
                options: [
                    { value: 'Testing', label: 'Testing' },
                    { value: 'Password', label: 'Password' },
                ],
            },
        ],
        submit_label: 'Login',
    },
};

const PASSWORD_FORM = {
    type: 'form',
    action: 'login!password',
    content: {
        fields: [
            { name: 'username', label: 'Username', type: 'text' },
            { name: 'password', label: 'Password', type: 'password' },
        ],
        submit_label: 'Login',
    },
};

export default class MockOxiBackendService extends Service {
    _state = 'anon'; // 'anon' | 'auth' | 'loggedout'

    request({ url, method, data }) {
        const page = data?.page;
        const action = data?.action;

        if (page === 'bootstrap!structure') return this._bootstrap();
        if (page === 'welcome')             return this._welcome();
        if (page === 'login')               return this._loginPage();
        if (page === 'login!password')      return this._loginPasswordPage();
        if (page === 'login!logout')        return this._loginLogoutPage();
        if (page === 'logout')              return this._logoutPage();
        if (action === 'login!stack')       return this._loginStack();
        if (action === 'login!password')    return this._loginPassword(data);

        console.warn('[MockOxiBackend] Unhandled request:', { page, action, method, url });
        return Promise.resolve({ ok: false, status: 500, json: () => Promise.resolve({}) });
    }

    _bootstrap() {
        if (this._state === 'auth') {
            return mockOk({
                session_id: SESSION.AUTH,
                rtoken: 'mock-rtoken',
                language: 'en',
                user: { name: 'raop', role: 'Admin' },
                structure: [],
            });
        }
        const sessionId = this._state === 'loggedout' ? SESSION.LOGGEDOUT : SESSION.ANON;
        return mockOk({
            session_id: sessionId,
            rtoken: 'mock-rtoken',
            language: 'en',
            user: null,
            structure: [],
        });
    }

    _welcome() {
        if (this._state === 'auth') {
            return mockOk({
                session_id: SESSION.AUTH,
                page: {
                    label: 'Welcome',
                    description: 'Tokens of type certsign are available in this realm.',
                },
                main: [],
            });
        }
        return mockOk({
            goto: 'login',
            type: 'internal',
            session_id: SESSION.ANON,
        });
    }

    _loginPage() {
        return mockOk({
            session_id: SESSION.ANON,
            page: { label: 'Login' },
            main: [HANDLER_SELECT_FORM],
        });
    }

    _loginStack() {
        // Redirect to the password page so the route transition recreates the form component
        return mockOk({
            goto: 'login!password',
            type: 'internal',
            session_id: SESSION.ANON,
        });
    }

    _loginPasswordPage() {
        return mockOk({
            session_id: SESSION.ANON,
            page: { label: 'Login' },
            main: [PASSWORD_FORM],
        });
    }

    _loginPassword(data) {
        if (data.username === 'raop' && data.password === 'openxpki') {
            this._state = 'auth';
            return mockOk({
                goto: 'welcome',
                type: 'internal',
                session_id: SESSION.AUTH,
            });
        }
        return mockOk({
            session_id: SESSION.ANON,
            status: { level: 'error', message: 'Login failed: Invalid credentials' },
            page: { label: 'Login' },
            main: [PASSWORD_FORM],
        });
    }

    _logoutPage() {
        this._state = 'loggedout';
        return mockOk({
            session_id: SESSION.LOGGEDOUT,
            page: {
                label: 'Logged Out',
                description: 'Logout Successful',
            },
            main: [],
        });
    }

    _loginLogoutPage() {
        this._state = 'loggedout';
        return mockOk({
            session_id: SESSION.LOGGEDOUT,
            page: {
                label: 'Logged Out',
                description: 'Logout Successful',
            },
            main: [],
        });
    }
}
