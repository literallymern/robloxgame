# 04 · Ready-to-Use Messages

All texts are ready to post. They live as Markdown files in [`discord/messages/`](../messages/), one file per channel (long texts are split into two files with `order: 2`).

**How to post them:** `npm run post-messages -- --apply` posts every file into its channel, turns `#channel-name` into clickable links, attaches the flag image to the welcome message and the encyclopedia PDF to #kagundi-lore (front matter `image:` or `file:`), and posts the button panels. Running it again later *edits* the messages it posted before instead of posting duplicates, so you can change a text file and run the script again. You can also copy a text by hand: open the file and copy everything below the second `---` line.

Messages never ping `@everyone` or `@here` (checked by `test/messages.test.js`).

## Which file covers which requirement

| Requirement | File | Channel |
|---|---|---|
| Welcome message | [welcome.md](../messages/welcome.md) (with flag image) | #welcome |
| Server rules | [rules.md](../messages/rules.md), [rules-2.md](../messages/rules-2.md) | #rules |
| Verification instructions | [verify.md](../messages/verify.md) + verification button | #verify |
| Beginner guide | [start-here.md](../messages/start-here.md) + Civilian button | #start-here |
| FAQ | [faq.md](../messages/faq.md) | #faq |
| Game guide | [game-guide.md](../messages/game-guide.md) | #game-guide |
| Lore (history, flag, holidays, language) | [kagundi-encyclopedia.md](../messages/kagundi-encyclopedia.md) with the encyclopedia PDF (`assets/kagundi-encyclopedia.pdf`, built from [`encyclopedia/kagundi-encyclopedia.html`](../encyclopedia/kagundi-encyclopedia.html); the rebuild command is at the top of that file). The earlier short lore texts are kept as `_kagundi-lore.md` and `_kagundi-lore-2.md`; files starting with `_` are not posted. | #kagundi-lore |
| Government information | [government-guide.md](../messages/government-guide.md) | #government-guide |
| Recruitment message | [faction-applications.md](../messages/faction-applications.md) (top part) | #faction-applications |
| Application instructions and forms | [faction-applications.md](../messages/faction-applications.md) + application buttons (forms in `bot/src/blueprint/tickets.js`) | #faction-applications |
| Careers overview | [civilian-careers.md](../messages/civilian-careers.md) | #civilian-careers |
| Support instructions | [support.md](../messages/support.md) + support buttons | #support |
| Player report template | [player-reports.md](../messages/player-reports.md) + report button | #player-reports |
| Appeals | [appeals.md](../messages/appeals.md) + appeal button | #appeals |
| Business registration instructions | [business-registration.md](../messages/business-registration.md), [business-information.md](../messages/business-information.md) | #business-registration, #business-information |
| Business guide | [business-guide.md](../messages/business-guide.md) | #business-guide |
| Economic guide | [economy-guide.md](../messages/economy-guide.md), [economy-guide-2.md](../messages/economy-guide-2.md) | #economy-guide |
| How to use the bank commands | [bank-terminal.md](../messages/bank-terminal.md) | #bank-terminal |
| How to read the daily report | [national-economic-report.md](../messages/national-economic-report.md) | #national-economic-report |
| Commodity board explanation | [commodity-markets.md](../messages/commodity-markets.md) | #commodity-markets |
| Courts and legal services | [legal-information.md](../messages/legal-information.md) + legal button | #legal-information |

## Ticket forms

When a member presses a ticket button, the bot opens a private channel and posts the matching form. The forms are defined in [`bot/src/blueprint/tickets.js`](../bot/src/blueprint/tickets.js):

- **Support:** general help, technical problem, private exploit report
- **Player report:** player, rule, time and place, evidence
- **Appeal:** decision, who and when, reasons
- **Applications:** City Police, Gendarmerie, Land Forces / Air Force, Revolutionary Guard, EMS, Brandwehr, Justice (with the justice degree requirement), civil service, AVK officer, staff team
- **Business registry enquiry** and **court filing / lawyer request** (with the 72-hour appeal deadline)

## Templates for office holders

These channels are written by people, not by the bot. Office holders can copy these templates.

**#government-information (pin this message and edit it when offices change)**

```
**Office holders of the Democratic Republic of Kagundi**
Leader of the Revolution: Dr. Justin Wachmann
Secretary-General of the People's Committee: (vacant)
Secretary for Internal Affairs and Infrastructure: (vacant)
Secretary for Defence and Foreign Affairs: (vacant)
Secretary for Economy and Education: (vacant)
Secretary for Health and Crisis Management: (vacant)

Requests to the administration: open a post in #public-administration.
Last updated: (date)
```

**#government-announcements (Official Gazette entry)**

```
**OFFICIAL GAZETTE · No. (number)**
Issued by: (office)
Date: (date)

(Title of the law, decree or appointment)

(Text)

Signed: (character name, office)
```

**#court-announcements (published judgment, no private data)**

```
**JUDGMENT · Case (number)**
Court: (first instance, mayor of ... / second instance, Stokondo / Military Tribunal)
Parties: (character names)
Decision: (guilty / not guilty / claim granted / claim dismissed)
Sentence or order: (e.g. fine of ... KGD, issued with /fine issue)
Appeal: possible within 72 hours (real time) through #legal-information.
```

**#announcements (staff announcement)**

```
**(Title)**
(What changes, from when, and what members need to do.)
Questions: #support
— The Ro-Nation staff team
```
