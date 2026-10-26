// Ro-Nation role hierarchy (top to bottom). This list is the single source of truth used by the
// server setup script, the bot's permission checks and the generated documentation.
//
// permissions = server-wide Discord permissions of the role. Channel access is granted per channel
// (see channels.js). Fictional government roles intentionally have NO server-wide permissions.

export const BASIC_MEMBER_PERMISSIONS = [
  'ViewChannel', 'SendMessages', 'SendMessagesInThreads', 'ReadMessageHistory', 'AddReactions',
  'UseApplicationCommands', 'Connect', 'Speak', 'UseVAD', 'ChangeNickname', 'UseExternalEmojis',
];

export const ROLES = [
  // ---------- Ownership and staff ----------
  { key: 'owner', name: 'Owner', group: 'Staff', color: '#E3B341', hoist: true, mentionable: false, permissions: ['Administrator'],
    purpose: 'Project owner. Ultimate control over the server and the economy bot (emergency overrides).', assignedBy: 'Server owner only' },
  { key: 'developer', name: 'Developer', group: 'Staff', color: '#9B59B6', hoist: true, mentionable: false,
    permissions: ['ViewAuditLog', 'ManageWebhooks', 'EmbedLinks', 'AttachFiles'],
    purpose: 'Builds the Roblox game and maintains bots. Posts development updates. No moderation powers.', assignedBy: 'Owner' },
  { key: 'administrator', name: 'Administrator', group: 'Staff', color: '#E74C3C', hoist: true, mentionable: false,
    permissions: ['ManageGuild', 'ManageRoles', 'ManageChannels', 'KickMembers', 'BanMembers', 'ModerateMembers', 'ManageMessages', 'ManageThreads',
      'ManageNicknames', 'ViewAuditLog', 'MentionEveryone', 'ManageEvents', 'MuteMembers', 'DeafenMembers', 'MoveMembers', 'EmbedLinks', 'AttachFiles'],
    purpose: 'Senior staff (keep to 1-3 people). Server configuration, role management, final moderation decisions. Does NOT hold the Discord "Administrator" permission.', assignedBy: 'Owner' },
  { key: 'moderator', name: 'Moderator', group: 'Staff', color: '#E67E22', hoist: true, mentionable: false,
    permissions: ['KickMembers', 'BanMembers', 'ModerateMembers', 'ManageMessages', 'ManageThreads', 'ManageNicknames', 'ViewAuditLog', 'MuteMembers', 'DeafenMembers', 'MoveMembers', 'EmbedLinks', 'AttachFiles'],
    purpose: 'Enforces the community rules, handles player reports and timeouts.', assignedBy: 'Owner, Administrator' },
  { key: 'support_team', name: 'Support Team', group: 'Staff', color: '#F1C40F', hoist: true, mentionable: true, permissions: ['EmbedLinks', 'AttachFiles'],
    purpose: 'Answers support tickets and helps new players. No moderation powers.', assignedBy: 'Owner, Administrator' },
  { key: 'economic_administrator', name: 'Economic Administrator', group: 'Staff', color: '#16A085', hoist: false, mentionable: false, permissions: ['EmbedLinks', 'AttachFiles'],
    purpose: 'Technical economy staff: corrects verified errors, runs events, reviews failed ticks. Out-of-character role, not a government office.', assignedBy: 'Owner' },

  // ---------- Government ----------
  { key: 'leader', name: 'Leader of the Revolution', group: 'Government', color: '#8B0000', hoist: true, mentionable: false, permissions: [],
    purpose: 'Head of state. Supreme political authority in roleplay. Appoints the Secretary-General and, jointly, the Secretaries.', assignedBy: 'Owner (character selection)' },
  { key: 'secretary_general', name: 'Secretary-General', group: 'Government', color: '#B22222', hoist: true, mentionable: false, permissions: [],
    purpose: 'Head of government (Secretary-General of the People\'s Committee). Coordinates the four secretariats.', assignedBy: 'Leader of the Revolution (via /roster), Administrator' },
  { key: 'secretary_internal', name: 'Secretary for Internal Affairs and Infrastructure', group: 'Government', color: '#C0392B', hoist: true, mentionable: false, permissions: [],
    purpose: 'Oversees internal administration, infrastructure, the City Police and the justice system.', assignedBy: 'Leader of the Revolution or Secretary-General (via /roster)' },
  { key: 'secretary_defence', name: 'Secretary for Defence and Foreign Affairs', group: 'Government', color: '#C0392B', hoist: true, mentionable: false, permissions: [],
    purpose: 'Oversees defence, the armed forces, the Gendarmerie and foreign relations.', assignedBy: 'Leader of the Revolution or Secretary-General (via /roster)' },
  { key: 'secretary_economy', name: 'Secretary for Economy and Education', group: 'Government', color: '#C0392B', hoist: true, mentionable: false, permissions: [],
    purpose: 'Oversees economic policy, the treasury, the central bank, AVK and education. Holds the in-game economic powers.', assignedBy: 'Leader of the Revolution or Secretary-General (via /roster)' },
  { key: 'secretary_health', name: 'Secretary for Health and Crisis Management', group: 'Government', color: '#C0392B', hoist: true, mentionable: false, permissions: [],
    purpose: 'Oversees public healthcare, EMS, the Brandwehr and crisis response.', assignedBy: 'Leader of the Revolution or Secretary-General (via /roster)' },
  { key: 'secretariat_member', name: 'Secretariat Member', group: 'Government', color: '#CD6155', hoist: false, mentionable: false, permissions: [],
    purpose: 'Staff of a government secretariat.', assignedBy: 'Secretary-General, Leader (via /roster)' },
  { key: 'government_official', name: 'Government Official', group: 'Government', color: '#D98880', hoist: true, mentionable: false, permissions: [],
    purpose: 'Civil servants and mayors in public administration. Can review business registrations.', assignedBy: 'Secretary-General, Secretary for Internal Affairs (via /roster)' },
  { key: 'congress_representative', name: 'General People\'s Congress Representative', group: 'Government', color: '#A04000', hoist: false, mentionable: false, permissions: [],
    purpose: 'Member of the General People\'s Congress (drawn from the People\'s Councils). Reviews the budget.', assignedBy: 'Secretary for Internal Affairs (via /roster), Administrator' },
  { key: 'council_member', name: 'People\'s Council Member', group: 'Government', color: '#BA4A00', hoist: false, mentionable: false, permissions: [],
    purpose: 'Local People\'s Council member (selected through trade unions and professional organisations).', assignedBy: 'Secretary for Internal Affairs (via /roster), Administrator' },

  // ---------- Justice ----------
  { key: 'judge', name: 'Judge', group: 'Justice', color: '#5D6D7E', hoist: true, mentionable: false, permissions: [],
    purpose: 'First-instance judges (mayors, "Maista") and second-instance appeal judges. Can issue and cancel fines.', assignedBy: 'Secretary for Internal Affairs (via /roster)' },
  { key: 'justice', name: 'Justice', group: 'Justice', color: '#85929E', hoist: false, mentionable: false, permissions: [],
    purpose: 'Lawyers, prosecutors (justice degree required) and court clerks.', assignedBy: 'Secretary for Internal Affairs (via /roster)' },

  // ---------- Security services ----------
  { key: 'guard_command', name: 'Revolutionary Guard Command', group: 'Security', color: '#4A235A', hoist: false, mentionable: false, permissions: [],
    purpose: 'Command of the Revolutionary Guard; oversees the Intelligence Service and sits on the Military Tribunal.', assignedBy: 'Leader of the Revolution (via /roster)' },
  { key: 'revolutionary_guard', name: 'Revolutionary Guard', group: 'Security', color: '#6C3483', hoist: true, mentionable: false, permissions: [],
    purpose: 'Protects the Leader, the Secretary-General and state facilities; investigates misconduct in the security services.', assignedBy: 'Revolutionary Guard Command (via /roster)' },
  { key: 'intelligence', name: 'Intelligence Service', group: 'Security', color: '#1B2631', hoist: false, mentionable: false, permissions: [],
    purpose: 'Serious national-security cases (terrorism, mass murder, critical infrastructure). Grants NO access to staff or moderation data.', assignedBy: 'Revolutionary Guard Command (via /roster)' },
  { key: 'gendarmerie_command', name: 'Gendarmerie Command', group: 'Security', color: '#0B5345', hoist: false, mentionable: false, permissions: [],
    purpose: 'Command of the Gendarmerie.', assignedBy: 'Secretary for Defence and Foreign Affairs (via /roster)' },
  { key: 'gendarmerie', name: 'Gendarmerie', group: 'Security', color: '#117A65', hoist: true, mentionable: true, permissions: [],
    purpose: 'Militarily organised police force; leads serious-crime (Verbrechen) cases within its jurisdiction.', assignedBy: 'Gendarmerie Command (via /roster)' },
  { key: 'armed_forces_command', name: 'Armed Forces Command', group: 'Security', color: '#4D5656', hoist: false, mentionable: false, permissions: [],
    purpose: 'Command of the Land Forces and the Air Force.', assignedBy: 'Secretary for Defence and Foreign Affairs (via /roster)' },
  { key: 'land_forces', name: 'Land Forces', group: 'Security', color: '#7D8B3A', hoist: true, mentionable: false, permissions: [],
    purpose: 'Soldiers of the Land Forces (including conscripts).', assignedBy: 'Armed Forces Command (via /roster)' },
  { key: 'air_force', name: 'Air Force', group: 'Security', color: '#5DADE2', hoist: true, mentionable: false, permissions: [],
    purpose: 'Personnel of the Air Force.', assignedBy: 'Armed Forces Command (via /roster)' },
  { key: 'police_command', name: 'City Police Command', group: 'Security', color: '#1A5276', hoist: false, mentionable: false, permissions: [],
    purpose: 'Command of the City Police.', assignedBy: 'Secretary for Internal Affairs (via /roster)' },
  { key: 'city_police', name: 'City Police', group: 'Security', color: '#2E86C1', hoist: true, mentionable: true, permissions: [],
    purpose: 'Patrols, traffic enforcement, investigations of ordinary offences. Can issue fines.', assignedBy: 'City Police Command (via /roster)' },

  // ---------- Health and civil protection ----------
  { key: 'ems_command', name: 'EMS Command', group: 'Public Services', color: '#CB4335', hoist: false, mentionable: false, permissions: [],
    purpose: 'Command of Emergency Medical Services.', assignedBy: 'Secretary for Health and Crisis Management (via /roster)' },
  { key: 'ems', name: 'EMS', group: 'Public Services', color: '#EC7063', hoist: true, mentionable: true, permissions: [],
    purpose: 'Paramedics and emergency medical staff.', assignedBy: 'EMS Command (via /roster)' },
  { key: 'brandwehr_command', name: 'Brandwehr Command', group: 'Public Services', color: '#A04000', hoist: false, mentionable: false, permissions: [],
    purpose: 'Command of the Brandwehr (fire and civil protection) and the Crisis Response Center.', assignedBy: 'Secretary for Health and Crisis Management (via /roster)' },
  { key: 'brandwehr', name: 'Brandwehr', group: 'Public Services', color: '#DC7633', hoist: true, mentionable: true, permissions: [],
    purpose: 'Firefighting, technical rescue and civil protection.', assignedBy: 'Brandwehr Command (via /roster)' },
  { key: 'avk_officer', name: 'AVK Officer', group: 'Public Services', color: '#229954', hoist: false, mentionable: false, permissions: [],
    purpose: 'Staff of AVK (Allgemeine Volksversicherung Kagundi). Reviews insurance claims.', assignedBy: 'Secretary for Economy and Education (via /roster)' },

  // ---------- Civilian and business ----------
  { key: 'business_owner', name: 'Business Owner', group: 'Civilian', color: '#27AE60', hoist: true, mentionable: false, permissions: [],
    purpose: 'Owns at least one registered business. Given and removed automatically by the bot.', assignedBy: 'Economy bot (automatic)' },
  { key: 'business_employee', name: 'Business Employee', group: 'Civilian', color: '#58D68D', hoist: false, mentionable: false, permissions: [],
    purpose: 'Employed by a registered business. Given and removed automatically by the bot.', assignedBy: 'Economy bot (automatic)' },
  { key: 'civilian', name: 'Civilian', group: 'Civilian', color: '#AAB7B8', hoist: true, mentionable: false, permissions: [],
    purpose: 'Plays civilian roleplay. Self-assigned with the button in #start-here.', assignedBy: 'Member (self-assign button)' },

  // ---------- Community ----------
  { key: 'community_member', name: 'Community Member', group: 'Community', color: '#95A5A6', hoist: false, mentionable: false, permissions: ['EmbedLinks', 'AttachFiles', 'Stream'],
    purpose: 'Established member (7+ days after verification). May post links, images and files.', assignedBy: 'Economy bot (automatic after 7 days)' },
  { key: 'verified', name: 'Verified Member', group: 'Community', color: null, hoist: false, mentionable: false, permissions: BASIC_MEMBER_PERMISSIONS,
    purpose: 'Has accepted the rules. Base access to the server.', assignedBy: 'Verification button (bot); Moderator via /mod verify' },
  { key: 'new_member', name: 'New Member', group: 'Community', color: null, hoist: false, mentionable: false, permissions: [],
    purpose: 'First 7 days after verification. Cannot post links or files yet.', assignedBy: 'Verification button (bot); removed automatically' },
  { key: 'restricted', name: 'Restricted Member', group: 'Community', color: '#7B7D7D', hoist: false, mentionable: false, permissions: [],
    purpose: 'Sanctioned member: only sees the start channels and #appeals. /mod restrict swaps Verified Member for this role.', assignedBy: 'Moderator via /mod restrict (bot)' },
];

