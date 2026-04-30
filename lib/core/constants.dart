import 'package:flutter/material.dart';

const String kAdminWhatsApp = '2250749931142';

/// Tous les textes visibles dans l'application sont regroupés ici
/// pour faciliter la personnalisation par écran.
const screenTextConfig = {
  'landing': {
    'tagline': 'Réservez votre beauté\nen quelque clics',
    'primaryCta': 'COMMENCER',
    'secondaryCta': 'SE CONNECTER',
    'commentLabel': 'Commentaire',
  },
  'clientDashboard': {
    'title': 'Espace cliente',
    'logout': 'Déconnexion',
    'tabHome': 'Accueil',
    'tabBook': 'Réserver',
    'tabBookings': 'Mes réservations',
    'welcome': 'Bienvenue',
  },
};

const screenStyleConfig = {
  // PAGE: LandingPage (lib/main.dart)
  'landing': {
    'backgroundImage': 'assets/img/BG1.png',
    'logoImage': 'assets/img/LOGO.png',
    'backgroundFit': BoxFit.cover,
    'overlayTopOpacity': 0.20,
    'overlayMiddleOpacity': 0.55,
    'overlayBottomOpacity': 0.92,
    'overlayStops': [0.0, 0.52, 1.0],
    'paddingLeft': 26.0,
    'paddingTop': 16.0,
    'paddingRight': 26.0,
    'paddingBottom': 22.0,
    'topSpacerFlex': 6,
    'middleSpacerFlex': 3,
    'bottomSpacerFlex': 1,
    'logoWidth': 240.0,
    'taglineFontSize': 24.0,
    'taglineLineHeight': 1.34,
    'taglineWeight': FontWeight.w400,
    'ctaVerticalGap': 40.0,
    'buttonHeight': 72.0,
    'buttonRadius': 16.0,
    'primaryCtaFontSize': 22.0,
    'primaryCtaLetterSpacing': 0.5,
    'primaryCtaWeight': FontWeight.w500,
    'primaryCtaIconSize': 46.0,
    'primaryCtaIconGap': 6.0,
    'betweenButtonsGap': 18.0,
    'secondaryCtaFontSize': 20.0,
    'secondaryCtaLetterSpacing': 1.0,
    'secondaryCtaWeight': FontWeight.w500,
    'secondaryBorderOpacity': 0.68,
    'secondaryBorderWidth': 2.0,
    'indicatorSize': 28.0,
    'indicatorGap': 18.0,
    'indicatorBorderWidth': 2.2,
  },
};

const reservationStatuses = [
  'En attente',
  'Confirmée',
  'Accomplie',
  'Annulée',
  'Reportée',
];

const paymentStatuses = ['Non soldé', 'Acompte payé', 'Soldé'];

const serviceTypeLabels = {
  'personne': 'par personne',
  'photo': 'par photo',
  'session': 'par session',
  'fixe': 'fixe',
};
