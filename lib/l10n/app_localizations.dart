import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:encounter_app/l10n/messages_all.dart';

class AppLocalizations {
  static Future<AppLocalizations> load(Locale locale) {
    final String name = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : locale.toString();
    final String localeName = Intl.canonicalizedLocale(name);

    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      return AppLocalizations();
    });
  }

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Define all your string getters here
  String get appTitle => Intl.message(
        'Encounter App',
        name: 'appTitle',
        desc: 'The title of the application',
      );

  String get signIn => Intl.message(
        'Sign In',
        name: 'signIn',
        desc: 'Text for sign in button',
      );

  String get signUp => Intl.message(
        'Sign Up',
        name: 'signUp',
        desc: 'Text for sign up button',
      );

  String get email => Intl.message(
        'Email',
        name: 'email',
        desc: 'Label for email field',
      );

  String get password => Intl.message(
        'Password',
        name: 'password',
        desc: 'Label for password field',
      );

  String get confirmPassword => Intl.message(
        'Confirm Password',
        name: 'confirmPassword',
        desc: 'Label for confirm password field',
      );

  String get forgotPassword => Intl.message(
        'Forgot Password',
        name: 'forgotPassword',
        desc: 'Text for forgot password option',
      );

  String get resetPassword => Intl.message(
        'Reset Password',
        name: 'resetPassword',
        desc: 'Text for reset password button',
      );

  String get continueWithEmail => Intl.message(
        'Continue with Email',
        name: 'continueWithEmail',
        desc: 'Text for continue with email button',
      );

  String get signInWithGoogle => Intl.message(
        'Sign in with Google',
        name: 'signInWithGoogle',
        desc: 'Text for sign in with Google button',
      );

  String get signInWithApple => Intl.message(
        'Sign in with Apple',
        name: 'signInWithApple',
        desc: 'Text for sign in with Apple button',
      );

  String get welcomeBack => Intl.message(
        'Welcome back!',
        name: 'welcomeBack',
        desc: 'Welcome message for returning users',
      );

  String get welcomeMessage => Intl.message(
        'Welcome to Encounter!',
        name: 'welcomeMessage',
        desc: 'Welcome message for new users',
      );

  String get welcomeSubtitle => Intl.message(
        'Sign in to connect with people around you',
        name: 'welcomeSubtitle',
        desc: 'Subtitle for welcome screen',
      );

  String get dontHaveAccount => Intl.message(
        'Don\'t have an account?',
        name: 'dontHaveAccount',
        desc: 'Message for users without an account',
      );

  String get createAccount => Intl.message(
        'Create Account',
        name: 'createAccount',
        desc: 'Text for create account button',
      );

  String get haveAccount => Intl.message(
        'Have an account?',
        name: 'haveAccount',
        desc: 'Message for users with an account',
      );

  String get verifyEmailTitle => Intl.message(
        'Verify Your Email',
        name: 'verifyEmailTitle',
        desc: 'Title for email verification screen',
      );

  String get verifyEmailSent => Intl.message(
        'A verification code has been sent to',
        name: 'verifyEmailSent',
        desc: 'Message indicating a verification code has been sent',
      );

  String get enterVerificationCode => Intl.message(
        'Enter verification code',
        name: 'enterVerificationCode',
        desc: 'Prompt to enter verification code',
      );

  String get didntReceiveCode => Intl.message(
        'Didn\'t receive code? Send again',
        name: 'didntReceiveCode',
        desc: 'Option to resend verification code',
      );

  String get invalidEmail => Intl.message(
        'Invalid email',
        name: 'invalidEmail',
        desc: 'Error message for invalid email',
      );

  String get invalidPassword => Intl.message(
        'Invalid password',
        name: 'invalidPassword',
        desc: 'Error message for invalid password',
      );

  String get passwordsDoNotMatch => Intl.message(
        'Passwords do not match',
        name: 'passwordsDoNotMatch',
        desc: 'Error message when passwords do not match',
      );

  String get editProfile => Intl.message(
        'Edit Profile',
        name: 'editProfile',
        desc: 'Text for edit profile option',
      );

  String get bio => Intl.message(
        'Bio',
        name: 'bio',
        desc: 'Label for bio field',
      );

  String get username => Intl.message(
        'Username',
        name: 'username',
        desc: 'Label for username field',
      );

  String get gender => Intl.message(
        'Gender',
        name: 'gender',
        desc: 'Label for gender field',
      );

  String get male => Intl.message(
        'Male',
        name: 'male',
        desc: 'Option for male gender',
      );

  String get female => Intl.message(
        'Female',
        name: 'female',
        desc: 'Option for female gender',
      );

  String get other => Intl.message(
        'Other',
        name: 'other',
        desc: 'Option for other gender',
      );

  String get none => Intl.message(
        'None',
        name: 'none',
        desc: 'Option for no gender',
      );

  String get everyone => Intl.message(
        'Everyone',
        name: 'everyone',
        desc: 'Option for everyone in filters',
      );

  String get close => Intl.message(
        'Close',
        name: 'close',
        desc: 'Text for close button',
      );

  String get cancel => Intl.message(
        'Cancel',
        name: 'cancel',
        desc: 'Text for cancel button',
      );

  String get saveChanges => Intl.message(
        'Save Changes',
        name: 'saveChanges',
        desc: 'Text for save changes button',
      );

  String get submit => Intl.message(
        'Submit',
        name: 'submit',
        desc: 'Text for submit button',
      );

  String get home => Intl.message(
        'Home',
        name: 'home',
        desc: 'Label for home tab',
      );

  String get messages => Intl.message(
        'Messages',
        name: 'messages',
        desc: 'Label for messages tab',
      );

  String get profile => Intl.message(
        'Profile',
        name: 'profile',
        desc: 'Label for profile tab',
      );

  String get settings => Intl.message(
        'Settings',
        name: 'settings',
        desc: 'Text for settings',
      );

  String get premium => Intl.message(
        'Premium',
        name: 'premium',
        desc: 'Text for premium membership',
      );

  String get active => Intl.message(
        'Active',
        name: 'active',
        desc: 'Status indicator for active',
      );

  String get closed => Intl.message(
        'Closed',
        name: 'closed',
        desc: 'Status indicator for closed',
      );

  String get expired => Intl.message(
        'Expired',
        name: 'expired',
        desc: 'Status indicator for expired',
      );

  String get archived => Intl.message(
        'Archived',
        name: 'archived',
        desc: 'Status indicator for archived',
      );

  String get currentPosts => Intl.message(
        'Current Posts',
        name: 'currentPosts',
        desc: 'Tab title for current posts',
      );

  String get archivedPosts => Intl.message(
        'Archived Posts',
        name: 'archivedPosts',
        desc: 'Tab title for archived posts',
      );

  String get blockedUsers => Intl.message(
        'Blocked Users',
        name: 'blockedUsers',
        desc: 'Title for blocked users screen',
      );

  String get noBlockedUsers => Intl.message(
        'No Blocked Users',
        name: 'noBlockedUsers',
        desc: 'Message when there are no blocked users',
      );

  String get blockUser => Intl.message(
        'Block User',
        name: 'blockUser',
        desc: 'Action to block a user',
      );

  String get unblock => Intl.message(
        'Unblock',
        name: 'unblock',
        desc: 'Action to unblock a user',
      );

  String get reports => Intl.message(
        'Reports',
        name: 'reports',
        desc: 'Label for reports section',
      );

  String get myReports => Intl.message(
        'My Reports',
        name: 'myReports',
        desc: 'Title for user reports screen',
      );

  String get reportUser => Intl.message(
        'Report User',
        name: 'reportUser',
        desc: 'Action to report a user',
      );

  String get reportReason => Intl.message(
        'Report Reason',
        name: 'reportReason',
        desc: 'Label for report reason field',
      );

  String get location => Intl.message(
        'Location',
        name: 'location',
        desc: 'Label for location',
      );

  String get distance => Intl.message(
        'Distance',
        name: 'distance',
        desc: 'Label for distance',
      );

  String get filter => Intl.message(
        'Filter',
        name: 'filter',
        desc: 'Text for filter action',
      );

  String get applyFilters => Intl.message(
        'Apply Filters',
        name: 'applyFilters',
        desc: 'Text for apply filters button',
      );

  String get miles => Intl.message(
        'Miles',
        name: 'miles',
        desc: 'Unit for miles',
      );

  String get enableLocation => Intl.message(
        'Enable Location',
        name: 'enableLocation',
        desc: 'Action to enable location',
      );

  String get locationAccess => Intl.message(
        'Location Access',
        name: 'locationAccess',
        desc: 'Title for location access dialog',
      );

  String get locationPermissionRequired => Intl.message(
        'Location permission is required to show nearby posts.',
        name: 'locationPermissionRequired',
        desc: 'Message about location permission requirement',
      );

  String get allowLocation => Intl.message(
        'Allow',
        name: 'allowLocation',
        desc: 'Button to allow location access',
      );

  String get notNow => Intl.message(
        'Not Now',
        name: 'notNow',
        desc: 'Button to skip location access for now',
      );

  String get chat => Intl.message(
        'Chat',
        name: 'chat',
        desc: 'Label for chat feature',
      );

  String get meet => Intl.message(
        'Meet',
        name: 'meet',
        desc: 'Action to meet with someone',
      );

  String get decline => Intl.message(
        'Decline',
        name: 'decline',
        desc: 'Action to decline an invitation',
      );

  String get endChat => Intl.message(
        'End Chat',
        name: 'endChat',
        desc: 'Action to end a chat',
      );

  String get typeMessage => Intl.message(
        'Type a message...',
        name: 'typeMessage',
        desc: 'Placeholder for message input',
      );

  String get chatEnded => Intl.message(
        'Chat Ended',
        name: 'chatEnded',
        desc: 'Status that chat has ended',
      );

  String get returnToHome => Intl.message(
        'Return to Home',
        name: 'returnToHome',
        desc: 'Action to return to home screen',
      );

  String get safetyGuidelines => Intl.message(
        'Safety Guidelines',
        name: 'safetyGuidelines',
        desc: 'Title for safety guidelines',
      );

  String get selectLanguage => Intl.message(
        'Select Language',
        name: 'selectLanguage',
        desc: 'Title for language selection',
      );

  String get english => Intl.message(
        'English',
        name: 'english',
        desc: 'Name of English language',
      );

  String get japanese => Intl.message(
        'Japanese',
        name: 'japanese',
        desc: 'Name of Japanese language',
      );

  String get korean => Intl.message(
        'Korean',
        name: 'korean',
        desc: 'Name of Korean language',
      );

  String get spanish => Intl.message(
        'Spanish',
        name: 'spanish',
        desc: 'Name of Spanish language',
      );

  String get french => Intl.message(
        'French',
        name: 'french',
        desc: 'Name of French language',
      );

  String get german => Intl.message(
        'German',
        name: 'german',
        desc: 'Name of German language',
      );

  String get vietnamese => Intl.message(
        'Vietnamese',
        name: 'vietnamese',
        desc: 'Name of Vietnamese language',
      );

  String get languageSettings => Intl.message(
        'Language Settings',
        name: 'languageSettings',
        desc: 'Title for language settings',
      );

  String get currentLanguage => Intl.message(
        'Current Language',
        name: 'currentLanguage',
        desc: 'Label for current language setting',
      );
  
  String get simplifiedChinese => Intl.message(
  'Simplified Chinese',
  name: 'simplifiedChinese',
  desc: 'Name of Simplified Chinese language',
);

  String get traditionalChinese => Intl.message(
    'Traditional Chinese',
    name: 'traditionalChinese',
    desc: 'Name of Traditional Chinese language',
  );
  }

// Now we'll create a LocalizationsDelegate for our AppLocalizations

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

@override
bool isSupported(Locale locale) {
  // Check language code
  if (!['en', 'ja', 'ko', 'es', 'fr', 'de', 'vi', 'zh'].contains(locale.languageCode)) {
    return false;
  }
  
  // For Chinese, check country code
  if (locale.languageCode == 'zh') {
    return ['CN', 'TW'].contains(locale.countryCode);
  }
  
  return true;
}

@override
Future<AppLocalizations> load(Locale locale) {
  // For zh_TW, set locale name explicitly to handle Traditional Chinese
  final String name;
  if (locale.languageCode == 'zh' && locale.countryCode == 'TW') {
    name = 'zh_TW';
  } else {
    name = locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : locale.toString();
  }
  
  final String localeName = Intl.canonicalizedLocale(name);
  return initializeMessages(localeName).then((_) {
    Intl.defaultLocale = localeName;
    return AppLocalizations();
  });
}

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}