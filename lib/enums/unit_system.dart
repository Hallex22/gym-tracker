enum UnitSystem {
  kg(label: 'kg'),
  lbs(label: 'lbs');

  final String label;
  const UnitSystem({required this.label});

  static const double _lbFactor = 2.20462262185;

  double toDisplay(double weightInKg) {
    if (this == UnitSystem.lbs) {
      return weightInKg * _lbFactor;
    }
    return weightInKg;
  }

  double toStorage(double weightInDisplayUnit) {
    if (this == UnitSystem.lbs) {
      return weightInDisplayUnit / _lbFactor;
    }
    return weightInDisplayUnit;
  }

  String toFullDisplay(double weightInKg) {

    return '${formatWeight(this.toDisplay(weightInKg))} ${this.label}';
    // '${_formatWeight(_globalUnit.toDisplay(currentSnapshotLog.totalVolume))} ${_globalUnit.label}',

  }

  String formatWeight(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
