import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/entities/pix_key.dart';
import '../bloc/pix_bloc.dart';
import '../bloc/pix_event.dart';
import '../bloc/pix_state.dart';


class ReceivePixPage extends StatefulWidget {
  const ReceivePixPage({super.key});

  @override
  State<ReceivePixPage> createState() => _ReceivePixPageState();
}

class _ReceivePixPageState extends State<ReceivePixPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedPixKeyId;
  bool _isStatic = false;

  @override
  void initState() {
    super.initState();
    context.read<PixBloc>().add(const LoadPixKeysEvent());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _generateQrCode() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedPixKeyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione uma chave Pix'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final amount = _amountController.text.isNotEmpty
          ? double.tryParse(_amountController.text.replaceAll(',', '.'))
          : null;

      context.read<PixBloc>().add(
            ReceivePixEvent(
              pixKeyId: _selectedPixKeyId!,
              amount: amount,
              description: _descriptionController.text.isNotEmpty
                  ? _descriptionController.text
                  : null,
              isStatic: _isStatic,
            ),
          );
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copiado para a área de transferência'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receber Pix'),
      ),
      body: BlocConsumer<PixBloc, PixState>(
        listener: (context, state) {
          if (state is PixQrCodeGenerateErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is PixKeysLoadingState) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is PixKeysErrorState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64.0,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Erro ao carregar as chaves Pix',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: () {
                      context.read<PixBloc>().add(const LoadPixKeysEvent());
                    },
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }

          if (state is PixKeysLoadedState) {
            if (state.keys.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.vpn_key,
                      size: 64.0,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16.0),
                    const Text(
                      'Você ainda não possui chaves Pix cadastradas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    const Text(
                      'Cadastre uma chave para receber transferências',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24.0),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('pix/keys/register');
                      },
                      child: const Text('Cadastrar Chave'),
                    ),
                  ],
                ),
              );
            }

            if (state is PixQrCodeGeneratedState) {
              return _buildQrCodeResult(context, state);
            }

            return _buildQrCodeForm(context, state.keys);
          }

          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  Widget _buildQrCodeForm(BuildContext context, List<PixKey> keys) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecione uma Chave Pix',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            _buildPixKeySelector(keys),
            const SizedBox(height: 24.0),
            const Text(
              'Valor (opcional)',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                hintText: 'R\$ 0,00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+[,.]?\d{0,2}')),
              ],
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final amount =
                      double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                  if (amount <= 0) {
                    return 'O valor deve ser maior que zero';
                  }
                }

                return null;
              },
            ),
            const SizedBox(height: 24.0),
            const Text(
              'Descrição (opcional)',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Ex: Pagamento de serviço',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLength: 140,
            ),
            const SizedBox(height: 16.0),
            SwitchListTile(
              title: const Text(
                'QR Code Estático',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'QR Code que pode ser reutilizado várias vezes',
              ),
              value: _isStatic,
              onChanged: (value) {
                setState(() {
                  _isStatic = value;
                });
              },
            ),
            const SizedBox(height: 32.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _generateQrCode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                ),
                child: const Text('Gerar QR Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPixKeySelector(List<PixKey> keys) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: keys.map((key) {
            return Column(
              children: [
                RadioListTile<String>(
                  value: key.id,
                  groupValue: _selectedPixKeyId,
                  onChanged: (value) {
                    setState(() {
                      _selectedPixKeyId = value;
                    });
                  },
                  title: Text(
                    key.formattedName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(key.formattedValue),
                  secondary: _getPixKeyTypeIcon(key.type),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
                if (keys.indexOf(key) < keys.length - 1) const Divider(),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildQrCodeResult(BuildContext context, PixState state) {
    final qrCode = (state as PixQrCodeGeneratedState).qrCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Card(
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'QR Code Pix',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  QrImageView(
                    data: qrCode.payload,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 24.0),
                  if (qrCode.amount != null)
                    Text(
                      'Valor: R\$ ${qrCode.amount!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (qrCode.description != null) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      'Descrição: ${qrCode.description}',
                      style: const TextStyle(
                        fontSize: 16.0,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8.0),
                  Text(
                    'Tipo: ${qrCode.isStatic ? 'Estático' : 'Dinâmico'}',
                    style: const TextStyle(
                      fontSize: 16.0,
                    ),
                  ),
                  if (qrCode.expiresAt != null) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      'Expira em: ${_formatDate(qrCode.expiresAt!)}',
                      style: const TextStyle(
                        fontSize: 16.0,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24.0),
                  const Divider(),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Código Pix Copia e Cola',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            qrCode.payload,
                            style: const TextStyle(
                              fontSize: 12.0,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copyToClipboard(qrCode.payload),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24.0),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                
                context.read<PixBloc>().add(const LoadPixKeysEvent());
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
              ),
              child: const Text('Gerar Outro QR Code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getPixKeyTypeIcon(PixKeyType type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case PixKeyType.cpf:
        iconData = Icons.badge;
        iconColor = Colors.blue;
        break;
      case PixKeyType.cnpj:
        iconData = Icons.business;
        iconColor = Colors.purple;
        break;
      case PixKeyType.email:
        iconData = Icons.email;
        iconColor = Colors.red;
        break;
      case PixKeyType.phone:
        iconData = Icons.phone;
        iconColor = Colors.green;
        break;
      case PixKeyType.random:
        iconData = Icons.vpn_key;
        iconColor = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }
}
