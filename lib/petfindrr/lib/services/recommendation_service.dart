import 'dart:math';
import '../models/pet.dart';
import '../models/user_profile.dart';
import '../models/swipe.dart';
import '../models/preference_vector.dart';

class RecommendationService {
  PreferenceVector _preferenceVector;
  final List<Swipe> _swipeHistory = [];

  // Likes recorded since the last retrain. Kept separate from _swipeHistory
  // so each like is learned from exactly once.
  final List<Swipe> _pendingLikes = [];
  int _swipesSinceRetrain = 0;

  static const int _maxSwipeHistory = 25;
  static const int _retrainInterval = 5;
  static const double _learningRate = 0.15;
  static const double _baseWeight = 0.6;
  static const double _adaptiveWeight = 0.4;

  RecommendationService(UserProfile userProfile)
      : _preferenceVector = PreferenceVector.fromUserProfile(
          userProfile.initialPreferenceVector,
        );

  void recordSwipe(Pet pet, bool liked) {
    final swipe = Swipe.fromPet(pet.id, pet.featureVector, liked);

    _swipeHistory.add(swipe);

    if (_swipeHistory.length > _maxSwipeHistory) {
      _swipeHistory.removeAt(0);
    }

    if (liked) {
      _pendingLikes.add(swipe);
    }

    // Count swipes directly rather than testing _swipeHistory.length, which
    // stops growing once the history hits its cap.
    _swipesSinceRetrain++;
    if (_swipesSinceRetrain >= _retrainInterval) {
      _swipesSinceRetrain = 0;
      _retrain();
    }
  }

  void _retrain() {
    if (_pendingLikes.isEmpty) return;

    for (final swipe in _pendingLikes) {
      _preferenceVector.update(swipe.petFeatures, _learningRate);
    }

    _pendingLikes.clear();
  }

  double _calculateBaseScore(Pet pet, UserProfile userProfile) {
    int score = 0;
    // Points available from the criteria this profile actually filled in.
    // Dividing by a fixed 100 would score a half-filled profile as a poor
    // match rather than an incomplete one.
    int available = 0;

    final petSize = pet.size.toLowerCase();
    final petEnergy = pet.energyLevel.toLowerCase();

    if (userProfile.budget != null) {
      available += 30;
      final budgetDiff = (userProfile.budget! - pet.price).abs();
      if (budgetDiff <= 100) {
        score += 30;
      } else if (budgetDiff <= 300) {
        score += 20;
      } else if (budgetDiff <= 500) {
        score += 10;
      }
    }

    final preferredSizes = userProfile.preferredSizes;
    if (preferredSizes != null && preferredSizes.isNotEmpty) {
      available += 25;
      if (preferredSizes.map((s) => s.toLowerCase()).contains(petSize)) {
        score += 25;
      }
    }

    const Map<String, List<String>> compatibleSizes = {
      'small': ['small'],
      'medium': ['small', 'medium'],
      'large': ['small', 'medium', 'large'],
    };
    // homeSize also arrives straight from Firestore, so an unexpected value
    // skips this criterion instead of throwing on a null assertion.
    final allowedSizes = compatibleSizes[userProfile.homeSize?.toLowerCase()];
    if (allowedSizes != null) {
      available += 20;
      if (allowedSizes.contains(petSize)) {
        score += 20;
      }
    }

    final activityLevel = userProfile.activityLevel?.toLowerCase();
    if (activityLevel != null) {
      available += 25;
      if (activityLevel == petEnergy) {
        score += 25;
      } else if (activityLevel == 'medium' || petEnergy == 'medium') {
        // One step apart: workable, but not an ideal pairing.
        score += 15;
      }
    }

    return available > 0 ? score / available : 0.75;
  }

  double _calculateAdaptiveScore(Pet pet) {
    if (_preferenceVector.updateCount == 0) {
      return 0.5; 
    }

    final petVector = pet.featureVector;
    final prefVector = _preferenceVector.vector;
    final length = min(petVector.length, prefVector.length);
    if (length == 0) return 0.5;

    double distance = 0.0;
    for (int i = 0; i < length; i++) {
      final diff = petVector[i] - prefVector[i];
      distance += diff * diff;
    }
    distance = sqrt(distance);

    // Every feature runs 1-3, so the furthest two vectors can be is
    // sqrt(n * 2^2) = 2 * sqrt(n). The old divisor of 6 never let this
    // score fall below about 0.4.
    final maxDistance = 2.0 * sqrt(length);
    final normalizedDistance = (distance / maxDistance).clamp(0.0, 1.0);
    return 1.0 - normalizedDistance;
  }

  double scoreFor(Pet pet, UserProfile userProfile) {
    final baseScore = _calculateBaseScore(pet, userProfile);
    final adaptiveScore = _calculateAdaptiveScore(pet);
    
    return (_baseWeight * baseScore) + (_adaptiveWeight * adaptiveScore);
  }

  List<Pet> rankPets(List<Pet> pets, UserProfile userProfile) {
    final scored = pets.map((pet) {
      return {
        'pet': pet,
        'score': scoreFor(pet, userProfile),
      };
    }).toList();

    scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    return scored.map((item) => item['pet'] as Pet).toList();
  }

  Map<String, dynamic> getPreferenceState() {
    return {
      'vector': _preferenceVector.vector,
      'swipeCount': _swipeHistory.length,
      'updateCount': _preferenceVector.updateCount,
      'likedCount': _swipeHistory.where((s) => s.liked).length,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'preferenceVector': _preferenceVector.toJson(),
      'swipeHistory': _swipeHistory.map((s) => s.toJson()).toList(),
    };
  }

  factory RecommendationService.fromJson(
    Map<String, dynamic> json,
    UserProfile userProfile,
  ) {
    final service = RecommendationService(userProfile);
    
    if (json['preferenceVector'] != null) {
      service._preferenceVector = PreferenceVector.fromJson(json['preferenceVector']);
    }
    
    if (json['swipeHistory'] != null) {
      service._swipeHistory.clear();
      service._swipeHistory.addAll(
        (json['swipeHistory'] as List).map((s) => Swipe.fromJson(s)),
      );
    }
    
    return service;
  }
}