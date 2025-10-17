// lib/mail/welcome_mail.dart

import 'package:flint_dart/flint_ui.dart';
import 'package:flint_dart/mail.dart';
import 'package:sample/src/mail/templates/newsletter_template.dart';
import 'package:sample/src/mail/templates/order_confirmation_template.dart';
import 'package:sample/src/mail/templates/password_reset_template.dart';
import 'package:sample/src/mail/templates/welcome_mail_template.dart';

class WelcomeMail extends TransactionalMailable {
  final String verificationUrl;
  final String loginUrl;

  WelcomeMail({
    required super.recipientName,
    required super.recipientEmail,
    required this.verificationUrl,
    required this.loginUrl,
  });

  @override
  String get subject => 'Welcome to Our Service, $recipientName! 🎉';

  @override
  FlintWidget build() {
    return WelcomeMailTemplate(
      recipientName: recipientName,
      recipientEmail: recipientEmail,
      verificationUrl: verificationUrl,
      loginUrl: loginUrl,
    );
  }
}

// lib/mail/password_reset_mail.dart

class PasswordResetMail extends TransactionalMailable {
  final String resetUrl;
  final int expiryHours;

  PasswordResetMail({
    required super.recipientName,
    required super.recipientEmail,
    required this.resetUrl,
    this.expiryHours = 24,
  });

  @override
  String get subject => 'Password Reset Request';

  @override
  FlintWidget build() {
    return PasswordResetTemplate(
      recipientName: recipientName,
      recipientEmail: recipientEmail,
      resetUrl: resetUrl,
      expiryHours: expiryHours,
    );
  }
}

// lib/mail/order_confirmation_mail.dart

class OrderConfirmationMail extends TransactionalMailable {
  final String orderNumber;
  final DateTime orderDate;
  final double orderTotal;
  final List<OrderItem> items;

  OrderConfirmationMail({
    required super.recipientName,
    required super.recipientEmail,
    required this.orderNumber,
    required this.orderDate,
    required this.orderTotal,
    required this.items,
  });

  @override
  String get subject => 'Order Confirmation - #$orderNumber';

  @override
  FlintWidget build() {
    return OrderConfirmationTemplate(
      recipientName: recipientName,
      recipientEmail: recipientEmail,
      orderNumber: orderNumber,
      orderDate: orderDate,
      orderTotal: orderTotal,
      items: items,
    );
  }
}

// lib/mail/newsletter_mail.dart

class NewsletterMail extends MarketingMailable {
  final String newsletterTitle;
  final String newsletterContent;
  final String? imageUrl;

  NewsletterMail({
    required super.recipients,
    required this.newsletterTitle,
    required this.newsletterContent,
    this.imageUrl,
  });

  @override
  String get subject => newsletterTitle;

  @override
  FlintWidget build() {
    return NewsletterTemplate(
      title: newsletterTitle,
      content: newsletterContent,
      imageUrl: imageUrl,
    );
  }
}
