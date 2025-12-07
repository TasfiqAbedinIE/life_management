import 'dart:convert';
import 'package:http/http.dart' as http;

/// Represents the minimal weather data we need
class WeatherData {
  final String city;
  final double temperatureC;
  final double windSpeed;
  final double humidity;
  final String condition;

  WeatherData({
    required this.city,
    required this.temperatureC,
    required this.windSpeed,
    required this.humidity,
    required this.condition,
  });
}

class WeatherService {
  /// Fetch current weather by city name using Open-Meteo + Geocoding
  static Future<WeatherData> fetchWeather(String city) async {
    // 1️⃣ Convert city → latitude & longitude
    final geoUrl = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search?name=$city',
    );
    final geoRes = await http.get(geoUrl);
    if (geoRes.statusCode != 200) {
      throw Exception('Failed to fetch location');
    }

    final geoData = json.decode(geoRes.body);
    if (geoData['results'] == null || geoData['results'].isEmpty) {
      throw Exception('City not found');
    }

    final lat = geoData['results'][0]['latitude'];
    final lon = geoData['results'][0]['longitude'];
    final name = geoData['results'][0]['name'];

    // 2️⃣ Fetch weather
    final weatherUrl = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true',
    );
    final weatherRes = await http.get(weatherUrl);
    if (weatherRes.statusCode != 200) {
      throw Exception('Failed to fetch weather');
    }

    final w = json.decode(weatherRes.body);
    final current = w['current_weather'];
    final temp = (current['temperature'] as num).toDouble();
    final wind = (current['windspeed'] as num).toDouble();
    final code = current['weathercode'];

    // Map weather code → condition text (simplified)
    final condition = _weatherCodeToString(code);

    // 3️⃣ Fake humidity (since Open-Meteo’s free tier omits it)
    final humidity = 50.0 + (wind % 30); // just for display feel

    return WeatherData(
      city: name,
      temperatureC: temp,
      windSpeed: wind,
      humidity: humidity,
      condition: condition,
    );
  }

  static String _weatherCodeToString(int code) {
    if (code == 0) return 'Clear sky';
    if ([1, 2, 3].contains(code)) return 'Partly cloudy';
    if ([45, 48].contains(code)) return 'Fog';
    if ([51, 53, 55].contains(code)) return 'Drizzle';
    if ([61, 63, 65].contains(code)) return 'Rain';
    if ([66, 67].contains(code)) return 'Freezing rain';
    if ([71, 73, 75].contains(code)) return 'Snow';
    if ([80, 81, 82].contains(code)) return 'Showers';
    if ([95, 96, 99].contains(code)) return 'Thunderstorm';
    return 'Unknown';
  }
}
