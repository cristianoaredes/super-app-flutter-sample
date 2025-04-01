import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../bloc/account_bloc.dart';
import '../bloc/account_event.dart';
import '../bloc/account_state.dart';


class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _agencyController = TextEditingController();
  final _bankController = TextEditingController();
  final _nameController = TextEditingController();
  final _documentController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _accountController.dispose();
    _agencyController.dispose();
    _bankController.dispose();
    _nameController.dispose();
    _documentController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _transferMoney() {
    if (_formKey.currentState?.validate() ?? false) {
      final amount =
          double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;

      context.read<AccountBloc>().add(
            TransferMoneyEvent(
              destinationAccount: _accountController.text,
              destinationAgency: _agencyController.text,
              destinationBank: _bankController.text,
              destinationName: _nameController.text,
              destinationDocument: _documentController.text,
              amount: amount,
              description: _descriptionController.text.isNotEmpty
                  ? _descriptionController.text
                  : null,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transferência'),
      ),
      body: BlocProvider<AccountBloc>(
        create: (context) => GetIt.instance<AccountBloc>(),
        child: BlocConsumer<AccountBloc, AccountState>(
          listener: (context, state) {
            if (state is TransferMoneySuccessState) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transferência realizada com sucesso'),
                  backgroundColor: Colors.green,
                ),
              );

              Navigator.of(context).pop();
            } else if (state is TransferMoneyErrorState) {
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
                          'Dados do Destinatário',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _bankController,
                          decoration: const InputDecoration(
                            labelText: 'Banco',
                            hintText: 'Ex: 341 - Itaú',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_balance),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, informe o banco';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _agencyController,
                          decoration: const InputDecoration(
                            labelText: 'Agência',
                            hintText: 'Ex: 1234',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, informe a agência';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _accountController,
                          decoration: const InputDecoration(
                            labelText: 'Conta',
                            hintText: 'Ex: 12345-6',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_box),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, informe a conta';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do Destinatário',
                            hintText: 'Ex: João da Silva',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, informe o nome do destinatário';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _documentController,
                          decoration: const InputDecoration(
                            labelText: 'CPF/CNPJ',
                            hintText: 'Ex: 123.456.789-00',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, informe o CPF/CNPJ';
                            }

                            final digits =
                                value.replaceAll(RegExp(r'[^\d]'), '');
                            if (digits.length != 11 && digits.length != 14) {
                              return 'CPF/CNPJ inválido';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 24.0),
                        const Text(
                          'Dados da Transferência',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Valor',
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
                        const SizedBox(height: 16.0),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Descrição (opcional)',
                            hintText: 'Ex: Pagamento de aluguel',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLength: 140,
                        ),
                        const SizedBox(height: 24.0),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state is TransferMoneyLoadingState
                                ? null
                                : _transferMoney,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                            ),
                            child: state is TransferMoneyLoadingState
                                ? const CircularProgressIndicator()
                                : const Text('Transferir'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state is TransferMoneyLoadingState)
                  const Positioned.fill(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
