const String kAdminWhatsApp = '2250749931142';
const int kTravelFee = 10000;

const reservationStatuses = [
  'En attente',
  'Confirmée',
  'Accomplie',
  'Annulée',
  'Reportée',
];

const paymentStatuses = ['Non soldé', 'Acompte payé', 'Soldé'];

const defaultServices = [
  {'nom': 'Maquillage événement / maquillage simple', 'prixUnitaire': 25000, 'typeQuantite': 'personnes', 'quantityLabel': 'Nombre de personnes'},
  {'nom': 'Maquillage mariée', 'prixUnitaire': 35000, 'typeQuantite': 'personnes', 'quantityLabel': 'Nombre de personnes'},
  {'nom': 'Cours d’auto-maquillage', 'prixUnitaire': 50000, 'typeQuantite': 'session', 'quantityLabel': 'Session'},
  {'nom': 'Conseils beauté coiffure', 'prixUnitaire': 60000, 'typeQuantite': 'personnes', 'quantityLabel': 'Nombre de personnes'},
  {'nom': 'Shooting photo', 'prixUnitaire': 100000, 'typeQuantite': 'photos', 'quantityLabel': 'Nombre de photos'},
  {'nom': 'Studio', 'prixUnitaire': 0, 'typeQuantite': 'session', 'quantityLabel': 'Session'},
];
