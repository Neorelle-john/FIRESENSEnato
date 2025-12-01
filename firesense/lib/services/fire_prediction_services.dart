import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firesense/services/notification_service.dart';

/// Service for loading TensorFlow Lite model and making fire predictions
/// based on sensor data from Firebase Realtime Database.
///
/// IMPORTANT: This service ONLY READS from RTDB, it NEVER WRITES to RTDB.
/// All predictions are stored in Firestore only.
///
/// Usage example:
/// ```dart
/// final service = FirePredictionService();
/// await service.loadModel();
///
/// // Make prediction for Arduino device (Device3)
/// final result = await service.predict('Device3');
/// if (result != null) {
///   print('Prediction: ${result['label']} (confidence: ${result['confidence']})');
/// }
/// ```
class FirePredictionService {
  static final FirePredictionService _instance =
      FirePredictionService._internal();
  factory FirePredictionService() => _instance;
  FirePredictionService._internal();

  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  // Real-time listening
  StreamSubscription<DatabaseEvent>? _realtimeListener;
  Map<String, StreamSubscription<DatabaseEvent>> _deviceListeners = {};
  bool _isListening = false;
  Timer? _debounceTimer;

  // Store last known sensor values to handle partial updates
  Map<String, double?> _lastSensorValues = {
    'mq2': null,
    'mq9': null,
    'flame': null,
  };

  // Store previous alarmType per device to avoid duplicate notifications
  Map<String, String?> _previousAlarmTypes = {};

  // Debounce delay to prevent too many predictions (in milliseconds)
  static const Duration _predictionDebounceDelay = Duration(seconds: 2);

  // Scaler parameters from training (StandardScaler)
  // TODO: Replace these with actual values from your training data
  // You can get these by running: scaler.mean_ and scaler.scale_ in Python
  // after training your model
  // Example Python code to get these values:
  // import joblib
  // scaler = joblib.load("scaler.pkl")
  // print("Mean:", scaler.mean_.tolist())
  // print("Std:", scaler.scale_.tolist())
  List<double> _scalerMean = [
    1011.9789915966387,
    1195.7100840336134,
    2018.2016806722688,
  ];
  List<double> _scalerStd = [
    142.39232840605948,
    218.74225072274777,
    1145.5250169101166,
  ];

  // Label mapping (from LabelEncoder)
  // TODO: Replace with actual labels from your training
  // You can get these by running: encoder.classes_ in Python
  // Example Python code to get these values:
  // import joblib
  // encoder = joblib.load("label_encoder.pkl")
  // print("Classes:", encoder.classes_.tolist())
  List<String> _labelClasses = ['fire', 'normal', 'smoke'];

  /// Load the TensorFlow Lite model from assets
  Future<bool> loadModel() async {
    if (_isModelLoaded && _interpreter != null) {
      print('Fire Prediction Service: Model already loaded');
      return true;
    }

    try {
      print('Fire Prediction Service: Loading model from assets...');
      // Load model from assets
      final modelPath = 'assets/models/fire_model.tflite';
      _interpreter = await Interpreter.fromAsset(modelPath);

      // Print model input/output details
      print('Fire Prediction Service: Model loaded successfully');
      print('Input tensor count: ${_interpreter!.getInputTensors().length}');
      print('Output tensor count: ${_interpreter!.getOutputTensors().length}');

      for (var i = 0; i < _interpreter!.getInputTensors().length; i++) {
        final inputTensor = _interpreter!.getInputTensors()[i];
        print('Input $i: shape=${inputTensor.shape}, type=${inputTensor.type}');
      }

      for (var i = 0; i < _interpreter!.getOutputTensors().length; i++) {
        final outputTensor = _interpreter!.getOutputTensors()[i];
        print(
          'Output $i: shape=${outputTensor.shape}, type=${outputTensor.type}',
        );
      }

      _isModelLoaded = true;
      return true;
    } catch (e, stackTrace) {
      print('Fire Prediction Service: Error loading model: $e');
      print('Stack trace: $stackTrace');
      _isModelLoaded = false;
      _interpreter = null;
      return false;
    }
  }

