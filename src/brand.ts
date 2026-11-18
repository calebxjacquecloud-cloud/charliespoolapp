/**
 * Everything specific to Charlie's Big Stick Energy night lives here, so the
 * rest of the app stays bar-neutral. Change times or wording in one place.
 */
export const BRAND = {
  bar: "Charlie's",
  city: 'Denver',
  event: 'Big Stick Energy',
  /** Short label under the logo and in titles. */
  eventShort: 'Big Stick Energy',
  address: '900 E. Colfax Ave, Denver, CO 80218 · 21+',
  schedule: 'Last Wednesday of every month',
  registration: '6:30pm',
  start: '7:00pm',
  /** Day of the week the tournament runs (0 = Sunday ... 3 = Wednesday). */
  weekday: 3,
  weekdayName: 'Wednesday',
  details: '$5 buy-in · 1 vs 1 · 1st & 2nd place win cash & gift cards',
  hostedBy: 'MJ',
  /** Prefix for this app's saved browser data, so it never mixes with another app. */
  storagePrefix: 'charlies-bse',
} as const;

/** "Registration 6:30pm · Tournament 7:00pm" */
export const TIMES = `Registration ${BRAND.registration} · Tournament ${BRAND.start}`;
