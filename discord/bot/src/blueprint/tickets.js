// Private ticket types. Each ticket becomes a private channel in the TICKETS category that only the
// applicant, the reviewer roles, Administrators and the bot can see.
// panel = the channel whose button panel offers this ticket type.

export const TICKET_TYPES = {
  support: {
    panel: 'support', label: 'General help', emoji: '❓', reviewers: ['support_team', 'moderator'],
    template: [
      '**General support request**',
      'Please answer briefly:',
      '1. What do you need help with?',
      '2. In-game name (Roblox username), if relevant:',
      '3. What have you already tried?',
    ],
  },
  technical: {
    panel: 'support', label: 'Technical problem', emoji: '🛠️', reviewers: ['support_team', 'developer'],
    template: [
      '**Technical support**',
      '1. Where does the problem happen (Roblox game, Discord bot, other)?',
      '2. What did you do, what did you expect, what happened instead?',
      '3. Exact error message or screenshot (no passwords or codes!):',
      '4. Device (PC, mobile, console):',
    ],
  },
  security: {
    panel: 'support', label: 'Exploit / security issue', emoji: '🔒', reviewers: ['developer'],
    template: [
      '**Private exploit or security report**',
      'Thank you for reporting privately. Do not share the exploit anywhere else.',
      '1. What can be abused (game mechanic, economy, bot command, permission)?',
      '2. Steps to reproduce:',
      '3. When did you notice it?',
      'Responsible reports are never punished. Abusing an exploit is.',
    ],
  },
  player_report: {
    panel: 'player_reports', label: 'Report a player', emoji: '🚩', reviewers: ['moderator'],
    template: [
      '**Player report**',
      '1. Discord and/or Roblox name of the player:',
      '2. Which rule was broken?',
      '3. When and where (channel or in-game location, time in Europe/Berlin)?',
      '4. Evidence (screenshots, clips, message links):',
      'Reports stay confidential. False reports are a rule violation.',
    ],
  },
  appeal: {
    panel: 'appeals', label: 'Appeal a decision', emoji: '⚖️', reviewers: ['moderator'], allowRestricted: true,
    template: [
      '**Moderation appeal**',
      '1. Which decision are you appealing (warning, timeout, restriction, role removal)?',
      '2. Who made the decision and when (if known)?',
      '3. Why should it be changed? Stay factual.',
      'An appeal is reviewed by a staff member who did not make the original decision where possible.',
    ],
  },
  apply_police: {
    panel: 'faction_applications', label: 'City Police', emoji: '🚓', reviewers: ['police_command'], application: true,
    template: applicationTemplate('City Police'),
  },
  apply_gendarmerie: {
    panel: 'faction_applications', label: 'Gendarmerie', emoji: '🛡️', reviewers: ['gendarmerie_command'], application: true,
    template: applicationTemplate('Gendarmerie'),
  },
  apply_armed_forces: {
    panel: 'faction_applications', label: 'Land Forces / Air Force', emoji: '🎖️', reviewers: ['armed_forces_command'], application: true,
    template: applicationTemplate('Armed Forces', 'State whether you want to join the Land Forces or the Air Force.'),
  },
  apply_guard: {
    panel: 'faction_applications', label: 'Revolutionary Guard', emoji: '🦅', reviewers: ['guard_command'], application: true,
    template: applicationTemplate('Revolutionary Guard', 'The Guard usually recruits experienced members of other security services.'),
  },
  apply_ems: {
    panel: 'faction_applications', label: 'EMS', emoji: '🚑', reviewers: ['ems_command'], application: true,
    template: applicationTemplate('Emergency Medical Services'),
  },
  apply_brandwehr: {
    panel: 'faction_applications', label: 'Brandwehr', emoji: '🚒', reviewers: ['brandwehr_command'], application: true,
    template: applicationTemplate('Brandwehr (fire and civil protection)'),
  },
  apply_justice: {
    panel: 'faction_applications', label: 'Justice (lawyer, prosecutor, judge)', emoji: '📜', reviewers: ['judge', 'secretary_internal'], application: true,
    template: applicationTemplate('Justice', 'Lawyers and prosecutors need a justice degree from the national university in Gundiville (in roleplay). Say whether your character holds one.'),
  },
  apply_civil_service: {
    panel: 'faction_applications', label: 'Civil service / government', emoji: '🏛️', reviewers: ['secretary_general', 'secretary_internal'], application: true,
    template: applicationTemplate('Public administration'),
  },
  apply_avk: {
    panel: 'faction_applications', label: 'AVK insurance officer', emoji: '📄', reviewers: ['secretary_economy'], application: true,
    template: applicationTemplate('AVK - Allgemeine Volksversicherung Kagundi'),
  },
  apply_staff: {
    panel: 'faction_applications', label: 'Staff team (out of character)', emoji: '🧑‍💼', reviewers: [],
    template: [
      '**Staff application** (out of character)',
      '1. Discord name, age range (13-15, 16-17, 18+) and time zone:',
      '2. Which team: Support, Moderation, Development, Economy?',
      '3. Previous staff or community experience:',
      '4. How many hours per week can you help?',
      '5. How would you handle a friend breaking the rules?',
      'Requirement: Community Member role and no active sanctions.',
    ],
  },
  business_registry: {
    panel: 'business_registration', label: 'Question to the business registry', emoji: '🏢', reviewers: ['secretary_economy', 'government_official', 'economic_administrator'],
    template: [
      '**Business registry enquiry**',
      'Business registration itself is done with `/business register` in #bank-terminal.',
      'Use this ticket for questions, special licences, state participation or partnerships.',
      '1. Business name and number (if registered):',
      '2. Your question or request:',
    ],
  },
  legal_case: {
    panel: 'legal_information', label: 'File a case / request a lawyer', emoji: '🏛️', reviewers: ['judge', 'justice'],
    template: [
      '**Court filing or legal assistance** (in character)',
      '1. Character name:',
      '2. Type: civil claim, defence lawyer request, appeal of a first-instance judgment, other:',
      '3. Other parties involved (character names):',
      '4. Short description of the facts:',
      '5. Evidence (screenshots, report numbers):',
      'Appeals of first-instance judgments must be filed within 72 hours (real time) of the judgment.',
    ],
  },
};

function applicationTemplate(institution, extra = null) {
  return [
    `**Application: ${institution}**`,
    '1. Roblox username and Discord name:',
    '2. Character name and short background (2-4 sentences):',
    '3. Why does your character want to join?',
    '4. Relevant roleplay experience:',
    '5. Availability (days and times, Europe/Berlin):',
    '6. Have you read the rules and the guides for this institution? (yes/no)',
    ...(extra ? [extra] : []),
    'Please do not share personal data beyond what is asked.',
  ];
}

export const PANELS = {
  support: { title: 'Support', description: 'Open a private ticket. Only you and the responsible team can see it.' },
  player_reports: { title: 'Player reports', description: 'Report a rule violation privately. Include evidence.' },
  appeals: { title: 'Appeals', description: 'Appeal a moderation decision. Stay factual and respectful.' },
  faction_applications: { title: 'Applications', description: 'Choose the institution you want to apply to. A private application channel opens for you and the responsible command.' },
  business_registration: { title: 'Business registry', description: 'Register with `/business register` in #bank-terminal. Questions? Open a ticket.' },
  legal_information: { title: 'Legal services', description: 'File a case, appeal a judgment or request a lawyer.' },
};

export function ticketTypesForPanel(panelKey) {
  return Object.entries(TICKET_TYPES).filter(([, t]) => t.panel === panelKey).map(([key, t]) => ({ key, ...t }));
}
