import 'package:core_interfaces/core_interfaces.dart';

/// Utilitário para validação de parâmetros de rota de forma segura e consistente.
///
/// Fornece métodos para extrair e validar parâmetros de rotas, evitando
/// force unwraps e garantindo type safety.
///
/// ## Uso Básico
///
/// ```dart
/// // Parâmetro obrigatório
/// final id = RouteParamsValidator.getRequiredParam(state.params, 'id');
///
/// // Parâmetro opcional
/// final filter = RouteParamsValidator.getOptionalParam(state.queryParams, 'filter');
///
/// // Validar UUID
/// final userId = RouteParamsValidator.getUuidParam(state.params, 'userId');
///
/// // Validar número
/// final page = RouteParamsValidator.getIntParam(state.queryParams, 'page');
/// ```
class RouteParamsValidator {
  /// Valida e retorna um parâmetro obrigatório da rota.
  ///
  /// Throws [RouteParamMissingException] se o parâmetro não existir ou estiver vazio.
  ///
  /// [params] mapa de parâmetros da rota
  /// [paramName] nome do parâmetro a ser extraído
  ///
  /// Returns o valor do parâmetro
  static String getRequiredParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = params[paramName];

    if (value == null || value.isEmpty) {
      throw RouteParamMissingException(paramName: paramName);
    }

