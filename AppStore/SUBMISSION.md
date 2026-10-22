# App Store submission kit: Color Door Rush 1.0

Paste these values into App Store Connect. Character limits were checked against Apple's limits.

## 1. Create the app record
App Store Connect → **Apps → + → New App**

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | `Color Door Rush` |
| Primary language | English (U.S.) |
| Bundle ID | `com.surproductions.colorgaterush` (unchanged by the rename) (it appears in the list after the first signed CI build registers it) |
| SKU | `colorgaterush-ios-001` (any unique string) |
| User access | Full access |

## 2. App Information
| Field | Value |
|---|---|
| Subtitle (≤30) | `Match colors. Dodge. Rush!` |
| Category | Primary: **Games**, subcategories **Arcade** and **Casual** |
| Content rights | Does **not** contain, show or access third-party content |
| Age rating | Fill in the questionnaire as described in section 5. The result is **4+**. |
| Privacy Policy URL | https://github.com/surproductions/Color-Gate-Rush/blob/main/PRIVACY.md |
| License agreement | Apple's standard EULA |

## 3. Pricing and Availability
- Price: **Free**
- Availability: all countries and regions. Narrow this if you need to.
- **EU Digital Services Act:** App Store Connect asks whether you are a trader. If you declare yourself a trader, your address, phone and email are shown on the EU storefront. A hobbyist publishing a free game can usually declare "not a trader". This is your legal call.

## 4. App Privacy
Under **App Privacy → Get Started**, answer **"No, we do not collect data from this app."**
The label will read **Data Not Collected**. This is accurate: the app has no network code, analytics or SDKs, and progress is stored only on the device. The app bundle also includes a privacy manifest (`PrivacyInfo.xcprivacy`).

## 5. Age rating questionnaire
Answer **None** or **No** to every item:
- Violence (cartoon, fantasy, realistic), horror/fear, profanity, mature or suggestive themes, sexual content or nudity, alcohol/tobacco/drugs, medical information, gambling (simulated or real), contests: **None** or **No**. Crashing the orb is abstract, not violence.
- Unrestricted web access: **No**. User-generated content: **No**. Messaging or chat: **No**. Advertising: **No**.
- Loot boxes: **No**. Cosmetics are bought with earned shards at fixed prices; nothing is random.
- Parental controls / age assurance: **No**.

Result: **4+**

## 6. Version 1.0 page

**Promotional text (≤170)**
```
Switch lanes, match your orb's color, and dodge barriers as the speed climbs. Short runs, instant retries, no ads, no purchases. How far can you rush?
```

**Description (≤4000):** use the contents of [`description.txt`](description.txt).

**Keywords (≤100, comma-separated, no spaces)**
```
arcade,color,match,runner,reflex,lanes,neon,endless,casual,offline,tap,speed,gates,doors,orb,dodge
```

| Field | Value |
|---|---|
| Support URL | https://github.com/surproductions/Color-Gate-Rush/issues |
| Marketing URL (optional) | https://github.com/surproductions/Color-Gate-Rush |
| Version | 1.0.0 |
| Copyright | `2026 surproductions` (use your legal or company name if you publish under one) |
| Routing app coverage file | none |

### Screenshots
Upload the files in [`screenshots/`](screenshots), in this order, to the **6.9" iPhone display** slot. They are 1320 × 2868 PNGs with no alpha channel:
`01-overdrive`, `02-prism`, `03-home`, `04-milestone`, `05-style`, `06-results`, `07-progress`. Apple scales them down for smaller iPhones, so no other sizes are required. The app is iPhone-only, so there is no iPad slot.

### Build
Select the build that the **iOS Build** workflow uploaded (section 8).

### App Review Information
- Sign-in required: **No**
- Contact: your name, phone and email. These are only visible to Apple.
- **Notes**, ready to paste:
```
Color Door Rush is a single-player offline arcade game. No account, login, network connection, in-app purchase or ads.

How to play: the first launch starts a short interactive tutorial. Tap the left/right side of the screen or swipe left/right to switch lanes (Settings and the pause menu offer Tap + Swipe, Tap Sides, or Swipe Only). Pass through gates matching the orb's color and shape; striped barriers end the run; full-width prisms change the orb's color. Shards earned in play unlock cosmetic items in "Style" (no real money).

Accessibility: Settings > Color Assist labels gates by name; Reduce Motion disables shake and speed effects. A privacy policy is available in Settings > Privacy Policy.
```

### Version release
Choose "Manually release this version" so you decide when it goes live after approval.

## 7. Export compliance
The app's Info.plist sets `ITSAppUsesNonExemptEncryption = NO` because the app uses no encryption, so App Store Connect won't ask the export-compliance question for each build.

## 8. Uploading the build (CI)
1. The repository secrets `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8` are set. The API key needs the **Admin** role so Xcode can create the distribution certificate.
2. Run **Actions → iOS Build → Run workflow** on `main`.
   - The first run (without *testflight_upload*) signs the app and registers the bundle ID. This lets you create the app record in step 1.
   - After the app record exists, run it again with **testflight_upload** ticked. The build appears in App Store Connect → TestFlight after Apple finishes processing, which usually takes 5–30 minutes.
3. Every CI run uses a higher build number (the run number), so repeat uploads never collide.

## 9. Final checklist before "Submit for Review"
- [ ] App record created with bundle ID `com.surproductions.colorgaterush`
- [ ] Subtitle, category, privacy policy URL and age rating (4+) entered
- [ ] App Privacy set to *Data Not Collected* and published
- [ ] Price set to Free, plus a DSA trader status
- [ ] Screenshots uploaded to the 6.9" slot
- [ ] Description, keywords, promotional text, support URL and copyright entered
- [ ] Build selected; export compliance needs no answer
- [ ] App Review contact info and notes entered
- [ ] Optional: a TestFlight pass on your own iPhone before submitting
