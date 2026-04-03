# Reply to App Review – Ҳуқуқи ронанда (Version 2.0)

**Copy the text below into App Store Connect → Your App → Resolution Center → Reply to App Review.**

---

Hello,

Thank you for your feedback. We have updated the app and would like to address each point as follows.

---

## Guideline 5.1.1(v) – Data Collection and Storage (Account Deletion)

**The app already supports full account deletion.**

**Where to find it:**
1. Open the app and go to **Profile** (tap the person icon in the top-right corner of the Home screen).
2. Sign in if you are not already signed in (account deletion is available only when the user is logged in).
3. Scroll to the bottom of the Profile screen.
4. Tap the red button: **"Нест кардани ҳисоб (Delete Account)"**.
5. Confirm in the dialog. The app then calls our backend `DELETE /auth/profile/` and permanently deletes the user account and all associated data from our servers. The user is returned to the login screen.

We have added the English label “(Delete Account)” next to the Tajik text so the feature is easy to locate during review. This is a permanent deletion, not a temporary deactivation.

---

## Guideline 3.1.1 – Business – Payments (In-App Purchase)

**On the iOS version of the app, we do not offer any in-app purchase or any other in-app payment mechanism.**

- The iOS build does **not** allow users to buy digital content, subscriptions, or premium chapters inside the app.
- There are no payment forms, no “top up balance” flows, and no links to external payment pages (e.g. SmartPay, DC Bank, Alif) for purchasing content on iOS.
- If an iOS user taps any area that would have led to a subscription or payment on other platforms (e.g. “Full access” or “Subscribe”), they see only an informational message: they may contact our support team via Telegram for further assistance. This is a **contact/support** flow, not a purchase flow. No digital content is sold or unlocked via this link.
- Any paid digital content or subscriptions are offered only on our other platforms (e.g. Android/Web), not within the iOS app. The iOS app provides only free, readable content and learning features.

We believe this complies with Guideline 3.1.1 for the iOS App Store. If you need any clarification, we are happy to provide it.

---

## Guideline 4.2 – Design – Minimum Functionality (“App is primarily a book”)

**Our app is not a static book. It is an interactive learning and training application for driving rules and road safety.**

- **Structured learning:** Content is organized by chapters with progress tracking (e.g. “X of Y chapters accessible”).
- **Interactive practice tests:** The app includes an exam/test mode where users can practice with questions and check their knowledge.
- **In-app search:** Users can search within the content (e.g. by keywords).
- **User accounts and profile:** Optional sign-in, profile editing, and (as noted above) full account deletion.
- **Offline access:** Cached content for use without an internet connection.

We are not distributing a single static book in EPUB or PDF form. The app is a dedicated learning tool (similar to training or exam-preparation apps) and is not intended for Apple Books. We believe it meets the minimum functionality expectations for the App Store.

We have submitted an updated build and would be grateful if you could review it again with the above in mind.

Thank you for your time and consideration.

Best regards,

[Your name / Team name]
