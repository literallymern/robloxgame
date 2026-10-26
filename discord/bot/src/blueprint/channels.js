// Ro-Nation channel tree. Each channel declares who can see it and who can post in it.
//
// view:  'everyone'  = also visible before verification
//        'verified'  = every Verified Member
//        [roleKeys]  = only these roles (private)
// post:  'all'       = everyone who can see the channel
//        'none'      = nobody except staff/bot (read-only)
//        [roleKeys]  = only these roles
// manage: roles that may pin/delete messages and manage threads in this channel
// bot:    the economy bot needs access (posts reports, panels, logs)
// type:   text | announcement | forum | voice
//
// Administrators can see and moderate every channel. Moderators can see every channel that
// Verified Members can see plus the support and staff areas.

const GOV_CORE = ['leader', 'secretary_general', 'secretary_internal', 'secretary_defence', 'secretary_economy', 'secretary_health'];
const GOV_ALL = [...GOV_CORE, 'secretariat_member', 'government_official'];
const STAFF = ['developer', 'administrator', 'moderator', 'support_team', 'economic_administrator'];
const EMERGENCY = ['city_police', 'police_command', 'gendarmerie', 'gendarmerie_command', 'ems', 'ems_command', 'brandwehr', 'brandwehr_command'];

export const CATEGORIES = [
  {
    key: 'cat_start', name: 'START HERE',
    channels: [
      { key: 'welcome', name: 'welcome', view: 'everyone', post: 'none', bot: true, topic: 'Welcome to Ro-Nation, the Democratic Republic of Kagundi.' },
      { key: 'rules', name: 'rules', view: 'everyone', post: 'none', bot: true, topic: 'Community rules. Read them before you verify.' },
      { key: 'verify', name: 'verify', view: 'everyone', post: 'none', bot: true, topic: 'Accept the rules to unlock the server.' },
      { key: 'start_here', name: 'start-here', view: 'everyone', post: 'none', bot: true, topic: 'Beginner guide: your first steps in Kagundi, roles and channels.' },
      { key: 'faq', name: 'faq', view: 'everyone', post: 'none', bot: true, topic: 'Frequently asked questions.' },
    ],
  },
  {
    key: 'cat_announcements', name: 'ANNOUNCEMENTS',
    channels: [
      { key: 'announcements', name: 'announcements', type: 'announcement', view: 'verified', post: ['administrator'], bot: true, topic: 'Major Ro-Nation news from the staff team.' },
      { key: 'development_updates', name: 'development-updates', type: 'announcement', view: 'verified', post: ['developer', 'administrator'], bot: true, topic: 'Development progress and the changelog.' },
      { key: 'official_notices', name: 'official-notices', view: 'verified', post: ['administrator', 'moderator'], bot: true, topic: 'Server notices: maintenance, rule changes, bot status.' },
      { key: 'events', name: 'events', view: 'verified', post: ['administrator', 'moderator', 'leader', 'secretary_general'], topic: 'Community and in-game events.' },
    ],
  },
  {
    key: 'cat_community', name: 'COMMUNITY',
    channels: [
      { key: 'general', name: 'general', view: 'verified', post: 'all', topic: 'Out-of-character community chat. English only.' },
      { key: 'community_media', name: 'community-media', view: 'verified', post: 'all', topic: 'Screenshots and clips. Posting media requires the Community Member role.' },
      { key: 'suggestions', name: 'suggestions', type: 'forum', view: 'verified', post: 'all', topic: 'One suggestion per post. Search before posting.' },
      { key: 'voice_lounge', name: 'Lounge', type: 'voice', view: 'verified', post: 'all' },
    ],
  },
  {
    key: 'cat_guides', name: 'RO-NATION GUIDES',
    channels: [
      { key: 'game_guide', name: 'game-guide', view: 'verified', post: ['administrator', 'developer'], bot: true, topic: 'How to play Ro-Nation and the map of Kagundi.' },
      { key: 'kagundi_lore', name: 'kagundi-lore', view: 'verified', post: ['administrator'], bot: true, topic: 'History, society and culture of Kagundi.' },
      { key: 'civilian_careers', name: 'civilian-careers', view: 'verified', post: ['administrator'], bot: true, topic: 'Careers, factions and how to join them.' },
      { key: 'economy_guide', name: 'economy-guide', view: 'verified', post: ['administrator', 'economic_administrator'], bot: true, topic: 'Banking, jobs, property, loans and insurance.' },
      { key: 'business_guide', name: 'business-guide', view: 'verified', post: ['administrator', 'economic_administrator'], bot: true, topic: 'Founding and running a business.' },
      { key: 'government_guide', name: 'government-guide', view: 'verified', post: ['administrator'], bot: true, topic: 'How the state of Kagundi is organised.' },
    ],
  },
  {
    key: 'cat_government', name: 'KAGUNDI GOVERNMENT',
    channels: [
      { key: 'government_announcements', name: 'government-announcements', view: 'verified', post: GOV_ALL, topic: 'Official Gazette: laws, decrees and appointments.' },
      { key: 'government_information', name: 'government-information', view: 'verified', post: ['leader', 'secretary_general', 'government_official'], topic: 'Current office holders and how to reach the administration.' },
      { key: 'public_administration', name: 'public-administration', type: 'forum', view: 'verified', post: 'all', manage: GOV_ALL, topic: 'Requests to the public administration (permits, certificates, questions). One request per post.' },
      { key: 'peoples_congress', name: 'peoples-congress', view: 'verified', post: ['congress_representative', 'secretary_general', 'leader'], topic: 'Public record of the General People\'s Congress.' },
      { key: 'peoples_councils', name: 'peoples-councils', view: 'verified', post: ['council_member', 'congress_representative'], topic: 'Motions and proposals of the People\'s Councils.' },
      { key: 'government_internal', name: 'government-internal', view: GOV_ALL, post: 'all', topic: 'Internal government coordination. Confidential (in roleplay).' },
      { key: 'cabinet', name: 'cabinet', view: GOV_CORE, post: 'all', topic: 'Leader of the Revolution, Secretary-General and the four Secretaries.' },
      { key: 'voice_government', name: 'Government Chamber', type: 'voice', view: GOV_ALL, post: 'all' },
    ],
  },
  {
    key: 'cat_police', name: 'CITY POLICE',
    channels: [
      { key: 'police_briefing', name: 'police-briefing', view: ['city_police', 'police_command', 'secretary_internal'], post: ['police_command'], manage: ['police_command'], topic: 'Announcements, SOPs and training.' },
      { key: 'police_general', name: 'police-general', view: ['city_police', 'police_command'], post: 'all', manage: ['police_command'], topic: 'Internal discussion and operations.' },
      { key: 'police_command_room', name: 'police-command', view: ['police_command', 'secretary_internal'], post: 'all', topic: 'Command coordination.' },
      { key: 'voice_police', name: 'Police Radio', type: 'voice', view: ['city_police', 'police_command'], post: 'all' },
    ],
  },
  {
    key: 'cat_gendarmerie', name: 'GENDARMERIE',
    channels: [
      { key: 'gendarmerie_briefing', name: 'gendarmerie-briefing', view: ['gendarmerie', 'gendarmerie_command', 'secretary_defence'], post: ['gendarmerie_command'], manage: ['gendarmerie_command'], topic: 'Announcements, SOPs and training.' },
      { key: 'gendarmerie_general', name: 'gendarmerie-general', view: ['gendarmerie', 'gendarmerie_command'], post: 'all', manage: ['gendarmerie_command'], topic: 'Internal discussion and operations.' },
      { key: 'gendarmerie_command_room', name: 'gendarmerie-command', view: ['gendarmerie_command', 'secretary_defence'], post: 'all', topic: 'Command coordination.' },
      { key: 'voice_gendarmerie', name: 'Gendarmerie Radio', type: 'voice', view: ['gendarmerie', 'gendarmerie_command'], post: 'all' },
    ],
  },
  {
    key: 'cat_armed_forces', name: 'ARMED FORCES',
    channels: [
      { key: 'armed_forces_briefing', name: 'armed-forces-briefing', view: ['land_forces', 'air_force', 'armed_forces_command', 'secretary_defence'], post: ['armed_forces_command'], manage: ['armed_forces_command'], topic: 'Orders, SOPs and training for Land Forces and Air Force.' },
      { key: 'land_forces_general', name: 'land-forces', view: ['land_forces', 'armed_forces_command'], post: 'all', manage: ['armed_forces_command'], topic: 'Land Forces internal.' },
      { key: 'air_force_general', name: 'air-force', view: ['air_force', 'armed_forces_command'], post: 'all', manage: ['armed_forces_command'], topic: 'Air Force internal.' },
      { key: 'armed_forces_command_room', name: 'armed-forces-command', view: ['armed_forces_command', 'secretary_defence'], post: 'all', topic: 'Command coordination and operational planning.' },
      { key: 'voice_military', name: 'Military Comms', type: 'voice', view: ['land_forces', 'air_force', 'armed_forces_command'], post: 'all' },
    ],
  },
  {
    key: 'cat_guard', name: 'REVOLUTIONARY GUARD',
    channels: [
      { key: 'guard_briefing', name: 'guard-briefing', view: ['revolutionary_guard', 'guard_command', 'leader'], post: ['guard_command'], manage: ['guard_command'], topic: 'Orders, SOPs and training.' },
      { key: 'guard_general', name: 'guard-general', view: ['revolutionary_guard', 'guard_command'], post: 'all', manage: ['guard_command'], topic: 'Internal discussion and protection details.' },
      { key: 'guard_command_room', name: 'guard-command', view: ['guard_command', 'leader'], post: 'all', topic: 'Command coordination.' },
      { key: 'intelligence_secure', name: 'intelligence-secure', view: ['intelligence', 'guard_command', 'leader'], post: 'all', manage: ['guard_command'], topic: 'Intelligence Service. Need-to-know only.' },
      { key: 'voice_guard', name: 'Guard Secure Line', type: 'voice', view: ['revolutionary_guard', 'guard_command', 'intelligence'], post: 'all' },
    ],
  },
  {
    key: 'cat_justice', name: 'JUSTICE',
    channels: [
      { key: 'legal_information', name: 'legal-information', view: 'verified', post: ['judge', 'secretary_internal'], bot: true, topic: 'Laws, court procedure and legal services. Use the buttons to file a case or request a lawyer.' },
      { key: 'court_announcements', name: 'court-announcements', view: 'verified', post: ['judge', 'justice'], topic: 'Hearing schedule and published judgments (no private data).' },
      { key: 'judicial_administration', name: 'judicial-administration', view: ['judge', 'justice', 'secretary_internal'], post: 'all', manage: ['judge'], topic: 'Private judicial administration.' },
      { key: 'case_coordination', name: 'case-coordination', view: ['judge', 'justice'], post: 'all', manage: ['judge'], topic: 'Case coordination. Use one private thread per case.' },
      { key: 'military_tribunal', name: 'military-tribunal', view: ['guard_command', 'leader'], post: 'all', manage: ['guard_command'], topic: 'Military Tribunal (military offences and state-security crimes).' },
      { key: 'voice_courtroom', name: 'Courtroom', type: 'voice', view: 'verified', post: 'all', manage: ['judge'] },
    ],
  },
  {
    key: 'cat_emergency', name: 'HEALTH & CIVIL PROTECTION',
    channels: [
      { key: 'joint_dispatch', name: 'joint-dispatch', view: EMERGENCY, post: 'all', topic: 'Shared emergency dispatch for Police, Gendarmerie, EMS and Brandwehr.' },
      { key: 'crisis_response_center', name: 'crisis-response-center', view: ['secretary_health', 'ems_command', 'brandwehr_command', 'police_command', 'gendarmerie_command', 'secretary_general', 'leader'], post: 'all', topic: 'Crisis Response Center (Gundiville): coordination of major incidents.' },
      { key: 'ems_briefing', name: 'ems-briefing', view: ['ems', 'ems_command', 'secretary_health'], post: ['ems_command'], manage: ['ems_command'], topic: 'EMS announcements, SOPs and training.' },
      { key: 'ems_general', name: 'ems-general', view: ['ems', 'ems_command'], post: 'all', manage: ['ems_command'], topic: 'EMS internal.' },
      { key: 'ems_command_room', name: 'ems-command', view: ['ems_command', 'secretary_health'], post: 'all', topic: 'EMS command.' },
      { key: 'brandwehr_briefing', name: 'brandwehr-briefing', view: ['brandwehr', 'brandwehr_command', 'secretary_health'], post: ['brandwehr_command'], manage: ['brandwehr_command'], topic: 'Brandwehr announcements, SOPs and training.' },
      { key: 'brandwehr_general', name: 'brandwehr-general', view: ['brandwehr', 'brandwehr_command'], post: 'all', manage: ['brandwehr_command'], topic: 'Brandwehr internal.' },
      { key: 'brandwehr_command_room', name: 'brandwehr-command', view: ['brandwehr_command', 'secretary_health'], post: 'all', topic: 'Brandwehr command.' },
      { key: 'voice_emergency', name: 'Emergency Radio', type: 'voice', view: EMERGENCY, post: 'all' },
    ],
  },
  {
    key: 'cat_civilian_economy', name: 'CIVILIAN ECONOMY',
    channels: [
      { key: 'business_information', name: 'business-information', view: 'verified', post: ['secretary_economy', 'government_official', 'economic_administrator'], bot: true, topic: 'Business registry notices and rules for companies.' },
      { key: 'employment', name: 'employment', type: 'forum', view: 'verified', post: 'all', bot: true, topic: 'Job offers and people looking for work. One post per offer. The bot posts new job postings automatically.' },
      { key: 'property_market', name: 'property-market', type: 'forum', view: 'verified', post: 'all', topic: 'Property for rent or sale. One post per property.' },
      { key: 'trade_and_commerce', name: 'trade-and-commerce', view: 'verified', post: 'all', topic: 'In-character trade, contracts and advertising.' },
      { key: 'bank_terminal', name: 'bank-terminal', view: 'verified', post: 'none', bot: true, topic: 'Use the economy commands here (/bank, /work, /jobs, /business ...). Private results are only visible to you.' },
    ],
  },
  {
    key: 'cat_economic_sim', name: 'ECONOMIC SIMULATION',
    channels: [
      { key: 'national_economic_report', name: 'national-economic-report', view: 'verified', post: 'none', bot: true, topic: 'Official daily National Economic Report (00:00 Europe/Berlin).' },
      { key: 'commodity_markets', name: 'commodity-markets', view: 'verified', post: 'none', bot: true, topic: 'Daily commodity price board.' },
      { key: 'economic_announcements', name: 'economic-announcements', view: 'verified', post: ['secretary_economy', 'secretary_general', 'leader', 'economic_administrator'], bot: true, topic: 'Economic policy, events and Central Bank decisions.' },
      { key: 'economic_administration', name: 'economic-administration', view: ['economic_administrator', 'secretary_economy', 'secretary_general', 'leader'], post: 'all', bot: true, topic: 'Treasury, budget and central bank coordination.' },
      { key: 'avk_office', name: 'avk-office', view: ['avk_officer', 'secretary_economy', 'economic_administrator'], post: 'all', bot: true, topic: 'AVK claims processing.' },
    ],
  },
  {
    key: 'cat_support', name: 'SUPPORT & APPLICATIONS',
    channels: [
      { key: 'support', name: 'support', view: 'verified', post: 'none', bot: true, topic: 'Open a private support ticket with the buttons below.' },
      { key: 'bug_reports', name: 'bug-reports', type: 'forum', view: 'verified', post: 'all', manage: ['developer'], topic: 'Public bug reports. Exploits must be reported privately through #support.' },
      { key: 'player_reports', name: 'player-reports', view: 'verified', post: 'none', bot: true, topic: 'Report a rule break privately.' },
      { key: 'appeals', name: 'appeals', view: ['verified', 'restricted'], post: 'none', bot: true, topic: 'Appeal a moderation decision privately.' },
      { key: 'faction_applications', name: 'faction-applications', view: 'verified', post: 'none', bot: true, topic: 'Apply to a faction, public office or the staff team.' },
      { key: 'business_registration', name: 'business-registration', view: 'verified', post: 'none', bot: true, topic: 'How to register a business. Run /business register in #bank-terminal.' },
    ],
  },
  {
    key: 'cat_tickets', name: 'TICKETS', tickets: true,
    channels: [],
  },
  {
    key: 'cat_staff', name: 'STAFF',
    channels: [
      { key: 'staff_announcements', name: 'staff-announcements', view: STAFF, post: ['administrator'], topic: 'Staff announcements.' },
      { key: 'staff_chat', name: 'staff-chat', view: STAFF, post: 'all', topic: 'Staff discussion.' },
      { key: 'moderation_log', name: 'moderation-log', view: ['administrator', 'moderator'], post: 'none', bot: true, topic: 'AutoMod alerts and moderation actions.' },
      { key: 'incident_reports', name: 'incident-reports', view: ['administrator', 'moderator', 'support_team'], post: 'all', topic: 'Write-ups of moderation incidents.' },
      { key: 'appeals_review', name: 'appeals-review', view: ['administrator', 'moderator'], post: 'all', topic: 'Internal discussion of appeals.' },
      { key: 'economy_audit_log', name: 'economy-audit-log', view: ['administrator', 'economic_administrator'], post: 'none', bot: true, topic: 'Automatic log of sensitive economic and administrative actions.' },
      { key: 'ticket_transcripts', name: 'ticket-transcripts', view: ['administrator'], post: 'none', bot: true, topic: 'Transcripts of deleted tickets.' },
      { key: 'bot_alerts', name: 'bot-alerts', view: ['developer', 'administrator', 'economic_administrator'], post: 'none', bot: true, topic: 'Bot errors and failed economic ticks.' },
      { key: 'technical_config', name: 'technical-config', view: ['developer', 'administrator'], post: 'all', topic: 'Bot and game configuration notes. Never post tokens or passwords.' },
      { key: 'voice_staff', name: 'Staff Voice', type: 'voice', view: STAFF, post: 'all' },
    ],
  },
];

export const CHANNELS = CATEGORIES.flatMap((cat) => cat.channels.map((ch) => ({ ...ch, type: ch.type ?? 'text', category: cat.key })));
export const CHANNEL_BY_KEY = Object.fromEntries(CHANNELS.map((c) => [c.key, c]));
export const CATEGORY_BY_KEY = Object.fromEntries(CATEGORIES.map((c) => [c.key, c]));
