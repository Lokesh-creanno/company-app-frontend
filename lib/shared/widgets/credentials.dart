import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

/// A password box that starts hidden and has an eye to reveal it.
///
/// Every password input in the app uses this, so "show password" behaves the
/// same everywhere. The eye is wrapped in ExcludeFocus: without it the Next key
/// lands on the icon button instead of the following field.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint,
    this.required = true,
    this.validator,
    this.focusNode,
    this.textInputAction,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _hidden,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: ExcludeFocus(
          child: IconButton(
            tooltip: _hidden ? 'Show password' : 'Hide password',
            icon: Icon(
              _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20,
            ),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      ),
      validator: widget.validator ??
          (v) {
            final val = (v ?? '').trim();
            if (!widget.required && val.isEmpty) return null;
            if (val.isEmpty) return 'Required';
            if (val.length < 6) return 'At least 6 characters';
            return null;
          },
    );
  }
}

/// The text a super admin hands to a new member. Kept in one place so the card
/// on screen and the copied text can never drift apart.
String loginCardText({
  required String name,
  required String email,
  required String password,
  String? employeeId,
}) =>
    'CREANNO login\n'
    '\n'
    'Name:     $name\n'
    '${employeeId != null && employeeId.isNotEmpty ? 'Staff ID: $employeeId\n' : ''}'
    'Email:    $email\n'
    'Password: $password\n'
    '\n'
    'Web app:  ${AppConstants.webAppUrl}\n'
    'Please change nothing — sign in with these exact details.';

/// Shows the credentials as a card with a copy button, for sending on to the
/// member. Plain text by design: the super admin chose recoverable passwords.
Future<void> showLoginCard(
  BuildContext context, {
  required String name,
  required String email,
  required String password,
  String? employeeId,
}) {
  final text = loginCardText(
      name: name, email: email, password: password, employeeId: employeeId);

  return showDialog<void>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: const Text('Login card'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceVarOf(dctx),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderOf(dctx)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  if (employeeId != null && employeeId.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(employeeId,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryOf(dctx))),
                  ],
                  const SizedBox(height: 12),
                  _CardRow(label: 'Email', value: email),
                  const SizedBox(height: 8),
                  _CardRow(label: 'Password', value: password, big: true),
                  const SizedBox(height: 8),
                  _CardRow(label: 'Web app', value: AppConstants.webAppUrl),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Send this to the member privately. Anyone with these details can sign in as them.',
              style: TextStyle(
                  fontSize: 11.5, color: AppColors.textSecondaryOf(dctx)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dctx), child: const Text('Close')),
        FilledButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (!dctx.mounted) return;
            Navigator.pop(dctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Login card copied — paste it to the member')));
          },
        ),
      ],
    ),
  );
}

class _CardRow extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  const _CardRow({required this.label, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondaryOf(context))),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
                fontSize: big ? 18 : 13.5,
                fontWeight: big ? FontWeight.w800 : FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
