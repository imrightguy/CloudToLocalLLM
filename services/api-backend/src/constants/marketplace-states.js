const QUALIFICATION_STATES = Object.freeze([
  'unknown',
  'qualified',
  'rejected',
  'needs_follow_up',
]);

const BOOKING_STATES = Object.freeze([
  'unbooked',
  'booking_pending',
  'scheduled',
  'confirmed',
  'in_progress',
  'completed',
  'cancelled',
  'no_show',
  'reschedule_requested',
]);

const MARKETPLACE_REASON_CODES = Object.freeze([
  'budget_mismatch',
  'not_ready_to_move',
  'duplicate_inquiry',
  'already_rented',
  'no_longer_interested',
  'tenant_unavailable',
  'employee_unavailable',
  'schedule_conflict',
  'access_issue',
  'weather',
  'other',
]);

module.exports = {
  QUALIFICATION_STATES,
  BOOKING_STATES,
  MARKETPLACE_REASON_CODES,
};
