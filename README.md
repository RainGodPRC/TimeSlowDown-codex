# TimeSlowDown Codex

Codex branch public demo for TimeSlowDown.

Core thesis: a time-slicing app that helps users keep concrete memory points, then compile them into tellable weekly stories.

Public demo: https://raingodprc.github.io/TimeSlowDown-codex/

Current demo focus:

- Quick Mark → today slice
- Claim 3 moments → editable weekly chapter
- Semantic zoom meadow: day / week / month / year / life
- Memory vault: local-first export, demo import, and delete controls
- 90-day recall ritual: free recall, quarter landscape, tellable moments
- Public trial guide: what to try, what is PoC, and what remains production work
- AI/sync boundary map: local rules, DeepSeek PoC, BYOK, E2EE, export/delete rights
- AI task sheet and off-device ledger: what leaves, what never leaves, fallback, revoke
- Model gateway console: provider status, task queue, cost budget, fallback, consent revoke
- Sync console: encrypted-backup demo, pause/resume sync, cancellation recovery window
- Account rights center: guest pass, recovery key, device review, non-hostage subscription, and copyable account report
- Review center: permissions, privacy-label draft, tester FAQ, production checklist
- Visual share studio: weekly poster, 90-day card, life meadow card, public/private copy, PNG export, and Web Share fallback
- Media memory anchors: attach photo/video files, external media links, and notes when creating a slice or later when reviewing existing slices
- Media memory wall: filter bound media by image/video/link and browse a recall timeline
- Media-first Quick Mark: start a slice directly from a photo/video, then optionally add text later
- Memory Camera entry: a top dock, bottom floating `+ image` action, and visible photo/video CTAs make image-first capture a primary mobile path
- Global media dock: a visible photo/video entry is available before text so users can anchor a moment first and write later
- Retroactive media attach: add or replace a photo/video anchor from a weekly review card so memory is not forced to rely on text alone
- People/place lens: regroup slices by user-written people and places without contacts, GPS, or face recognition
- Media vault path: Photos permission strategy, E2EE layers, thumbnails, export package, delete audit, family media review, and Web Share boundaries
- Install center: inline manifest, iOS web-app meta, app-like shell detection, and copyable install instructions
- Launch readiness center: production preflight ledger, export checksum, deletion receipt, App Store review packet, and copyable launch report
- Native handoff ledger: SwiftUI shell, PhotosPicker, Keychain/E2EE, DeepSeek gateway, App Privacy Details, Privacy Manifest, required reason API, and TestFlight packet checklist
- App Store submission packet: product page copy, screenshot/app preview plan, privacy questionnaire, age rating, review notes, support/privacy URLs, and subscription wording
- Native Core Kit: a Swift package under `ios/TimeSlowDownNative` that starts the real iOS core with memory slices, media anchors, weekly chapters, privacy boundaries, SwiftUI shell state, PhotosPicker bridge, Native Handoff rows, and Submission Packet rows
- Xcode project skeleton: `ios/TimeSlowDownNative/TimeSlowDown.xcodeproj` wires a native iOS app target to `TimeSlowDownKit`, Info.plist, Privacy Manifest, entitlements, launch screen, and App Icon asset catalog for the next Xcode/TestFlight handoff
- App Store launch asset packet: deterministic App Icon PNGs, TestFlight build notes, App Review route, signing readiness plan, and launch asset checklist are now Swift-verifiable while real archive/upload remains a full-Xcode task
- Production Trust contracts: Swift stubs for Keychain-shaped device keys, metadata-only E2EE envelopes, export manifest signatures, deletion receipts, and DeepSeek task envelopes keep privacy/export/delete/AI boundaries testable before the real backend exists
- Implementation adapters: Keychain persistence plan, DeepSeek backend request plan, export ZIP archive plan, and deletion receipt API request plan turn the trust contracts into concrete engineering handoff points
- Keychain production adapter: a Security.framework-backed device key record store can save/load/delete metadata-only key records with this-device-only, non-synchronizable defaults; automated checks verify the adapter contract without writing to the user's Keychain
- Mobile UI polish: clearer CTA hierarchy, softer card surfaces, tactile buttons, right-side Memory Camera FAB, and app-like bottom navigation
- Top-app DNA: Bento home cards, Journal-style media timeline, photo wall, and map-style media switching inspired by the strengths of Day One, Diarly, Craft, and Apple Journal
- Production privacy center: data lifecycle, permission ladder, processing boundaries, and copyable privacy report
- Demo QA Console: public-trial smoke route, pass/PoC/todo checklist, and copyable QA report

Native core verification:

```bash
cd ios/TimeSlowDownNative
swift build
swift run TimeSlowDownNativeChecks
swift build --product TimeSlowDownAppPreview
plutil -lint TimeSlowDown.xcodeproj/project.pbxproj AppStore/Info.plist AppStore/PrivacyInfo.xcprivacy AppStore/TimeSlowDown.entitlements
python3 -m json.tool TimeSlowDownApp/Assets.xcassets/Contents.json >/dev/null
python3 -m json.tool TimeSlowDownApp/Assets.xcassets/AppIcon.appiconset/Contents.json >/dev/null
python3 -m json.tool TimeSlowDownApp/Assets.xcassets/AccentColor.colorset/Contents.json >/dev/null
xmllint --noout TimeSlowDownApp/Base.lproj/LaunchScreen.storyboard
```

Current native limitation: this machine has Swift CLI but not full Xcode, so the repository can verify SwiftPM, plist/project syntax, and static Xcode handoff contracts here; archive, signing, simulator, and TestFlight must run on a full Xcode installation with an Apple Developer team.
