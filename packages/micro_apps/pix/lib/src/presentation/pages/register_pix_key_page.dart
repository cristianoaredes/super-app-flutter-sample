import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/pix_key.dart';
import '../bloc/pix_bloc.dart';
import '../bloc/pix_event.dart';
import '../bloc/pix_state.dart';


class RegisterPixKeyPage extends StatefulWidget {
  const RegisterPixKeyPage({super.key});

  @override
  State<RegisterPixKeyPage> createState() => _RegisterPixKeyPageState();
}

class _RegisterPixKeyPageState extends State<RegisterPixKeyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  
  PixKeyType _selectedType = PixKeyType.cpf;
  
  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }
  
  void _registerPixKey() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<PixBloc>().add(
        RegisterPixKeyEvent(
          type: _selectedType,
          value: _valueController.text,
          name: _nameController.text.isNotEmpty ? _nameController.text : null,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Chave Pix'),
      ),
      body: BlocConsumer<PixBloc, PixState>(
        listener: (context, state) {
          if (state is PixKeyRegisteredState) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chave Pix cadastrada com sucesso'),
                backgroundColor: Colors.green,
              ),
            );
            
            Navigator.of(context).pop();
          } else if (state is PixKeysErrorState) {
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
                        'Valor da Chave',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _valueController,
                        decoration: InputDecoration(
                          hintText: _getValueHint(),
                          border: const OutlineInputBorder(),
                          prefixIcon: _getValueIcon(),
                        ),
                        keyboardType: _getKeyboardType(),
                        inputFormatters: _getInputFormatters(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, informe o valor da chave';
                          }
                          
                          if (!_validateValue(value)) {
                            return 'Valor inválido para o tipo de chave selecionado';
                          }
                          
                          return null;
                        },
                      ),
                      const SizedBox(height: 24.0),
                      
                      const Text(
                        'Nome da Chave (opcional)',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Chave pessoal',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                        ),
                      ),
                      const SizedBox(height: 32.0),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: state is PixKeyRegisteringState
                              ? null
                              : _registerPixKey,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                          ),
                          child: state is PixKeyRegisteringState
                              ? const CircularProgressIndicator()
                              : const Text('Cadastrar Chave'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (state is PixKeyRegisteringState)
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
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            _buildPixKeyTypeOption(
              type: PixKeyType.cpf,
              title: 'CPF',
              subtitle: 'Seu CPF',
              icon: Icons.badge,
              iconColor: Colors.blue,
            ),
            const Divider(),
            _buildPixKeyTypeOption(
              type: PixKeyType.cnpj,
              title: 'CNPJ',
              subtitle: 'Seu CNPJ',
              icon: Icons.business,
              iconColor: Colors.purple,
            ),
            const Divider(),
            _buildPixKeyTypeOption(
              type: PixKeyType.email,
              title: 'E-mail',
              subtitle: 'Seu endereço de e-mail',
              icon: Icons.email,
              iconColor: Colors.red,
            ),
            const Divider(),
            _buildPixKeyTypeOption(
              type: PixKeyType.phone,
              title: 'Telefone',
              subtitle: 'Seu número de telefone',
              icon: Icons.phone,
              iconColor: Colors.green,
            ),
            const Divider(),
            _buildPixKeyTypeOption(
              type: PixKeyType.random,
              title: 'Chave Aleatória',
              subtitle: 'Chave gerada automaticamente',
              icon: Icons.vpn_key,
              iconColor: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPixKeyTypeOption({
    required PixKeyType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return RadioListTile<PixKeyType>(
      value: type,
      groupValue: _selectedType,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedType = value;
            _valueController.clear();
          });
        }
      },
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(subtitle),
      secondary: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
        ),
      ),
      activeColor: Theme.of(context).colorScheme.primary,
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
        return 'Chave aleatória gerada pelo banco';
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