  /// Get sensor data from Firebase Realtime Database for a specific device
  ///
  /// The Arduino uploads sensor data to Devices/{deviceId} in RTDB.
  /// For example, if deviceId is "Device3", it reads from Devices/Device3.
  /// Expected sensor fields: mq2, mq9, flame (case-insensitive)
  ///
  /// NOTE: This method ONLY READS from RTDB, it does not write.
  Future<Map<String, double>?> getSensorData(String deviceId) async {
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final snapshot = await dbRef.child('Devices/$deviceId').get();

      if (!snapshot.exists) {
        print('Fire Prediction Service: Device $deviceId not found in RTDB');
        return null;
      }

      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) {
        print('Fire Prediction Service: No data for device $deviceId');
        return null;
      }

      // Extract sensor values (mq2, mq9, flame)
      // Note: Firebase uses capitalized field names: MQ2, MQ9, Flame
      final mq2 = _parseDouble(data['MQ2'] ?? data['mq2']);
      final mq9 = _parseDouble(data['MQ9'] ?? data['mq9']);
      final flame = _parseDouble(data['Flame'] ?? data['flame']);

      if (mq2 == null || mq9 == null || flame == null) {
        print(
          'Fire Prediction Service: Missing sensor data for device $deviceId',
        );
        print('Available keys: ${data.keys.toList()}');
        return null;
      }

