// Operator profile rules
// Operator profile rules
const OperatorProfileRules = (() => {
  const FRANCHISE_NUMBER = /^(\d{2}-\d{5}|\d{4}-\d{7})$/;
  const CONTACT_NUMBER = /^09\d{9}$/;

  return {
    // Franchise problem
    franchiseProblem: (value) =>
      (value && !FRANCHISE_NUMBER.test(value)
        ? 'Franchise number must look like 23-28051 or 2003-0900460.'
        : ''),

    // Contact problem
    contactProblem: (value) =>
      (value && !CONTACT_NUMBER.test(value)
        ? 'Contact number must start with 09 and have 11 digits, like 09171234567.'
        : ''),
  };
})();
