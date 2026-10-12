// Sample /trip-plan responses, same shape as backend trip_models.py.

Map<String, dynamic> stopJson(String id, String name, double lng, double lat) => {
      'id': id,
      'name': name,
      'sequence': 1,
      'location': {
        'type': 'Point',
        'coordinates': [lng, lat],
      },
      'route_ids': ['r1'],
      'landmark': null,
    };

/// Two legs, one transfer. First board stop is the backend stub's
/// placeholder ("0" at [0, 0]). Second leg fare is an int on purpose.
Map<String, dynamic> sampleResponse() => {
      'options': [
        {
          'rank': 1,
          'total_eta_min': 25,
          'total_fare': 28.0,
          'transfers': 1,
          'legs': [
            {
              'route_id': 'r1',
              'route_name': '01K',
              'board_stop': stopJson('0', 'Origin', 0, 0),
              'alight_stop': stopJson('s2', 'Colon', 123.9, 10.29),
              'eta_min': 10,
              'fare': 13.0,
            },
            {
              'route_id': 'r2',
              'route_name': '13C',
              'board_stop': stopJson('s2', 'Colon', 123.9, 10.29),
              'alight_stop': stopJson('s3', 'IT Park', 123.905, 10.33),
              'eta_min': 15,
              'fare': 15,
            },
          ],
        },
      ],
      'generated_at': '2026-10-01T08:00:00.123456',
    };

Map<String, dynamic> emptyResponse() => {
      'options': <dynamic>[],
      'generated_at': '2026-10-01T08:00:00',
    };

/// Recommender-style response: one direct option on [routeId], boarding at
/// [boardId], with the walking / live-wait fields the recommender adds.
Map<String, dynamic> recommenderResponse({
  String routeId = 'r1',
  String boardId = 'b1',
  String boardName = 'Capitol',
  int waitMin = 4,
  bool live = true,
}) =>
    {
      'options': [
        {
          'rank': 1,
          'total_eta_min': 20,
          'total_fare': 13.0,
          'transfers': 0,
          'total_walk_m': 180,
          'walk_from_alight_m': 60,
          'walk_from_alight_min': 1,
          'legs': [
            {
              'route_id': routeId,
              'route_name': 'Banawa - Carbon',
              'route_code': '07B',
              'board_stop': stopJson(boardId, boardName, 123.89, 10.316),
              'alight_stop': stopJson('a1', 'CNU', 123.896, 10.301),
              'eta_min': waitMin + 8,
              'fare': 13.0,
              'walk_to_board_m': 120,
              'walk_to_board_min': 2,
              'wait_min': waitMin,
              'wait_is_live': live,
              'next_vehicle_id': live ? 'v1' : null,
              'ride_km': 1.93,
              'ride_min': 8,
              'path': {
                'type': 'LineString',
                'coordinates': [
                  [123.89, 10.316],
                  [123.893, 10.31],
                  [123.896, 10.301],
                ],
              },
            },
          ],
        },
      ],
      'generated_at': '2026-10-12T08:00:00',
    };
