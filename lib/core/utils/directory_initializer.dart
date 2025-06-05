import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

/// A utility class that ensures all required application directories
/// are created and accessible on app startup
class DirectoryInitializer {
  static final Logger _logger = Logger();
  
  /// Initialize all required directories for the app
  static Future<void> initializeAppDirectories() async {
    try {
      // Get application documents directory
      final appDocDir = await getApplicationDocumentsDirectory();
      
      // Create common directories
      final directories = [
        'cache',
        'data',
        'temp',
        'downloads',
        'logs',
      ];
      
      // Ensure each directory exists
      for (final dir in directories) {
        final dirPath = '${appDocDir.path}/$dir';
        final directory = Directory(dirPath);
        
        if (!await directory.exists()) {
          await directory.create(recursive: true);
          _logger.d('Created directory: $dirPath');
        }
      }
      
      // Create a file to test file system access
      final testFilePath = '${appDocDir.path}/data/test_access.txt';
      final testFile = File(testFilePath);
      await testFile.writeAsString('File system access test ${DateTime.now()}');
      
      _logger.d('Application directories initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize application directories: $e');
    }
  }
} 