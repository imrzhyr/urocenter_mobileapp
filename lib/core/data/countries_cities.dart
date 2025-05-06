/// Sample data for countries and their cities.
/// In a real app, this might come from an API or a more extensive local database.

const String defaultCountry = 'Iraq';
const String defaultCity = 'Baghdad';

const Map<String, List<String>> cityData = {
  'Iraq': [
    'Baghdad',
    'Mosul',
    'Basra',
    'Erbil',
    'Kirkuk',
    'Sulaymaniyah',
    'Najaf',
    'Karbala',
    'Nasiriyah',
    'Amara',
    'Diwaniyah',
    'Kut',
    'Hilla',
    'Ramadi',
    'Fallujah',
    'Samarra',
    'Baqubah',
    'Dohuk',
    'Zakho',
    'Tikrit',
    // Add more Iraqi cities as needed
  ],
  'Egypt': [
    'Cairo',
    'Alexandria',
    'Giza',
    'Shubra El Kheima',
    'Port Said',
    'Suez',
    'Luxor',
    'Mansoura',
    'Tanta',
    'Asyut',
    'Ismailia',
    'Faiyum',
    'Zagazig',
    'Aswan',
    'Damietta',
    // Add more Egyptian cities as needed
  ],
  'Saudi Arabia': [
    'Riyadh',
    'Jeddah',
    'Mecca',
    'Medina',
    'Dammam',
    'Taif',
    'Khobar',
    'Tabuk',
    'Buraidah',
    'Khamis Mushait',
    'Abha',
    'Hail',
    'Najran',
    'Jubail',
    'Yanbu',
    // Add more Saudi cities as needed
  ],
  'United Arab Emirates': [
    'Dubai',
    'Abu Dhabi',
    'Sharjah',
    'Al Ain',
    'Ajman',
    'Ras Al Khaimah',
    'Fujairah',
    'Umm Al Quwain',
    // Add more UAE cities as needed
  ],
  'Jordan': [
    'Amman',
    'Zarqa',
    'Irbid',
    'Russeifa',
    'Sahab',
    'Aqaba',
    'Madaba',
    'Salt',
    'Mafraq',
    'Jerash',
    // Add more Jordanian cities as needed
  ],
};

// Alias for countryData to match usage in profile setup screen
const Map<String, List<String>> countryData = cityData; 