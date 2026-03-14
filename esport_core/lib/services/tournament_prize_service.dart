import 'dart:math';

class TournamentPrizeService {
  /// Calculates the current prize pool for a dynamic tournament.
  static double calculateCurrentPool({
    required double entryFee,
    required int joinedPlayers,
    required double commissionPercentage,
  }) {
    final totalPool = entryFee * joinedPlayers;
    final commission = totalPool * (commissionPercentage / 100);
    return max(0, totalPool - commission);
  }

  /// Calculates the maximum possible prize pool.
  static double calculateMaxPool({
    required double entryFee,
    required int totalSlots,
    required double commissionPercentage,
  }) {
    final totalPool = entryFee * totalSlots;
    final commission = totalPool * (commissionPercentage / 100);
    return max(0, totalPool - commission);
  }

  /// Calculates rank-based rewards for a dynamic prize pool.
  /// [rankPercentages] is a map like {"1": 40, "2": 25, "3": 15}
  static Map<String, double> calculateRankRewards({
    required double currentPool,
    required Map<String, dynamic> rankPercentages,
  }) {
    final rewards = <String, double>{};
    rankPercentages.forEach((rank, percentage) {
      final p = (percentage as num).toDouble();
      rewards[rank] = (currentPool * p) / 100;
    });
    return rewards;
  }
}
