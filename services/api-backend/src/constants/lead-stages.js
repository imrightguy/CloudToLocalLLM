const VALID_LEAD_STAGES = Object.freeze([
  'nouveau',
  'contacte',
  'qualifie',
  'visitePlanifiee',
  'visite_planifiee',
  'offreEnvoyee',
  'negociation',
  'bailSigne',
  'signe',
  'visite_completee',
  'interesse',
  'inactif',
]);

const USER_FACING_STAGES = Object.freeze([
  'nouveau',
  'contacte',
  'qualifie',
  'visitePlanifiee',
  'visite_planifiee',
  'offreEnvoyee',
  'negociation',
  'bailSigne',
  'signe',
]);

const SMS_FLOW_STAGES = Object.freeze([
  'visite_completee',
  'interesse',
  'inactif',
]);

module.exports = { VALID_LEAD_STAGES, USER_FACING_STAGES, SMS_FLOW_STAGES };
