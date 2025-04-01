import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_interfaces/core_interfaces.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/pix_key.dart';
import '../bloc/pix_bloc.dart';
import '../bloc/pix_event.dart';
import '../bloc/pix_state.dart';


class PixKeysPage extends StatefulWidget {
  const PixKeysPage({super.key});

  @override
  State<PixKeysPage> createState() => _PixKeysPageState();
}

class _PixKeysPageState extends State<PixKeysPage> {
  @override
  void initState() {
    super.initState();
    context.read<PixBloc>().add(const LoadPixKeysEvent());
  }

  void _navigateToRegisterPixKey() {
    final navigationService = GetIt.instance<NavigationService>();
    navigationService.navigateTo('/pix/keys/register');
  }

  void _deletePixKey(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Chave Pix'),
        content: const Text('Tem certeza que deseja excluir esta chave Pix?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<PixBloc>().add(DeletePixKeyEvent(id: id));
            },
            child: const Text('Excluir'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Chaves Pix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<PixBloc>().add(const LoadPixKeysEvent());
            },
          ),
        ],
      ),
      body: BlocConsumer<PixBloc, PixState>(
        listener: (context, state) {
          if (state is PixKeyDeletedState) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chave Pix excluída com sucesso'),
                backgroundColor: Colors.green,
              ),
            );

            
            context.read<PixBloc>().add(const LoadPixKeysEvent());
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
          if (state is PixKeysLoadingState || state is PixKeyDeletingState) {
            return const Center(
              child: CircularProgressIndicator(),
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
                      'Cadastre uma chave para enviar e receber transferências',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24.0),
                    ElevatedButton(
                      onPressed: _navigateToRegisterPixKey,
                      child: const Text('Cadastrar Chave'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<PixBloc>().add(const LoadPixKeysEvent());
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: state.keys.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final key = state.keys[index];
                  return _buildPixKeyItem(key);
                },
              ),
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

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToRegisterPixKey,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPixKeyItem(PixKey key) {
    return Card(
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getPixKeyTypeIcon(key.type),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        key.formattedName,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        key.formattedValue,
                        style: const TextStyle(
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deletePixKey(key.id),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tipo: ${_getPixKeyTypeName(key.type)}',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  'Cadastrada em: ${_formatDate(key.createdAt)}',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24.0,
      ),
    );
  }

  String _getPixKeyTypeName(PixKeyType type) {
    switch (type) {
      case PixKeyType.cpf:
        return 'CPF';
      case PixKeyType.cnpj:
        return 'CNPJ';
      case PixKeyType.email:
        return 'E-mail';
      case PixKeyType.phone:
        return 'Telefone';
      case PixKeyType.random:
        return 'Chave Aleatória';
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }
}
