import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vyra_tv/services/movies_service.dart';

void main() {
  group('MoviesService series support', () {
    test('loads movie and series catalog entries independently', () async {
      final client = MockClient((request) async {
        final kind = request.url.queryParameters['kind'];
        if (request.url.host == 'app.kurdfilm.krd' && kind == 'movie') {
          return http.Response(jsonEncode({
            'data': [
              {'id': 'movie-1', 'title': 'Demo Movie', 'type': 'movie'},
            ],
          }), 200);
        }
        if (request.url.host == 'app.kurdfilm.krd' && kind == 'series') {
          return http.Response(jsonEncode({
            'data': [
              {'id': 'show-1', 'title': 'Demo Series', 'type': 'series'},
            ],
          }), 200);
        }
        if (request.url.host == 'www.movieskurdish.com') {
          return http.Response(jsonEncode({'feed': {'entry': []}}), 200);
        }
        return http.Response('{}', 404);
      });
      final service = MoviesService(client: client);
      final items = await service.fetchMovies();
      expect(items.map((item) => item.id), containsAll(['movie-1', 'show-1']));
      expect(items.firstWhere((item) => item.id == 'show-1').kind, 'series');
      service.close();
    });

    test('parses season episodes and their provider-returned servers', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/movies/show-1') {
          return http.Response('{}', 404);
        }
        if (request.url.path == '/api/titles/show-1') {
          return http.Response(jsonEncode({
            'data': {
              'id': 'show-1',
              'title': 'Demo Series',
              'seasons': [
                {
                  'season_number': 1,
                  'name': 'Season 1',
                  'episodes': [
                    {
                      'episode_number': 1,
                      'title': 'Pilot',
                      'servers': [
                        {'name': 'Primary', 'url': 'https://cdn.example/episode.m3u8'},
                      ],
                    },
                  ],
                },
              ],
            },
          }), 200);
        }
        return http.Response('{}', 404);
      });
      final service = MoviesService(client: client);
      const show = MovieItem(id: 'show-1', title: 'Demo Series', provider: 'KURDFILM', kind: 'series');
      final details = await service.fetchKurdfilmDetails(show);
      expect(details, isNotNull);
      expect(details!.seasons, hasLength(1));
      expect(details.seasons.first.episodes, hasLength(1));
      expect(details.seasons.first.episodes.first.servers.single.url, 'https://cdn.example/episode.m3u8');
      service.close();
    });
  });
}
