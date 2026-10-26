// /link: connect a Discord account to a Roblox account for the Ro-Nation game.
import { confirmLink, activeLinkByDiscord, requestLinkRemoval, cancelLinkRemoval, removalEffectiveAt, LINK_RULES } from '../../economy/links.js';
import { formatKGD } from '../../economy/money.js';
import { requireVerified } from '../auth.js';
import { embed, reply, COLORS } from '../format.js';
import { command, citizen, notMaintenance } from './common.js';

const when = (iso) => `<t:${Math.floor(new Date(iso).getTime() / 1000)}:f>`;
const robloxLabel = (link) => `**${link.roblox_name ?? 'Roblox user'}** (ID ${link.roblox_user_id})`;

const link = {
  data: command('link', 'Link your Discord account to your Roblox account for the Ro-Nation game')
    .addSubcommand((s) => s.setName('confirm').setDescription('Confirm the code shown in the Ro-Nation game')
      .addStringOption((o) => o.setName('code').setDescription('The code from the game, e.g. ABCD-EFGH').setRequired(true).setMinLength(8).setMaxLength(12)))
    .addSubcommand((s) => s.setName('status').setDescription('Show which Roblox account is linked'))
    .addSubcommand((s) => s.setName('remove').setDescription(`Remove the link (takes effect after ${LINK_RULES.removalCoolingHours} hours)`))
    .addSubcommand((s) => s.setName('keep').setDescription('Cancel a requested link removal')),
  async execute(ctx, interaction) {
    const sub = interaction.options.getSubcommand();
    const eco = ctx.eco;
    const me = interaction.user.id;
    if (sub === 'confirm') {
      notMaintenance(ctx, interaction);
      // Opens the citizen record with the normal Discord rules (the starting grant can only come from here, once).
      const { grantPaid } = citizen(ctx, interaction);
      const created = confirmLink(eco, { discordId: me, code: interaction.options.getString('code') });
      return reply(interaction, { embeds: [embed({
        title: 'Accounts linked', color: COLORS.ok,
        description: `Your Discord account is now linked to the Roblox account ${robloxLabel(created)}.\n`
          + 'Your Kagundi bank account is now available in the game. Your money stays in one place: this economy.'
          + (grantPaid ? `\n\nWelcome to Kagundi! You received a one-time starting balance of ${formatKGD(grantPaid)}.` : ''),
        footer: 'Only you can see this message. Remove the link any time with /link remove.',
      })] });
    }
    requireVerified(ctx, interaction);
    if (sub === 'status') {
      const current = activeLinkByDiscord(eco, me);
      if (!current) return reply(interaction, 'Your Discord account is not linked to a Roblox account. Open the Ro-Nation game, press "Link Discord" and enter the code here with /link confirm.');
      const removal = removalEffectiveAt(current);
      return reply(interaction, `Linked to the Roblox account ${robloxLabel(current)} since ${when(current.linked_at)}.`
        + (removal ? ` Removal requested: the link ends ${when(removal)}. Keep it with /link keep.` : ''));
    }
    if (sub === 'remove') {
      const { link: current, effectiveAt } = requestLinkRemoval(eco, { discordId: me });
      return reply(interaction, `The link to ${robloxLabel(current)} will be removed ${when(effectiveAt)} (${LINK_RULES.removalCoolingHours}-hour safety delay). `
        + 'Until then it keeps working. Changed your mind? Use /link keep.');
    }
    if (sub === 'keep') {
      const current = cancelLinkRemoval(eco, { discordId: me });
      return reply(interaction, `Removal cancelled. Your link to ${robloxLabel(current)} stays active.`);
    }
  },
};

export default [link];
