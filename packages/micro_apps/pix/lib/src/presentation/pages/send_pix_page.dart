import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/pix_key.dart';
import '../bloc/pix_bloc.dart';
import '../bloc/pix_event.dart';
import '../bloc/pix_state.dart';


class SendPixPage extends StatefulWidget {
  const SendPixPage({super.key});

  @override
  State<SendPixPage> createState() => _SendPixPageState();
}

class _SendPixPageState extends State<SendPixPage> {
  final _formKey = GlobalKey<FormState>();
  final _pixKeyController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _receiverNameController = TextEditingController();

  PixKeyType _selectedType = PixKeyType.cpf;

  @override
  void dispose() {
    _pixKeyController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _receiverNameController.dispose();
    super.dispose();
  }

  void _sendPix() {
    if (_formKey.currentState?.validate() ?? false) {
      final amount =
          double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;

      context.read<PixBloc>().add(
            SendPixEvent(
              pixKeyValue: _pixKeyController.text,
              pixKeyType: _selectedType,
              amount: amount,
              description: _descriptionController.text.isNotEmpty
                  ? _descriptionController.text
                  : null,
              receiverName: _receiverNameController.text.isNotEmpty
                  ? _receiverNameController.text
                  : null,
            ),
          );
    }
  }

  void _navigateToScanQrCode() {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo('/pix/scan');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviar Pix'),
      ),
      body: BlocConsumer<PixBloc, PixState>(
        listener: (context, state) {
          if (state is PixSentState) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pix enviado com sucesso'),
                backgroundColor: Colors.green,
              ),
            );

            Navigator.of(context).pop();
          } else if (state is PixSendErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _navigateToScanQrCode,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Ler QR Code'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24.0),
                      const Divider(),
                      const SizedBox(height: 24.0),

                      const Text(
                        'Tipo de Chave',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      _buildPixKeyTypeSelector(),
                      const SizedBox(height: 24.0),

                      const Text(
                        'Chave Pix',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _pixKeyController,
                        decoration: InputDecoration(
                          hintText: _getValueHint(),
                          border: const OutlineInputBorder(),
                          prefixIcon: _getValueIcon(),
                        ),
                        keyboardType: _getKeyboardType(),
                        inputFormatters: _getInputFormatters(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, informe a chave Pix';
                          }

                          if (!_validateValue(value)) {
                            return 'Chave Pix inválida para o tipo selecionado';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 24.0),

                      const Text(
                        'Valor',
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+[,.]?\d{0,2}')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, informe o valor';
                          }

                          final amount =
                              double.tryParse(value.replaceAll(',', '.')) ??
                                  0.0;
                          if (amount <= 0) {
                            return 'O valor deve ser maior que zero';
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
                          hintText: 'Ex: Pagamento de aluguel',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLength: 140,
                      ),
                      const SizedBox(height: 16.0),

                      const Text(
                        'Nome do Destinatário (opcional)',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _receiverNameController,
                        decoration: const InputDecoration(
                          hintText: 'Ex: João da Silva',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 32.0),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: state is PixSendingState ? null : _sendPix,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                          ),
                          child: state is PixSendingState
                              ? const CircularProgressIndicator()
                              : const Text('Enviar Pix'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state is PixSendingState)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPixKeyTypeSelector() {
    return DropdownButtonFormField<PixKeyType>(
      value: _selectedType,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      ),
      items: [
        DropdownMenuItem(
          value: PixKeyType.cpf,
          child: _buildDropdownItem(
            'CPF',
            Icons.badge,
            Colors.blue,
          ),
        ),
        DropdownMenuItem(
          value: PixKeyType.cnpj,
          child: _buildDropdownItem(
            'CNPJ',
            Icons.business,
            Colors.purple,
          ),
        ),
        DropdownMenuItem(
          value: PixKeyType.email,
          child: _buildDropdownItem(
            'E-mail',
            Icons.email,
            Colors.red,
          ),
        ),
        DropdownMenuItem(
          value: PixKeyType.phone,
          child: _buildDropdownItem(
            'Telefone',
            Icons.phone,
            Colors.green,
          ),
        ),
        DropdownMenuItem(
          value: PixKeyType.random,
          child: _buildDropdownItem(
            'Chave Aleatória',
            Icons.vpn_key,
            Colors.orange,
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedType = value;
            _pixKeyController.clear();
          });
        }
      },
    );
  }

  Widget _buildDropdownItem(String text, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 16.0,
          ),
        ),
        const SizedBox(width: 8.0),
        Text(text),
      ],
    );
  }

  String _getValueHint() {
    switch (_selectedType) {
      case PixKeyType.cpf:
        return '123.456.789-00';
      case PixKeyType.cnpj:
        return '12.345.678/0001-90';
      case PixKeyType.email:
        return 'exemplo@email.com';
      case PixKeyType.phone:
        return '(11) 98765-4321';
      case PixKeyType.random:
        return 'Chave aleatória';
    }
  }

  Icon _getValueIcon() {
    switch (_selectedType) {
      case PixKeyType.cpf:
        return const Icon(Icons.badge);
      case PixKeyType.cnpj:
        return const Icon(Icons.business);
      case PixKeyType.email:
        return const Icon(Icons.email);
      case PixKeyType.phone:
        return const Icon(Icons.phone);
      case PixKeyType.random:
        return const Icon(Icons.vpn_key);
    }
  }

  TextInputType _getKeyboardType() {
    switch (_selectedType) {
      case PixKeyType.cpf:
      case PixKeyType.cnpj:
      case PixKeyType.phone:
        return TextInputType.number;
      case PixKeyType.email:
        return TextInputType.emailAddress;
      case PixKeyType.random:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter> _getInputFormatters() {
    switch (_selectedType) {
      case PixKeyType.cpf:
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ];
      case PixKeyType.cnpj:
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(14),
        ];
      case PixKeyType.phone:
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ];
      case PixKeyType.email:
      case PixKeyType.random:
        return [];
    }
  }

  bool _validateValue(String value) {
    switch (_selectedType) {
      case PixKeyType.cpf:
        
        return value.replaceAll(RegExp(r'[^\d]'), '').length == 11;
      case PixKeyType.cnpj:
        
        return value.replaceAll(RegExp(r'[^\d]'), '').length == 14;
      case PixKeyType.email:
        
        return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
      case PixKeyType.phone:
        
        return value.replaceAll(RegExp(r'[^\d]'), '').length == 11;
      case PixKeyType.random:
        
        return true;
    }
  }
}
