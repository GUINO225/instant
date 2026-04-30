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
    'backgroundImage': 'assets/img/BG1.png', // Image de fond de l'écran d'accueil.
    'logoImage': 'assets/img/LOGO.png', // Logo affiché au centre de la page.
    'backgroundFit': BoxFit.cover, // Ajustement de l'image de fond pour couvrir tout l'écran.
    'overlayTopOpacity': 0.20, // Opacité du dégradé dans la zone haute.
    'overlayMiddleOpacity': 0.55, // Opacité du dégradé dans la zone centrale.
    'overlayBottomOpacity': 0.92, // Opacité du dégradé dans la zone basse.
    'overlayStops': [0.0, 0.52, 1.0], // Positions des points du dégradé vertical.
    'paddingLeft': 26.0, // Marge intérieure à gauche de la page.
    'paddingTop': 16.0, // Marge intérieure en haut de la page.
    'paddingRight': 26.0, // Marge intérieure à droite de la page.
    'paddingBottom': 22.0, // Marge intérieure en bas de la page.
    'topSpacerFlex': 6, // Espace flexible avant le bloc principal.
    'middleSpacerFlex': 3, // Espace flexible entre logo et actions.
    'bottomSpacerFlex': 1, // Espace flexible sous les boutons.
    'logoWidth': 240.0, // Largeur fixe du logo.
    'taglineFontSize': 24.0, // Taille du texte d'accroche.
    'taglineLineHeight': 1.34, // Hauteur de ligne du texte d'accroche.
    'taglineWeight': FontWeight.w400, // Graisse du texte d'accroche.
    'ctaVerticalGap': 40.0, // Espace vertical avant le bouton principal.
    'buttonHeight': 72.0, // Hauteur des boutons d'action.
    'buttonRadius': 16.0, // Rayon des coins des boutons.
    'primaryCtaFontSize': 22.0, // Taille de police du bouton principal.
    'primaryCtaLetterSpacing': 0.5, // Espacement des lettres du bouton principal.
    'primaryCtaWeight': FontWeight.w500, // Graisse du texte du bouton principal.
    'primaryCtaIconSize': 46.0, // Taille de l'icône dans le bouton principal.
    'primaryCtaIconGap': 6.0, // Espace entre le texte et l'icône du bouton principal.
    'betweenButtonsGap': 18.0, // Espace vertical entre les deux boutons.
    'secondaryCtaFontSize': 20.0, // Taille de police du bouton secondaire.
    'secondaryCtaLetterSpacing': 1.0, // Espacement des lettres du bouton secondaire.
    'secondaryCtaWeight': FontWeight.w500, // Graisse du texte du bouton secondaire.
    'secondaryBorderOpacity': 0.68, // Opacité de la bordure du bouton secondaire.
    'secondaryBorderWidth': 2.0, // Épaisseur de la bordure du bouton secondaire.
    'indicatorSize': 28.0, // Taille des indicateurs (points/pastilles).
    'indicatorGap': 18.0, // Espace entre les indicateurs.
    'indicatorBorderWidth': 2.2, // Épaisseur de bordure des indicateurs.
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
