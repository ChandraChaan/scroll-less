# Data safety form – answers

Play Console → Policy → App content → Data safety.

## Overview questions

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** (crash logs and diagnostics only) |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (Crashlytics uses HTTPS) |
| Do you provide a way for users to request that their data is deleted? | **Yes** – uninstalling removes all local data; crash data can be deleted on request via the contact email. Point the "deletion" field at https://scroll-less-chandra.web.app/privacy |
| Does your app comply with Google Play Families policy? | Not targeting children (select "No, my app does not target children") |

## Data types

Only one group applies. Everything else (location, personal info, financial, health, messages, photos, audio, files, calendar, contacts, app activity, web browsing, app info and performance → *app interactions*, device IDs) is **not collected**.

| Category | Data type | Collected? | Shared? | Processed ephemerally? | Required or optional | Purpose |
| --- | --- | --- | --- | --- | --- | --- |
| App info and performance | **Crash logs** | Yes | No* | No | Required | App functionality (bug fixes) |
| App info and performance | **Diagnostics** | Yes | No* | No | Required | App functionality (bug fixes) |
| Device or other IDs | **Device or other IDs** (Crashlytics installation ID) | Yes | No* | No | Required | App functionality (bug fixes) |

\* Crashlytics is a service provider processing data on the developer's behalf, which Play treats as "not shared".

Note on the Accessibility API: the on-screen text of Instagram and YouTube is processed on-device and **never collected** (never stored in raw form, never transmitted). Play's definition of "collected" is data transmitted off the device, so it does not need to be declared as a collected data type. Mention this in the Accessibility declaration (see `permissions_declaration.md`).

## Security practices

| Practice | Answer |
| --- | --- |
| Data is encrypted in transit | Yes |
| You can request that data be deleted | Yes |
| Committed to follow the Play Families policy | No (not a children's app) |
| Independent security review | No |