      return {'mq2': mq2, 'mq9': mq9, 'flame': flame};
    } catch (e, stackTrace) {
      print('Fire Prediction Service: Error fetching sensor data: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Parse a value to double, handling various types
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  /// Scale sensor data using StandardScaler parameters
  /// Formula: (x - mean) / std
  List<double> _scaleSensorData(Map<String, double> sensorData) {
    final mq2 = sensorData['mq2']!;
    final mq9 = sensorData['mq9']!;
    final flame = sensorData['flame']!;

    return [
      (mq2 - _scalerMean[0]) / _scalerStd[0],
      (mq9 - _scalerMean[1]) / _scalerStd[1],
      (flame - _scalerMean[2]) / _scalerStd[2],
    ];
  }

  /// Make a prediction using the loaded model
  /// Returns a map with 'label' (predicted class) and 'confidence' (probability)
  Future<Map<String, dynamic>?> predict(String deviceId) async {
    if (!_isModelLoaded || _interpreter == null) {
      print('Fire Prediction Service: Model not loaded. Loading now...');
      final loaded = await loadModel();
      if (!loaded) {
        print('Fire Prediction Service: Failed to load model');
        return null;
      }
    }

    // Get sensor data from Firebase
    final sensorData = await getSensorData(deviceId);
    if (sensorData == null) {
      print('Fire Prediction Service: Could not fetch sensor data');
      return null;
    }

    try {
      // Scale the sensor data
      final scaledData = _scaleSensorData(sensorData);
      print('Fire Prediction Service: Raw sensor data: $sensorData');
      print('Fire Prediction Service: Scaled data: $scaledData');

      // Prepare input tensor
      // Model expects shape [1, 3] for batch of 1 sample with 3 features
      final input = [scaledData];

      // Prepare output tensor - must match the model's output shape
      final outputTensor = _interpreter!.getOutputTensors()[0];
      final outputShape = outputTensor.shape;
      print('Fire Prediction Service: Output tensor shape: $outputShape');

      // Create output buffer matching the exact shape
      // For shape [1, 3], we need [[0.0, 0.0, 0.0]]
      final output = _createOutputBuffer(outputShape);

      // Run inference
      _interpreter!.run(input, output);
      print('Fire Prediction Service: Model output: $output');

      // Extract probabilities from output (handle nested structure)
      final probabilities = _extractProbabilities(output, outputShape);

      double maxProb = probabilities[0];
      int predictedIndex = 0;
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          predictedIndex = i;
        }
      }

      // Map index to label
      final predictedLabel =
          predictedIndex < _labelClasses.length
              ? _labelClasses[predictedIndex]
              : 'unknown';

      return {
        'label': predictedLabel,
        'confidence': maxProb,
        'probabilities': probabilities,
        'sensorData': sensorData,
      };
    } catch (e, stackTrace) {
      print('Fire Prediction Service: Error during prediction: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Make a prediction with raw sensor values (for testing)
  Future<Map<String, dynamic>?> predictWithValues(
    double mq2,
    double mq9,
    double flame,
  ) async {
    if (!_isModelLoaded || _interpreter == null) {
      print('Fire Prediction Service: Model not loaded. Loading now...');
      final loaded = await loadModel();
      if (!loaded) {
        print('Fire Prediction Service: Failed to load model');
        return null;
      }
    }

    try {
      // Scale the sensor data
      final sensorData = {'mq2': mq2, 'mq9': mq9, 'flame': flame};
      final scaledData = _scaleSensorData(sensorData);
      print('Fire Prediction Service: Raw sensor data: $sensorData');
      print('Fire Prediction Service: Scaled data: $scaledData');

      // Prepare input tensor
      final input = [scaledData];

      // Prepare output tensor - must match the model's output shape
      final outputTensor = _interpreter!.getOutputTensors()[0];
      final outputShape = outputTensor.shape;
      print('Fire Prediction Service: Output tensor shape: $outputShape');

      // Create output buffer matching the exact shape
      // For shape [1, 3], we need [[0.0, 0.0, 0.0]]
      final output = _createOutputBuffer(outputShape);

      // Run inference
      _interpreter!.run(input, output);
      print('Fire Prediction Service: Model output: $output');

      // Extract probabilities from output (handle nested structure)
      final probabilities = _extractProbabilities(output, outputShape);

      double maxProb = probabilities[0];
      int predictedIndex = 0;
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          predictedIndex = i;
        }
      }

      // Map index to label
      final predictedLabel =
          predictedIndex < _labelClasses.length
              ? _labelClasses[predictedIndex]
              : 'unknown';

      return {
        'label': predictedLabel,
        'confidence': maxProb,
        'probabilities': probabilities,
        'sensorData': sensorData,
      };
    } catch (e, stackTrace) {
      print('Fire Prediction Service: Error during prediction: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Update scaler parameters (mean and std for each feature)
  /// Call this after getting the actual values from your training
  ///
  /// Example Python code to get these values:
  /// import joblib
  /// scaler = joblib.load("scaler.pkl")
  /// mean = scaler.mean_.tolist() # [mq2_mean, mq9_mean, flame_mean]
  /// std = scaler.scale_.tolist() # [mq2_std, mq9_std, flame_std]
  void updateScalerParams({
    required List<double> mean,
    required List<double> std,
  }) {
    if (mean.length != 3 || std.length != 3) {
      throw ArgumentError('Mean and std must have exactly 3 values');
    }

    _scalerMean = List<double>.from(mean);
    _scalerStd = List<double>.from(std);

    print('Fire Prediction Service: Scaler params updated');
    print('Mean: $_scalerMean');
    print('Std: $_scalerStd');
  }

  /// Update label classes
  ///
  /// Example Python code to get these values:
  /// import joblib
  /// encoder = joblib.load("label_encoder.pkl")
  /// labels = encoder.classes_.tolist() # ['normal', 'fire', ...]
  void updateLabelClasses(List<String> labels) {
    if (labels.isEmpty) {
      throw ArgumentError('Labels list cannot be empty');
    }

    _labelClasses = List<String>.from(labels);
    print('Fire Prediction Service: Label classes updated');
    print('Labels: $_labelClasses');
  }

  /// Create output buffer matching the model's output tensor shape
  /// For shape [1, 3], creates [[0.0, 0.0, 0.0]]
  dynamic _createOutputBuffer(List<int> shape) {
    if (shape.isEmpty) {
      return <double>[];
    }

    if (shape.length == 1) {
      // Shape is [num_classes], return flat list
      return List.generate(shape[0], (index) => 0.0);
    } else if (shape.length == 2) {
      // Shape is [batch_size, num_classes], return nested list
      return List.generate(
        shape[0],
        (i) => List.generate(shape[1], (j) => 0.0),
      );
    } else {
      // For higher dimensions, create nested structure recursively
      return _createNestedBuffer(shape, 0);
    }
  }

  /// Recursively create nested buffer for multi-dimensional shapes
  dynamic _createNestedBuffer(List<int> shape, int index) {
    if (index == shape.length - 1) {
      return List.generate(shape[index], (i) => 0.0);
    } else {
      return List.generate(
        shape[index],
        (i) => _createNestedBuffer(shape, index + 1),
      );
    }
  }

  /// Extract probabilities from output based on tensor shape
  /// Handles both flat lists and nested structures
  List<double> _extractProbabilities(dynamic output, List<int> shape) {
    if (output == null) {
      throw ArgumentError('Output cannot be null');
    }

    if (shape.isEmpty) {
      if (output is List<double>) {
        return output;
      }
      throw ArgumentError('Invalid output format for empty shape');
    }

    if (shape.length == 1) {
      // Shape is [num_classes], output should be List<double>
      if (output is List<double>) {
        return output;
      }
      throw ArgumentError('Expected List<double> for shape $shape');
    } else if (shape.length == 2) {
      // Shape is [batch_size, num_classes]
      // Output should be List<List<double>>, we want the first batch
      if (output is List && output.isNotEmpty) {
        final firstBatch = output[0];
        if (firstBatch is List<double>) {
          return firstBatch;
        } else if (firstBatch is List) {
          // Convert to List<double>
          return firstBatch.map((e) => (e as num).toDouble()).toList();
        }
      }
      throw ArgumentError('Expected List<List<double>> for shape $shape');
    } else {
      // For higher dimensions, extract first element recursively
      dynamic current = output;
      for (int i = 0; i < shape.length - 1; i++) {
        if (current is List && current.isNotEmpty) {
          current = current[0];
        } else {
          throw ArgumentError('Cannot extract probabilities from shape $shape');
        }
      }

      if (current is List<double>) {
        return current;
      } else if (current is List) {
        return current.map((e) => (e as num).toDouble()).toList();
      }
      throw ArgumentError('Invalid output format for shape $shape');
    }
  }

  /// Print prediction results in a formatted, readable way
  void printPrediction(Map<String, dynamic>? result) {
    if (result == null) {
      print('═══════════════════════════════════════════════════════');
      print('🔥 FIRE PREDICTION SERVICE - RESULT');
      print('═══════════════════════════════════════════════════════');
      print('❌ Prediction failed - No result returned');
      print('═══════════════════════════════════════════════════════');
      return;
    }

    final label = result['label'] as String;
    final confidence = result['confidence'] as double;
    final probabilities = result['probabilities'] as List<double>;
    final sensorData = result['sensorData'] as Map<String, double>;

    print('\n═══════════════════════════════════════════════════════');
    print('🔥 FIRE PREDICTION SERVICE - RESULT');
    print('═══════════════════════════════════════════════════════');
    print('📊 SENSOR DATA:');
    print(' MQ2: ${sensorData['mq2']?.toStringAsFixed(2) ?? 'N/A'}');
    print(' MQ9: ${sensorData['mq9']?.toStringAsFixed(2) ?? 'N/A'}');
    print(' Flame: ${sensorData['flame']?.toStringAsFixed(2) ?? 'N/A'}');
    print('');
    print('🎯 PREDICTION:');
    print(' Label: $label');
    print(' Confidence: ${(confidence * 100).toStringAsFixed(2)}%');
    print('');
    print('📈 ALL PROBABILITIES:');
    for (int i = 0; i < probabilities.length; i++) {
      final classLabel =
          i < _labelClasses.length ? _labelClasses[i] : 'Class $i';
      final prob = probabilities[i];
      final percentage = (prob * 100).toStringAsFixed(2);
      final bar = '█' * ((prob * 50).round());
      print(' ${classLabel.padRight(12)}: ${percentage.padLeft(6)}% $bar');
    }
    print('═══════════════════════════════════════════════════════\n');
  }

  /// Test the model with specific sensor values and print results
  /// This is a convenience method for testing
  ///
  /// Example:
  /// ```dart
  /// await FirePredictionService().testPrediction(
  ///   mq2: 974.0,
  ///   mq9: 1100.0,
  ///   flame: 3200.0,
  /// );
  /// ```
  Future<void> testPrediction({
    required double mq2,
    required double mq9,
    required double flame,
  }) async {
    print('\n🧪 TESTING FIRE PREDICTION MODEL');
    print('═══════════════════════════════════════════════════════');
    print('Loading model and making prediction...\n');

    // Load model if not already loaded
    if (!_isModelLoaded || _interpreter == null) {
      final loaded = await loadModel();
      if (!loaded) {
        print('❌ Failed to load model');
        return;
      }
    }

    // Make prediction
    final result = await predictWithValues(mq2, mq9, flame);

    // Print results
    printPrediction(result);
  }

  /// Test prediction for a specific device from Firebase RTDB
  /// and print results
  ///
  /// Example:
  /// ```dart
  /// await FirePredictionService().testDevicePrediction('Device3');
  /// ```
  Future<void> testDevicePrediction(String deviceId) async {
    print('\n🧪 TESTING FIRE PREDICTION FOR DEVICE: $deviceId');
    print('═══════════════════════════════════════════════════════');
    print('Loading model and fetching sensor data...\n');

    // Load model if not already loaded
    if (!_isModelLoaded || _interpreter == null) {
      final loaded = await loadModel();
      if (!loaded) {
        print('❌ Failed to load model');
        return;
      }
    }

    // Make prediction
    final result = await predict(deviceId);

    // Print results
    printPrediction(result);
  }

  /// Start listening to Firebase RTDB in real-time for a device
  /// and automatically run predictions when sensor data changes
  ///
  /// This will listen to Devices/{deviceId} and whenever sensor data
  /// (mq2, mq9, flame) changes, it will automatically run a prediction
  /// and print the results.
  ///
  /// NOTE: This method ONLY READS from RTDB (listens to changes),
  /// it does not write to RTDB. All predictions are saved to Firestore.
  ///
  /// Example:
  /// ```dart
  /// await FirePredictionService().startRealtimePrediction('Device3');
  /// ```
  Future<void> startRealtimePrediction(String deviceId) async {
    // Stop any existing listener
    stopRealtimePrediction();

    print('\n🔴 STARTING REAL-TIME PREDICTION LISTENER');
    print('═══════════════════════════════════════════════════════');
    print('Device: $deviceId');
    print('Listening to: Devices/$deviceId');
    print('Timestamp: ${DateTime.now()}\n');

    // Load model if not already loaded
    if (!_isModelLoaded || _interpreter == null) {
      print('📦 Loading TensorFlow Lite model...');
      final loaded = await loadModel();
      if (!loaded) {
        print('❌ Failed to load model. Cannot start real-time prediction.');
        print(' Please check if assets/models/fire_model.tflite exists');
        return;
      }
      print('✅ Model loaded successfully\n');
    } else {
      print('✅ Model already loaded\n');
    }

    final dbRef = FirebaseDatabase.instance.ref();

    // Reset last known values when starting new listener
    _lastSensorValues = {'mq2': null, 'mq9': null, 'flame': null};

    // Set up real-time listener
    _realtimeListener = dbRef
        .child('Devices/$deviceId')
        .onValue
        .listen(
          (event) async {
            print(
              '📡 Real-time Prediction: Data change detected for $deviceId',
            );

            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data == null) {
              print('⚠️ Real-time Prediction: No data for device $deviceId');
              return;
            }

            print(
              '📊 Real-time Prediction: Available keys: ${data.keys.toList()}',
            );

            // Extract sensor values (update last known values)
            // Note: Firebase uses capitalized field names: MQ2, MQ9, Flame
            final mq2 = _parseDouble(data['MQ2'] ?? data['mq2']);
            final mq9 = _parseDouble(data['MQ9'] ?? data['mq9']);
            final flame = _parseDouble(data['Flame'] ?? data['flame']);

            print(
              '🔍 Real-time Prediction: Extracted values - '
              'MQ2: ${mq2?.toStringAsFixed(1) ?? "null"}, '
              'MQ9: ${mq9?.toStringAsFixed(1) ?? "null"}, '
              'Flame: ${flame?.toStringAsFixed(1) ?? "null"}',
            );

            // Update last known values (keep previous if new value is null)
            if (mq2 != null) _lastSensorValues['mq2'] = mq2;
            if (mq9 != null) _lastSensorValues['mq9'] = mq9;
            if (flame != null) _lastSensorValues['flame'] = flame;

            // Get the latest values (use stored values if current update is partial)
            final latestMq2 = mq2 ?? _lastSensorValues['mq2'];
            final latestMq9 = mq9 ?? _lastSensorValues['mq9'];
            final latestFlame = flame ?? _lastSensorValues['flame'];

            // Check if we have all required sensor values
            if (latestMq2 == null || latestMq9 == null || latestFlame == null) {
              // Partial update - wait for more data
              print(
                '⏳ Real-time Prediction: Waiting for all sensor data... '
                '(MQ2: ${latestMq2 != null ? latestMq2.toStringAsFixed(1) : "?"}, '
                'MQ9: ${latestMq9 != null ? latestMq9.toStringAsFixed(1) : "?"}, '
                'Flame: ${latestFlame != null ? latestFlame.toStringAsFixed(1) : "?"})',
              );
              return;
            }

            // Debounce: Cancel previous timer if it exists
            _debounceTimer?.cancel();

            // Set up debounce timer to prevent too many predictions
            _debounceTimer = Timer(_predictionDebounceDelay, () async {
              try {
                print('\n🔄 Sensor data updated - Running prediction...');
                print(
                  ' MQ2: ${latestMq2.toStringAsFixed(1)}, '
                  'MQ9: ${latestMq9.toStringAsFixed(1)}, '
                  'Flame: ${latestFlame.toStringAsFixed(1)}',
                );

                // Make prediction with latest sensor values
                final result = await predictWithValues(
                  latestMq2,
                  latestMq9,
                  latestFlame,
                );

                // Print formatted prediction
                printPrediction(result);

                // Save prediction to Firestore ONLY (NOT to RTDB)
                // RTDB is only used for reading sensor data, not storing predictions
                if (result != null) {
                  // Save/update prediction in Firestore (single document gets updated)
                  await _savePredictionToFirestore(deviceId, result);
                }
              } catch (e, stackTrace) {
                print('❌ Error during real-time prediction: $e');
                print('Stack trace: $stackTrace');
              }
            });
          },
          onError: (error) {
            print('❌ Real-time Database listener error: $error');
          },
        );

    _isListening = true;
    print('✅ Real-time prediction listener started!');
    print(
      ' Predictions will be printed automatically when sensor data changes.\n',
    );
  }

  /// Stop listening to real-time predictions for a specific device
  void stopRealtimePrediction([String? deviceId]) {
    if (deviceId != null) {
      // Stop specific device listener
      _deviceListeners[deviceId]?.cancel();
      _deviceListeners.remove(deviceId);
      print('🛑 Stopped real-time prediction listener for device $deviceId');
    } else {
      // Stop single device listener (legacy method)
      if (_realtimeListener != null) {
        _realtimeListener!.cancel();
        _realtimeListener = null;
        print('🛑 Real-time prediction listener stopped');
      }
    }

    // Update listening state
    _isListening = _deviceListeners.isNotEmpty || _realtimeListener != null;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    // Reset stored values
    _lastSensorValues = {'mq2': null, 'mq9': null, 'flame': null};
  }

  /// Stop all real-time prediction listeners
  void stopAllRealtimePredictions() {
    // Stop all device listeners
    for (var entry in _deviceListeners.entries) {
      entry.value.cancel();
      print('🛑 Stopped real-time prediction listener for device ${entry.key}');
    }
    _deviceListeners.clear();

    // Stop single device listener (legacy)
    if (_realtimeListener != null) {
      _realtimeListener!.cancel();
      _realtimeListener = null;
    }

    _isListening = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    // Reset stored values
    _lastSensorValues = {'mq2': null, 'mq9': null, 'flame': null};
    print('🛑 All real-time prediction listeners stopped');
  }

  /// Internal method to start real-time prediction for a specific device
  /// This is used by startListeningToAllUserDevices to listen to multiple devices
  /// Only listens to devices that belong to the current user
  Future<void> _startRealtimePredictionForDevice(String deviceId) async {
    // Don't start if already listening to this device
    if (_deviceListeners.containsKey(deviceId)) {
      print(
        'Fire Prediction Service: Already listening to device $deviceId, skipping',
      );
      return;
    }

    final dbRef = FirebaseDatabase.instance.ref();

    // Reset last known values for this device
    _lastSensorValues = {'mq2': null, 'mq9': null, 'flame': null};

    // Set up real-time listener for this device
    final listener = dbRef
        .child('Devices/$deviceId')
        .onValue
        .listen(
          (event) async {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data == null) {
              return;
            }

            // Extract sensor values
            final mq2 = _parseDouble(data['MQ2'] ?? data['mq2']);
            final mq9 = _parseDouble(data['MQ9'] ?? data['mq9']);
            final flame = _parseDouble(data['Flame'] ?? data['flame']);

            // Update last known values
            if (mq2 != null) _lastSensorValues['mq2'] = mq2;
            if (mq9 != null) _lastSensorValues['mq9'] = mq9;
            if (flame != null) _lastSensorValues['flame'] = flame;

            // Get the latest values
            final latestMq2 = mq2 ?? _lastSensorValues['mq2'];
            final latestMq9 = mq9 ?? _lastSensorValues['mq9'];
            final latestFlame = flame ?? _lastSensorValues['flame'];

            // Check if we have all required sensor values
            if (latestMq2 == null || latestMq9 == null || latestFlame == null) {
              return;
            }

            // Debounce: Cancel previous timer if it exists
            _debounceTimer?.cancel();

            // Set up debounce timer to prevent too many predictions
            _debounceTimer = Timer(_predictionDebounceDelay, () async {
              try {
                // Make prediction with latest sensor values
                final result = await predictWithValues(
                  latestMq2,
                  latestMq9,
                  latestFlame,
                );

                // Print formatted prediction
                printPrediction(result);

                // Save prediction to Firestore (only for the current user's device)
                if (result != null) {
                  await _savePredictionToFirestore(deviceId, result);
                }
              } catch (e, stackTrace) {
                print('❌ Error during real-time prediction for $deviceId: $e');
                print('Stack trace: $stackTrace');
              }
            });
          },
          onError: (error) {
            print('❌ Real-time Database listener error for $deviceId: $error');
          },
        );

    _deviceListeners[deviceId] = listener;
    print('✅ Started real-time prediction listener for device $deviceId');
  }

  /// Save prediction result to Firestore under user's device collection
  ///
  /// NOTE: Predictions are ONLY stored in Firestore, NOT in RTDB.
  /// RTDB is only used for reading sensor data.
  /// The prediction is stored directly in the device document as 'alarmType'.
  /// Path: users/{userId}/devices/{deviceId}
  Future<void> _savePredictionToFirestore(
    String deviceId,
    Map<String, dynamic> predictionResult,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ Cannot save prediction: User not logged in');
        return;
      }

      // Get the predicted label
      final predictedLabel = predictionResult['label'] as String;
      final confidence = predictionResult['confidence'] as double;

      // Get previous alarmType to detect changes
      final previousAlarmType = _previousAlarmTypes[deviceId];

      // Update the device document directly with alarmType field
      // Path: users/{userId}/devices/{deviceId}
      final deviceDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId);

      // Get device data to retrieve name and address for notification
      final deviceDoc = await deviceDocRef.get();
      final deviceData = deviceDoc.data();
      final deviceName = deviceData?['name'] as String? ?? 'Your device';
      final deviceAddress = deviceData?['address'] as String?;

      await deviceDocRef.update({
        'alarmType': predictedLabel,
        'lastPrediction': {
          'label': predictedLabel,
          'confidence': confidence,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'lastPredictionAt': FieldValue.serverTimestamp(),
      });

      // Update previous alarmType
      _previousAlarmTypes[deviceId] = predictedLabel;

      // Update RTDB Alarm field based on alarmType
      await _updateRTDBAlarm(deviceId, predictedLabel, previousAlarmType);

      // Send notification if alarmType changed to "smoke"
      if (predictedLabel == 'smoke' && previousAlarmType != 'smoke') {
        await _sendSmokeNotification(deviceId, deviceName, deviceAddress);
      }

      print(
        '✅ Updated alarmType in Firestore for device $deviceId: $predictedLabel '
        '(${(confidence * 100).toStringAsFixed(1)}% confidence)',
      );
    } catch (e, stackTrace) {
      print('❌ Error saving prediction to Firestore: $e');
      print('Stack trace: $stackTrace');
      // Don't throw - we don't want save errors to crash the prediction flow
    }
  }

  /// Start listening to all devices for the current logged-in user
  /// This will fetch all devices from the user's Firestore collection and start
  /// real-time prediction listeners for each device
  ///
  /// IMPORTANT: Only listens to devices that belong to the current user
  /// Devices are fetched from: users/{userId}/devices
  Future<void> startListeningToAllUserDevices() async {
    // Stop any existing listeners first
    stopAllRealtimePredictions();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print(
        'Fire Prediction Service: No user logged in, cannot start listening',
      );
      return;
    }

    final userId = user.uid;
    print(
      'Fire Prediction Service: Starting to listen to all devices for user $userId',
    );

    // Load model if not already loaded
    if (!_isModelLoaded || _interpreter == null) {
      print('Fire Prediction Service: Loading model...');
      final loaded = await loadModel();
      if (!loaded) {
        print(
          'Fire Prediction Service: Failed to load model. Cannot start listening.',
        );
        return;
      }
    }

    // Fetch all devices from the current user's Firestore collection
    // Path: users/{userId}/devices - ensures we only get this user's devices
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('devices')
              .get();

      print(
        'Fire Prediction Service: Found ${snapshot.docs.length} device(s) for user $userId',
      );

      if (snapshot.docs.isEmpty) {
        print(
          'Fire Prediction Service: No devices found for user $userId. Predictions will start when devices are added.',
        );
        return;
      }

      // Start listening to each device that belongs to this user
      for (var doc in snapshot.docs) {
        final deviceData = doc.data();
        final deviceId = deviceData['deviceId'] as String?;

        if (deviceId != null) {
          // Initialize previous alarmType to current value to avoid false notifications
          final currentAlarmType = deviceData['alarmType'] as String?;
          _previousAlarmTypes[deviceId] = currentAlarmType;

          // Sync RTDB Alarm field if device already has alarmType="fire"
          if (currentAlarmType != null && currentAlarmType == 'fire') {
            await _updateRTDBAlarm(deviceId, currentAlarmType, null);
          }

          print(
            'Fire Prediction Service: Starting prediction listener for user device $deviceId (user: $userId)',
          );
          await _startRealtimePredictionForDevice(deviceId);
        } else {
          print(
            'Fire Prediction Service: Device document ${doc.id} has no deviceId, skipping',
          );
        }
      }

      _isListening = _deviceListeners.isNotEmpty;
      if (_isListening) {
        print(
          '✅ Fire Prediction Service: Started listening to ${_deviceListeners.length} device(s) for user $userId',
        );
      }
    } catch (e, stackTrace) {
      print('Fire Prediction Service: Error fetching user devices: $e');
      print('Stack trace: $stackTrace');
      // Don't let Firestore errors crash the app
    }
  }

  /// Update RTDB Alarm field based on alarmType
  /// Sets Alarm to true when alarmType is "fire", false otherwise
  Future<void> _updateRTDBAlarm(
    String deviceId,
    String currentAlarmType,
    String? previousAlarmType,
  ) async {
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final alarmPath = 'Devices/$deviceId/Alarm';

      // If alarmType is "fire", set Alarm to true
      if (currentAlarmType == 'fire') {
        // Only update if it wasn't already fire (avoid unnecessary writes)
        if (previousAlarmType != 'fire') {
          await dbRef
              .child(alarmPath)
              .set(true)
              .timeout(const Duration(seconds: 5));
          print(
            '✅ Updated RTDB Alarm to true for device $deviceId (fire detected)',
          );
        }
      } else {
        // If alarmType changed from "fire" to something else, set Alarm to false
        if (previousAlarmType == 'fire') {
          await dbRef
              .child(alarmPath)
              .set(false)
              .timeout(const Duration(seconds: 5));
          print(
            '✅ Updated RTDB Alarm to false for device $deviceId '
            '(alarmType changed from fire to $currentAlarmType)',
          );
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error updating RTDB Alarm: $e');
      print('Stack trace: $stackTrace');
      // Don't throw - RTDB update errors shouldn't crash the prediction flow
    }
  }

  /// Send smoke detection notification to the user
  Future<void> _sendSmokeNotification(
    String deviceId,
    String deviceName,
    String? deviceAddress,
  ) async {
    try {
      // Build notification message with device location if available
      String notificationBody;
      if (deviceAddress != null && deviceAddress.isNotEmpty) {
        notificationBody =
            'Smoke or gas leak detected by $deviceName located at $deviceAddress. '
            'Please check the sensor immediately to ensure safety.';
      } else {
        notificationBody =
            'Smoke or gas leak detected by $deviceName. '
            'Please check the sensor immediately to ensure safety.';
      }

      await NotificationService().showNotification(
        title: 'Smoke/Gas Detection Alert',
        body: notificationBody,
        deviceId: deviceId,
      );

      print(
        '✅ Smoke detection notification sent for device $deviceId ($deviceName)',
      );
    } catch (e, stackTrace) {
      print('❌ Error sending smoke notification: $e');
      print('Stack trace: $stackTrace');
      // Don't throw - notification errors shouldn't crash the prediction flow
    }
  }

  /// Check if currently listening to real-time predictions
  bool get isListening => _isListening;

  /// Dispose resources
  void dispose() {
    stopAllRealtimePredictions();
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    _previousAlarmTypes.clear();
  }
}