    return value;
  }

  /// Valida e retorna um parâmetro opcional da rota.
  ///
  /// Returns o valor do parâmetro ou `null` se não existir.
  ///
  /// [params] mapa de parâmetros da rota
  /// [paramName] nome do parâmetro a ser extraído
  static String? getOptionalParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = params[paramName];
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Valida um parâmetro como UUID.
  ///
  /// Throws [RouteParamMissingException] se o parâmetro não existir.
  /// Throws [RouteParamInvalidException] se o formato não for UUID válido.
  ///
  /// [params] mapa de parâmetros da rota
  /// [paramName] nome do parâmetro a ser extraído
  ///
  /// Returns o UUID validado
  static String getUuidParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = getRequiredParam(params, paramName);

    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (!uuidRegex.hasMatch(value)) {
      throw RouteParamInvalidException(
        paramName: paramName,
        receivedValue: value,
        expectedFormat: 'UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)',
      );
    }

    return value;
  }

  /// Valida um parâmetro como número inteiro.
  ///
  /// Throws [RouteParamMissingException] se o parâmetro não existir.
  /// Throws [RouteParamInvalidException] se não for um número válido.
  ///
  /// [params] mapa de parâmetros da rota
  /// [paramName] nome do parâmetro a ser extraído
  ///
  /// Returns o número inteiro
  static int getIntParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = getRequiredParam(params, paramName);

    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw RouteParamInvalidException(
        paramName: paramName,
        receivedValue: value,
        expectedFormat: 'número inteiro',
      );
    }

    return parsed;
  }

  /// Valida um parâmetro como número inteiro opcional.
  ///
  /// Returns o número inteiro ou `null` se não existir.
  /// Throws [RouteParamInvalidException] se existir mas não for um número válido.
  ///
  /// [params] mapa de parâmetros da rota
  /// [paramName] nome do parâmetro a ser extraído
  static int? getOptionalIntParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = getOptionalParam(params, paramName);
    if (value == null) return null;

    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw RouteParamInvalidException(
        paramName: paramName,
        receivedValue: value,
        expectedFormat: 'número inteiro',
      );
    }

    return parsed;
  }

  /// Valida um parâmetro como número decimal (double).
  ///
  /// Throws [RouteParamMissingException] se o parâmetro não existir.
  /// Throws [RouteParamInvalidException] se não for um número válido.
  ///
  /// [params] mapa de parâmetros da rota
  /// [paramName] nome do parâmetro a ser extraído
  ///
  /// Returns o número decimal
  static double getDoubleParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = getRequiredParam(params, paramName);

    final parsed = double.tryParse(value);
    if (parsed == null) {
      throw RouteParamInvalidException(
        paramName: paramName,
        receivedValue: value,
        expectedFormat: 'número decimal',
      );
    }

    return parsed;
  }

  /// Valida um parâmetro como boolean.
  ///
  /// Aceita: 'true', 'false', '1', '0', 'yes', 'no'
  ///
  /// Throws [RouteParamMissingException] se o parâmetro não existir.
  /// Throws [RouteParamInvalidException] se não for um valor boolean válido.
  ///
  /// [params] mapa de parâmetros da rota
  /// [paramName] nome do parâmetro a ser extraído
  ///
  /// Returns o valor boolean
  static bool getBoolParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = getRequiredParam(params, paramName).toLowerCase();

    if (value == 'true' || value == '1' || value == 'yes') {
      return true;
    } else if (value == 'false' || value == '0' || value == 'no') {
      return false;
    } else {
      throw RouteParamInvalidException(
        paramName: paramName,
        receivedValue: value,
        expectedFormat: 'boolean (true/false, 1/0, yes/no)',
      );
    }
  }

  /// Valida um parâmetro como enum.
  ///
  /// Throws [RouteParamMissingException] se o parâmetro não existir.
  /// Throws [RouteParamInvalidException] se o valor não corresponder a nenhum enum value.
  ///
  /// [params] mapa de parâmetros da rota
  /// [paramName] nome do parâmetro a ser extraído
  /// [values] lista de valores enum possíveis
  ///
  /// Returns o enum value correspondente
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// enum TransactionType { debit, credit }
  ///
  /// final type = RouteParamsValidator.getEnumParam(
  ///   state.params,
  ///   'type',
  ///   TransactionType.values,
  /// );
  /// ```
  static T getEnumParam<T extends Enum>(
    Map<String, String> params,
    String paramName,
    List<T> values,
  ) {
    final value = getRequiredParam(params, paramName);

    try {
      return values.firstWhere((e) => e.name == value);
    } catch (e) {
      throw RouteParamInvalidException(
        paramName: paramName,
        receivedValue: value,
        expectedFormat:
            'um dos valores: ${values.map((e) => e.name).join(", ")}',
      );
    }
  }

  /// Valida um parâmetro como email.
  ///
  /// Throws [RouteParamMissingException] se o parâmetro não existir.
  /// Throws [RouteParamInvalidException] se o formato de email for inválido.
  ///
  /// [params] mapa de parâmetros da rota
  /// [paramName] nome do parâmetro a ser extraído
  ///
  /// Returns o email validado
  static String getEmailParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = getRequiredParam(params, paramName);

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      throw RouteParamInvalidException(
        paramName: paramName,
        receivedValue: value,
        expectedFormat: 'email válido (exemplo@dominio.com)',
      );
    }

    return value;
  }

  /// Valida um parâmetro como data no formato ISO 8601.
  ///
  /// Throws [RouteParamMissingException] se o parâmetro não existir.
  /// Throws [RouteParamInvalidException] se o formato de data for inválido.
  ///
  /// [params] mapa de parâmetros da rota
  /// [paramName] nome do parâmetro a ser extraído
  ///
  /// Returns o DateTime parseado
  static DateTime getDateParam(
    Map<String, String> params,
    String paramName,
  ) {
    final value = getRequiredParam(params, paramName);

    try {
      return DateTime.parse(value);
    } catch (e) {
      throw RouteParamInvalidException(
        paramName: paramName,
        receivedValue: value,
        expectedFormat: 'data ISO 8601 (YYYY-MM-DD ou YYYY-MM-DDTHH:MM:SS)',
      );
    }
  }

  /// Valida múltiplos parâmetros de uma vez.
  ///
  /// Útil quando você precisa validar vários parâmetros e quer coletar
  /// todos os erros de uma vez ao invés de falhar no primeiro.
  ///
  /// Returns um Map com os valores validados ou lança [ValidationException]
  /// com todos os erros encontrados.
  ///
  /// ## Exemplo
  ///
  /// ```dart
  /// final validated = RouteParamsValidator.validateMultiple(
  ///   state.params,
  ///   required: ['id', 'userId'],
  ///   optional: ['filter'],
  /// );
  /// ```
  static Map<String, String?> validateMultiple(
    Map<String, String> params, {
    List<String> required = const [],
    List<String> optional = const [],
  }) {
    final result = <String, String?>{};
    final errors = <String, String>{};

    // Validar parâmetros obrigatórios
    for (final paramName in required) {
      try {
        result[paramName] = getRequiredParam(params, paramName);
      } on RouteParamException catch (e) {
        errors[paramName] = e.message;
      }
    }

    // Coletar parâmetros opcionais
    for (final paramName in optional) {
      result[paramName] = getOptionalParam(params, paramName);
    }

    // Se houver erros, lançar ValidationException
    if (errors.isNotEmpty) {
      throw ValidationException(
        message: 'Parâmetros de rota inválidos',
        fieldErrors: errors,
      );
    }

    return result;
  }
}
