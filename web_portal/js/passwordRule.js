// Password rule
const PasswordRule = {
  // New password problem
  problem(password) {
    const pw = String(password || '');
    if (pw.length < 8) return 'Password must be at least 8 characters.';
    if (new TextEncoder().encode(pw).length > 72) return 'Password must be at most 72 bytes.';
    if (!/[A-Za-z]/.test(pw) || !/\d/.test(pw)) return 'Password must contain at least one letter and one number.';
    return '';
  },
};
