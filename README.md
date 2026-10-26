# PetFindrr

A pet adoption app with a swipe-based interface, built over a weekend at the Stonehill hackathon in February 2026.

The idea is simple: adoption listings are usually a wall of filters and thumbnails, which is a bad way to work out whether you actually want a particular animal. Swiping is a better fit for that kind of decision, and it gives the app something to learn from. Every swipe tells it a little more about what you're drawn to, so the ordering improves as you go.

Built with Flutter and Firebase. There are two sides to it: adopters browse and match, and sellers or shelters list pets.

## What's in it

- Swipe through pets, with the ordering driven by a recommendation model rather than a fixed sort
- Separate flows for adopters and for people listing pets
- A profile builder that captures budget, home size, activity level and size preference
- Matches and chat, backed by Firestore
- Photo upload for listings, up to five per pet

## How the matching works

Each pet becomes a four-number vector: size, energy level, price and age, all on a 1 to 3 scale. Your profile becomes a vector in the same space, built from your home size, activity level and budget.

Scoring combines two things. The base score is rule-based and checks the hard constraints: does the price fit the budget, is the pet a size that suits the home, does its energy level match how active you are. The adaptive score is the distance between a pet's vector and a running preference vector that shifts toward the pets you like. The two are weighted 60/40 in favour of the rules, so the model nudges the ordering rather than taking it over.

The preference vector retrains every five swipes, moving a fraction of the way toward each newly liked pet. Pets are then ranked by the combined score.

## Running it

The Flutter project lives in `lib/petfindrr`, so start there:

```bash
cd lib/petfindrr
flutter pub get
flutter run
```

You'll need Flutter 3.5 or later. Firebase is already configured for Android, and the swipe screen falls back to a set of mock pets if Firestore has nothing in it, so you can see the app working without any backend setup.

## This fork

Forked from [whyender/stonehill_hack](https://github.com/whyender/stonehill_hack), the original hackathon repo. The app was written at the hackathon by [@whyender](https://github.com/whyender) and me.

Changes in this fork, all of them cleanup rather than new features:

- Filled in UI text that was still placeholder at the end of the hackathon, and replaced the mock pet data with something readable
- Fixed the retrain trigger. It tested `swipeHistory.length % 5`, but that list is capped at 25 entries, so once it filled up the condition was permanently true and the model retrained on every single swipe
- Made retraining learn from each liked pet once, instead of re-applying the whole liked history every time it ran
- Put price on the same 1 to 3 scale as the other features. It had been normalised to 0 to 1, so it carried about a third of the weight it should have
- Corrected the distance normaliser, which was dividing by 6 when the largest possible distance is 4. The adaptive score could never drop below about 0.4
- Made the base score divide by the points actually available rather than a flat 100, so a half-filled profile isn't scored as a bad match
- Removed a null assertion on the home-size lookup that would throw on any value not in the lookup table
- Deleted a leftover duplicate `MainActivity.kt` and two orphaned files at the repo root

## Licence

MIT, as in the original. See [LICENSE](LICENSE) — copyright remains with whyender as the original author.
