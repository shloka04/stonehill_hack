# PetFindrr

A pet adoption app with a swipe interface, built over a weekend at the Stonehill hackathon in February 2026.

Adoption listings are usually a wall of filters and thumbnails, which is a poor way to decide whether you actually want a particular animal. Swiping suits that kind of judgement better, and it gives the app something to learn from: every swipe says a little more about what you respond to, so the ordering improves as you go.

Flutter and Firebase, with two sides to it — adopters browse and match, shelters and sellers list pets.

## What's in it

- A swipe deck whose ordering comes from a recommendation model rather than a fixed sort
- Separate onboarding flows for adopters and for people listing pets
- A profile builder capturing budget, home size, activity level and size preference
- Matching and chat, backed by Firestore
- Photo upload for listings, up to five per pet
- Firebase authentication, with a mock-data fallback so the swipe deck works before any backend exists

Roughly 3,500 lines of Dart across 8 screens, 6 models, 4 services and a set of shared widgets.

## How the matching works

Each pet becomes a four-number vector — size, energy level, price and age — all on a 1 to 3 scale. Your profile becomes a vector in the same space, built from home size, activity level and budget.

Two scores combine:

**The base score** is rule-based and checks hard constraints. Does the price fit the budget, is the pet a size the home can take, does its energy level match how active you are. Each criterion contributes points, and the total is divided by the points actually available — so a half-filled profile is treated as incomplete rather than as a bad match.

**The adaptive score** is the distance between a pet's vector and a running preference vector that shifts toward the pets you like. It retrains every five swipes, moving a fraction of the way toward each newly liked pet.

The two are weighted 60/40 in favour of the rules, so the learned component nudges the ordering rather than taking it over. Pets are then ranked by the combined score.

## Running it

The Flutter project lives in `lib/petfindrr`:

```bash
cd lib/petfindrr
flutter pub get
flutter run
```

Needs Flutter 3.5 or later. Firebase is configured for Android, and the swipe screen falls back to a set of mock pets when Firestore is empty, so the app is explorable with no backend setup.

## This fork

Forked from [whyender/stonehill_hack](https://github.com/whyender/stonehill_hack), the original hackathon repository. The app was written at the hackathon by [@whyender](https://github.com/whyender) and me.

This fork is a cleanup pass. No new features — the changes are things that were wrong, found by reading the code carefully afterwards.

**Four bugs in the recommendation model:**

The retrain trigger tested `swipeHistory.length % 5`, but that list is capped at 25 entries. Once it filled, the condition was permanently true and the model retrained on *every* swipe. Worse, each retrain re-applied the entire liked history rather than only new likes, so the same preferences compounded repeatedly and the vector collapsed onto the liked centroid.

The adaptive score could never fall below about 0.4. Distances were normalised by a hardcoded 6.0 when the true maximum is `2√n = 4`, compressing half the ranking signal into 60% of its range.

Price carried a third of the weight it should have. Three features ran 1–3 while price was normalised to 0–1, so it barely moved the Euclidean distance. Both `Pet.priceScore` and `UserProfile.budgetScore` now use the same 1–3 scale.

The base score always divided by a fixed 100 despite counting which criteria applied, so a user who set only a budget could score at most 0.30 against a full profile's 1.0. Incomplete data was being scored as poor fit.

**One crash:** `compatibleSizes[homeSize]!` threw on any value outside its lookup table. The UI constrains the input, but `homeSize` also loads straight from Firestore, so it was reachable. Every other lookup in the codebase uses a `switch` with a default; this one didn't.

**Cleanup:** placeholder UI text left at the end of the hackathon, a duplicate `MainActivity.kt` orphaned by a package rename, and two dead files at the repository root.

## Licence

MIT, as in the original. See [LICENSE](LICENSE) — copyright remains with whyender as the original author.
