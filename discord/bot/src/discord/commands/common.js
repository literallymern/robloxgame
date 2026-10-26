// Shared helpers for slash commands.
import { InteractionContextType, SlashCommandBuilder } from 'discord.js';
import { ensureCitizen } from '../../economy/citizens.js';
import { parseAmount, toMinor } from '../../economy/money.js';
import { isMaintenance } from '../../economy/admin.js';
import { businessesForUser, searchBusinesses } from '../../economy/businesses.js';
import { UserError } from '../../economy/errors.js';
import { COMMODITIES, PARTNERS, INDUSTRIES, AVK_PRODUCTS, BUDGET_CATEGORIES, CITIES } from '../../economy/constants.js';
import { requireVerified, memberRoleKeys, isOwner } from '../auth.js';

export function command(name, description) {
  return new SlashCommandBuilder().setName(name).setDescription(description).setContexts(InteractionContextType.Guild);
}

export function displayName(interaction) {
  return interaction.member?.displayName ?? interaction.member?.nick ?? interaction.user.globalName ?? interaction.user.username;
}

// Registers the caller as a citizen (first use) and returns the citizen record.
export function citizen(ctx, interaction) {
  requireVerified(ctx, interaction);
  const ageDays = (Date.now() - interaction.user.createdTimestamp) / 86_400_000;
  const keys = memberRoleKeys(ctx, interaction.member);
  const grantEligible = keys.includes('verified') && ageDays >= ctx.config.grantMinAccountAgeDays;
  return ensureCitizen(ctx.eco, { userId: interaction.user.id, displayName: displayName(interaction), grantEligible });
}

// Blocks state-changing commands while the Owner has switched on maintenance mode.
export function notMaintenance(ctx, interaction) {
  if (isMaintenance(ctx.eco) && !isOwner(ctx, interaction.user.id, interaction.member)) {
    throw new UserError('The economy is in maintenance mode. Please try again later.');
  }
}

export function amountOption(interaction, name = 'amount', { required = true, max } = {}) {
  const value = interaction.options.getNumber(name, required);
  if (value === null) return null;
  return parseAmount(value, max ? { max } : undefined);
}

// Like amountOption, but 0 is allowed (rents, budgets, fees).
export function amountOrZero(interaction, name) {
  const minor = toMinor(interaction.options.getNumber(name, true));
  if (minor < 0) throw new UserError('The amount cannot be negative.');
  return minor;
}

// Reads an ID from a string option filled by autocomplete (e.g. "12" or "#12").
export function idOption(interaction, name, required = true) {
  const raw = interaction.options.getString(name, required);
  if (raw === null || raw === undefined) return null;
  const n = Number(String(raw).replace(/^#/, ''));
  if (!Number.isInteger(n) || n <= 0) throw new UserError(`Invalid ${name}. Pick an entry from the list.`);
  return n;
}

// Autocomplete: businesses the user owns or manages.
export function autocompleteMyBusinesses(ctx, interaction) {
  const focused = String(interaction.options.getFocused() ?? '').toLowerCase();
  return businessesForUser(ctx.eco, interaction.user.id)
    .filter((b) => b.name.toLowerCase().includes(focused))
    .slice(0, 25)
    .map((b) => ({ name: `${b.name} (#${b.id}, ${b.access})`.slice(0, 100), value: String(b.id) }));
}

// Autocomplete: any active business.
export function autocompleteAnyBusiness(ctx, interaction) {
  const focused = String(interaction.options.getFocused() ?? '');
  return searchBusinesses(ctx.eco, focused).map((b) => ({ name: `${b.name} (#${b.id})`.slice(0, 100), value: String(b.id) }));
}

export const commodityChoices = (filter = () => true) => Object.values(COMMODITIES).filter(filter).map((c) => ({ name: `${c.name} (${c.unit})`, value: c.key }));
export const partnerChoices = () => Object.values(PARTNERS).map((p) => ({ name: p.name, value: p.key }));
export const industryChoices = () => Object.values(INDUSTRIES).map((i) => ({ name: i.name, value: i.key }));
export const productChoices = () => Object.values(AVK_PRODUCTS).map((p) => ({ name: p.name.slice(0, 100), value: p.key }));
export const budgetChoices = () => Object.entries(BUDGET_CATEGORIES).map(([value, name]) => ({ name, value }));
export const cityChoices = () => CITIES.map((c) => ({ name: c, value: c }));
