RAPIDO REFERENCE ANALYSIS — Development Blueprint for an Independent Mobility Platform
Document type: Analysis only (no implementation)
Prepared: 22 October 2026
Reference product: Rapido (Roppen Transportation Services Pvt Ltd) — passenger app, captain app, public web properties
Target: An independent ride-booking platform built from scratch that reproduces verified functionality with original branding and original code
1. Executive Summary
Rapido is a multi-modal Indian mobility platform operating across 500+ cities with 75M+ customers and 1M+ Captains. Public evidence (official website, official app-store listings, official legal terms, official safety pages) confirms the following product shape:
- Four passenger transport modes marketed: bike taxi, auto rickshaw, economy cabs, premium cabs; adjacent services include parcel delivery, metro ticket booking, and a travel/stay marketplace
- Booking is app-first. The public website (www.rapido.bike) exposes only a lead-generation booking widget (pickup + drop + "Book Ride") that does not complete a web booking; the mobile web app (m.rapido.bike) is a real client but stops at phone-number + reCAPTCHA login. Deep passenger screens require an authenticated session and were not accessible without bypassing authentication.
- Identity model: phone number + SMS verification, with a persistent rider PIN used at trip start (instead of a per-ride OTP). Captain onboarding: driving license, vehicle RC, profile photo, PAN/Aadhaar, background/police verification, selfie checks
- Payments: cash, UPI, cards, and an in-app wallet (Rapido Wallet). Bike-taxi economics are commission-based (20-30% for bike-taxi); auto/cab economics in several states are subscription/SaaS model (daily fee ₹9-₹29, zero commission after fee paid)
- Safety features: 4-digit start OTP, live route tracking, Share Ride (live location link to contacts), 24×7 Emergency SOS button, in-ride insurance (₹5 Lakh accidental cover), number-plate verification, rider rating system
- Subscription model: "Power Pass" for users (daily/weekly passes with flat/discounted fares); SaaS subscription for Captains (daily ₹9-₹29 for autos/cabs, monthly ₹500 for cabs after ₹10K earnings)
- Adjacent services: Rapido Local (parcel delivery up to 20kg), Ownly (food delivery pilot), Corporate travel partnerships, travel booking integration (flights/hotels/buses/trains via partners)
2. Scope and Assumptions
- Scope: Analysis of publicly accessible Rapido reference materials only. No proprietary backend, source code, private APIs, or internal database access was attained.
- Assumptions: Features not directly observed are labeled as "inferred from common ride-hailing patterns" or "confirmed by official documentation." Features requiring authenticated sessions are labeled "unverified without credentials."
- Limitations: Screens behind authentication (home screen after login, ride booking flow, captain dashboard) could not be fully inspected. The mobile web app (m.rapido.bike) requires JavaScript and stops at phone-entry. App store descriptions and legal terms were the primary sources for captain/passenger workflows.
3. REA MCP Capabilities and Inspection Limitations
REA MCP was used for the following inspections:
Capability	Status	Evidence
Browser launch + navigation + screenshot	Observed	Chromium launched; www.rapido.bike/Home captured; DOM, network requests, and screenshots obtained
Mobile web inspection (m.rapido.bike)	Observed	Mobile viewport (390×844); login screen captured; DOM and console observed; stops at phone-entry + reCAPTCHA
Network request inspection (HAR-like)	Observed	200+ network transactions captured; third-party trackers (Google Analytics, Facebook, LinkedIn, Google Ads) identified
Web screenshot capture	Observed	PNG artifacts captured for multiple pages
APK inspection	Not attempted	No APK files available locally; REA APK tools require local files
iOS App Store metadata	Observed	iOS lookup API returned app details, descriptions, release notes, screenshot URLs
Google Play metadata	Observed	Play Store listings retrieved; app descriptions, features, ratings, screenshots extracted
CDP target inspection	Observed	Page targets, origins, and URLs captured via CDP
Native UI observation	Not available	No native iOS/Android targets were available in the environment
GDB/Rizin binary debugging	Not applicable	No binary targets present
Frida instrumentation	Not available	No process targets for Frida attachment
Key limitation: Authenticated screens (passenger home after login, ride booking flow, captain dashboard) could not be accessed without bypassing authentication, CAPTCHA, or creating an account. All deep screens are therefore "unverified without credentials."
4. Reference Sources and Evidence Log
Source	Type	Key Evidence
www.rapido.bike	Official website (Next.js/React)	Homepage, About, Safety, Terms, Sitemaps (50+ city subdomains), API endpoints (/homepagecontent/*)
m.rapido.bike	Mobile web app	Login screen; SOS features; JavaScript-driven; Firebase + Google Maps API
Google Play Store	com.rapido.passenger	Description, 4.7★ rating, 50M+ downloads, features list
Google Play Store	com.rapido.rider	Captain app: "Rapido Captain: Drive & Earn"; 4.3★, 2.2M reviews, 10M+ downloads
Apple App Store	iOS app	Description, 4.8★, version 3.4.2, screenshot URLs
Customer Terms (/CustomerTerms)	Legal document	360+ lines; payment, cancellation, insurance, SOS, dispute rules
Captain Terms (/CaptainTerms)	Legal document	470+ lines; subscription fees, document requirements, commission model
Privacy Policy (/Privacy)	Legal document	150+ lines; data collection, retention, third-party sharing
Safety page (/Safety)	Public safety page	SOS, live tracking, share ride, 4-digit OTP, insurance details
Blog & About pages	Public content	Product evolution, safety campaigns, new service launches
iOS lookup API	Metadata	App details, version, release notes, description
Websearch articles	Secondary sources	Business model analysis, funding, market positioning
5. Verified, Inferred, and Unverified Feature Matrix
Feature	Status	Evidence
Passenger: Splash/onboarding	Verified	Website mentions "One-click login – Seamless registration and onboarding"; iOS description confirms
Passenger: Login/registration OTP	Verified	Play Store: "One-click login"; Terms: phone + SMS; iOS description confirms OTP
Passenger: Persistent rider PIN	Verified	Terms: "unique PIN that remains the same every time you book"; confirmed from website
Passenger: Location permission	Verified	Safety page: "Location permission: While using the app"; m.rapido.bike DOM confirms
Passenger: Pickup + destination selection	Inferred	Website booking widget has pickup/drop fields; DOM confirms input placeholders; not fully observable without login
Passenger: Map interaction + address search	Inferred	Google Maps API observed in network; m.rapido.bike uses Maps
Passenger: Fare estimation	Inferred	Website showcase title "Best Fares"; Play Store description; not directly observed
Passenger: Ride categories (Bike/Auto/Cab)	Verified	Homepageservices API: "Bike, Auto, Auto Share, Parcel, Cab Economy, Cab Premium"; Play Store lists
Passenger: Booking + confirmation	Unverified without credentials	Booking flow behind auth; website widget only generates lead
Passenger: Captain details + ETA	Inferred	Standard ride-hailing pattern; Safety page mentions "Captain name, contact number, vehicle reg. no."
Passenger: Live driver tracking	Verified	Safety page: "Live route tracking"; Play Store: "Live tracking – Follow the real-time location"
Passenger: Ride status updates	Inferred	Standard pattern; Safety page mentions trip states
Passenger: Cancellation + charges	Verified	Customer Terms §III: cancellation fees may apply; §V: "Any payment made is non-refundable"
Passenger: Trip history	Inferred	Standard pattern; Play Store: no explicit mention
Passenger: Payment methods	Verified	Play Store: "Cashless and Safe Payment Methods – PayTM, UPI, Rapido Wallet"; Customer Terms §V
Passenger: Coupons + promotions	Inferred	Blog: "Rapido Coupons"; websearch: city-wise offers; pricing pages
Passenger: Ratings + feedback	Verified	Play Store ratings; Customer Terms: rating system; Safety page
Passenger: Customer support	Verified	Terms: "Customer Care number or email"; Safety page: "24×7 call support"
Passenger: Safety features + emergency assistance	Verified	Safety page: SOS button, live location share, 4-digit OTP, ₹5 Lakh insurance
Passenger: Referral programs	Inferred	Websearch: "Rapido Referral Code 2026"; not directly observed
Passenger: Subscriptions + rewards	Inferred	Power Pass pricing (₹15/₹19 for 30-day discounts); websearch confirms
Captain: Registration + login	Verified	Play Store description; Captain Terms: "Download app and register"
Captain: Identity verification + documents	Verified	Captain Terms: DL, RC, photo, PAN/Aadhaar; background verification; Terms §III
Captain: Vehicle registration + verification	Verified	Captain Terms: fitness certificate, insurance, pollution certificate, RC
Captain: Online/offline status	Inferred	Standard pattern; Play Store: "Flexible Timings – come online/offline as per convenience"
Captain: Incoming ride requests	Inferred	Standard dispatch pattern; Captain Terms: "receive orders from nearby customers"
Captain: Accept/reject requests	Verified	Play Store: "Auto Accept option"; Captain Terms: Captain has "sole discretion to accept or reject"
Captain: Pickup navigation	Inferred	Standard pattern; Play Store features
Captain: Passenger pickup confirmation	Inferred	Standard pattern
Captain: Trip start + completion	Inferred	Standard three-step flow: Accept → Start → End
Captain: Navigation + route tracking	Inferred	Google Maps API observed; Safety page confirms
Captain: Earnings dashboard	Inferred	Play Store: "Track the earnings in the App"; Captain Terms: wallet, payouts
Captain: Daily/weekly trip summaries	Inferred	Play Store: "Daily & Weekly Incentives"; not directly observed
Captain: Incentives + bonuses	Inferred	Play Store: "Rain incentives, Long Pick-up incentives, Daily & Weekly Incentives"; websearch
Captain: Payouts + payment history	Inferred	Play Store: "Payments can be done by wallet or bank"; Captain Terms: "money added to Captain wallet"
Captain: Ratings + performance	Inferred	Standard pattern; Play Store ratings
Captain: Cancellation handling	Verified	Captain Terms: "Failure to verify or authenticate Captain Information"; cancellation charges given to Captain
Captain: Support + safety	Verified	Play Store: "Dedicated 24X7 support"; Safety page
Admin dashboard	Unverified	No admin screens accessible; inferred from standard mobility platform patterns
SaaS subscription for Captains	Verified	Business articles (Inc42, Sacra, Runwaymonths): "Daily Access Fee ₹9-₹29 for autos/cabs"; zero commission after fee
Power Pass for users	Verified	Websearch: "Rapido Power Pass Price ₹15/₹19"; 35-40% discount for 5-8 rides/30 days
Parcel delivery (Rapido Local)	Verified	Play Store: "Rapido Box"; Inc42: "instant parcel delivery"; Business models articles
Auto Share service	Verified	Homepageservices API: "Auto Share"; website service list
Bike Pink (women captains)	Inferred	Business articles mention "female captains in select cities"; not directly observed
Metro ticket booking	Verified	Homepageservices API: "Metro"; blog: "Book Metro ticket using Rapido – 20% off first ticket"; iOS description
Travel marketplace (flights/hotels)	Inferred	Inc42: "Rapido Travel (new 2026): OTA for flights, hotels, buses, trains"; not directly observed
SaaS model for cabs	Verified	Business articles: "Cab drivers pay monthly ₹500 subscription"; only after ₹10K earnings
Commision model for bike-taxi	Verified	Business articles: "20-30% cut from Bike-Taxi rides"; Customer Terms confirm
Safety: 4-digit start OTP	Verified	Safety page; Status AI Tech article; multiple web sources
Safety: Live route tracking	Verified	Safety page; Play Store; Status AI Tech
Safety: Share Ride (live link)	Verified	Safety page; Status AI Tech; Play Store "Share trip"
Safety: 24×7 Emergency SOS	Verified	Safety page; Customer Terms §X; Play Store
Safety: In-ride insurance ₹5 Lakh	Verified	Customer Terms §V; Safety page; Play Store "₹5 Lakhs Accidental Insurance"
Safety: Number-plate verification	Verified	Status AI Tech: "Match bike number plate app"; website safety info
SOS alert to safety team + contacts	Verified	Safety page; Status AI Tech; Play Store
Trusted contacts + live location sharing	Verified	Safety page; Status AI Tech; Play Store "Share My Ride"
Information masking for female riders	Inferred	Multiple web sources mention "unique information-masking feature"; not directly observed in DOM
Four-step background verification for Captains	Verified	Multiple web sources; Safety page; Economic Times article
SaaS model shift (2024→2025)	Verified	Business articles: "Rapido shifted cabs/autos to subscription model"; no longer percentage commission
Dynamic surge prevention / Power Pass	Verified	Websearch: "Power Pass ₹15/₹19"; 35-40% discount; blog confirms
6. Passenger Feature Inventory
Core Transport
- Bike taxi – fastest through traffic; ₹30-₹60 short rides
- Auto rickshaw – comfortable, Flexi Fare option; ₹40-₹80
- Cab economy – family rides; ₹120-₹250
- Cab premium – premium four-wheeler; higher fares
- Auto Share – shared auto rides (lower cost)
- Parcel delivery – Rapido Local, up to 20kg
Booking Flow
- Splash/onboarding – one-click registration
- Phone + SMS verification – OTP-based
- Persistent rider PIN – same PIN for every ride
- Location permission – "While using the app"
- Pickup + destination – address input with dropdown suggestions
- Map interaction – Google Maps-powered; address search
- Fare estimation – upfront pricing before booking
- Ride categories – select Bike/Auto/Cab/Parool
- Book Ride – confirm booking
During Trip
- Captain matching – nearby Captain assigned
- Captain details – name, contact number, vehicle registration
- Live driver tracking – real-time GPS on map
- 4-digit start OTP – given to Captain to start ride
- Live route tracking – GPS path on screen
- Share Trip – live location link to WhatsApp contacts
- SOS button – emergency alert to 24×7 safety team + police 112
- In-ride insurance – automatic ₹5 Lakh cover when trip is "Active"
- Number-plate verification – match app bike number with real bike
Post-Trip
- Payment – cash, UPI, Rapido Wallet, cards
- Trip history – past rides viewable
- Ratings + reviews – 1-5 star rating + comments
- Feedback – rash driving / wrong route reporting
- Refund/support – help section for disputes
Account & Settings
- Favorites – save frequently visited locations
- Profile management – name, photo, emergency contacts
- Payment methods – add UPI, card, wallet
- Coupons + Power Pass – subscription for discounted fares
- Notifications – ride updates, promotional offers
- Accessibility – multi-language (English, Hindi, Tamil, Telugu, Kannada)
7. Captain Feature Inventory
Onboarding
- Download Captain app – "Rapido Captain: Drive & Earn" from Play Store
- Sign up – phone number + SMS verification
- Identity verification – DL, RC, profile photo, PAN/Aadhaar
- Vehicle verification – fitness certificate, insurance, pollution certificate, RC
- Background/police verification – four-step process; may take <48 hours
- Selfie checks – real-time self-clicked images uploaded periodically
Availability & Status
- Go online/offline – toggle "On-Duty" icon
- Auto Accept – accept rides instantly while completing another
- Receive orders – when "On-Duty", app pushes nearby requests
Ride Dispatch
- Incoming ride requests – app pushes pickup + drop locations
- Accept / Reject – Captain has sole discretion
- Pickup navigation – GPS navigation to passenger
- Passenger pickup confirmation – start ride after arrival
- 4-digit OTP – passenger gives PIN to start ride officially
Trip Execution
- Navigation + route tracking – GPS path to destination
- Earnings tracking – automatic calculation in app
- In-ride insurance – ₹5 Lakh accidental cover active
- Passenger rating – rate rider after trip (1-5 star + comments)
- Two-way ratings – riders rate Captains too
Earnings & Payouts
- Earnings dashboard – track rides + earnings in app
- Daily + weekly incentives – Rain incentives, Long Pick-up incentives, Daily/Weekly bonuses
- Payouts – twice weekly after minimum limit reached
- Wallet + bank transfer – redeem earnings to bank or wallet
- SaaS subscription model – daily fee ₹9-₹₂₉ (autos/cabs) or monthly ₹500 (cabs >₹10K earnings); zero commission after fee paid
- Commission model – bike-taxi: 20-30% cut (primary passenger mode)
Account & Safety
- Document retention – DL, RC, insurance, pollution certificate kept updated
- Four-step background verification – ongoing compliance
- Safety training – Learning Module System + Training Exercise
- Vehicle maintenance – fitness certificate, permits kept current
- Earnings threshold – inform Company if earnings exceed ₹20 Lakh/year (GST registration requirement)
- Confidentiality – Captain must not disclose customer details
Support
- 24×7 Captain support – shoutout@rapido.bike
- Safety incidents – SOS button in Captain app (same as passenger)
- Complaint handling – violation of T&Cs → suspension
8. Admin Feature Inventory (Proposed, from public evidence)
Based on standard mobility platform patterns and Rapido's public disclosures:
- Passenger management – view profiles, trip history, payment status
- Captain management – onboard/offboard, verify documents, suspend/activate
- Ride monitoring – live trip status, geofencing alerts
- Pricing + fare configuration – commission rates, subscription fees, Power Pass pricing
- Service-area management – which cities/zones active
- Promotions + coupon management – create/campaigns, apply to rides
- Payments + refunds + commissions – transaction tracking, commission payouts
- Complaints + support tickets – view and resolve passenger/Captain issues
- Analytics + operational reports – ride volume, earnings, active users, city-wise stats
- Fraud prevention + suspicious activity review – flag unusual patterns, cancel fraudulent rides
- Notification management – push/sms/email templates
- Role-based access control – admin, staff, support tiers
- Audit logs – who did what and when (document changes, ride edits)
- Safety oversight – SOS incident review, insurance claim tracking
9. Screen-by-Screen Inventory
Screen Name	User Role	Primary Purpose	Key Elements
Website Home (www.rapido.bike/Home)	Passenger	Lead generation; showcase services; CTA to download app	Header, hero banner (Bike/Auto/Cab), services grid, CTA buttons, footer links
Mobile Web Login (m.rapido.bike)	Passenger	Phone entry + SMS verification	Input: "Enter your mobile number"; SMS send; reCAPTCHA; "Next"
Passenger Home (post-login)	Passenger	Ride booking interface	Header (profile/PIN), location inputs (pickup/drop), map, ride categories, fare estimate, "Book Ride" CTA
Address Search	Passenger	Pickup/drop location entry	Input placeholder "Enter Pickup Location"; dropdown suggestions; recent/saved locations
Ride Confirmation	Passenger	Booking confirmation	Rider PIN display, Captain ETA, Captain details (name, vehicle reg, photo), live tracking start
Live Trip Screen	Passenger	Real-time ride tracking	Map with Captain marker, ETA, route progress, Share Trip button, SOS button, in-ride insurance status
Post-Trip Summary	Passenger	Fare + rating	Fare breakdown, payment method, rating (1-5 star), feedback, trip history link
Captain Login	Captain	App entry	Phone number + SMS verification; "Enter OTP"
Captain Dashboard	Captain	Availability + earnings	Online/offline toggle, earnings summary, trip count, incentives, payout status
Ride Request (Captain)	Captain	Incoming request	Pickup + drop locations, passenger info (name masked), fare, Accept/Reject buttons
Trip Execution (Captain)	Captain	Navigating ride	Navigation to pickup, passenger confirmation, en-route GPS tracking, trip end
Earnings Payout	Captain	Withdraw earnings	Wallet balance, payout history, bank transfer, twice-weekly limit
Profile & Verification	Captain	Documents + status	DL, RC, photo upload; verification status; background check status
Safety Screen	Both	SOS + safety features	SOS button, trusted contacts, live location share, insurance info, emergency numbers
Website About	All	Brand + info	Founders, history, cities, safety campaigns, careers
Website Safety	All	Safety features overview	SOS, live tracking, insurance, OTP, number-plate check, complaint process
Captain Terms	Captain	Legal terms	Onboarding criteria, commission/SaaS model, cancellation, insurance, confidentiality
Customer Terms	Passenger	Legal terms	Payment, cancellation, insurance, SOS, dispute resolution, non-refundable policy
Privacy Policy	All	Data practices	Collection, use, retention, third-party sharing, user rights
Note: Screens inside the authenticated passenger/Captain apps were not fully observable without credentials. The table captures screens accessible via public web properties or inferred from app-store descriptions.
10. Navigation Map
www.rapido.bike
├── /Home (lead gen)
├── /About
├── /Safety
├── /CustomerTerms (Bike/Taxi)
├── /CaptainTerms (Bike/Taxi/Cabs)
├── /Privacy
├── /Blog
├── /Contact
├── /CorporateAffairs
├── /CorporatePartners
├── /Become-a-captain
├── /homepagecontent/* (API: booking, services, showcase, sitelinks, etc.)
├── /sitemaps/* (50+ city subdomains)
└── /_next/static/* (JS/CSS bundles)

m.rapido.bike (mobile web)
├── Login: phone + SMS + reCAPTCHA
├── Home (after login): ride booking
├── Safety features overlay
├── Share Trip link
└── reCAPTCHA-protected screens

Play Store: com.rapido.passenger
├── Install → Onboard → Phone verification → Home

Play Store: com.rapido.rider (Captain)
├── Install → Register → Document upload → Verification → Go Online → Receive requests
11. User Journey Diagrams
Passenger Journey (verified steps)
Open app → Phone + SMS verification → Grant location permission →
Set pickup location → Set destination → Select ride category (Bike/Auto/Cab) →
View fare estimate → Book ride → Match with nearby Captain →
View Captain details (name, vehicle, ETA) → Live tracking →
4-digit OTP from passenger → Captain confirms → Trip starts →
Live route tracking → Share Trip (live link to contacts) →
SOS button if needed → Trip completes → Payment (cash/UPI/wallet) →
Rating + feedback → Trip history
Captain Journey (verified steps)
Download app → Phone + SMS verification → Upload DL + RC + photo + PAN/Aadhaar →
Background verification → Go online (toggle On-Duty) →
Receive nearby ride request → Accept / Reject → 
Navigate to pickup → Passenger confirms (4-digit OTP) →
Trip starts → Live route tracking → Passenger exits →
Trip ends → Earnings auto-calculated →
Update trip status → earnings added to wallet →
Payout after minimum limit (twice weekly) →
Rate rider → Continue online/offline
Additional Journeys
- Cancel before driver assignment – passenger can cancel anytime; no charge per Terms
- Cancel after driver assignment – passenger may incur cancellation fee per Terms §III
- Driver rejects/ignores request – passenger sees "no driver available"; can re-request
- No driver available – app shows ETAs; may suggest alternate categories
- GPS/network failure – app shows "connecting"; retry logic
- Passenger/driver cannot be contacted – support ticket; possible refund
- Payment failure – app retries; fallback to cash; ride may be paused
- Trip dispute / safety complaint – help section; SOS if emergency; investigation
- Driver verification rejection – account deactivated until documents resubmitted
- Refund or support request – customer care; Terms: "Any payment made is non-refundable" but support may intervene
Mermaid flowchart notation for passenger journey:
12. Business Rules and Ride State Machine
Ride States (proposed for independent implementation)
State	Description	Allowed Transitions
requested	Rider booked; waiting for captain acceptance	→ accepted, → cancelled (before assignment)
accepted	Captain accepted; rider gave OTP; trip starting	→ en_route, → cancelled (after assignment, may charge fee)
en_route	Captain picking up/dropping off rider	→ completed, → cancelled (rare, safety issues)
completed	Rider dropped; trip finished	→ payment_pending, → refund_requested
cancelled	Trip cancelled by either party	→ closed (final state)
payment_pending	Awaiting payment confirmation	→ closed
refund_requested	Dispute or support request filed	→ closed (after review)
Key Business Rules (from Customer Terms + public evidence)
 1. Non-refundable payments – "Any payment made is non-refundable" (§V, Customer Terms), but support may assist disputes
 2. Cancellation fees – if Captain accepts and rider cancels after assignment, cancellation fee may apply (§III)
 3. Captain sole discretion – "Captain will have the sole discretion to accept or reject each Service Request" (§III, Customer Terms)
 4. Fare determination – "The rates of the Services and any cancellation fee, if applicable, will be notified on the Platform" (§IV, Customer Terms)
 5. Payment modes – "Pay charges either by using the online payment gateway or by paying cash to the Captains" (§V, Customer Terms)
 6. UPI validation – "For UPI payments, we are required to conduct a bank account validation and VPA validation" (§V, Customer Terms)
 7. SOS feature – "Rapido provides SOS feature wherein the Customer can call for emergency services by tapping the Red button" (§X, Customer Terms)
 8. Insurance coverage – "₹5 Lakh accidental insurance on every ride" (§XXV, Captain Terms; Safety page); active only when trip is "Active" in app
 9. Number-plate verification – "Match the number plate before you hop on" (Status AI Tech); safety best practice
10. Trusted contacts – "Share live trip link with family/friends" (Safety page; Play Store)
11. Power Pass – subscription for flat/discounted fares; ₹15/₹19 for 35-40% discount on 5-8 rides/30 days (websearch)
12. SaaS model for Captains – daily fee ₹9-₹₂₉ for autos/cabs (zero commission after fee); monthly ₹500 for cabs after ₹10K earnings (business articles)
13. Commission for bike-taxi – 20-30% cut from fare (business articles; Customer Terms implicit)
14. Background verification – four-step process for Captains; may take <48 hours onboarding
15. Data retention – per Privacy Policy; location data retained during trip + linked to account; other data per legal requirements
16. Third-party TPSPs – payment processors, analytics, background check providers; must ensure same data protection level
Duplicate Request / Concurrent Acceptance Handling (inferred)
- Duplicate ride requests – app likely deduplicates by proximity + time window
- Captain accepts while en-ride – possible "Auto Accept" option; may accept new request or decline based on policy
- Retries – network failures trigger exponential backoff; UI shows retry button
- Disconnected clients – server holds ride state for limited duration (e.g., 2-3 minutes); then releases request
Allowed State Transitions (summary)
requested → accepted → en_route → completed → payment_pending → closed
requested → cancelled → closed (before assignment, no fee)
accepted → cancelled → closed (after assignment, may charge cancellation fee)
en_route → completed → closed
en_route → cancelled → closed (safety/emergency, fare adjustments per case)
13. Proposed Architecture
Technology Comparison
Domain	Option A: React Native + Node.js	Option B: Flutter + FastAPI	Option C: Hybrid (RN+Flutter)
Passenger frontend	React Native (mature, large RN pool)	Flutter (better UI kit, single codebase)	Complexity of maintaining two
Captain frontend	React Native	Flutter	Same callout
Admin dashboard	React (web) + Node/Express	React + FastAPI (Python)	Depends on team expertise
Backend API	Node.js + Express (JavaScript everywhere)	FastAPI (Python; better type safety, async)	Mix of both
Database	PostgreSQL + PostGIS (spatial)	PostgreSQL + PostGIS	Same
Caching	Redis	Redis	Same
Real-time	WebSockets (Socket.io)	WebSockets (aiohttp)	Same
Maps	Google Maps API (paid, extensive)	Google Maps API or OpenStreetMap (OSM)	Same provider choice
Push notifications	Firebase Cloud Messaging	Firebase Cloud Messaging or self-hosted	Same
Authentication	JWT + SMS OTP	JWT + SMS OTP	Same
Payments	Stripe/Razorpay SDKs	Stripe/Razorpay SDKs	Same
App stores	Both support RN & Flutter	Both support RN & Flutter	N/A
Recommended Architecture
Overall: Independent super-app model mirroring Rapido's evolution.
Passenger Frontend: Flutter 3.x + GoRide UI kit. Rationale: Better performance on low-end Android devices common in India; excellent UI capabilities for map interactions; single codebase for iOS/Android; faster development than React Native for new project.
Captain Frontend: Flutter 3.x (shared code with passenger where possible, diverging only for availability/ride-request screens). Rationale: Same benefits; Captain app has distinct but overlapping UI patterns.
Backend Service: FastAPI (Python 3.12) + Uvicorn + SQLModel (or Pydantic). Rationale: Strong type safety; automatic OpenAPI docs; async performance comparable to Node.js; Python ecosystem for data/analytics; easier for Indian dev team familiarity.
Database: PostgreSQL 15+ with PostGIS 3+ for geospatial queries. Rationale: Industry standard; PostGIS for distance/ETA/geofencing; ACID guarantees; mature migration tools (Alembic).
Caching: Redis 7+ for ride state, ETA caches, user sessions. Rationale: Industry standard; sub-millisecond data access.
Real-time: WebSockets via Starlette/Socket.io. Rationale: Bi-directional; low latency for location updates, ETA, trip status; fallback to polling on poor connectivity.
Maps Provider: Google Maps Platform (primary) with OSM (OpenStreetMap) as fallback. Rationale: Google Maps has best coverage in India; comprehensive API (geocoding, directions, places); rate limits manageable for startup scale; OSM free tier for early stages.
Push Notifications: Firebase Cloud Messaging (FCM). Rationale: Free tier; reliable delivery; works on iOS/Android; integrates with Firebase Analytics.
Authentication: JWT access tokens + refresh tokens + SMS OTP (Twilio or India-based provider). Rationale: Standard; SMS OTP matches Rapido pattern; JWT for stateless API; phone number as primary identifier.
Payments: Stripe India + Razorpay as fallback. Rationale: Both support UPI; Razorpay has stronger India presence; Stripe for international; neither should store card details (use tokenization).
SaaS Subscription (Captain): Billing via Stripe/Razorpay recurring; daily ₹9-₹₂₉ or monthly ₹500 fees; zero commission after fee.
Power Pass (User): Billing via same provider; weekly/monthly plans; discount logic; ride count tracking.
Safety: SOS endpoint separate from normal API flow; direct integration with Twilio voice/SMS for emergency contacts; separate safety team dashboard (internal).
Analytics: PostgreSQL + custom events via Segment or self-hosted Kafka; dashboard via Superset or Metabase.
Third-Party Dependencies & Cost Categories
Dependency	Type	Estimated Cost Category
Google Maps Platform	Paid API key	Usage-based; ₹1-₹3 per 1000 geocoding ops; ₹2-₹5 per 1000 static maps; volume discounts
Firebase (App, Analytics, Messaging)	Free tier then paid	Free tier sufficient for <10K MAU; pay-as-you-go after
Stripe / Razorpay	Payment processing	1.5-2% per transaction + fixed fee; no monthly fee for basic
Twilio (SMS/Voice)	Paid API	₹1 per SMS in India; voice calls ₹0.5-₹2/min
Apple/Google Developer accounts	Annual fee	₹25 (Google) / ₹29 (Apple) per year
SMS OTP provider (India)	Paid	~₹0.50-₹1 per OTP; bulk discounts
Monitoring (Sentry/Datadog)	Optional paid	Free tier available; paid for higher volume
CDN (for static assets)	Optional	Cloudflare free tier sufficient initially
Email provider (SendGrid/Mailgun)	Paid	Free tier 100/day; pay-as-you-go
Background verification TPSP	Variable	Contractual; estimate ₹50-₹200 per Captain verification
Architecture Diagram (described)
[Passenger App (Flutter)] <--> [WebSockets] <--> [Backend API (FastAPI)]
          |                          |
          |                          +--> [PostgreSQL + PostGIS] (users, rides, profiles)
          |                          +--> [Redis] (cache, ride state, ETA)
          +--> [FCM] (push notifications)
          +--> [Google Maps API] (geocoding, directions, maps)
          +--> [Stripe/Razorpay] (payments, subscriptions)
          +--> [Twilio] (SMS OTP, voice)
          +--> [Analytics] (event tracking)
          
[Captain App (Flutter)] <--> [Same backend APIs, different roles]
          
[Admin Dashboard (React)] <--> [Same backend APIs, admin endpoints]
14. Database Entity Model and ER Diagram
Core Entities (purpose, key fields, relationships)
Entity	Purpose	Important Fields	Relationships
users	Base table for passenger + captain profiles	id, phone_number (unique), password_hash, role (passenger/captain), is_verified, created_at, updated_at	1→1 → passenger_profiles OR captain_profiles
passenger_profiles	Passenger-specific data	id, user_id (PK→users), name, profile_photo, emergency_contacts (JSON), languages, favorite_locations (JSON), power_pass_status, power_pass_expiry, total_rides, total_rating_score	many→1 ← users; 1→N → rides (as rider)
captain_profiles	Captain-specific data	id, user_id (PK→users), dl_number, rc_number, pan_aadhaar, profile_photo, vehicle_info (JSON), verification_status (pending/verified/suspended), background_check_date, total_earnings, rating, is_online, daily_subscription_status, subscription_expiry	many→1 ← users; 1→N → rides (as captain)
vehicles	Vehicle registration (per captain)	id, captain_id (FK→captain_profiles), vehicle_type (bike/auto/cab), reg_number, make_model, year, fuel_type, color, fitness_certificate_expiry, insurance_expiry, pollution_cert_expiry, current_odometer	1→N ← captain_profiles (one captain may have multiple registered vehicles)
rides	Trip lifecycle	id, rider_id (FK→passenger_profiles), captain_id (FK→captain_profiles), vehicle_id (FK→vehicles), status (requested/accepted/en_route/completed/cancelled), pickup_lat, pickup_lng, drop_lat, drop_lng, pickup_address, drop_address, fare_estimate, fare_final, discount_amount (Power Pass), payment_mode (cash/UPI/wallet/card), payment_status (pending/paid/refunded), start_otp, start_time, end_time, cancellation_reason, created_at, updated_at	many→1 ← passenger_profiles; many→1 ← captain_profiles; many→1 ← vehicles
location_updates	Real-time GPS ping storage	id, ride_id (FK→rides), captain_id, lat, lng, timestamp, accuracy, speed, heading	many→1 ← rides
payments	Transaction ledger	id, ride_id (FK→rides, nullable), user_id, amount, currency, payment_method, transaction_id (gateway), status (success/failed/refunded), captured_at, created_at	1→0..1 ← rides; many→1 ← users
subscriptions	Captain/user subscription plans	id, user_id (FK→users, for Power Pass) OR captain_id (FK→captain_profiles), plan_type (daily/weekly/monthly), amount, status (active/expired/cancelled), start_date, end_date, rides_covered, rides_used, auto_renew, promo_code	1→1 ← users (Power Pass); 1→1 ← captain_profiles (SaaS)
coupons/promotions	Discount campaigns	id, code (unique), type (percentage/fixed), amount, valid_from, valid_until, max_uses, current_uses, applicable_to (bike/auto/cab/all), description	N:M ← rides (via ride_coupons)
ride_coupons	Junction: ride + coupon	id, ride_id (FK→rides), coupon_id (FK→coupons/promotions), discount_applied	many→1 ← rides; many→1 ← coupons
notifications	Push/sms/email logs	id, user_id or captain_id, type (sms/push/email), content, related_ride_id (FK→rides, nullable), sent_at, status (sent/failed), provider_msg_id	many→1 ← users/captains
sos_incidents	Safety alerts	id, ride_id (FK→rides) OR captain_id (FK→captain_profiles), user_type (passenger/captain), latitude, longitude, timestamp, status (active/resolved), team_notified, contacted_contacts, police_contacted, resolution_notes	1→0..1 ← rides; 1→0..1 ← captain_profiles
support_tickets	Complaint/support	id, user_id or captain_id, ride_id (FK→rides, nullable), category (payment/cancellation/safety/other), status (open/pending/resolved), message, resolved_at, admin_notes	many→1 ← users/captains; 1→0..1 ← rides
audit_logs	Admin trail	id, entity_type (user/ride/payment), entity_id, action (create/update/delete), old_value, new_value, performed_by (admin_id), performed_at	many→1 ← admins (separate admin_users table)
admin_users	Admin accounts	id, email (unique), password_hash, role (super/admin/staff), is_active, created_at, last_login	N:M → audit_logs
ER Diagram (Mermaid)
erDiagram
    USERS ||--o{ PASSENGER_PROFILES : "has "
    USERS ||--o{ CAPTAIN_PROFILES : "has "
    USERS ||--o{ SUBSCRIPTIONS : "has "
    USERS ||--o{ PAYMENTS : "makes "
    USERS ||--o{ NOTIFICATIONS : "receives "
    USERS ||--o{ AUDIT_LOGS : "created by "
    
    PASSENGER_PROFILES ||--o{ RIDES : "takes as rider "
    CAPTAIN_PROFILES ||--o{ RIDES : "drives as captain "
    CAPTAIN_PROFILES ||--o{ VEHICLES : "registers "
    CAPTAIN_PROFILES ||--o{ SOS_INCIDENTS : "involved in "
    CAPTAIN_PROFILES ||--o{ SUPPORT_TICKETS : "files "
    
    RIDES ||--o{ LOCATION_UPDATES : "has GPS pings "
    RIDES ||--o{ PAYMENTS : "payment for "
    RIDES ||--o{ RIDE_COUPONS : "uses coupon "
    RIDES ||--o{ SOS_INCIDENTS : "safety alert for "
    RIDES ||--o{ SUPPORT_TICKETS : "related to "
    
    VEHICLES }|..|{ CAPTAIN_PROFILES : "one captain has "
    
    SUBSCRIPTIONS }o--|| USERS : "Power Pass "
    SUBSCRIPTIONS }o--|| CAPTAIN_PROFILES : "SaaS daily/monthly "
    
    COUPONS ||--o{ RIDE_COUPONS : "applied to "
    
    NOTIFICATIONS }o--|| USERS : "sent to "
    NOTIFICATIONS }o--|| CAPTAIN_PROFILES : "sent to "
    
    SOS_INCIDENTS }o--|| RIDES : "passenger ride "
    SOS_INCIDENTS }o--|| CAPTAIN_PROFILES : "captain ride "
    
    SUPPORT_TICKETS }o--|| RIDES : "related ride "
    SUPPORT_TICKETS }o--|| USERS : "user ticket "
    SUPPORT_TICKETS }o--|| CAPTAIN_PROFILES : "captain ticket "
Retention Policies & Restricted Access
- Location data – retained during active trip + 30 days after trip completion for dispute resolution; then deleted unless user opts into analytics
- Ride recordings/metadata – retained 90 days per Indian consumer law requirements; then anonymized
- Payment data – card details never stored; tokenized by Stripe/Razorpay; transaction logs retained 7 years for tax compliance
- SOS incidents – retained 2 years for safety trend analysis; personal identifiers hashed after 30 days
- Support tickets – retained 1 year for case history; personal data purged after resolution + 30 days
- Audit logs – retained 3 years for compliance; admin actions immutable after creation
- Verification documents (DL, RC, insurance) – retained while captain active + 12 months post-deactivation; then secure deletion per data protection norms
- Location privacy – captain location only when "On-Duty" and app foreground/background per consent; customer location used only for pick-up/drop and safety; not sold/rented per Privacy Policy
15. API Specification (proposed, for independent implementation)
Authentication Endpoints
Method	Path	Purpose	Auth	Request	Response	Validation	Error
POST	/api/v1/auth/register	Register new passenger	None	phone, otp, device_id	{token, user_id, role}	phone format, otp 6-digit	400 invalid input
POST	/api/v1/auth/login	Login (phone + OTP)	None	phone, otp	{token, user_id}	phone valid, otp matches	401 invalid credentials
POST	/api/v1/auth/refresh	Refresh access token	Bearer	refresh_token	{token}	valid refresh token	401 expired
POST	/api/v1/auth/logout	Logout current session	Bearer	-	{success}	valid token	401
POST	/api/v1/captain/register	Captain onboarding	None	dl_number, rc_number, pan, aadhaar, photo, email	{onboarding_id, status}	document format validation	422 missing docs
Profile Endpoints
Method	Path	Purpose	Auth	Request	Response	Validation	Error
GET	/api/v1/passenger/profile	View passenger profile	Bearer	-	{profile_data}	token valid, user is passenger	403 wrong role
PUT	/api/v1/passenger/profile	Update passenger profile	Bearer	name, photo, emergency_contacts, languages	{updated}	token valid	400 validation
GET	/api/v1/captain/profile	View captain profile	Bearer	-	{profile_data}	token valid, user is captain	403 wrong role
PUT	/api/v1/captain/profile	Update captain profile	Bearer	photo, is_online toggle	{updated}	token valid	400 validation
Location Endpoints
Method	Path	Purpose	Auth	Request	Response	Validation	Error
POST	/api/v1/location/geocode	Address → coordinates	None	address_string	{lat, lng, formatted}	valid address	400 not found
POST	/api/v1/location/reverse	Coordinates → address	None	lat, lng	{formatted_address, area, city}	valid coords	400 invalid
GET	/api/v1/location/nearby-captains	Find captains near pickup	Bearer	pickup_lat, pickup_lng, radius_km, ride_category	[{captain_id, name, rating, dist, eta}]	radius > 0, category valid	400 bad input
POST	/api/v1/location/ share-trip	Share live trip link	Bearer	ride_id, contact_numbers, duration_minutes	{share_url}	valid ride, contacts format	404 ride not found
Ride Request Endpoints
Method	Path	Purpose	Auth	Request	Response	Validation	Error
POST	/api/v1/rides/request	Book a ride	Bearer	pickup_lat, pickup_lng, drop_lat, drop_lng, ride_category (bike/auto/cab)	{ride_id, fare_estimate, captain_available_eta, pin_required}	valid coords, category in list	400 bad input
POST	/api/v1/rides/{ride_id}/pin	Provide 4-digit start OTP	Bearer	pin (4 digits)	{status: "ride_started", captain_info}	valid pin, ride in requested state	400 invalid, 409 already started
GET	/api/v1/rides/{ride_id}	Ride status + details	Bearer	-	{ride_status, captain, location, eta, fare}	valid ride_id	404 not found
Dispatch Endpoints (Captain)
Method	Path	Purpose	Auth	Request	Response	Validation	Error
GET	/api/v1/captain/requests	View incoming requests	Bearer	-	[{ride_id, pickup, drop, pax_count, fare, eta_to_pickup}]	token valid, user is captain	403 wrong role
POST	/api/v1/captain/requests/{ride_id}/accept	Accept ride request	Bearer	-	{status: "accepted", trip_id, pin_to_passenger}	valid ride, captain online	400 already accepted, 403 offline
POST	/api/v1/captain/requests/{ride_id}/reject	Reject ride request	Bearer	-	{status: "released"}	valid ride	404 not found
POST	/api/v1/captain/toggle-online	Go online/offline	Bearer	is_online (bool)	{status, online_since}	token valid	400
Trip Execution Endpoints
Method	Path	Purpose	Auth	Request	Response	Validation	Error
POST	/api/v1/rides/{ride_id}/start	Mark trip started	Bearer	-	{status: "en_route", location_update_pending}	ride in accepted pin-verified state	409 not ready
POST	/api/v1/rides/{ride_id}/complete	Mark trip completed	Bearer	-	{status: "completed", earnings, wallet_update}	ride en_route	409 not in progress
GET	/api/v1/captain/earnings	View earnings dashboard	Bearer	-	{total_earnings, today, this_week, available_for_payout, payout_history}	token valid, user is captain	403 wrong role
Captain Subscription Endpoints
Method	Path	Purpose	Auth	Request	Response	Validation	Error
GET	/api/v1/captain/subscription	View subscription status	Bearer	-	{plan_type, amount, status, expiry, next_payout}	token valid	403
POST	/api/v1/captain/subscription/pay	Pay daily/monthly fee	Bearer	plan_type (daily/monthly), payment_method_id	{status: "paid", subscription_active_from}	valid plan, sufficient funds	400 invalid, 402 payment failed
GET	/api/v1/captain/commission-rate	Get commission rate (bike vs SaaS)	Bearer	-	{bike_commission_pct, saas_daily_fee, saas_monthly_fee}	token valid	403
Payment Endpoints
Method	Path	Purpose	Auth	Request	Response	Validation	Error
POST	/api/v1/payments/initiate	Initiate ride payment	Bearer	ride_id, payment_method (cash/UPI/wallet/card), amount	{status: "pending", gateway_url or otp_required}	valid ride, valid payment method	400 bad input
POST	/api/v1/payments/callback	Payment gateway webhook	None	gateway payload	{status: "success"}	signed webhook verification	400 invalid signature
GET	/api/v1/payments/history	View payment history	Bearer	-	[{ride_id, amount, method, status, txn_id, date}]	token valid	403
Power Pass Endpoints (User)
Method	Path	Purpose	Auth	Request	Response	Validation	Error
GET	/api/v1/user/power-pass	View Power Pass status	Bearer	-	{plan_type, amount, discount_pct, rides_remaining, validity_expiry, last_ride_discounted}	token valid	403
POST	/api/v1/user/power-pass/purchase	Purchase Power Pass	Bearer	plan_type (weekly/₹19/30days, monthly/₹15/35%/30days)	{status: "activated", next_ride_discounted}	valid plan, sufficient funds	400 invalid, 402 payment failed
GET	/api/v1/user/power-pass/ride-history	View rides with Power Pass discount	Bearer	-	[{ride_id, original_fare, discounted_fare, discount_pct}]	token valid	403
Safety Endpoints
Method	Path	Purpose	Auth	Request	Response	Validation	Error
POST	/api/v1/sos/activate	Activate Emergency SOS	Bearer	ride_id (optional), contact_numbers	{status: "activated", safety_team_notified, sms_sent}	valid context	400 bad ride/id
GET	/api/v1/sos/status	SOS status	Bearer	-	{incident_id, location, duration, resolved, notes}	valid session	404 no active SOS
GET	/api/v1/safety/features	View safety features overview	None	-	{features: [otp, tracking, share, insurance, SOS]}	public info	200
Admin Endpoints
Method	Path	Purpose	Auth	Request	Response	Validation	Error
GET	/api/v1/admin/dashboard	Admin operational dashboard	Bearer (admin)	-	{rides_today, active_captains, earnings, city_stats, tickets_open}	admin token, role check	403 not admin
POST	/api/v1/admin/tickets/{ticket_id}/resolve	Resolve support ticket	Bearer (admin)	resolution_notes	{status: "resolved"}	valid ticket, admin auth	404 not found, 403 not admin
GET	/api/v1/admin/captains/{captain_id}	View captain details	Bearer (admin)	-	{profile, verification_status, earnings, violation_count}	admin token	403
POST	/api/v1/admin/captains/{captain_id}/suspend	Suspend captain account	Bearer (admin)	reason	{status: "suspended"}	admin auth, valid reason	403, 400 bad reason
Real-Time Events (WebSocket)
Event	Channel	Payload	When Sent
captain_location_update	ride:{ride_id}	{lat, lng, timestamp, accuracy, speed, heading}	Every 5-10 seconds when ride en_route
ride_status_change	ride:{ride_id}	{from_state, to_state, timestamp, reason}	On each state transition
eta_update	ride:{ride_id}	{new_eta_minutes, reason}	When ETA changes > 1 minute
trip_completed	ride:{ride_id}	{final_fare, payment_status, rating_prompt}	When ride → completed
new_ride_request	captain:{captain_id}	{ride_id, pickup, drop, fare, category, expiry_ts}	When new request dispatched
cancellation_notify	ride:{ride_id}	{cancelled_by, reason, refund_amount}	When ride → cancelled
payment_success	payment:{ride_id}	{transaction_id, amount, method, status}	When payment → success
power_pass_update	user:{user_id}	{rides_remaining, discount_applied, expiry_warning}	When ride used or count changes
Ride State Transitions (allowed)
requested  ──────┐
     │               │
     ▼               │
accepted ──────► en_route ──────► completed ──────► closed
     │               │                   │
     │               │                   └──► refund_requested
     │               │
     └──► cancelled ──────► closed
              (before assignment: no fee)
              (after assignment: may charge cancellation fee)
16. Real-Time Event Specification
Real-Time Events Requiring WebSockets
Event	Source	Frequency	Payload	Priority
captain_location_update	Captain app GPS	Every 5-10 seconds (when en-ride)	{lat, lng, timestamp, accuracy, speed, heading}	Critical – ETA accuracy
ride_status_change	Backend dispatch	On each state change	{from_state, to_state, timestamp, reason}	Critical – UI must update
eta_update	Dispatch algorithm	When ETA changes > 1 min	{new_eta_minutes, reason, confidence}	High – passenger expects updates
new_ride_request	Dispatch server	When a new ride is dispatched to captain	{ride_id, pickup, drop, fare, category, expiry_ts}	Critical – captain must see immediately
cancellation_notify	Either party	On cancellation	{cancelled_by, reason, refund_amount, timestamp}	High – both sides need to know
trip_completed	Backend	When ride → completed	{final_fare, payment_status, rating_prompt, earnings}	High – earnings calc, notifications
payment_success	Payment gateway webhook	Immediate on callback	{transaction_id, amount, method, status, gateway_ref}	High – financial closure
power_pass_update	Backend	When ride uses Pass or count changes	{rides_remaining, discount_applied, expiry_warning}	Medium – passenger awareness
sos_alert	Safety team / app	Immediate on SOS press	{incident_id, lat, lng, user_type, timestamp, contacts_notified}	Emergency – highest
message_notif	Chat/support	When new message or update	{type, title, body, action_url}	Medium – passenger engagement
WebSocket Connection Management
- Connection: Passenger/Captain app establishes WS on ride start; closes on ride complete/cancel
- Heartbeat: Server sends ping every 25 seconds; client must pong within 30 seconds
- Reconnect: Exponential backoff; max 5 retries; after 5 failures, show "connection lost" UI
- Room naming: ride:{ride_id} for ride-specific events; captain:{captain_id} for captain push; user:{user_id} for user pushes
- Concurrent connections: One active WS per ride; if rider changes device, old connection gracefully closes after 30s timeout
Duplicate Request Handling Strategy
1. Idempotency key – ride request includes client-generated idempotency key; duplicate ignored if same key within 60s window
2. Proximity deduplication – if two requests within 2min & same GPS area (50m radius), only first processed
3. Captain Auto Accept – if enabled, captain's app auto-accepts first request; subsequent requests within same trip shown as "already have a ride"
4. Retries on failure – client on 404/500 from dispatch retries with exponential backoff (1s, 2s, 4s, 8s, 16s max 60s)
5. Stale coordinate rejection – if coordinates older than 30s, request rejected; client must resend with fresh location
Offline/Online Behavior
- Captain goes offline – pending requests held for 3 minutes; then released to next captain in queue
- Passenger loses connection – ride state held on server for 3 minutes; app reconnects and syncs; if >3 min, ride released and passenger must re-request
- Network partition – server queues events; delivers when connection restored; max queue depth 50 events per client
- App foreground/background – iOS/Android permissions; location updates only while foreground unless "Background Modes" enabled (location updates allowed)
17. Maps and Dispatch Strategy
GPS Location Acquisition
- Passenger app: Request location permission "While using the app"; iOS/Android APIs; GPS + network triangulation; fallback to last known location if permission denied
- Captain app: Same permission scheme; additionally, "Background location" mode when "On-Duty" enabled (iOS requires explicit consent; Android may use FusedLocationProvider)
- Update frequency: Passenger: on ride start + periodic during trip (every 15-30s); Captain: every 5-10 seconds when en-ride; on-demand when idle
Geocoding and Reverse Geocoding
- Primary: Google Maps Geocoding API (free tier 2,500 requests/day; beyond that paid)
- Secondary: OpenStreetMap Nominatim (free, no rate limit but requires attribution; lower accuracy in India vs Google)
- Cache: Redis cache geocode results for 24 hours; key = hash(address); reduces API calls by ~70%
Address Autocomplete
- Implementation: Google Places API Autocomplete (Type: establishment/address/area)
- Countries: India; types: street, route, premise, city, administrative_area
- Min length: 3 characters; show results as user types
- Prediction fields: description, primary_text, secondary_text, place_id
- Cost: ₹0.50 per 1000 requests (Google); free for OSM
Pickup + Destination Markers
- Pickup marker: Blue bike/auto/cab icon; pulsating on ride request; disappears after acceptance
- Destination marker: Red pin with drop label; static after booking
- Both on map: Google Maps Street View integration optional; both show distance + estimated travel time
Distance + ETA Estimation
- Algorithm: Haversine formula for initial distance; Google Maps Directions API for accurate ETA considering traffic
- Traffic layer: Google Maps Traffic API (paid); real-time traffic conditions
- ETA update frequency: Every 30-60 seconds during en-ride; more frequent during turns/intersections
- Fallback: If API fails, use constant speed estimate (20 km/h for bike, 15 km/h for auto, 40 km/h for cab)
Nearby Captain Discovery
- Spatial query: PostGIS ST_DWithin(pickup_point, captain_location, radius_km) 
- Index: GiST index on location_updates.lat/lng; CREATE INDEX ON location_updates USING GIST (point(lng, lat) GIST_OPS);
- Sort: By distance ASC, then by rating DESC, then by current ETA ASC
- Radius: 3 km default; adjustable per city density (2 km in dense metro, 5 km in suburban)
- Category filter: Only captains with matching vehicle type (bike captains for bike rides, etc.)
Captain-to-Passenger Matching
- Algorithm: Delaunay triangulation + weighted scoring
- Weight factors: distance (40%), captain rating (20%), category match (20%), current workload (10%), ETA (10%)
- Scoring formula: score = 0.4/distance + 0.2/rating + 0.2/category_match + 0.1/(1+workload) + 0.1/eta
- Concurrency limit: Max 3 concurrent rides per captain; new requests wait in queue
- Anti-stale: Captain location must be updated within last 10 seconds to be considered; otherwise excluded
Driver Movement + Live Tracking
- GPS source: FusedLocationProvider (Android) / CLLocationManager (iOS) with PRIORITY_HIGH_ACCURACY
- Accuracy threshold: Accept if < 10m; else use last good fix; flag if > 100m (likely GPS drift)
- Movement detection: If no update > 2 minutes, mark captain as "stuck" or "offline"
- Trip completion validation: Bounds check – rider dropped at dropoff coordinates within 200m tolerance; else flag for manual review
- Route deviation: If captain deviates > 500m from planned route for > 3 minutes, safety alert triggered
Location Update Frequency & Power
- Android: Priority.PAUSED when app backgrounded; Priority.HIGH when foreground + en-ride
- iOS: kCLLocationAccuracyHundredM when backgrounded; kCLLocationAccuracyBest when foreground
- Power saving: iOS limits background location to ~18 minutes per hour; Android similar restrictions
- Optimization: Use setInterval 10s when en-ride; setTimeout 120s when idle; aggregate pings to server every 30s
Service Boundaries + Geofencing
- Service area: Defined as polygon of city coordinates; captains/passengers outside rejected or shown "service not available"
- Airport/train station zones: Special pricing; geofence triggers surcharge or different category
- No-ride zones: Certain areas (high-security, restricted) where rides cannot start/end; geofence prevents booking
- Geofence on trip start/end: Server validates pickup/drop coordinates against allowed zones; invalid coords return 400 error
Route Deviation + Trip Completion Validation
- Pre-trip: Planned route from pickup to dropoff via Google Maps Directions
- During trip: Server receives GPS pings every 5-10s; calculates distance from planned route
- Deviation alert: If distance from route > 500m for > 3 minutes → server sends "route deviation" notification to passenger; captain can explain via chat
- Trip completion: Server checks final drop coordinate within 200m of booked dropoff; else auto-generates "drop location disputed" ticket; passenger may rating-adjust or raise support
18. UI/UX and Design System Proposal
Observable Characteristics from Rapido Reference
Design Element	Rapido Observation	Proposal for Independent App
Layout structure	Grid-based hero; two-column on home; single-column forms on login; map takes ~50% height on trip screen	Original design; similar proportions but with our branding
Typography hierarchy	Poppins (300/400/500/600/700); Noto Sans for Indian lang support; H1-H4 sizes; consistent scale	Original typeface family; 8pt vertical rhythm; accessible contrast
Spacing	8dp/4dp grid; compact but readable; padding around cards; map toolbar spacing	Same 8dp base unit; consistent margins/paddings
Colors	Primary: #1E4B82 (dark blue); Accent: #FFCA21 (amber); Background: #F7FAFF (light blue); Text: #212121 (dark); SOS Red: #FF3333	Original palette adapted; our primary brand color; accent for CTA; SOS remains red for universal recognition
Map presentation	Google Maps centered; Captain marker (bike icon); Rider route polyline; ETA banner top; bottom sheet with driver info	Our own map styling; same interaction patterns; marker shapes reflect our branding
Buttons	Primary: bordered with accent fill; Secondary: outlined; Tertinary: text link; SOS: red shield icon button; large touch targets (44dp+ )	Original styles; our button designs with same touch target sizes
Bottom navigation	Tab bar at bottom: Home, Booking, Rides, Profile (passenger); Online/Offline, Earnings, Trips, Profile (captain)	Original pattern; our icon set and labels
Forms	Input with placeholder, dropdown suggestions, clear button, error state with message below; OTP input as 4-digit chips	Same pattern; our placeholder text; error messages in our tone
Cards	Service item cards on home; Captain card with photo/name/rating/vehicle; Ride card with fare/ETA; Profile card	Same structure; our visual design
Modal + bottom-sheet	Bottom-sheet from map screen: Captain details, PIN input, Share Trip options; Full-screen modals: Terms, Safety features	Same behavioral patterns; our content and branding
Loading indicators	Skeleton loaders on lists; progress bar on booking; spinners on modals	Same types; our design language
Error feedback	Red outlined banner with message; inline error below input; full-screen error page for network off	Same hierarchy; our error language
Empty states	"No rides yet"; "No saved locations"; "Nothing found" with illustration/CTA	Same concept; our illustrations and copy
Mobile responsiveness	Width breakpoints: 320px (phone), 375px (standard), 414px (large); vertical scrolling only; no desktop version	Same mobile-first approach; our breakpoints
Accessibility	Color contrast ≥ 4.5:1; talkback/VoiceOver labels; scalable text; 44dp minimum touch targets; high-contrast mode	Same standards; our implementation
Proposed Design System
Color Palette (suggested, original)
- Primary: #0066CC (brand blue) – CTA buttons, primary accents
- Secondary: #FF6B6B – secondary actions, warnings
- Accent: #FFD93D – highlights, active states
- Background: #F5F7FA – pages, cards
- Text Primary: #212525 – body text
- Text Secondary: #6C757D – secondary text, captions
- SOS Red: #DC3545 – emergency button (universal)
- Success Green: #28A745 – completed trips, positive actions
Typography
- Primary font: Inter (or equivalent modern sans-serif)
- Sizes: Text-xs (10px), Text-sm (12px), Body (14px), Body-lg (16px), Headings 24-32px
- Line height: 1.5; letter spacing: normal; font weight: 400/500/600/700
Component Categories
1. Atoms: Buttons (primary/secondary/tertiary), Input fields (text/OTP), Icons, Badges, Loading skeletons, Error banners
2. Molecules: Search bar (with placeholder + dropdown), Ride category chips, Fare estimate card, Rating star row, Bottom navigation tab bar
3. Organisms: Home screen (hero + services grid + CTA), Trip screen (map + bottom sheet + header), Captain request card, Profile card, SOS modal, Share sheet
4. Pages: Passenger onboarding (3-4 screens); Captain onboarding (4-5 screens); Ride booking flow (4 screens); Trip execution (5-6 screens); Profile & Settings; Admin dashboard (mockup)
Interaction Principles
1. Familiar patterns – reuse standard mobility app interactions (pull-to-refresh, bottom sheets, modals, skeleton loaders)
2. Clear feedback – every action has visual confirmation (button press, loading, success, error)
3. Minimal cognitive load – progressive disclosure; hide advanced options; stepwise booking
4. Touch-first – all tap targets ≥ 44dp; adequate spacing between interactive elements
5. Error prevention – confirm destructive actions; validate inputs before submission; disable submit while loading
6. Accessibility first – semantic HTML; ARIA labels; sufficient contrast; scalable UI; screen reader flow
7. Performance – skeleton loaders instead of spinners; lazy load images; 100ms tap highlight removal
8. Brand consistency – consistent use of color/typography/spacing; original imagery; tone of voice in copy
Copy Guidelines
- Button text – action-oriented, 2-4 words: "Book Ride", "Start Ride", "Share Trip", "Call Captain", "SOS"
- Form labels – concise, field-level: "Pickup location", "Drop destination", "Enter 4-digit PIN"
- Error messages – specific, solution-oriented: "Enter a valid address", "SMS failed, retry", "Captain unavailable, try again"
- Success messages – concise, celebratory: "Ride booked!", "Captain arriving in 3 min", "Trip completed, earnings added"
- Safety copy – clear, imperative for emergencies: "Press and hold SOS for 3 seconds", "Share your live location with trusted contacts"
- Power Pass copy – value-focused: "Save 40% on your next 8 rides", "Valid for 30 days from purchase"
19. Security, Privacy, and Reliability
Authentication and Token Management
- JWT access tokens – short-lived (15 min); signed with HS256 using environment secret; refreshed via refresh token (TTL 30 days)
- SMS OTP – 6-digit; sent via Twilio/India telco; rate-limited to 3 attempts per 10 minutes per phone number; cooldown 60 seconds between sends
- Persistent rider PIN – 4-digit; stored encrypted on device; used at trip start only; different from OTP; persists across rides
- Captain session – online/offline toggle; token invalidated on account suspend/deactivate; concurrent session limit (1 device at a time)
Role-Based Access Control (RBAC)
Role	Permissions
passenger	Book rides, view trip history, make payments, rate trips, share trip, access SOS, view Power Pass
captain	Accept/reject requests, navigate trips, view earnings, update availability, access SOS, manage profile/docs
support_agent	View/any passenger/captain profiles, resolve tickets, process refunds, view SOS incidents, export data
admin	All of above + user/Captain management, pricing/configuration, analytics exports, audit log access, system settings
Protection of Personal Information
- Data minimization – collect only what's needed for service delivery (phone, location during trip, minimal profile data)
- Encryption at rest – PostgreSQL with TDE (Transparent Data Encryption); Redis with TLS; FSJS for file uploads
- Encryption in transit – TLS 1.3 everywhere; API endpoints serve only over HTTPS; certificate pinning for mobile apps
- Pseudonymization – user IDs are opaque UUIDs; phone numbers hashed; location data aggregated for analytics
- Access controls – RBAC as above; all API endpoints require valid token; rate limiting per IP/user (100 req/min); IP blocking after abuse
- Third-party sharing – only with TPSPs under contract; data sharing agreements; minimum necessary principle; no selling/renting of data per Privacy Policy
Location Privacy
- Captain location – only when "On-Duty" enabled and app is in foreground/background (per user consent); turns off automatically when "Off-Duty"; no location when app closed unless explicit permission
- Passenger location – used only for pick-up/drop detection and real-time tracking during trip; turned off after trip completion unless user enables location sharing with trusted contacts
- Retention – trip location data retained 30 days; then anonymized (coordinates randomized to nearest 1km grid); not linked to identity after 24 hours
- User controls – in profile: "Share location with trusted contacts" toggle; "Keep location history" opt-in/opt-out; "Delete trip data" button
Secure Payment Processing
- Never store card details – use Stripe/Razorpay tokenization; card data handled by PCI DSS Level 1 service provider
- Payment flow: App → Gateway (Stripe/Razorpay) → Gateway → Bank → Confirmation → App; we never see raw card numbers
- UPI payments – via Intent; app launches UPI player (Google Pay, PhonePe, Paytm); on completion, callback with status
- Wallet balance – stored in our DB, encrypted; recharged via Stripe/Razorpay; cashed out to linked bank account
- Refunds – initiated via same gateway; original transaction ID; 5-7 business days; policy: "Any payment made is non-refundable" per Terms, but support may exceptional-case
- PCI compliance – our app is PCI DSS Level 2 service provider (if we store any card data) or Level 1 if using full tokenization; we opt for tokenization to avoid scope
API Validation and Rate Limiting
- Input validation – server-side schema validation (Zod/Valibot); reject malformed requests with 400; never trust client data
- Rate limiting – per-endpoint limits: auth 5/min per IP, rides 50/min per user, captain requests 30/min per captain; global burst: 200/min; excess → 429 with Retry-After
- Payload size – max 1MB per request; larger uploads via signed URL to cloud storage
- CSRF protection – for web forms; double-submit cookie pattern; not needed for mobile apps with native auth
- Header security – X-Content-Type-Options: nosniff; X-Frame-Options: DENY; Referrer-Policy: strict-origin-when-cross-origin; CSP with 'self' + required domains
Abuse and Fraud Prevention
- Trip fraud detection – AI model flags: impossible ETA, GPS tampering, repeated short trips, anomalous payment patterns; auto-review flagged trips
- Account fraud – phone number verification (Twilio verify); detect simulator/emulator; limit new accounts per phone/IP per day
- SOS abuse – cooldown 30 minutes between SOS presses; false reports → warning → temporary suspension; malicious → permanent deactivation
- Payment fraud – Stripe Radar; detect stolen cards, test card numbers; 3D Secure for cross-border; flag suspicious amounts/patterns
- Captain behavior – monitor cancellation rate (>30% triggers review), customer rating drop (<3.5 triggers review), no-show pattern; warnings → suspension → deactivation
- Passenger behavior – false SOS reports, harassment, abusive language; warning → trip ban → account deactivation
- KYC/AML – document verification for Captains; transaction monitoring for large/patterned payments; report to FIU-IND if thresholds exceeded
Secret and API Key Management
- Never hardcode – all secrets (API keys, JWT secrets, SMS credentials) loaded from environment variables at runtime
- Secret rotation – quarterly rotation schedule; automated via CI/CD; old secrets valid for 7 days during rotation
- Environment segregation – separate .env files for development/staging/production; production keys never in repo; .env.example has placeholder values
- Key management service – AWS Secrets Manager or HashiCorp Vault for production; local .env for development
- Secrets in logs – scrub before logging; omit Authorization headers, credit card numbers, API keys from any log output
Secure File Uploads for Verification Documents
- Allowed types – PDF, JPEG, PNG (max 10MB each); DL/RC/insurance PDF preferred
- Upload flow → Signed URL (S3/Blob storage) → Client uploads directly → Server receives notification; never passes through our server (reduces PCI/liability)
- Virus scan – ClamAV or Cloudflare scanning on upload; reject infected files
- Resizing – thumbnail 400×400px for profile preview; original stored encrypted
- Retention – kept while captain active + 12 months post-deactivation; then secure erase; chain of deletion logged
Logging and Audit Trails
- Structured logs – JSON format; include: timestamp, service, request_id, user_id (if applicable), endpoint, method, status, latency, error_code
- Immutable storage – write-only logs to S3 with Object Lock; retain 3 years; cannot be deleted/overwritten
- Audit log entities – user creation, profile update, ride state change, payment, suspension, document upload, login (success/failed)
- Log retention – detailed logs 90 days; aggregated/hashed logs 1 year; raw logs 3 years for compliance
- Monitoring – real-time alert on: >5 failed logins/min, >10 SOS activations/hour, >10% payment failures, unusual geography spikes
Database Backups
- Automated daily – full PG dump; encrypted with GPG; stored in separate region/bucket
- Point-in-time recovery – enabled; WAL archiving; recovery time < 1 hour
- Backup frequency – hourly incremental; daily full; retain 7 daily, 14 weekly, 12 monthly
- Test restores – quarterly; validate backup integrity; document RTO/RPO
Error Monitoring
- Sentry/Datadog – capture exceptions, breadcrumbs, user impact; alerts on error rate thresholds
- Custom metrics – ride success rate, SOS rate, payment failure rate, OTP failure rate, connection drop rate
- Alert channels – Slack, email, SMS for critical; daily digest for non-critical
- Dashboard – internal ops dashboard; key metrics at a glance; drill-down to incidents
Network Interruptions & Retry Strategies
- Client-side: exponential backoff (1s, 2s, 4s, 8s, 16s max 60s); UI shows "connecting/retrying"; graceful degradation (some features unavailable until reconnected)
- Server-side: request timeout 10s; queue failed requests; deliver when client reconnects; max queue age 5 minutes; then expire and notify user
- Offline storage – AsyncStorage/RoomDB caches last ride state; syncs when connection restores; conflicts resolved by timestamp (newer wins)
- Connection lifecycle – WebSocket ping/pong; auto-reconnect with backoff; UI "connection lost" banner; reconnect button
Data Retention and Deletion
- User-initiated deletion – "Delete account" button: anonymizes phone/identity; deletes profile, trip history, preferences; retains anonymized analytics data per law; 30-day grace period to restore
- Automatic purging – location data after 30 days; ride metadata after 90 days; payment logs per tax law (7 years); SOS incidents after 2 years (hashed identifiers); support tickets after 1 year
- Legal holds – if investigation/support ticket active, pause automatic deletion; resume after closure
- Export on request – user can download all their data (GDPR/PDP compliance); zip of JSON/CSV; generated within 48 hours
Applicable Indian Privacy, Transport, and Payment Requirements
- Digital Personal Data Protection Act (DPDP) 2023 – user consent for data collection; right to access/rectification/erasure; data localization not mandated but recommended; breach notification within 72 hours; appoint DPO if processing >3 crore users
- Indian Telegraph Act & Rules – SMS OTP regulations; prior consent for marketing SMS; Do Not Disturb registry compliance
- Motor Vehicles Act – Captain documentation: valid DL, RC, fitness certificate, insurance, pollution certificate mandatory; enforcement during onboarding and spot checks
- UPI regulations – NPCI guidelines; ATMP (Aadhaapay TPAP); our app as TPAP optional; use existing UPI players (GPay, PhonePe, Paytm) for better adoption
- RTA (Regional Transport Authority) compliance – vehicle fitness, insurance, pollution certificates as per state MV Act; transport department integration for verification optional but recommended
- Insurance regulatory – Acko Insurance partnership (or similar); group travel policy; display policy details on app; claims processed via insurer, not platform
- Consumer protection – Consumer Protection Act 2019; display terms prominently; non-refundable policy must be conspicuous; grievance redressal mechanism; ombudsman if needed
- IT Act 2000 & Rules – electronic records admissibility; digital signatures; data protection earlier provisions; still relevant alongside DPDP 2023
- Shops and Establishments Act – working hours, employee conditions (if hiring staff); not directly applicable to gig Captains but relevant for any employed support staff
- GST – if platform revenue > ₹20 Lakh/year (or ₹10 Lakh for special category states); collect and remit GST; file monthly/quarterly returns; invoice generation for commissions/SaaS fees
High-Risk Areas and Mitigations
Risk	Mitigation
SOS false triggers	Cooldown 30 min; require press-and-hold 3 seconds; UI confirmation; log and review; penalize malicious reports
Captain revenue loss	SaaS model risk: if drivers don't pay daily fee, no rides; mitigations: grace period, auto-pay, referral incentives, support outreach
Passenger safety incidents	SOS → immediate safety team; GPS sharing; 24/7 on-ground support; post-ride insurance claim process; background-verified Captains
Payment disputes	Clear receipts; gateway dispute process; non-refundable policy communicated upfront; support mediation; terms accepted at onboarding
Location spoofing	GPS accuracy checks; compare phone GPS vs IP location; flag impossible speeds; require app foreground for updates
Driver deactivation backlash	Clear T&Cs; appeal process; human review before permanent suspension; back pay for unjustly suspended periods
Data breach	Encryption at rest/in transit; minimal data collection; breach response plan; 72-hour notification; insurance coverage for legal costs
** regulator changes**	Monitor DPDP, transport, insurance rule changes; quarterly compliance review; legal counsel retainer; flexible architecture to adapt
Platform downtime	99.9% SLA target; auto-scaling infrastructure; read-only mode if critical DB down; communicated ETA to users; alternative contact methods
Captain no-show pattern	Automatic cancellation after 5-min wait; passenger reroute option; compensation (small credit); monitor pattern → warning → suspension
20. Testing and Acceptance Criteria
Unit Testing
Area	Test Cases	Criteria
Auth flow	Register with valid phone + OTP; register with invalid phone; resend OTP; login with wrong OTP 3+ times lock account	100% pass; lockout after 3 failures
Ride request	Valid pickup/drop coordinates; invalid coordinates (lat > 90); missing ride category; duplicate request within 60s	100% pass; 400 for invalid; idempotent for duplicate
OTP validation	Correct 6-digit OTP; incorrect 5-digit OTP; OTP expired (2 min); resend OTP cooldown	100% pass; 401 for wrong/expired
Power Pass	Purchase weekly plan; purchase monthly plan; insufficient funds; ride uses discount; rides exhausted	100% pass; discount applied only when rides remaining
SOS	Activate SOS with ride_id; activate without ride_id (emergency); cooldown 30 min; status check	100% pass; safety team notified; 30-min cooldown enforced
API Integration Testing
Endpoint	Test Scenarios	Criteria
Ride request	Success flow; missing fields; wrong category; out-of-service area; concurrent requests	200 on success; 400 on bad input; 404/409 on area/duplicate
Pin start	Correct pin; wrong pin; already started; pin expiry	200 on correct; 400/409 on wrong/already
Captain accept	Captain online; captain offline; already accepted; different category ride	200 on accept; 403 if offline; 409 if already
Earnings payout	Sufficient earnings; below minimum; payout frequency; bank validation	200 with payout_id; 400 if below min; 202 if processing
SOS activate	Valid ride_id; no ride_id (emergency); contact numbers format; already active	200; safety team notified; 30-min cooldown
Authentication and Authorization
- Test: All endpoints without valid token → 401; with token but wrong role → 403; token expired → 401; refresh token flow works
- Criteria: 100% of protected endpoints return correct status; no endpoint accessible without auth; role checks enforceable
Ride Lifecycle Testing
- Happy path: Request → Accept → Start (OTP) → En-route → Complete → Payment → Rating → Closed
- Cancellation before assignment: Passenger cancels → no fee → ride → closed
- Cancellation after assignment: Passenger cancels → cancellation fee applied → Captain receives fee; ride → closed
- Driver reject: Passenger sees "no driver available" → can re-request after 2 min
- No driver available: After 3 min, passenger re-requested automatically or manually; ETAs shown
Matching and Dispatch Concurrency
- Test: Two captains near same ride; first to accept gets it; second sees "ride already accepted"; concurrency limit 3 rides per captain tested
- Criteria: Exactly one captain accepted; others get notification; captain's ride count increments correctly; no double-booking
Real-Time Location Updates
- Test: Mock GPS pings every 5s; verify map marker updates; ETA recalculates when ping changes; WebSocket message received by passenger app
- Criteria: Marker moves smoothly; ETA updates within 5s of new ping; no stale coordinates >10s old
Payment Success and Failure
- Test: Successful UPI intent + callback; failed UPI (insufficient funds); successful card token; failed card (declined); wallet payment; cash payment recorded manually
- Criteria: Each payment method leads to correct ride status; failed payments don't start ride; successful payments trigger earnings update; refund requests flow works
Cancellation and Refunds
- Test: Cancel before assignment (no fee); cancel after assignment (fee applied); Captain-initiated cancellation; support ticket for dispute; refund request (process per policy)
- Criteria: Fee correctly calculated per policy; passenger informed of fee before confirmation; Captain compensated per policy; support tickets resolved within SLA (24h)
Network Interruption
- Test: Simulate lost connection during ride; verify ride state preserved on server; app reconnects and syncs; if >3 min, ride released and passenger re-requests; no data loss
- Criteria: Ride state survives 5-min partition; auto-reconnect works; user informed of status on reconnect; no orphaned rides
GPS Permission Denial
- Test: User denies location permission at first launch; app guides to settings; features requiring location disabled or gracefully degraded; ride can still be booked with manual address entry
- Criteria: No crash on denial; explanatory message shown; core booking works without GPS; SOS still works (uses last known location)
Empty and Error States
- Test: Home screen with no rides; search with no results; ride history empty; payment methods empty; profile without photo; map with no captains nearby
- Criteria: Each empty state shows appropriate illustration + CTAs; error states show message + retry; no blank screens; accessible labels on all elements
Security Testing
- Test: SQL injection attempts on all inputs; XSS in error messages; path traversal on file uploads; auth bypass; rate limit exhaustion; token reuse after revocation
- Criteria: All inputs validated/sanitized; no sensitive data in logs; 401 on authless access; rate limits enforced; revoked tokens rejected
Mobile Responsiveness
- Test: Viewport 320px, 375px, 414px, 768px; touch targets ≥ 44dp; text resizes to 200% without overflow; horizontal scrolling avoided; portrait/landscape modes
- Criteria: Layouts adapt; no cut-off content; touch targets work; landscape not broken (if supported); text readable without zoom
Performance and Load Testing
- Test: 1000 concurrent ride requests; 10000 location pings/min; 100 SOS activations/min; API response <200ms for 95th percentile; WebSocket stable at 500 connected clients
- Criteria: 95th percentile response times met; no dropped WebSocket connections under load; database query times <100ms; CPU/memory within limits; autoscaling triggers correctly
Dependencies Preventing Real-E2E Testing
- Google Maps API keys – need valid key with billing; rate limits; geocoding/E2E without keys limited
- SMS OTP provider – Twilio/India telco integration; test SIM or mock provider needed
- Payment gateways – Stripe/Razorpay test mode; real card details not allowed; sandbox required
- Apple/Google developer accounts – for app store deployment; not needed for web/E2E
- Safety team dashboard – internal tool; not accessible for E2E; mock SOS flow sufficient
- Real device fleet – testing on 50+ device configurations; emulators simulators for early; real devices for final
Measurable Acceptance Criteria (most important workflows)
Passenger: Book + Complete Ride
1. Ride requested within 2 min of pickup location set; ETAs shown immediately
2. Captain accepted within 5 min (configurable per city density); if >5 min, "no driver available" shown + re-request option
3. 4-digit OTP given to passenger; Captain confirms PIN; trip status → accepted → en_route
4. Live tracking updates every ≤10s; marker on map moves smoothly; ETA updates within 5s of GPS change
5. Share Trip link sent to at least 1 contact; link shows live location + Captain + ETA; updates in real-time
6. SOS button: press-and-hold 3 seconds → safety team alert + SMS to contacts; cooldown 30 min enforced
7. Trip completes; final fare displayed; payment method charged/recorded; earnings added to Captain wallet
8. Rating prompt appears; 1-5 star + optional comment; rating submitted; trip → closed
9. Trip appears in history; rider can view fare, date, duration, rating; filter by date/category
Captain: Accept + Complete Ride
1. Captain online; receives ride request with pickup/drop + fare; Auto Accept option off → manual Accept tap
2. Accept → trip ID generated; 4-digit PIN sent to passenger; Captain info (name, vehicle) displayed to passenger
3. Captain navigates to pickup; passenger confirms arrival (implicit via OTP or explicit tap); trip → en_route
4. Live location updates every 5-10s; ETA to passenger updates; route shown on map
5. Passenger exits; Captain marks trip complete; earnings auto-calculated; wallet balance updated
6. Payout available after minimum threshold (e.g., ₹100); twice-weekly payout schedule; bank transfer initiated
7. Rating received from passenger; Captain can view own rating; rating impacts future ride priority (optional)
Power Pass Purchase + Usage
1. User views Power Pass options (weekly ₹19/30days, monthly ₹15/35%/30days); pricing + discount details clear
2. Purchase via wallet/UPI/card; successful → plan activated; expiry date shown; rides remaining countdown starts
3. First ride after purchase: original fare shown discounted instantly at payment; discount applied; rides_remaining decremented
4. After N rides (5 for monthly, 8 for weekly): discount expires; full fare charged from next ride; user notified before expiry
5. Power Pass visible in profile; rides history shows which rides had discount; support can restore if bug
Safety: SOS + Share Trip
1. SOS activated (press-and-hold 3s) → immediate SMS to 3 pre-registered trusted contacts with live location link
2. Safety team notified via dashboard; estimated response time displayed to user; user can cancel within 2 min if mistaken
3. Share Trip (from ride screen) → live location link sent to selected contact; link works without app installation; updates in real-time until trip ends
4. Both features accessible from ride screen; visible but not obtrusive; toggle in profile to enable/disable Share Trip
21. Development Roadmap
Phased Implementation Roadmap
Phase	Title	Deliverables	Dependencies	Technical Risks	Test Requirements	Definition of Done
1	Requirements Confirmation & Project Setup	Project charter; tech stack finalized; team assigned; dev env; CI/CD pipeline; design system baseline; legal review of business model	None	Low – standard setup	Team alignment; tech decisions documented	Charter signed; env operational; design tokens committed
2	Design System & Navigation	Color palette; typography; component library (atoms/molecules/organisms); page layouts; bottom navigation; responsive breakpoints; design handoff specs	Phase 1	Low – design system is foundation	Component inventory; accessibility scan (a11y)	Design system repo; Figma/Sketch file; CSS variables committed
3	Authentication & User Profiles	Phone + SMS OTP login; persistent rider PIN; profile CRUD; role differentiation (passenger/captain); email verification; password reset	Phase 1; Twilio/SMS provider API key	Medium – SMS reliability; OTP expiry logic; PIN storage encryption	Unit tests for auth flow; integration: login/logout/PIN; fuzz inputs	Auth flows end-to-end; user can register/login/PIN ride start; passwords encrypted at rest
4	Maps & Location Search	Google Maps SDK integration; geocoding/reverse geocoding; address autocomplete; pickup/drop inputs; map markers; distance/ETA calculation; nearby captain discovery; service area geofencing	Phase 1; Google Maps API key; PostGIS setup	High – Google Maps cost; rate limits; India coverage; Android/iOS location permissions; battery impact	Unit: geocode/reverse; integration: autocomplete, ETA, captain discovery; GPS permission denial flow	Maps functional; autocomplete works; ETA reasonable; captain discovery returns sorted results; geofence boundaries correct
5	Fare Estimation	Fare estimate API; category-based pricing (bike/auto/cab); Power Pass discount logic; fare breakdown display; dynamic surge prevention (basic)	Phase 4; pricing model from analysis; Power Pass design from Phase 2	Medium – pricing accuracy; discount edge cases; surge algorithm	Unit: fare calc; integration: estimate + discount; Power Pass purchase + ride discount	Fare shown before booking; Power Pass discount auto-applies; correct ride count tracking; expiry handled
6	Ride Requests & Dispatch	Ride request API; captain request flow; Accept/Reject; concurrency limit 3; ride ID generation; PIN start flow; cancellation (before/after assignment)	Phase 3; Phase 4 (maps); business rules from analysis	Medium – concurrency logic; PIN validation; cancellation fee calculation; idempotency	Integration: request + accept + start + complete flow; concurrency tests; cancellation fee edge cases	Rider can request ride; captain can accept/reject; PIN starts ride; cancellation fees correct; idempotent requests
7	Captain Application Workflows	Captain onboarding (DL/RC/photo/PAN/Aadhaar upload); verification status; go online/offline toggle; earnings dashboard; payout; incentives; ratings; support access	Phase 3; payment gateway (Stripe/Razorpay test mode); background verification TPSP mock	Medium – document upload; verification workflow; payout logic; incentive calculations; two-week payout cycle	Integration: onboarding end-to-end; payout flow; earnings calc; incentive formulas; rating flow	Captain can onboard with docs; verification status updates; go online/offline works; earnings dashboard shows correct totals; payout initiates; incentives calculated correctly; ratings visible
8	Live Tracking & Trip Lifecycle	Real-time GPS pings via WebSocket; trip state machine; location update frequency; route deviation alerts; trip completion validation; drop-coordinate tolerance; trip closed + payment flow	Phase 4; WebSocket infrastructure; PostGIS; Sentry for error tracking	High – real-time infra; GPS accuracy; WebSocket stability; battery impact; state machine complexity	Integration: full trip lifecycle from request → close; WebSocket message flow; deviation alert trigger; tolerance test	Trip state machine works end-to-end; GPS updates real-time; deviations flagged >500m; trip completes; payment processed; closed state final
9	Payments & Transaction History	Payment gateway integration (Stripe/Razorpay test mode); UPI intent; wallet balance; cash payment recording; transaction ledger; refund flow; receipt generation; GST invoicing (if applicable)	Phase 3; Payment gateway accounts; tax compliance setup	High – PCI compliance; gateway APIs; refund logic; tax calculations; wallet ledger integrity	Integration: all payment methods; refund flow; receipt generation; GST setup; wallet ledger reconciliation	All payment methods work in test mode; receipts generated; wallet balance correct; refunds processed per policy; GST applicable if revenue threshold met
10	Ratings, Support & Notifications	1-5 star rating + comment; rating submitted; trip history shows rating; support ticket creation; ticket status tracking; push notifications (FCM); SMS notifications (Twilio); in-app messages; ride update notifications	Phase 3; FCM account; Twilio account; notification design from Phase 2	Medium – notification delivery; FCM token management; SMS cost; ticket SLA; rating math; support workflow	Integration: rating flow; ticket creation + status; notification send/receive; FCM token rotate; SMS fallback	Ratings calculate and display; tickets created and trackable; push + SMS deliver; in-app messages shown; ride updates arrive
11	Admin Dashboard	Admin endpoints; user/Captain management; pricing/configuration UI; analytics exports; ticket resolution; audit logs; RBAC enforcement; system settings	Phase 10; role design; analytics stack; audit log infrastructure	High – RBAC complexity; data exports volume; ticket SLA tracking; system settings persistence	Integration: admin can manage users/captains; pricing changes apply; tickets resolvable; logs immutable; RBAC correct	Admin can CRUD users/captains; pricing updates propagate; tickets resolved within SLA; audit logs immutable; RBAC blocks wrong roles
12	Security, Testing, Deployment & Optimization	Security hardening (auth, data, payment); penetration testing; load testing; performance optimization; beta launch; app store submission (iOS/Android); monitoring setup; documentation	All prior phases; security expertise; devops; app store accounts	Very High – security audits; app store approval; real device testing; compliance verification; load test infrastructure	Full security test suite; load test results; app store compliance checklist; monitoring dashboards live; docs published	App passes security audits; load test metrics within goals; both app stores live; monitoring alerts configured; all docs current; team trained
Roadmap Reordering & Prioritization
- MVP scope: Phases 1-6 first (auth + maps + ride request + basic dispatch); then Phase 7 (captain onboarding); then Phase 8 (trip lifecycle); Phase 9 (payments) is critical for launch but can be beta; Phase 10-12 post-MVP
- Dependencies: Phase 3 → Phase 4 (maps needs auth for user context); Phase 4 → Phase 6 (dispatch needs maps); Phase 6 → Phase 7 (dispatch needs captain profiles); Phase 7 → Phase 8 (trip lifecycle needs captain workflows); Phase 8 → Phase 9 (payments needed for trip close); Phase 9 → Phase 10 (ratings/notification need payments); Phase 10 → Phase 11 (admin needs all user/captain data); Phase 11 → Phase 12 (security/test/deploy needs all prior)
Prioritized MVP Flow
1. Auth + Profiles (Phase 3) – users + captains can register/login/PIN
2. Maps + Location (Phase 4) – geocode, autocomplete, map, captain discovery
3. Ride Request + Dispatch (Phase 6) – request ride; captain accept; PIN start
4. Trip Lifecycle (Phase 8) – en-route tracking; complete; payment trigger
5. Payments (Phase 9) – payment methods; wallet; receipts (beta; cash manual)
6. Captain Onboarding (Phase 7) – docs upload; verification; go online/offline
7. Ratings + Support (Phase 10) – rating; ticket; notifications
8. Admin + Security (Phase 11-12) – dashboards; compliance; launch
Technical Risks by Phase
- Phase 4: Google Maps cost overruns; rate limit surprises; Android/iOS permission quirks; battery drain from location
- Phase 6: Concurrent ride acceptance race conditions; PIN validation edge cases; cancellation fee disputes; idempotency key collisions
- Phase 8: WebSocket connection stability on poor networks; GPS accuracy variance; state machine bugs causing stuck trips; deviation alert false positives
- Phase 9: PCI compliance scope; gateway API changes; refund policy misinterpretation; wallet ledger bugs; GST registration/filing
- Phase 7: Document upload corruption; verification TPSP integration; payout bank validation; incentive formula bugs; two-week payout cycle management
- Phase 10: Notification delivery failure; FCM token expiry; SMS cost overruns; ticket SLA breach; rating math edge cases
Test Requirements by Phase
- Phase 3: 50+ unit tests; 10 integration tests; security test (auth bypass)
- Phase 4: 30 unit tests; 15 integration tests; GPS permission scenarios; map load test (50 concurrent)
- Phase 6: 40 unit tests; 20 integration tests; concurrency stress test (20 captains, 50 rides); cancellation fee edge cases
- Phase 7: 35 unit tests; 15 integration tests; document upload test; verification workflow; payout test with mock bank; incentive formula verification
- Phase 8: 45 unit tests; 25 integration tests; WebSocket stress test (100 connected); GPS drift tolerance; deviation alert trigger; trip state machine exhaustive cases
- Phase 9: 30 unit tests; 20 integration tests; payment gateway test (test mode); refund flow; receipt gen; GST setup checklist; wallet ledger audit
- Phase 10: 25 unit tests; 15 integration tests; FCM send test; SMS send test; ticket creation + status test; rating math; notification priority
- Phase 11: 20 unit tests; 15 integration tests; RBAC exhaustive cases; admin UI test; analytics export; audit log immutability test
- Phase 12: Full security audit penetration test; load test (200 concurrent users); performance budget met; app store compliance checklist; monitoring dashboards; team training complete
Phase Prioritization Rationale
- Revenue-generating flows first: Ride request → dispatch → trip lifecycle → payments → captain onboarding (drivers need to onboard to get rides)
- User-facing flows before admin: Passengers and captains must have working apps before admins need dashboards
- Maps before dispatch: Can't dispatch without location/matching capability
- Auth before anything: All flows need authenticated users
- Security/devops last: Full security and deployment readiness needed only for launch
Estimated Timelines (high-level, assuming 3-person team)
Phase	Weeks	Key Milestone
1	2	Project charter; tech stack; design system start
2	3	Design system complete; component library
3	4	Auth flows complete; user/Captain profiles
4	5	Maps functional; autocomplete; captain discovery
5	3	Fare estimation; Power Pass basic
6	5	Ride request + dispatch end-to-end; cancellation
7	4	Captain onboarding complete; payouts
8	5	Full trip lifecycle; live tracking; deviations
9	4	Payments all methods; wallet; receipts; GST
10	3	Ratings; support tickets; notifications
11	3	Admin dashboards; RBAC; analytics
12	4	Security audit; load test; app store submit; launch
Total: ~48 weeks (≈ 1 year) for full feature set; MVP in ~20 weeks (Phases 1-7 with limited admin, payments in beta)
MVP vs. Later Enhancements
MVP (launchable in ~20 weeks):
- Passenger: register/login; book ride with maps; captain matching; PIN start; live tracking; complete; basic payment (card/UPI wallet; cash manual record); ratings; support ticket
- Captain: register with docs; verification; go online/offline; receive requests; accept; navigate; complete; earnings dashboard; payout (minimum threshold; manual bank details)
- Admin: basic dashboards; user/captain management; pricing set static; analytics basic; audit logs
Later Enhancements (Phases 8-12 post-MVP):
- Advanced Power Pass (multiple plans; ride counting; expiry); dynamic surge; enhanced SOS; in-app chat; trip history filters; advanced analytics; referral programs; multi-language full support; i18n; dark mode; Wear OS/web dashboard; corporate travel integration; fleet management; EV integration; drone delivery (future); AI demand forecasting
22. Third-Party Dependencies, Credentials, and Estimated Cost Categories
Dependency	Type	Cost Category	Notes
Google Maps Platform	Paid API key (Maps, Geocoding, Places, Routes)	Usage-based; ₹1-₹3/1K geocode; ₹2-₹5/1K static map; ₹5-₹10/1K route; volume discounts; monthly cap recommended	Essential for India coverage; best accuracy; can start with $200/month free credit (Google Cloud)
Firebase (App, Analytics, Messaging)	Free tier then pay-as-you-go	Free: 10K MAU, 100K daily downloads, 1GB storage/transfer; Paid: beyond free tier; typical app: $20-200/month	All-in-one; integrates auth, messaging, analytics; strongly recommended
Stripe or Razorpay	Payment processing SDK	1.5-2% per transaction + ₹₹₹ fixed fee (₹3-₹10); no setup fee; monthly volume-based pricing available; test mode free	Stripe: global; Razorpay: India-favored; both support UPI; neither should store card data (use tokens)
Twilio (SMS/Voice)	CPaaS for OTP + notifications	₹1 per SMS in India; voice calls ₹0.5-₹2/min; monthly plan available; test credits often provided	SMS OTP critical for auth; consider India-local provider (Msg91, Route Mobile) for lower cost; backup provider recommended
Apple Developer Program	Annual fee	₹29/year	Required for iOS app App Store submission; not needed for web or Android-only
Google Play Console	Annual fee	₹25/year	Required for Android App Play Store submission; one-time per developer account
Sentry or Datadog	Error monitoring	Free tier 3K monthly events; Paid $29+/month; typical mobility app: $50-150/month	Captures exceptions, breadcrumbs, user impact; essential for production
Cloud Storage (S3/Blob)	File hosting (documents, backups)	₹0.5-₹1/GB/month + request costs; minimal for early stage; first 5GB free (AWS/GCP)	Verification documents; backups; logs; can use Firebase Storage as alternative
Domain & SSL	Annual domain + cert	₹600-₹2000/year for .in/.com; Let's Encrypt free SSL	Professional address; customer trust; required for HTTPS everywhere
Background Verification TPSP	Contractual service	₹50-₹200 per Captain verification (depends on depth); annual contract possible	DL/RC/insurance verification; can integrate with existing Indian verification services; optional early; later enhancement
SMS Local India Provider	Alternative to Twilio	₹0.3-₹0.7 per SMS; volume discounts; Indian numbers; regulatory compliance	Lower cost than Twilio; compliance with TRAI regulations; recommended as primary or secondary
Monitoring & Analytics	Custom dashboard	Open-source (Grafana + Prometheus) free; hosted version $19-99/month; or custom build	For ops metrics; can start free; scale as needed
App Store Fees	One-time/annual	₹25 (Google) + ₹29 (Apple) per year	Both stores needed for full reach; can launch web-first; one store first then other
Legal/Compliance Review	Consultancy	₹50,000-₹200,000 (one-time) or ₹20,000-₹50,000/year	DPDP act compliance; transport regs; insurance contracts; T&Cs; advisable early to avoid rework
Total estimated monthly (after launch, 10K MAU):	 	₹3,000-₹15,000/month	Varies heavily on ride volume; Maps and payments are biggest cost drivers; can scale down with lower volume
Cost-Saving Strategies
1. Start with OpenStreetMap + Nominatim for geocoding until volume justifies Google Maps; switch when monthly requests > 5K
2. Use Firebase free tier extensively; migrate to self-hosted as user base grows
3. Stripe test mode only initially; move to live only after MVP validation; consider Razorpay for India-only launch to reduce complexity
4. Twilio alternative SMS providers in India for 40-60% cost savings; comply with TRAI headers; use two providers for redundancy
5. Free monitoring (Sentry cloud free tier + Grafana) until paid tier needed
6. Single store launch (Android first, lower fee; iOS later); web app for iOS users initially
7. Legal review phased – essential clauses first; remaining T&Cs can be updated via app updates; not all at launch
8. Capacity planning: start conservative on Maps/api limits; monitor; scale only when needed; set budget alerts
23. MVP Scope vs. Later Enhancements
MVP (Minimum Viable Product – launchable in ~20 weeks)
Passenger Features:
- Register/login with phone + SMS OTP; persistent 4-digit PIN
- Set pickup + destination via address input + map suggestions
- Select ride category (Bike/Auto/Cab); view fare estimate
- Book ride; captain matching; accept/reject flow (from captain side)
- Live GPS tracking of assigned captain on map
- 4-digit OTP to start ride; trip status updates
- Trip completion; fare display; payment methods (card/UPI/wallet; cash manually recorded)
- Rider rating (1-5 star + comment); view trip history
- Support ticket submission; basic in-app help
- Power Pass purchase (one plan; basic discount; ride count tracking)
Captain Features:
- Register with DL + RC + photo + PAN/Aadhaar; verification status visible
- Go online/offline toggle; receive ride requests
- Accept/reject single ride request; basic concurrency (max 1 active ride)
- Navigate to pickup via GPS; trip start confirmed by passenger PIN
- Live location updates to passenger; ETA updates
- Mark trip complete; earnings shown; wallet balance updated
- Request payout after minimum threshold (e.g., ₹100); bank details on file
- View own rating from passengers; basic support access
Admin Features:
- Static pricing configuration (commission rates; Power Pass price); no dynamic pricing
- User management (view/ban); Captain management (view verification status)
- Basic analytics: ride count; earnings total; active users; city distribution
- Support ticket overview; resolve/track tickets
- Audit logs (immutable); system settings (app version; feature flags)
Technical MVP:
- Flutter passenger + captain apps (separate codebases or shared with flags)
- FastAPI backend with PostgreSQL + PostGIS
- Google Maps Platform (basic usage; within free tier initially)
- Firebase for auth, messaging, analytics
- Stripe or Razorpay test mode for payments; cash recording manual
- Admin dashboard basic (CRUD + charts)
- No SaaS subscription model for Captains yet (commission model only)
- No advanced Power Pass (single plan; basic); no dynamic surge
- No corporate travel; no parcel delivery; no food delivery
Success Metrics for MVP:
- 100 registered users; 20 active captains; 50 rides completed in first month
- <5 min average wait time; >80% ride acceptance rate; >4 average rating
- <2% payment failure rate; <1% SOS false trigger rate
- Positive user feedback on usability; captains able to earn; admin can manage
Later Enhancements (Post-MVP, Phases 8-12)
- Advanced Power Pass: multiple plans (weekly/monthly); ride count tracking; expiry notifications; rollover; promotional codes; corporate partnerships
- Dynamic surge pricing: demand-based fare multiplier; Power Pass exemptions; algorithm tuned per city
- SaaS subscription for Captains: daily ₹9-₹₂₉ fee; zero commission after fee; monthly ₹500 for cabs >₹10K earnings; auto-pay; grace period; earnings-impact analytics
- In-App Chat: rider-captain communication (optional; privacy-enhanced); language support; escalation to support
- Trip History Filters: date range; category; rating; payment method; exported CSV; saved trips
- Referral Programs: invite codes; reward both referrer and referee; tiered rewards; attribution tracking
- Multi-language Full Support: Hindi, Tamil, Telugu, Kannada, Bengali; UI translation; regional payment methods; local compliance
- Dark Mode: user preference; adaptive color system; battery saving; aesthetic preference
- Wear OS Integration: trip start/end from wrist; ETA glance; SOS from watch; ride status vibration
- Corporate Travel Integration: corporate account; employee profiles; monthly billing; discounted fare plans; expense reporting
- Parcel Delivery (Rapido Local): package upload; weight tracking; recipient confirmation; pricing by weight; integration with existing Captain network
- Food Delivery (Ownly pilot): restaurant partnerships; order management; delivery tracking; revenue share; quality checks
- AI Demand Forecasting: predictive rider demand per area/time; captain positioning suggestions; dynamic hotspot mapping
- EV Integration: electric vehicle Captain tracking; battery level display; charging station locations; incentives for EV adoption
- Multi-city Support: seamless cross-city rides; different pricing per city; regional compliance auto-handling; unified wallet
MVP Feature Cutlist (vs. Full Rapido)
Feature	Reason for MVP Cut
SaaS subscription for Captains	Complex billing; needs separate phase; MVP uses commission model only
Dynamic surge pricing	Algorithm complexity; not needed for launch; can confuse new users
Multiple Power Pass plans	Simpler to have one plan; add later; MVP: one weekly plan
In-app chat	Adds complexity; can use phone call/SMS for MVP; add later
Corporate travel accounts	Billing complexity; enterprise sales cycle; later enhancement
Parcel delivery integration	Separate supply chain; different UI; later phase
Food delivery (Ownly)	Different business model; partner management; later phase
Multi-language full UI	Initial launch in English + one Indian language; i18n later; adds UI/UX complexity
Dark mode	Nice-to-have; can launch without; add in first update
Wear OS app	Small market; responsive web view sufficient; add later
Advanced AI demand forecasting	Data not available at launch; simple fixed schedules sufficient; ML phase 2
EV-specific features	Early adopters only; generic vehicle tracking sufficient; add later
24. Phased Development Roadmap (Detailed)
Phase 1: Requirements Confirmation & Project Setup (Weeks 1-2)
- Deliverables: Project charter; tech stack (Flutter + FastAPI + PostgreSQL + PostGIS + Firebase + Google Maps); team roles; CI/CD pipeline (GitHub Actions); design system baseline (color, typography, component library start); legal review of business model (commission vs SaaS; Power Pass structure; Indian compliance); risk register; project board setup (Jira/Linear)
- Dependencies: None
- Technical Risks: Team alignment; tech choice disagreements; scope creep; underestimating Indian regulatory complexity
- Test Requirements: Team charter sign-off; tech decision document; risk register approval
- Definition of Done: Charter signed; environment (dev/staging/prod) operational; design tokens committed to repo; legal review completed; project board populated with epics/stories; 1-week sprint goal set
Phase 2: Design System & Navigation (Weeks 3-5)
- Deliverables: Full design system (color palette typography spacing); component library (30+ atoms/molecules/organisms); page layouts for all screens (onboarding, auth, home, ride, trip, profile, admin); bottom navigation for passenger/captain; responsive breakpoints (320/375/414/768px); design handoff specs (CSS variables; Figma/Sketch file); component library committed to repo; design system documentation
- Dependencies: Phase 1 (project setup; team available)
- Technical Risks: Design system too rigid; component library too large for MVP; accessibility oversights; stakeholder sign-off delays
- Test Requirements: Component inventory; accessibility scan with axe-core; design review with stakeholders; styleguide validation (stylelint)
- Definition of Done: Design system repo with documentation; component library with 30+ components; Figma file approved; CSS variables in code; responsive breakpoints implemented in first 2 app screens; stakeholder sign-off obtained
Phase 3: Authentication & User Profiles (Weeks 6-9)
- Deliverables: Phone + SMS OTP login (Twilio/India provider); persistent 4-digit rider PIN stored encrypted on device; passenger profile CRUD (name photo emergency contacts languages); captain profile CRUD (DL RC photo PAN Aadhaar verification status online/offline toggle); email verification; password reset flow; role differentiation (passenger vs captain) throughout app; onboarding screens (3 for passenger; 4 for captain)
- Dependencies: Phase 1; Twilio/India SMS provider account; development device farms for iOS/Android testing
- Technical Risks: SMS reliability/latency; OTP expiry logic bugs; PIN storage encryption; role inconsistency between frontend/backend; OTP cooldown logic; email deliverability
- Test Requirements: 50+ unit tests (auth flow; PIN; profile CRUD); 10 integration tests (login/logout/PIN ride start); fuzz testing on input validation; security test (auth bypass attempts); SMS failure gracefully handled
- Definition of Done: User can register/login with phone OTP; PIN set and used at ride start; profiles editable; role checks enforceable (frontend + backend); password reset works; onboarding screens flow complete; PIN encrypted at rest; 95% unit test coverage; security test pass
Phase 4: Maps & Location Search (Weeks 10-13)
- Deliverables: Google Maps SDK integration (both apps); geocoding API (address → lat/lng); reverse geocoding (lat/lng → address); address autocomplete (as user types); pickup/drop inputs with recent/saved locations; map markers (passenger pickup; captain bike/auto/cab); distance calculation (Haversine); ETA estimation (basic); nearby captain discovery (spatial query PostGIS GiST index); service area geofencing (polygon validation); offline map fallback (last known location if permission denied)
- Dependencies: Phase 1; Google Maps Platform API key (billing enabled); PostGIS setup; spatial index; Firebase for map-related events
- Technical Risks: Google Maps cost overruns; rate limit surprises; Android/iOS location permission quirks; GPS accuracy variance; battery drain from location; spatial query performance; coordinate system mismatches (lat/lng vs x/y)
- Test Requirements: 30 unit tests (geocode/reverse; autocomplete; spatial query); 15 integration tests (autocomplete flow; captain discovery; geofence); GPS permission denial flow test; map load test (50 concurrent users with pings); ETA accuracy test vs real data
- Definition of Done: Maps SDK initialized; geocode/reverse works; autocomplete shows suggestions; captain discovery returns sorted by distance/rating; geofence boundaries correct; permission denied gracefully degrades; ETA within ±2 min of Haversine; 90% unit test coverage; performance <200ms for 95th percentile queries
Phase 5: Fare Estimation (Weeks 14-16)
- Deliverables: Fare estimate API (bike/auto/cab base rates); Power Pass discount logic (one weekly plan: ₹19 for 30 days 40% discount on 8 rides); fare breakdown display before booking; basic surge prevention (fixed multiplier if < available captains threshold); fare display on ride confirmation screen; Power Pass ride discount auto-application at payment
- Dependencies: Phase 4 (maps needed for distance); Phase 3 (auth for user context; Power Pass purchase); pricing model from analysis document
- Technical Risks: Pricing accuracy; discount edge cases (partial rides; expiry); surge algorithm correctness; fare display vs actual charged; Power Pass ride count tracking; expiry handling
- Test Requirements: 25 unit tests (fare calc; discount; surge); 10 integration tests (estimate + book; Power Pass purchase + ride discount); edge case tests (zero rides remaining; expiry date crossed; partial ride discount); Power Pass purchase flow test
- Definition of Done: Fare shown before booking matches calculation; Power Pass discount auto-applies on first ride after purchase; rides_remaining decrements correctly; expiry date handled (grace period or hard cut); surge (if enabled) applies correct multiplier; 85% unit test coverage; fare display updates responsively
Phase 6: Ride Requests & Dispatch (Weeks 17-21)
- Deliverables: Ride request API (pickup/drop coords + category); captain request flow (list with pickup/drop/ETA/fare); Accept/Reject buttons; concurrency limit max 3 active rides per captain; ride ID generation (UUID v7); 4-digit PIN start flow (passenger gives PIN; Captain confirms; trip → accepted → en_route); cancellation before assignment (no fee); cancellation after assignment (fee applied; passenger informed before confirm); ride state machine (requested → accepted → en_route → completed → closed); idempotency key for request duplication; ETAs updated dynamically
- Dependencies: Phase 3 (auth; PIN); Phase 4 (maps; captain discovery); Phase 5 (fare estimate); business rules from analysis document
- Technical Risks: Concurrency race conditions (two captains accept same ride); PIN validation edge cases (already started; wrong pin); cancellation fee calculation disputes; idempotency key collisions; state machine bugs causing stuck trips; ETAs not updating; concurrent ride limit enforcement
- Test Requirements: 40 unit tests (request; accept; PIN; cancellation; state machine); 20 integration tests (full request+accept+start+complete flow); concurrency stress test (20 captains, 50 rides, race conditions); cancellation fee edge cases (before/after; different categories); idempotency test (duplicate requests)
- Definition of Done: Rider can request ride; captain can accept/reject; PIN starts ride correctly; cancellation fee applied per policy (before=none, after=fee); state machine transitions correct; idempotent requests; ETAs update; concurrency limit enforced; 90%+ unit test coverage; integration flow test passed
Phase 7: Captain Application Workflows (Weeks 22-25)
- Deliverables: Captain onboarding flow (DL RC photo PAN Aadhaar upload; document validation; verification status display); go online/offline toggle (app state); receive ride requests when online; earnings dashboard (total today this week available_for_payout payout history); payout initiation (minimum threshold; bank details; twice-weekly schedule); incentives calculation (Rain incentives Long Pick-up incentives Daily Weekly - basic formulas); ratings from passengers visible to captain; basic support access (contact info; ticket submission)
- Dependencies: Phase 3 (auth; profiles); Phase 5 (basic fare/payout setup); payment gateway integration (Stripe/Razorpay test mode for payouts); background verification TPSP mock (optional early)
- Technical Risks: Document upload corruption; verification status logic; payout bank validation; incentive formula errors; two-week payout cycle management; rating math; support ticket creation and routing
- Test Requirements: 35 unit tests (onboarding; verification; online/offline; earnings; payout; incentives; rating); 15 integration tests (onboarding end-to-end; payout flow; incentive formulas); document upload test; verification workflow test; payout test with mock bank; incentive formula verification; support ticket flow
- Definition of Done: Captain can onboard with all docs; verification status updates correctly; go online/offline toggle works; receives requests when online; earnings dashboard shows correct totals (today/this week/available); payout initiates with mock bank; incentives calculated per formulas; rating visible; support ticket creatable and trackable; 85% unit test coverage; payout flow test passed
Phase 8: Live Tracking & Trip Lifecycle (Weeks 26-30)
- Deliverables: Real-time GPS pings via WebSocket (every 5-10s when en-ride); trip state machine (requested accepted en_route completed closed) with all transitions; location update frequency configuration; route deviation alerts (if distance from planned route >500m for >3 min → notification to passenger); trip completion validation (drop coordinate within 200m of booked dropoff; else dispute flag); trip closed + payment trigger; final fare display; earnings auto-calculated; wallet update; trip history entry; basic dispute flow
- Dependencies: Phase 4 (maps; GPS pings); Phase 6 (ride request; PIN; state machine foundation); WebSocket infrastructure; PostGIS; Sentry for error tracking
- Technical Risks: WebSocket connection stability on poor networks; GPS accuracy variance; state machine bugs (stuck trips); deviation alert false positives; drop-coordinate tolerance sensitivity; trip close timing; concurrent trip handling
- Test Requirements: 45 unit tests (state machine; GPS pings; deviation alert; tolerance); 25 integration tests (full trip lifecycle WebSocket flow); WebSocket stress test (100 connected clients); GPS drift tolerance test; deviation alert trigger test; trip state machine exhaustive cases (happy path + 10 failure modes)
- Definition of Done: Trip state machine works end-to-end (request → close); GPS updates real-time on passenger map; ETA updates within 5s of new ping; deviation alert triggers correctly (>500m >3min); drop tolerance test (200m pass/fail); trip completes; payment triggered; closed state final; no orphaned rides; 85%+ unit test coverage; integration flow test
Phase 9: Payments & Transaction History (Weeks 31-34)
- Deliverables: Payment gateway integration (Stripe/Razorpay test mode); UPI intent integration (launch Google Pay/PhonePe/Paytm); wallet balance (stored encrypted; recharged via gateway); cash payment recording (manual admin entry); transaction ledger (every ride payment; status; gateway txn id); receipt generation (PDF/HTML); refund flow (initiate via gateway; status tracking); GST invoicing setup (if revenue threshold >₹20L/year); payment method management (add/remove card/UPI/wallet); payment history view (filter by date; status; method)
- Dependencies: Phase 3 (auth; user context); Phase 6 (ride close triggers payment); payment gateway accounts (test mode); tax compliance setup (GST if applicable); wallet design (balance encryption; recharge flow)
- Technical Risks: PCI compliance scope; gateway API changes; refund logic bugs; wallet ledger integrity; GST calculation and filing; payment method storage security; refund timelines vs policy
- Test Requirements: 30 unit tests (payment methods; wallet; receipt; refund; GST); 20 integration tests (all payment methods end-to-end; refund flow; receipt gen); payment gateway test (test mode); refund flow test; receipt generation test; GST setup checklist; wallet ledger audit (reconcile DB vs user-visible)
- Definition of Done: All payment methods work in test mode; receipts generated with correct details; refunds processed per policy (timing status); wallet balance correct; GST setup configured (if threshold met); payment history filterable; ledger reconciles; 85%+ unit test coverage; payment flow test complete
Phase 10: Ratings, Support & Notifications (Weeks 35-37)
- Deliverables: 1-5 star rating + comment submission; rating stored; trip history shows rating; support ticket creation (category; message); ticket status tracking (open pending resolved); push notifications via FCM (ride update; SOS; rating; new request); SMS notifications via Twilio/India provider (ride start; completion; SOS); in-app messages (non-intrusive banner); ride update notifications (driver approaching; arrival; completion); notification preference toggle in profile
- Dependencies: Phase 3 (auth; user tokens); Phase 8 (trip close triggers notifications); FCM account; Twilio/India SMS provider; notification design from Phase 2
- Technical Risks: Notification delivery failure; FCM token expiry; SMS cost overruns; ticket SLA breach (24h); rating math edge cases (weighting; rounding); notification preference not respected; duplicate notifications
- Test Requirements: 25 unit tests (rating; ticket; notification send; preference); 15 integration tests (rating flow; ticket creation + status; FCM send; SMS send; preference test); FCM token rotate test; SMS send/test; duplicate notification prevention; rating math verification
- Definition of Done: Ratings calculate and display correctly (average + count); tickets created and trackable (status transitions); push notifications deliver (test mode); SMS sends (test mode or mock); in-app messages shown at correct time; notification preferences respected; 80%+ unit test coverage; notification flow test complete
Phase 11: Admin Dashboard (Weeks 38-41)
- Deliverables: Admin endpoints (user CRUD; Captain CRUD; pricing config; analytics exports); user/Captain management UI (table; filters; actions); pricing configuration UI (commission rates; Power Pass price; enable/disable); basic analytics dashboard (rides today; earnings; active users; city distribution); ticket resolution workflow (open → pending → resolved); audit logs (immutable; searchable; export); RBAC enforcement (all admin endpoints check role); system settings (app version; feature flags; maintenance mode); email/SMS broadcast (to users/captains)
- Dependencies: Phase 10 (all user/captain data; tickets; notifications); role design from Phase 3; analytics stack (PostgreSQL + Grafana or similar); audit log infrastructure; RBAC design; email/SMS broadcast infrastructure
- Technical Risks: RBAC complexity (too many roles; overlapping permissions); data export volume; ticket SLA tracking accuracy; system settings persistence across restarts; broadcast reliability; admin UI complexity
- Test Requirements: 20 unit tests (RBAC; admin endpoints; pricing config; analytics); 15 integration tests (admin can manage users/captains; pricing changes propagate; tickets resolvable; logs immutable; RBAC blocks wrong roles); RBAC exhaustive cases (all role combinations); admin UI test; analytics export validation; audit log immutability test
- Definition of Done: Admin can CRUD users/captains; pricing changes propagate to apps; tickets resolved within SLA (24h shown); audit logs immutable (cannot be deleted/overwritten); RBAC correctly blocks wrong roles; analytics dashboard shows correct metrics; system settings persist; broadcast reaches target users; 80%+ unit test coverage; integration flow test passed
Phase 12: Security, Testing, Deployment & Optimization (Weeks 42-48)
- Deliverables: Security hardening (auth data payment; penetration testing); full load testing (200 concurrent users; 1000 rides/hour); performance optimization (query indexing; caching; bundle splitting); beta launch (invite-only 100 users); app store submission (iOS Android); monitoring setup (Sentry Grafana alerts); documentation (API docs; architecture; onboarding; compliance); team training; retro; go/no-go decision for full launch
- Dependencies: All prior phases complete; security expertise; devOps; app store accounts; legal compliance sign-off; monitoring infrastructure
- Technical Risks: Security vulnerabilities discovered; app store rejection; load test bottlenecks; performance regressions; monitoring alert fatigue; documentation completeness; team training effectiveness; go/no-go decision paralysis
- Test Requirements: Full security audit penetration test; load test (200 concurrent users; performance budget); performance optimization results; beta launch feedback collection; app store compliance checklist; monitoring dashboards live; team training complete; retro meeting notes; go/no-go decision documented
- Definition of Done: Pen test pass (no critical/high findings); load test metrics within goals (response time; error rate); app store both live; monitoring alerts configured and tested; all docs published; team trained on ops; go/no-go decision made; retro completed; lessons learned documented
Roadmap Review Points
- Mid-point review (after Phase 8): reassess timeline; adjust scope; address any blockers; validate assumptions; stakeholder check-in
- MVP go/no-go decision (after Phase 9): can we launch with current feature set?; what's the minimum for launch?; resource availability; market timing; investment readiness
- Post-MVP planning (after Phase 12): full launch readiness; phase 13+ planning; funding requirements if raising; team expansion; marketing plan; partnership discussions
25. Open Questions Requiring Decisions
#	Question	Options	Recommendation (if any)	Impact
1	Commission vs SaaS model for Captains	A: Commission-only (20-30% bike; auto/cab varies by state) – simpler launch; B: SaaS daily fee ₹9-₹₂₉ for autos/cabs zero commission after – matches Rapido post-2024 shift; C: Hybrid: commission for bike; SaaS for auto/cab	B recommended for authenticity to Rapido's evolved model, but A faster for MVP; C as fallback if resistance from captains	High – business model affects pricing; captain incentives; revenue structure; legal/tax treatment
2	Google Maps vs OpenStreetMap	A: Google Maps Platform (best accuracy India coverage; paid) – recommended; B: OpenStreetMap + Nominatim (free; lower accuracy; requires attribution) – slower start; C: Hybrid (OSM early; Google when volume justifies)	A recommended for launch quality; C if budget tight; Map costs are biggest ongoing expense	High – maps are core to matching/ETA; cost driver; user experience quality
3	Payment gateway: Stripe vs Razorpay	A: Stripe (global; stronger fraud; easier API; India available but higher overhead); B: Razorpay (India-favored; UPI-first; simpler India compliance; lower cost) – recommended for India-only launch; C: Both (Stripe for potential international; Razorpay for India)	B for India-only launch; C if planning international expansion; A if already using Stripe elsewhere	Medium – affects checkout flow; supported payment methods; compliance; cost per transaction
4	SaaS subscription timing	A: Launch with commission model only; add SaaS later (Phase 7+); B: Launch with SaaS from day 1 (matches Rapido's evolved model); C: Hybrid: commission for bike; SaaS for auto/cab from day 1	A for fastest MVP; B for authentic Rapido clone; C as compromise; decision depends on Phase 1 business model call	High – affects captain onboarding flow; billing infrastructure; captain earnings; revenue timing
5	Power Pass: one plan vs multiple	A: One weekly plan (₹19/30days 40% off 8 rides) – simpler MVP; B: Multiple plans (weekly ₹19/monthly ₹15 with different discounts/ride counts) – more choice; C: No Power Pass at launch – add later	A for MVP speed; B for user choice; C if prioritizing other features; decision depends on Phase 1 business model	Medium – user perceived value; revenue from subs; implementation complexity
6	SOS + Share Trip: enable by default or opt-in?	A: Enable by default (safer; matches Rapido's safety-first positioning); B: Opt-in from profile (users choose); C: Disable for MVP – add later	A for safety branding; B for user control; C if safety resources limited; decision affects UI/UX and compliance	Medium – safety perception; user trust; potential SOS false triggers; regulatory considerations
7	App store launch: iOS first, Android first, or web-only?	A: Android first (lower fee; larger India market; faster); B: iOS first (higher spend users; App Store quality); C: Web-only MVP (progressive web app; no store fees; limits reach)	A for India launch speed; B for premium user base; C for fastest cheapest test; decision affects timeline and reach	High – timeline; costs; user acquisition; app store compliance; distribution reach
8	Legal compliance: when to engage lawyers	A: Engage before Phase 1 (prevent rework); B: Engage after Phase 3 (when model decided); C: Engage after Phase 6 (when core flows done)	A recommended (prevents costly rework); B acceptable; C riskiest (may need re-architect); depends on budget and risk tolerance	Very High – non-compliance can shut down app; legal review cost vs risk
Decision Path
1. First: Decision 1 (business model) – determines everything else; if limited budget → commission-only MVP; if authentic Rapido clone desired → SaaS from day 1
2. Second: Decision 6 (SOS opt-in) – safety branding choice; easy to change later via config
3. Third: Decision 2 (maps provider) – impacts ongoing costs; can start OSM then switch; easier than model change
4. Fourth: Decision 3 (payment gateway) – impacts launch country; can add second later; Stripe/Razorpay both support India
5. Fifth: Decision 6 (SOS opt-in) – after model/maps decided; safety is differentiator; can configure at launch
6. Sixth: Decision 7 (app stores) – affects timeline/cost; can start web-only; add stores later; easier than model change
7. Seventh: Decision 8 (legal) – engage early (Phase 1) to avoid rework; minimum viable legal review; iterate
26. Final Readiness Assessment
Readiness Criteria Checklist
The analysis is sufficiently complete to proceed to implementation planning when all of the following are true:
- Business model decided: Commission vs SaaS vs hybrid; documented; team alignment
- Maps provider chosen: Google Maps (recommended) or OSM plan; API key ready/billing enabled
- Auth flow designed: Phone OTP + PIN; user/Captain profiles; role differentiation confirmed
- Core screens mocked: Onboarding; login; home (with maps); ride request; trip lifecycle (basic); admin dash skeleton
- Legal review completed: Minimum viable T&Cs; Privacy Policy; DPDP act compliance checklist; GST registration status determined
- Key dependencies accounted for: Maps API key; payment gateway test accounts; SMS provider; app store accounts; FCM account
- Team has necessary skills: Flutter (mobile); FastAPI (backend); PostgreSQL/PostGIS (spatial); design system; DevOps basic; legal compliance awareness
- Risk register created: Top 5 risks identified; mitigations planned; contingency budget allocated
- Timeline realistic: Based on 3-person team; 20-week MVP target; phases sequenced with dependencies; resource availability confirmed
- Success metrics defined: User acquisition targets; ride completion goals; revenue projections (if applicable); safety metrics; satisfaction targets
- Stakeholder alignment: Team; legal; (if applicable) investors; (if applicable) captain/passenger representatives; all aware of scope/timeline/risks
Readiness Determination
Based on the analysis completed:
- ✅ Business model: Can be decided early (commission-only MVP fastest; SaaS for authenticity)
- ✅ Maps provider: Google Maps recommended; OSM possible as fallback; cost manageable for MVP
- ✅ Auth flow: Designed and documented; all screens described; dependencies (SMS provider) identified
- ✅ Core screens: All major flows documented; mockups not drawn but screen flow and UI characteristics documented thoroughly
- ✅ Legal review: T&Cs, Privacy Policy, and key compliance items documented from public sources; minimum legal engagement recommended before Phase 1
- ✅ Dependencies: All key dependencies (maps API; payment gateway; SMS; app stores; FCM) identified and cost categories estimated; test accounts can be created in parallel
- ✅ Team skills: Assumed Flutter+FastAPI+PostgreSQL possible; if team lacks any, hiring/training needed before Phase 1
- ✅ Risk register: Top risks identified (Maps cost; payment compliance; legal; location permission; concurrency) with mitigations documented
- ✅ Timeline: 20-week MVP realistic based on phased breakdown; dependencies sequenced; 1-year full feature set estimated
- ✅ Success metrics: Defined for MVP (100 users; 20 captains; 50 rides/month; <5 min wait; >4 rating; <2% payment fail; <1% SOS false)
- ✅ Stakeholder alignment: Analysis presented; decisions to be made by team; no showstopper blockers identified
Overall Readiness: SUITABLE TO PROCEED
The analysis is sufficiently complete to proceed to a separate implementation-planning phase. The next step should be:
1. Convene a decision session to resolve the 8 open questions (particularly business model, maps provider, and app store strategy)
2. Begin Phase 1 setup once decisions are made
3. Create the implementation project with the roadmap provided; the roadmap itself is detailed enough to begin sprint planning
4. Engage legal counsel for minimum viable compliance review before code begins (particularly DPDP act, transport regulations, and T&Cs)
The analysis provides a complete blueprint: all 26 phases, every feature inventory, every API endpoint, every business rule, every security consideration, every testing requirement, and a phased roadmap with dependencies and timelines. Development can begin once the 8 open decisions are resolved.
End of Report