export const ROLE_BY_KEY = Object.fromEntries(ROLES.map((r) => [r.key, r]));

// Server-wide permissions of @everyone (members who are not verified yet).
export const EVERYONE_PERMISSIONS = [];

// Who may assign which role with /roster (department leaders manage only their own department).
// Administrators and the Owner may assign every role in this list.
export const ROSTER_RIGHTS = {
  police_command: ['city_police'],
  gendarmerie_command: ['gendarmerie'],
  armed_forces_command: ['land_forces', 'air_force'],
  guard_command: ['revolutionary_guard', 'intelligence'],
  ems_command: ['ems'],
  brandwehr_command: ['brandwehr'],
  secretary_internal: ['police_command', 'judge', 'justice', 'government_official', 'congress_representative', 'council_member'],
  secretary_defence: ['gendarmerie_command', 'armed_forces_command'],
  secretary_health: ['ems_command', 'brandwehr_command'],
  secretary_economy: ['avk_officer'],
  secretary_general: ['secretariat_member', 'government_official', 'secretary_internal', 'secretary_defence', 'secretary_economy', 'secretary_health'],
  leader: ['secretary_general', 'guard_command', 'secretary_internal', 'secretary_defence', 'secretary_economy', 'secretary_health', 'secretariat_member', 'government_official'],
};

// Roles that /roster can ever manage (staff, community and automatic roles are excluded).
export const ROSTER_MANAGEABLE = ROLES.filter((r) => ['Government', 'Justice', 'Security', 'Public Services'].includes(r.group)).map((r) => r.key);
