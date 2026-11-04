/// Remote endpoints used by the app.
/// Availability, authorization requirements and permitted use must be verified.
class ApiConfig {
  static const beenarBase = 'https://beenar.net';
  static const kurdfilmBase = 'https://app.kurdfilm.krd/api';
  static const opticTvBase = 'https://api.optictv.cloud';
  static const tmdbBase = 'https://api.themoviedb.org/3';

  static const firebaseDatabase =
      'https://kobani-4k-default-rtdb.europe-west1.firebasedatabase.app';

  static const beenarMovies = '/api/client/movie';
  static const beenarShows = '/api/client/title-show/';
  static const kurdfilmMovies = '/movies/';
  static const kurdfilmTitles = '/titles';

  // Do not place Service Account private keys or activation secrets here.
}
