import 'package:flutter/material.dart';
import 'package:monitoring/core/constants/app_constant.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'data/datasources/sensor_remote_data_source.dart';
import 'data/repositories/sensor_repository_impl.dart';
import 'domain/repositories/sensor_repository.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/providers/sensor_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load .env file
    await dotenv.load(fileName: '.env');
    
    // Debug environment variables
    final envVars = dotenv.env;
 
    // Validate environment variables
    _validateEnvironmentVariables();
    
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
    
    runApp(const MyApp());
    
  } catch (e) {
    runApp(ConfigurationErrorApp(error: e.toString()));
  }
}

void _validateEnvironmentVariables() {
  final url = AppConstants.supabaseUrl;
  final key = AppConstants.supabaseAnonKey;
  
  if (url.isEmpty || key.isEmpty) {
    throw Exception('Environment variables not loaded properly');
  }
}

class ConfigurationErrorApp extends StatelessWidget {
  final String error;
  
  const ConfigurationErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Configuration Error - Monitoring App',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please check your .env file:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• .env file exists in project root\n'
                  '• SUPABASE_URL and SUPABASE_ANON_KEY are set\n'
                  '• Values are correct (no placeholder text)\n'
                  '• File format is correct (no quotes, no spaces)',
                  style: TextStyle(fontSize: 12),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SensorRemoteDataSource>(
          create: (_) => SensorRemoteDataSource(),
        ),
        Provider<SensorRepository>(
          create: (context) => SensorRepositoryImpl(
            context.read<SensorRemoteDataSource>(),
          ),
        ),
        ChangeNotifierProvider<SensorProvider>(
          create: (context) => SensorProvider(
            context.read<SensorRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const HomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}