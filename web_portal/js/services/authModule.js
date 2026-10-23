// js/services/authModule.js
//
// FRANCIS B. VELEZ — web portal auth module + mock adapter (F7).
// Emae's Login / Operator Register / Forgot-Password / OTP views call
// these methods. Swap the mock bodies for real fetch() calls to FastAPI
// when the backend is live. Do not move this logic into index.html,
// js/main.js, or js/router.js.
//
// Demo accounts:
//   operator@gmail.com / password123
//   admin@gmail.com    / password123
// Forgot-password error fixture (Web_Error.png):
//   test@account.com → "This email is not registered"
// OTP fixture: 123456

const AuthModule = (() => {
  const USE_MOCKS = false; // true = offline demo accounts below; false = live FastAPI
  const delay = (ms = 450) => new Promise((resolve) => setTimeout(resolve, ms));

  const users = {
    'operator@gmail.com': { password: 'password123', role: 'operator' },
    'admin@gmail.com': { password: 'password123', role: 'admin' },
    'testing@account.com': { password: 'password123', role: 'operator' },
  };
  const otps = {};

  async function request(method, path, body) {
    if (!USE_MOCKS) return ApiClient.request(method, path, body, { auth: false });
    await delay();
    return mockDispatch(method, path, body);
  }

  function mockDispatch(method, path, body = {}) {
    if (method === 'POST' && path === '/auth/login') {
      const id = String(body.email || '').trim().toLowerCase();
      const user = users[id];
      if (!user || user.password !== body.password) {
        const err = new Error('Invalid email or password.');
        err.statusCode = 401;
        throw err;
      }
      return { access_token: 'mock-access', role: user.role };
    }

    if (method === 'POST' && path === '/auth/register') {
      const email = String(body.email || '').trim().toLowerCase();
      if (!email) {
        const err = new Error('Email is required.');
        err.statusCode = 400;
        throw err;
      }
      if (users[email] && body.auth_provider !== 'google') {
        const err = new Error('Email is already registered.');
        err.statusCode = 409;
        throw err;
      }
      users[email] = { password: body.password || 'google-oauth', role: 'operator' };
      return { id: `mock-${Object.keys(users).length}`, email, role: 'operator' };
    }

    if (method === 'POST' && path === '/auth/google') {
      if (!body.id_token) {
        const err = new Error('Google sign-in cancelled.');
        err.statusCode = 401;
        throw err;
      }
      return {
        access_token: 'mock-google',
        role: 'operator',
        email: body.email || 'operator@gmail.com',
        needs_profile: true,
      };
    }

    if (method === 'POST' && path === '/auth/forgot-password') {
      const email = String(body.email || '').trim().toLowerCase();
      if (email === 'test@account.com' || !users[email]) {
        const err = new Error('This email is not registered');
        err.statusCode = 404;
        throw err;
      }
      otps[email] = '123456';
      return { status: 'accepted' };
    }

    if (method === 'POST' && path === '/auth/reset-password') {
      const email = String(body.email || '').trim().toLowerCase();
      const expected = otps[email] || '123456';
      if (String(body.otp || '').trim() !== expected) {
        const err = new Error('Incorrect or expired code. Try again.');
        err.statusCode = 400;
        throw err;
      }
      delete otps[email];
      return { status: 'ok' };
    }

    const err = new Error(`No mock for ${method} ${path}`);
    err.statusCode = 404;
    throw err;
  }

  /** Saves company details for the signed-in operator (POST /operators). */
  function createOperatorProfile({ company_name, franchise_number, contact_number }) {
    // user_id is required by the schema but the server overwrites it with
    // the id from the token, so any placeholder works.
    return ApiClient.post('/operators', { user_id: 'self', company_name, franchise_number, contact_number });
  }

  return {
    /**
     * Resolves with the token response, or with { two_factor_required: true,
     * email } when the account has two-factor on — then finish with
     * verifyLoginCode() using the code that was emailed.
     */
    login: async (email, password, rememberMe) => {
      const result = await request('POST', '/auth/login', { email, password });
      if (result?.two_factor_required) return result;
      Session.save({ ...result, email }, rememberMe);
      return result;
    },

    /** Second step of a two-factor login (POST /auth/login/verify). */
    verifyLoginCode: async (email, otp, rememberMe) => {
      const result = await request('POST', '/auth/login/verify', { email, otp });
      Session.save({ ...result, email }, rememberMe);
      return result;
    },

    logout: async () => {
      try {
        await ApiClient.post('/auth/logout');
      } catch {
        // JWTs are stateless — clearing the local session is what logs out.
      }
      Session.clear();
    },

    /**
     * Email/password operator sign-up: creates the account, signs in once to
     * save the company profile (that endpoint needs a token), then signs out
     * so the operator logs in normally afterwards. `acceptedTerms` is the
     * User Agreement / Privacy Policy box — the backend requires and records it.
     */
    registerOperator: async ({ name, email, password, profile, acceptedTerms }) => {
      await request('POST', '/auth/register', {
        name, email, password, role: 'operator', accepted_terms: acceptedTerms === true,
      });
      try {
        const tokens = await request('POST', '/auth/login', { email, password });
        Session.save({ ...tokens, email });
        await createOperatorProfile(profile);
      } finally {
        Session.clear();
      }
    },

    /**
     * Signs in with a Google ID token. `role` only applies when the Google
     * account is brand new (the backend never changes an existing role).
     */
    loginWithGoogle: async (idToken, { role, email, rememberMe = false } = {}) => {
      const result = await request('POST', '/auth/google', { id_token: idToken, role });
      Session.save({ ...result, email }, rememberMe);
      return result;
    },

    /** The signed-in operator's company profile, or null if not created yet. */
    getMyOperatorProfile: async () => {
      try {
        return await ApiClient.get('/operators/me');
      } catch (err) {
        if (err.statusCode === 404) return null;
        throw err;
      }
    },

    createOperatorProfile,

    /** Records the signed-in user's agreement to the User Agreement / Privacy Policy. */
    acceptTerms: () => ApiClient.post('/users/me/accept-terms'),

    forgotPassword: (email) =>
      request('POST', '/auth/forgot-password', { email }),

    resetPassword: (email, otp, newPassword) =>
      request('POST', '/auth/reset-password', {
        email,
        otp,
        new_password: newPassword,
      }),
  };
})();
