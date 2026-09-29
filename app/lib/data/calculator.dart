enum QtyUnit { kg, quintal, bags }

class CalcInput {
  final double qty;
  final QtyUnit unit;
  final double bagKg;
  /// Rate in the crop's canonical unit: arecanut ₹/quintal, rubber ₹/kg.
  final double rate;
  final bool ratePerQuintal;
  final double commissionPct, hamali, transport;
  const CalcInput({
    required this.qty,
    required this.unit,
    this.bagKg = 65,
    required this.rate,
    required this.ratePerQuintal,
    this.commissionPct = 0,
    this.hamali = 0,
    this.transport = 0,
  });
}

class CalcResult {
  final double kg, gross, commission, deductions, net;
  const CalcResult(this.kg, this.gross, this.commission, this.deductions, this.net);
}

CalcResult calculate(CalcInput i) {
  final kg = switch (i.unit) {
    QtyUnit.kg => i.qty,
    QtyUnit.quintal => i.qty * 100,
    QtyUnit.bags => i.qty * i.bagKg,
  };
  final gross = i.ratePerQuintal ? kg / 100 * i.rate : kg * i.rate;
  final commission = gross * i.commissionPct / 100;
  final deductions = commission + i.hamali + i.transport;
  return CalcResult(kg, gross, commission, deductions, gross - deductions);
}
