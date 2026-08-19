import 'package:flutter/material.dart';

class PasswordDialog extends StatefulWidget {
  final String mode; // 'create' or 'unlock'
  final Function(String) onPasswordEntered;

  const PasswordDialog({
    super.key,
    required this.mode,
    required this.onPasswordEntered,
  });

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _error = 'Password cannot be empty';
      });
      return;
    }

    if (widget.mode == 'create') {
      final confirmPassword = _confirmPasswordController.text;
      if (password != confirmPassword) {
        setState(() {
          _error = 'Passwords do not match';
        });
        return;
      }
      if (password.length < 8) {
        setState(() {
          _error = 'Password must be at least 8 characters';
        });
        return;
      }
    }

    widget.onPasswordEntered(password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.mode == 'create' ? 'Create Wallet' : 'Unlock Wallet'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            if (widget.mode == 'create') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.mode == 'create' ? 'Create' : 'Unlock'),
        ),
      ],
    );
  }
}
