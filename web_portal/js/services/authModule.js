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
  const USE_MOCKS = true; // TODO: Velez — set false once POST /auth/* is live
  const delay = (ms = 450) => new Promise((resolve) => setTimeout(resolve, ms));

  const users = {
    'operator@gmail.com': { password: 'password123', role: 'operator' },
    'admin@gmail.com': { password: 'password123', role: 'admin' },
    'testing@account.com': { password: 'password123', role: 'operator' },
  };
  const otps = {};

  async function request(method, path, body) {
    // TODO: Velez — replace this mock switch with:
    //   return apiClient.request(method, path, body)
    // Endpoints: POST /auth/login, /auth/register, /auth/forgot-password,
    //            /auth/reset-password, /auth/google
    if (!USE_MOCKS) {
      throw new Error('Live apiClient is not wired yet — keep USE_MOCKS true or plug F7 here.');
    }
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

  return {
    login: (email, password, rememberMe) =>
      request('POST', '/auth/login', {
        email,
        password,
        remember_me: rememberMe,
      }),

    registerOperator: (payload) =>
      request('POST', '/auth/register', { ...payload, role: 'operator' }),

    loginWithGoogle: (idToken, email) =>
      request('POST', '/auth/google', { id_token: idToken, email }),

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
