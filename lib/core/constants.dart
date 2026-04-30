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
  'landing': {
    'primaryCtaLetterSpacing': 0.5,
    'secondaryCtaLetterSpacing': 1.0,
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
