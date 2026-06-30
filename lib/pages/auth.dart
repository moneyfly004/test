import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _savePassword = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final creds = await StorageService().getSavedCredentials();
    if (creds != null && mounted) {
      _accountCtrl.text = creds['account'] ?? '';
      _pwCtrl.text = creds['password'] ?? '';
      setState(() => _savePassword = true);
    }
  }

  Future<void> _handleAuthSuccess(Map<String, dynamic> result) async {
    final invalidLoginResponse = context.appLocalizations.invalidLoginResponse;
    final storage = StorageService();
    final accessToken = (result['access_token'] ?? '').toString();
    if (accessToken.isEmpty) {
      throw StateError(invalidLoginResponse);
    }
    await storage.saveToken(accessToken);
    await storage.saveRefreshToken((result['refresh_token'] ?? '').toString());
    final accountState = await MoneyFlyService.refreshAccountState(ref);
    if (!accountState.available) {
      await storage.clearTokens();
      if (!mounted) return;
      _showError(
        accountState.message ?? context.appLocalizations.accountUnavailable,
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _showError(String message) {
    setState(() => _formError = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login({bool validate = true}) async {
    if (validate && !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _formError = null;
    });
    try {
      final account = _accountCtrl.text.trim();
      final result = await ApiService().login(account, _pwCtrl.text);
      if (_savePassword) {
        await StorageService().saveCredentials(account, _pwCtrl.text);
      } else {
        await StorageService().clearCredentials();
      }
      await _handleAuthSuccess(result);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        'MoneyFly',
                        textAlign: TextAlign.center,
                        style: context.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appLocalizations.appTagline,
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: cs.outline,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _AuthErrorText(message: _formError),
                      _AuthTextField(
                        controller: _accountCtrl,
                        label: appLocalizations.emailOrUsername,
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: 16),
                      _AuthTextField(
                        controller: _pwCtrl,
                        label: appLocalizations.password,
                        icon: Icons.lock_outline,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _loading ? null : _login(),
                        validator: _requiredValidator,
                        suffixIcon: _PasswordVisibilityButton(
                          obscure: _obscure,
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                ),
                          child: Text(appLocalizations.forgotPassword),
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _savePassword,
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _savePassword = v ?? false),
                        title: Text(
                          appLocalizations.rememberPassword,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(appLocalizations.rememberPasswordTip),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 12),
                      _SubmitButton(
                        loading: _loading,
                        label: appLocalizations.login,
                        onPressed: () => _login(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(child: Text(appLocalizations.noAccount)),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterPage(),
                                    ),
                                  ),
                            child: Text(appLocalizations.registerNow),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  bool _disposed = false;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  bool _loading = false;
  bool _sendingCode = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  int _countdown = 0;
  String? _formError;
  Timer? _countdownTimer;

  Future<void> _sendCode() async {
    if (!_validateEmailOnly()) return;
    setState(() {
      _sendingCode = true;
      _formError = null;
    });
    try {
      await ApiService().sendVerificationCode(_emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.appLocalizations.codeSent)),
        );
        setState(() => _countdown = 60);
        _startCountdown();
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _disposed || _countdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) timer.cancel();
    });
  }

  bool _validateEmailOnly() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError(context.appLocalizations.fieldRequired);
      return false;
    }
    if (!_isValidEmail(email)) {
      _showError(context.appLocalizations.emailInvalid);
      return false;
    }
    return true;
  }

  void _showError(String message) {
    setState(() => _formError = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final invalidLoginResponse = context.appLocalizations.invalidLoginResponse;
    setState(() {
      _loading = true;
      _formError = null;
    });
    try {
      final result = await ApiService().register(
        username: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
        verificationCode: _codeCtrl.text.trim(),
        inviteCode: _inviteCtrl.text.trim().isEmpty
            ? null
            : _inviteCtrl.text.trim(),
      );
      await StorageService().clearCredentials();
      final accessToken = (result['access_token'] ?? '').toString();
      if (accessToken.isEmpty) {
        throw StateError(invalidLoginResponse);
      }
      await StorageService().saveToken(accessToken);
      await StorageService().saveRefreshToken(
        (result['refresh_token'] ?? '').toString(),
      );
      final accountState = await MoneyFlyService.refreshAccountState(ref);
      if (!accountState.available) {
        await StorageService().clearTokens();
        if (!mounted) return;
        _showError(
          accountState.message ?? context.appLocalizations.accountUnavailable,
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
    _codeCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Scaffold(
      appBar: AppBar(title: Text(appLocalizations.createAccount)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AuthErrorText(message: _formError),
                      _AuthTextField(
                        controller: _nameCtrl,
                        label: appLocalizations.username,
                        icon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        validator: _usernameValidator,
                      ),
                      const SizedBox(height: 16),
                      _AuthTextField(
                        controller: _emailCtrl,
                        label: appLocalizations.email,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _AuthTextField(
                              controller: _codeCtrl,
                              label: appLocalizations.verificationCode,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _requiredValidator,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 56,
                            child: FilledButton.tonal(
                              onPressed:
                                  _countdown > 0 || _sendingCode || _loading
                                  ? null
                                  : _sendCode,
                              child: _sendingCode
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _countdown > 0
                                          ? '${_countdown}s'
                                          : appLocalizations.send,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _AuthTextField(
                        controller: _pwCtrl,
                        label: appLocalizations.password,
                        icon: Icons.lock_outline,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: _passwordValidator,
                        suffixIcon: _PasswordVisibilityButton(
                          obscure: _obscure,
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AuthTextField(
                        controller: _confirmPwCtrl,
                        label: appLocalizations.confirmPassword,
                        icon: Icons.lock_reset,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) =>
                            _confirmPasswordValidator(value, _pwCtrl.text),
                        suffixIcon: _PasswordVisibilityButton(
                          obscure: _obscureConfirm,
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AuthTextField(
                        controller: _inviteCtrl,
                        label: appLocalizations.inviteCodeOptional,
                        icon: Icons.card_giftcard_outlined,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _loading ? null : _register(),
                      ),
                      const SizedBox(height: 24),
                      _SubmitButton(
                        loading: _loading,
                        label: appLocalizations.register,
                        onPressed: _register,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  bool _disposed = false;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _loading = false;
  bool _sendingCode = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  int _countdown = 0;
  String? _formError;
  Timer? _countdownTimer;

  Future<void> _sendCode() async {
    if (!_validateEmailOnly()) return;
    setState(() {
      _sendingCode = true;
      _formError = null;
    });
    try {
      await ApiService().sendForgotPasswordCode(_emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.appLocalizations.codeSent)),
        );
        setState(() => _countdown = 60);
        _startCountdown();
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _disposed || _countdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) timer.cancel();
    });
  }

  bool _validateEmailOnly() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError(context.appLocalizations.fieldRequired);
      return false;
    }
    if (!_isValidEmail(email)) {
      _showError(context.appLocalizations.emailInvalid);
      return false;
    }
    return true;
  }

  void _showError(String message) {
    setState(() => _formError = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final invalidLoginResponse = context.appLocalizations.invalidLoginResponse;
    setState(() {
      _loading = true;
      _formError = null;
    });
    try {
      await ApiService().resetPassword(
        _emailCtrl.text.trim(),
        _codeCtrl.text.trim(),
        _pwCtrl.text,
      );
      final result = await ApiService().login(
        _emailCtrl.text.trim(),
        _pwCtrl.text,
      );
      await StorageService().clearCredentials();
      final accessToken = (result['access_token'] ?? '').toString();
      if (accessToken.isEmpty) {
        throw StateError(invalidLoginResponse);
      }
      await StorageService().saveToken(accessToken);
      await StorageService().saveRefreshToken(
        (result['refresh_token'] ?? '').toString(),
      );
      final accountState = await MoneyFlyService.refreshAccountState(ref);
      if (!accountState.available) {
        await StorageService().clearTokens();
        if (!mounted) return;
        _showError(
          accountState.message ?? context.appLocalizations.accountUnavailable,
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Scaffold(
      appBar: AppBar(title: Text(appLocalizations.resetPassword)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AuthErrorText(message: _formError),
                      _AuthTextField(
                        controller: _emailCtrl,
                        label: appLocalizations.email,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _AuthTextField(
                              controller: _codeCtrl,
                              label: appLocalizations.verificationCode,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: _requiredValidator,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 56,
                            child: FilledButton.tonal(
                              onPressed:
                                  _countdown > 0 || _sendingCode || _loading
                                  ? null
                                  : _sendCode,
                              child: _sendingCode
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _countdown > 0
                                          ? '${_countdown}s'
                                          : appLocalizations.send,
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _AuthTextField(
                        controller: _pwCtrl,
                        label: appLocalizations.newPassword,
                        icon: Icons.lock_outline,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: _passwordValidator,
                        suffixIcon: _PasswordVisibilityButton(
                          obscure: _obscure,
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AuthTextField(
                        controller: _confirmPwCtrl,
                        label: appLocalizations.confirmPassword,
                        icon: Icons.lock_reset,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) =>
                            _confirmPasswordValidator(value, _pwCtrl.text),
                        onFieldSubmitted: (_) => _loading ? null : _reset(),
                        suffixIcon: _PasswordVisibilityButton(
                          obscure: _obscureConfirm,
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SubmitButton(
                        loading: _loading,
                        label: appLocalizations.resetPassword,
                        onPressed: _reset,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffixIcon;

  const _AuthTextField({
    required this.controller,
    required this.label,
    this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.onFieldSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  final bool obscure;
  final VoidCallback onPressed;

  const _PasswordVisibilityButton({
    required this.obscure,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscure
          ? context.appLocalizations.showPassword
          : context.appLocalizations.hidePassword,
      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
      onPressed: onPressed,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}

class _AuthErrorText extends StatelessWidget {
  final String? message;

  const _AuthErrorText({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message!,
          style: TextStyle(color: context.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}

String? _requiredValidator(String? value) {
  return value == null || value.trim().isEmpty
      ? currentAppLocalizations.fieldRequired
      : null;
}

String? _usernameValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return currentAppLocalizations.fieldRequired;
  if (text.length < 2) return currentAppLocalizations.usernameTooShort;
  return null;
}

String? _emailValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return currentAppLocalizations.fieldRequired;
  if (!_isValidEmail(text)) return currentAppLocalizations.emailInvalid;
  return null;
}

String? _passwordValidator(String? value) {
  final text = value ?? '';
  if (text.isEmpty) return currentAppLocalizations.fieldRequired;
  if (text.length < 8) return currentAppLocalizations.passwordTooShort;
  return null;
}

String? _confirmPasswordValidator(String? value, String password) {
  final requiredError = _passwordValidator(value);
  if (requiredError != null) return requiredError;
  if (value != password) return currentAppLocalizations.passwordMismatch;
  return null;
}

bool _isValidEmail(String value) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
}
