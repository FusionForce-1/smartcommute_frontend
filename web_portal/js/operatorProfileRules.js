// js/operatorProfileRules.js
//
// Formats for an operator's Franchise Number and Contact Number, checked by
// Register, the Google "Complete your Profile" popup and Edit Profile. The
// backend checks the same formats with the same messages
// (app/models/operators_models.py). A blank value passes here: each form
// decides whether the field is required.

const OperatorProfileRules = (() => {
  // LTFRB franchise (case) number: YY-NNNNN, e.g. 23-28051, or YYYY-NNNNNNN, e.g. 2003-0900460.
  const FRANCHISE_NUMBER = /^(\d{2}-\d{5}|\d{4}-\d{7})$/;
  // Philippine mobile number written the local way: 09 and 9 more digits, e.g. 09171234567.
  const CONTACT_NUMBER = /^09\d{9}$/;

  return {
    /** The error for a franchise number in the wrong format, or ''. */
    franchiseProblem: (value) =>
      (value && !FRANCHISE_NUMBER.test(value)
        ? 'Franchise number must look like 23-28051 or 2003-0900460.'
        : ''),

    /** The error for a contact number in the wrong format, or ''. */
    contactProblem: (value) =>
      (value && !CONTACT_NUMBER.test(value)
        ? 'Contact number must start with 09 and have 11 digits, like 09171234567.'
        : ''),
  };
})();
