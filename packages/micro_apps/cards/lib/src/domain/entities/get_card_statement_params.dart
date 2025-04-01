class GetCardStatementParams {
  final String cardId;
  final DateTime startDate;
  final DateTime endDate;

  const GetCardStatementParams({
    required this.cardId,
    required this.startDate,
    required this.endDate,
  });
}
