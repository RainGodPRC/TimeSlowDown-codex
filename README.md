# TimeSlowDown Codex

Codex branch public demo for TimeSlowDown.

Core thesis: a time-slicing app that helps users keep concrete memory points, then compile them into tellable weekly stories.

Public demo: https://raingodprc.github.io/TimeSlowDown-codex/

Current demo focus:

- P0 Daily Loop: the home screen now turns Daily Difference Radar candidates into real slices and shows 90-day tellable progress toward the north-star target of 5–10 vivid memories
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
- App Store submission packet: product page copy, screenshot/app preview plan, screenshot/App Preview creative packet, privacy questionnaire, age rating, review notes, support/privacy URLs, and subscription wording
- Native Core Kit: a Swift package under `ios/TimeSlowDownNative` that starts the real iOS core with memory slices, media anchors, weekly chapters, privacy boundaries, SwiftUI shell state, PhotosPicker bridge, Native Handoff rows, and Submission Packet rows
- Xcode project skeleton: `ios/TimeSlowDownNative/TimeSlowDown.xcodeproj` wires a native iOS app target to `TimeSlowDownKit`, Info.plist, Privacy Manifest, entitlements, launch screen, and App Icon asset catalog for the next Xcode/TestFlight handoff
- App Store launch asset packet: deterministic App Icon PNGs, TestFlight build notes, App Review route, signing readiness plan, and launch asset checklist are now Swift-verifiable while real archive/upload remains a full-Xcode task
- Production Trust contracts: Swift stubs for Keychain-shaped device keys, metadata-only E2EE envelopes, export manifest signatures, deletion receipts, and DeepSeek task envelopes keep privacy/export/delete/AI boundaries testable before the real backend exists
- Implementation adapters: Keychain persistence plan, DeepSeek backend request plan, export ZIP archive plan, and deletion receipt API request plan turn the trust contracts into concrete engineering handoff points
- Keychain production adapter: a Security.framework-backed device key record store can save/load/delete metadata-only key records with this-device-only, non-synchronizable defaults; automated checks verify the adapter contract without writing to the user's Keychain
- On-device export ZIP builder: memory exports can be assembled into a standard ZIP container with manifest, slices, chapters, media index, and deletion-rights documents while keeping raw media and AI transcripts out by default
- Native export UI state: Account Rights can trigger a local memory ZIP export and show a rights-safe summary before the future Files/share-sheet integration exists
- System file exporter bridge: the native shell wraps the ZIP package as a SwiftUI `FileDocument` for the future Files/share-sheet export flow without claiming signed-device validation yet
- Raw media export policy envelope: optional original photo/video export now has a Swift-verifiable opt-in contract with thumbnails-only default, consent receipt, media manifest, encrypted staged Files export, family media caution, no cloud/provider upload, no AI transcripts, and post-subscription access
- Raw media staged export builder: selected photo/video originals can now be written into a local staged ZIP package only after explicit consent, while thumbnail-only exports exclude provided original bytes and unselected originals stay out of the package
- Photos-library byte import adapter: user-selected media bytes can now become `RawMediaAssetPayload` for staged export through a limited-library, user-initiated import boundary that forbids full-library scans, GPS inference, face recognition, cloud upload, and unconsented originals
- E2EE media vault adapter: imported media payloads can now be sealed into local ciphertext records, unsealed for consented export, and deleted with a receipt boundary without plaintext persistence, AI/provider access, or subscription-hostage behavior
- CryptoKit media vault envelope contract: the native trust layer now defines the production path from the v51 vault record to a CryptoKit AES.GCM envelope with Secure Enclave key agreement, HKDF, random nonce, AAD, no plaintext/CEK persistence, and signed-device validation still required
- Secure Enclave device-key contract: the native trust layer now defines the production request and reference receipt for non-extractable P256 media-vault keys with this-device-only Keychain metadata, user presence, no software fallback, no private-key bytes in app data/repo/payloads, and signed-device validation still required
- Signed-device Keychain validation scaffold: the native trust layer now defines the physical-device validation plan and honest pending receipt for Secure Enclave key generation, public-key digest capture, metadata-only Keychain save/load, access-control challenge, wrong-device rejection, and deletion without claiming production validation on this SwiftPM host
- Deletion API audit envelope: account deletion requests now have a Swift-verifiable client envelope with idempotency headers, export-before-delete evidence, response contract, and raw-memory-free privacy review boundaries
- DeepSeek server gateway envelope: AI weekly chapter requests now have a Swift-verifiable backend handoff contract with consent receipt, idempotency, budget ceiling, short retention, user-region policy, mockable responses, and no provider key exposure to the client
- DeepSeek provider validation scaffold: the native trust layer now distinguishes pending backend, mock gateway, and real provider-passed receipts for `deepseek-v4-flash`, keeping provider credentials server-side and preventing mock success from unlocking production AI or App Store gates
- DeepSeek integration test runner contract: the native trust layer now defines redacted backend test requests, provider result evidence, mock-result rejection, and provider-pass receipt promotion rules so future deployed gateway tests can prove real `deepseek-v4-flash` round trips without exposing provider credentials, raw media, or full archives
- DeepSeek backend endpoint/provider proxy contract: the native trust layer now defines the future `/v1/ai/tasks/weekly-chapter` service boundary, requiring auth, consent, idempotency, task digest, budget, short retention, user-region policy, server-secret-manager credentials, minimal provider messages, editable draft/source-trace responses, and no provider key/raw media/full archive/contacts/GPS/face embeddings/subscription state crossing the backend/provider boundary
- DeepSeek endpoint execution harness: the native trust layer now executes the backend endpoint/gateway/provider-proxy safety gates locally, proving auth/consent/idempotency/task digest/budget/forbidden-field checks while ensuring local stubs and provider-required receipts never unlock production AI or App Store gates
- DeepSeek live backend probe: native checks can optionally POST a minimal weekly-chapter payload to a configured TSD backend with `TSD_DEEPSEEK_BACKEND_BASE_URL` and `TSD_DEEPSEEK_TEST_TOKEN`, parse the real provider response, and promote it through the same provider-pass receipt gate without ever accepting a client-side DeepSeek key
- Deletion service integration boundary: account deletion now has a Swift-verifiable backend job contract covering export opportunity, reauthentication, write freeze, encrypted backup/AI draft/thumbnail erasure, tombstones, per-system results, and downloadable completion receipt boundaries
- Deletion service live probe: native checks can optionally POST a test-account deletion payload to a configured TSD backend with `TSD_DELETION_BACKEND_BASE_URL` and `TSD_DELETION_TEST_TOKEN`, then require real job, audit, tombstone, per-system erasure, and downloadable receipt evidence before production deletion gates can pass
- App Store submission gate: native checks now aggregate the commercial release blockers into a single Swift-verifiable gate covering full Xcode, Team ID, archive, TestFlight upload, support/privacy URLs, App Privacy questionnaire, screenshot/App Preview assets, Privacy Manifest required reason API review, encryption export compliance, 12+ age-rating review, signed-device Keychain/Photos/Files receipts, DeepSeek provider evidence, and deletion completion evidence
- Public URL packet: the public demo now exposes HTTPS deep links for support, privacy, export rights, deletion rights, subscription rights, and the App Review route; native checks verify the URL packet shape while final legal/company support review remains a release blocker
- Backend release manifest: native checks now require a real HTTPS TSD backend manifest, server-side DeepSeek secret manager, weekly chapter endpoint, deletion jobs endpoint, audit/deletion worker boundaries, live provider receipt, completed deletion receipt, and deployment review before backend release gates can pass
- App Privacy questionnaire packet: native checks now map TSD user content, photo/video anchors, account identifiers, purchases, diagnostics, minimal AI task payloads, and optional encrypted sync into a machine-checkable App Store privacy-answer packet while keeping final App Store Connect entry and legal/release review blocked
- Age Rating review packet: native checks now map private memory/media UGC, no public social feed, no Kids Category claim, bounded AI editing, external links, purchases, no gambling/medical/harm content, and support path into a machine-checkable age-rating packet while keeping final App Store Connect/legal review blocked
- Signed-device media validation packet: native checks now define honest pending/pass receipt shapes for limited-library Photos import and Files/share ZIP export, while keeping final Photos/Files release gates blocked until a real signed physical-device pass exists
- Archive/signing readiness packet: native checks now define honest pending/pass receipt shapes for full Xcode, Apple Developer Team, Release archive, Transporter upload, and App Store Connect processing, while keeping real archive/TestFlight gates blocked until a production receipt exists
- App Store metadata/legal review packet: native checks now map product page positioning, screenshots/app preview, review notes, support/privacy/data-rights URLs, subscription wording, AI disclosure, and legal/release checklist into a machine-checkable metadata packet while keeping final App Store Connect entry and legal/release review blocked
- Privacy Manifest required reason API audit packet: native checks now audit current shipping-target use of Apple required reason API categories, keep the current `PrivacyInfo.xcprivacy` no-tracking/no-collected-data/no-accessed-API shape honest for the local app path, and keep the final full-Xcode privacy report/dependency-manifest/release-review gate blocked
- Encryption export compliance review packet: native checks now conservatively declare encryption use in `Info.plist`, map CryptoKit AES.GCM, Secure Enclave, Keychain metadata, encrypted media vault, and HTTPS transport to export-compliance review, and keep final App Store Connect/legal/release classification blocked
- Screenshot/App Preview creative packet: native checks now map Memory Camera, today slice, weekly chapter, life meadow, media wall, and Account Rights to Apple screenshot/App Preview constraints with real-UI capture, synthetic/consented media, privacy masking, and no death/fear/shame marketing, while keeping final rendered assets, App Store Connect upload, localization/legal/release review blocked
- Public release contract marker: the Web demo now displays `Release Contract v73 · First-Week Return Loop`, with `styles.css?v=35` / `app.js?v=73`; Yesterday Echo, user-authored revisit layers, weekly story progress, the non-punitive weekend workbench, and revisit export are visible in the product and native checks
- Native build v74 replaces the engineering-style SwiftUI home and Launch tab with a branded Memory Camera home, Yesterday Echo reflection sheet, one-gap-at-a-time Weekend Workbench, and a private Life Marks gallery with mystery achievements but no totals, rankings, or streak debt
- Native build v75 starts new users with an honest empty vault, atomically persists slices/revisits/privacy/export state in Application Support, reads legacy JSON, preserves corrupt backups, and provides intentional empty states for Today, Slices, and Meadow
- Native build v76 renders selected images into metadata-stripped protected JPEG thumbnails, displays them across slice list/detail, supports editing title/body/people/meaning, media replacement/removal, missing-thumbnail recovery, and slice delete with undo; videos remain honest poster-pending clues
- Native build v77 imports selected videos through a file representation, extracts a protected JPEG poster with AVFoundation, and discards the raw video handoff without loading it into app memory or retaining it in the memory vault
- Native build v78 serializes debounced persistence with background flush, imports photo/video thumbnails through file representations, disables the unsafe legacy byte bridge, and includes available protected thumbnails in the default portable ZIP without exporting raw originals
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
